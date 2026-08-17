// SPDX-FileCopyrightText: 2026 Benjamin Bellamy <benjamin@castopod.org>
// SPDX-License-Identifier: AGPL-3.0-or-later

namespace Awale {

    /** What a stored score is worth relative to the window it was found in. */
    internal enum TranspositionBound {
        /** The score is the true value of the position. */
        EXACT,
        /** The true value is at least the stored score. */
        LOWER,
        /** The true value is at most the stored score. */
        UPPER
    }

    internal struct TranspositionEntry {
        public bool occupied;
        public Board position;
        public int depth;
        public int score;
        public int best_move;
        public TranspositionBound bound;
    }

    /** One move available at the root, with the score the search gave it. */
    public struct MoveScore {
        public int house;
        public int score;
    }

    public struct SearchResult {
        /** House to play, or -1 when the position has no legal move at all. */
        public int best_move;
        public int score;
        /** Deepest iteration that finished. Lower than asked for means the budget ran out. */
        public int depth_reached;
        public int64 nodes;
        public int64 elapsed_ms;
        /** Every root move with its score, best first. Empty when nothing is playable. */
        public MoveScore[] moves;
    }

    /**
     * Negamax with alpha-beta pruning, iterative deepening, move ordering and a
     * transposition table.
     *
     * The search is synchronous and deterministic: the same board searched to
     * the same depth by a freshly cleared instance always gives the same
     * answer. Anything random belongs in {@link Opponent}, above this class.
     *
     * The repetition and no capture guards of RULES.md 6.2 are deliberately
     * ignored here. They depend on the history of the game, which a bare
     * {@link Board} does not carry, and at these depths they cannot be reached
     * from a fresh position anyway.
     */
    public class Search : Object {

        /** Scores at or beyond this decide the game instead of estimating it. */
        public const int DECISIVE_THRESHOLD = 90000;

        private const int WIN_SCORE = 100000;
        private const int SCORE_INFINITY = 1000000;
        private const int TABLE_SIZE = 1 << 16;
        /** Nodes between two readings of the clock, minus one. Must be 2^n - 1. */
        private const int64 CLOCK_CHECK_MASK = 1023;

        public GrandSlamPolicy grand_slam_policy {
            get; set; default = GrandSlamPolicy.LEGAL_NO_CAPTURE;
        }

        /** Off for the shallow difficulty levels, which cannot profit from it. */
        public bool use_transposition_table { get; set; default = true; }

        /**
         * Whether reaching {@link WINNING_SEEDS} settles the game, as RULES.md
         * 6.1 says. With it off, a decided position is scored on material like
         * any other, which is what a caller playing a won game out needs: every
         * line being a win tells the player nothing.
         */
        public bool end_at_winning_score { get; set; default = true; }

        private TranspositionEntry[] table = new TranspositionEntry[TABLE_SIZE];
        private int64 deadline;
        private int64 node_count;
        private bool aborted;

        /** Forgets everything learned about previous positions. */
        public void clear () {
            table = new TranspositionEntry[TABLE_SIZE];
        }

        /**
         * Searches {@link board} to at most {@link max_depth} plies, stopping
         * early if {@link time_budget_ms} runs out. An iteration that does not
         * finish is thrown away, so the answer always comes from a fully
         * searched depth.
         */
        public SearchResult search (Board board, int max_depth, int64 time_budget_ms) {
            int64 started = get_monotonic_time ();
            deadline = started + time_budget_ms * 1000;
            node_count = 0;
            aborted = false;

            SearchResult result = SearchResult ();
            result.best_move = -1;
            result.score = 0;
            result.depth_reached = 0;
            result.moves = new MoveScore[0];

            int[] moves = board.legal_moves (grand_slam_policy);
            if (moves.length == 0) {
                result.elapsed_ms = milliseconds_since (started);
                return result;
            }

            var children = new Board[moves.length];
            var order = new int[moves.length];
            for (int i = 0; i < moves.length; i++) {
                children[i] = board.copy ();
                order[i] = children[i].apply_move (moves[i], grand_slam_policy).captured;
            }
            order_moves (moves, children, order);
            result.best_move = moves[0];

            for (int depth = 1; depth <= max_depth; depth++) {
                var scored = new MoveScore[moves.length];
                for (int i = 0; i < moves.length; i++) {
                    // A full window for every root move, so that each reported
                    // score is the real value rather than a bound. Opponent
                    // needs those scores to tie-break, and there are at most
                    // six of them.
                    MoveScore entry = MoveScore ();
                    entry.house = moves[i];
                    entry.score = -negamax (children[i], depth - 1,
                                            -SCORE_INFINITY, SCORE_INFINITY, 1);
                    scored[i] = entry;
                    if (aborted) {
                        break;
                    }
                }
                if (aborted) {
                    break;
                }

                sort_by_score (scored);
                result.moves = scored;
                result.best_move = scored[0].house;
                result.score = scored[0].score;
                result.depth_reached = depth;

                promote (moves, children, result.best_move);

                if (result.score >= DECISIVE_THRESHOLD || result.score <= -DECISIVE_THRESHOLD) {
                    break;
                }
            }

            result.nodes = node_count;
            result.elapsed_ms = milliseconds_since (started);
            return result;
        }

        private int negamax (Board board, int depth, int alpha, int beta, int ply) {
            node_count++;
            if ((node_count & CLOCK_CHECK_MASK) == 0 && get_monotonic_time () >= deadline) {
                aborted = true;
                return 0;
            }

            // RULES.md 6.1, decided before anything else is worth computing.
            bool decided = board.south_store >= WINNING_SEEDS
                || board.north_store >= WINNING_SEEDS;
            if ((end_at_winning_score && decided) || board.seeds_on_board () == 0) {
                return decisive_score (board, ply);
            }
            if (!board.has_legal_move (grand_slam_policy)) {
                return no_move_score (board, ply);
            }
            if (depth <= 0) {
                return evaluate (board, board.to_move, grand_slam_policy);
            }

            int table_move = -1;
            int index = 0;
            if (use_transposition_table) {
                index = (int) (position_hash (board) % TABLE_SIZE);
                TranspositionEntry entry = table[index];
                if (entry.occupied && entry.position.equals (board)) {
                    table_move = entry.best_move;
                    if (entry.depth >= depth) {
                        int stored = score_from_table (entry.score, ply);
                        if (entry.bound == TranspositionBound.EXACT
                            || (entry.bound == TranspositionBound.LOWER && stored >= beta)
                            || (entry.bound == TranspositionBound.UPPER && stored <= alpha)) {
                            return stored;
                        }
                    }
                }
            }

            int[] moves = board.legal_moves (grand_slam_policy);
            var children = new Board[moves.length];
            var order = new int[moves.length];
            for (int i = 0; i < moves.length; i++) {
                children[i] = board.copy ();
                int captured = children[i].apply_move (moves[i], grand_slam_policy).captured;
                // The move the table already liked goes first, then the ones
                // that take the most seeds.
                order[i] = captured + (moves[i] == table_move ? 1000 : 0);
            }
            order_moves (moves, children, order);

            int original_alpha = alpha;
            int best_score = -SCORE_INFINITY;
            int best_move = moves[0];
            for (int i = 0; i < moves.length; i++) {
                int score = -negamax (children[i], depth - 1, -beta, -alpha, ply + 1);
                if (aborted) {
                    return 0;
                }
                if (score > best_score) {
                    best_score = score;
                    best_move = moves[i];
                }
                if (best_score > alpha) {
                    alpha = best_score;
                }
                if (alpha >= beta) {
                    break;
                }
            }

            if (use_transposition_table) {
                TranspositionEntry entry = TranspositionEntry ();
                entry.occupied = true;
                entry.position = board.copy ();
                entry.depth = depth;
                entry.score = score_to_table (best_score, ply);
                entry.best_move = best_move;
                if (best_score >= beta) {
                    entry.bound = TranspositionBound.LOWER;
                } else if (best_score <= original_alpha) {
                    entry.bound = TranspositionBound.UPPER;
                } else {
                    entry.bound = TranspositionBound.EXACT;
                }
                table[index] = entry;
            }
            return best_score;
        }

        /** Scores a decided position from the point of view of the side to move. */
        private int decisive_score (Board board, int ply) {
            int mine = board.store (board.to_move);
            int theirs = board.store (board.to_move.opponent ());
            if (mine > theirs) {
                // Subtracting the ply prefers winning sooner and losing later.
                return WIN_SCORE - ply;
            }
            if (mine < theirs) {
                return -(WIN_SCORE - ply);
            }
            return 0;
        }

        /** Scores a position whose player to move has nothing legal to play. */
        private int no_move_score (Board board, int ply) {
            if (board.has_sowable_move ()) {
                // RULES.md 6.4, only reachable under GrandSlamPolicy.FORBIDDEN.
                return 0;
            }
            // RULES.md 6.3, the board goes to the player who cannot move.
            Board settled = board.copy ();
            settled.collect_board (settled.to_move);
            return decisive_score (settled, ply);
        }

        /**
         * A decisive score counts plies from the root, so it has to be made
         * relative to the node before it is stored and absolute again when it
         * is read back, or the table hands out wrong distances.
         */
        private int score_to_table (int score, int ply) {
            if (score >= DECISIVE_THRESHOLD) {
                return score + ply;
            }
            if (score <= -DECISIVE_THRESHOLD) {
                return score - ply;
            }
            return score;
        }

        private int score_from_table (int score, int ply) {
            if (score >= DECISIVE_THRESHOLD) {
                return score - ply;
            }
            if (score <= -DECISIVE_THRESHOLD) {
                return score + ply;
            }
            return score;
        }

        /** FNV-1a over the whole position. Collisions are caught by comparing boards. */
        private uint64 position_hash (Board board) {
            uint64 hash = 14695981039346656037U;
            for (int house = 0; house < HOUSE_COUNT; house++) {
                hash = (hash ^ (uint64) board.houses[house]) * 1099511628211U;
            }
            hash = (hash ^ (uint64) board.south_store) * 1099511628211U;
            hash = (hash ^ (uint64) board.north_store) * 1099511628211U;
            hash = (hash ^ (uint64) board.to_move) * 1099511628211U;
            return hash;
        }

        /** Sorts moves and their boards together, highest order value first. */
        private void order_moves (int[] moves, Board[] children, int[] order) {
            for (int i = 1; i < moves.length; i++) {
                int move = moves[i];
                Board child = children[i];
                int key = order[i];
                int j = i - 1;
                while (j >= 0 && order[j] < key) {
                    moves[j + 1] = moves[j];
                    children[j + 1] = children[j];
                    order[j + 1] = order[j];
                    j--;
                }
                moves[j + 1] = move;
                children[j + 1] = child;
                order[j + 1] = key;
            }
        }

        /** Stable insertion sort, highest score first, so ties keep house order. */
        private void sort_by_score (MoveScore[] scored) {
            for (int i = 1; i < scored.length; i++) {
                MoveScore entry = scored[i];
                int j = i - 1;
                while (j >= 0 && scored[j].score < entry.score) {
                    scored[j + 1] = scored[j];
                    j--;
                }
                scored[j + 1] = entry;
            }
        }

        /** Moves one house to the front so the next iteration searches it first. */
        private void promote (int[] moves, Board[] children, int house) {
            for (int i = 0; i < moves.length; i++) {
                if (moves[i] != house) {
                    continue;
                }
                int move = moves[i];
                Board child = children[i];
                for (int j = i; j > 0; j--) {
                    moves[j] = moves[j - 1];
                    children[j] = children[j - 1];
                }
                moves[0] = move;
                children[0] = child;
                return;
            }
        }

        private int64 milliseconds_since (int64 started) {
            return (get_monotonic_time () - started) / 1000;
        }
    }
}
