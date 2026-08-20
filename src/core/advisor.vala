// SPDX-FileCopyrightText: 2026 Benjamin Bellamy <benjamin@castopod.org>
// SPDX-License-Identifier: AGPL-3.0-or-later

namespace Awale {

    /** Why the advisor recommends a move. */
    public enum AdviceKind {
        /** It takes seeds straight away. */
        CAPTURES,
        /** It keeps the opponent from taking one of your houses next turn. */
        PROTECTS,
        /** The opponent is starving and this move feeds them (RULES.md 4). */
        FEEDS,
        /** Nothing else is legal. */
        ONLY_MOVE,
        /** No tactic either way, it simply leaves the better position. */
        BUILDS
    }

    /** A ranking of the moves available, and a reason for the best of them. */
    public struct Advice {
        /** House to recommend, or -1 when there is nothing to play. */
        public int best_house;
        public AdviceKind kind;
        /**
         * The number the reason is about: seeds captured, or seeds the
         * computer is threatening to take.
         */
        public int seeds;
        /**
         * The houses the threatened capture would take, when {@link kind} is
         * PROTECTS.
         *
         * Read off the position as it stands, so a player can look at every
         * house named. A capture runs backwards through the houses it was sown
         * into for as long as they qualify (RULES.md 3.1), so it is usually
         * more than one, and the computer drops one of its own seeds in each
         * of them on the way past, which is why they hold fewer seeds between
         * them than {@link seeds} says would be taken.
         */
        public int[] exposed_houses;
        /**
         * The most the opponent could take straight back, when {@link kind} is
         * CAPTURES. A capture is not the gain it looks like when the reply
         * takes more than it won, so the hint has to be able to say so.
         */
        public int reply;
        /** Every legal move with its score, best first. */
        public MoveScore[] moves;

        /**
         * A move that looks better than the recommendation but is not, or -1.
         *
         * Only offered when the recommendation neither wins seeds now nor
         * keeps any safe now, while this one does. That is the case where a
         * player has every reason to distrust the star, so the board can say
         * what the tempting move really costs.
         */
        public int tempting_house;
        /** What {@link tempting_house} wins now, and what comes straight back. */
        public int tempting_captures;
        public int tempting_reply;
    }

    /**
     * Ranks the player's moves and works out, in engine terms, why the best one
     * is best. The reason comes back as data rather than as a sentence: turning
     * it into words is the user interface's job, because the words have to be
     * translated and this layer has no business knowing about language.
     *
     * Always searches at the Hard depth, whatever the opponent's difficulty is
     * set to, because a hint that is worse than the opponent would be useless.
     */
    public class Advisor : Object {

        public GrandSlamPolicy grand_slam_policy {
            get; set; default = GrandSlamPolicy.LEGAL_NO_CAPTURE;
        }

        private Search engine = new Search ();

        public Advice advise (Board board) {
            Advice advice = Advice ();
            advice.best_house = -1;
            advice.kind = AdviceKind.BUILDS;
            advice.moves = new MoveScore[0];

            engine.grand_slam_policy = grand_slam_policy;
            engine.use_transposition_table = true;

            SearchResult result = engine.search (board,
                                                 Difficulty.HARD.max_depth (),
                                                 Difficulty.HARD.time_budget_ms ());
            if (result.best_move < 0) {
                return advice;
            }

            advice.moves = result.moves;
            advice.best_house = pick_among_equals (board, result.moves);
            explain (board, ref advice);
            find_temptation (board, ref advice);
            return advice;
        }

        /**
         * Which of the moves the search rated equally to recommend.
         *
         * Taking whichever one the search listed first is not the neutral
         * choice it looks like. That order is the search's own move ordering,
         * kept because a stable sort leaves it alone, and following it measured
         * 9 wins to 20 losses over thirty games against the Hard opponent where
         * spreading the choice across the tied moves measured 16 to 12.
         *
         * The tied moves are put in house order before choosing, so the choice
         * depends only on which moves tie and not on an order the search never
         * promised to keep. The position then picks, so a player looking at the
         * same board is always told the same move while no house is favoured
         * across positions.
         */
        private int pick_among_equals (Board board, MoveScore[] moves) {
            if (moves.length == 0) {
                return -1;
            }

            int[] tied = {};
            foreach (MoveScore scored in moves) {
                if (scored.score == moves[0].score) {
                    tied += scored.house;
                }
            }

            // Insertion sort: there are never more than six of these.
            for (int i = 1; i < tied.length; i++) {
                int moving = tied[i];
                int j = i - 1;
                while (j >= 0 && tied[j] > moving) {
                    tied[j + 1] = tied[j];
                    j--;
                }
                tied[j + 1] = moving;
            }

            return tied[(int) (board.fingerprint () % tied.length)];
        }

        /** Runs {@link advise} on a worker thread so the window stays alive. */
        public async Advice advise_async (Board board) {
            SourceFunc resume = advise_async.callback;
            Advice advice = Advice ();

            var worker = new Thread<void> ("awale-advisor", () => {
                advice = advise (board);
                Idle.add ((owned) resume);
            });

            yield;
            worker.join ();
            return advice;
        }

        public void reset () {
            engine.clear ();
        }

        private void explain (Board board, ref Advice advice) {
            int[] legal = board.legal_moves (grand_slam_policy);

            // Being forced comes first: when there is no choice to make, that
            // is more use to the player than anything about the move itself.
            if (legal.length == 1) {
                advice.kind = AdviceKind.ONLY_MOVE;
                return;
            }

            MoveTrace trace = board.trace_move (advice.best_house, grand_slam_policy);
            if (trace.captured > 0) {
                advice.kind = AdviceKind.CAPTURES;
                advice.seeds = trace.captured;
                advice.reply = worst_reply (board, advice.best_house, null);
                return;
            }
            if (board.row_is_empty (board.to_move.opponent ())) {
                advice.kind = AdviceKind.FEEDS;
                return;
            }
            if (explains_protection (board, legal, ref advice)) {
                return;
            }
            advice.kind = AdviceKind.BUILDS;
            advice.seeds = 0;
        }

        /**
         * True when the recommendation puts a capture the computer is set up
         * to make out of reach, and some other move would leave it there.
         *
         * The threat is read off the position the player is looking at, so
         * every house named still holds the seeds it is named for. Working it
         * out on the board that follows some other move instead, as this once
         * did, names houses whose seeds cannot be counted anywhere: it would
         * point at an empty house and say two seeds were about to be lost from
         * it.
         */
        private bool explains_protection (Board board, int[] legal, ref Advice advice) {
            int[] threatened;
            int threat = standing_threat (board, out threatened);
            if (threat == 0) {
                return false;
            }
            // The claim is that these houses come to no harm, so it is only
            // made when nothing the computer can reply with touches them.
            if (!houses_survive (board, advice.best_house, threatened)) {
                return false;
            }

            bool another_leaves_them = false;
            foreach (int move in legal) {
                if (move != advice.best_house
                    && !houses_survive (board, move, threatened)) {
                    another_leaves_them = true;
                    break;
                }
            }
            if (!another_leaves_them) {
                // Every move saves them, so saving them is not why this one
                // was chosen.
                return false;
            }

            advice.kind = AdviceKind.PROTECTS;
            advice.seeds = threat;
            advice.exposed_houses = in_row_order (threatened);
            return true;
        }

        /**
         * The most the computer could capture if it were to move on the
         * position as it stands, and the houses it would empty.
         *
         * Only captures whose houses all hold a seed already are counted. A
         * chain running through an empty house is taking seeds the computer
         * is about to sow there itself, and pointing at an empty house to say
         * two seeds are about to be lost from it is precisely the advice a
         * player cannot check against the board.
         */
        private int standing_threat (Board board, out int[] threatened) {
            threatened = new int[0];

            Board turned = board.copy ();
            turned.to_move = board.to_move.opponent ();

            int most = 0;
            foreach (int move in turned.legal_moves (grand_slam_policy)) {
                MoveTrace trace = turned.trace_move (move, grand_slam_policy);
                if (trace.captured <= most || !all_occupied (board, trace.captured_houses)) {
                    continue;
                }
                most = trace.captured;
                threatened = trace.captured_houses;
            }
            return most;
        }

        /** True when every one of {@link houses} holds a seed already. */
        private bool all_occupied (Board board, int[] houses) {
            if (houses.length == 0) {
                return false;
            }
            foreach (int house in houses) {
                if (board.houses[house] == 0) {
                    return false;
                }
            }
            return true;
        }

        /** True when no reply to {@link move} can take any of {@link houses}. */
        private bool houses_survive (Board board, int move, int[] houses) {
            Board after = board.copy ();
            after.apply_move (move, grand_slam_policy);
            foreach (int reply in after.legal_moves (grand_slam_policy)) {
                MoveTrace trace = after.trace_move (reply, grand_slam_policy);
                foreach (int taken in trace.captured_houses) {
                    foreach (int house in houses) {
                        if (taken == house) {
                            return false;
                        }
                    }
                }
            }
            return true;
        }

        /**
         * Finds the move a player would most likely play instead of the one
         * recommended, when the recommendation shows nothing for itself.
         *
         * A recommendation that takes seeds, or that leaves the opponent no
         * capture in reply, speaks for itself and nothing is offered. It is
         * when the star sits on a move that does neither, while another move
         * does one of them, that the advice looks wrong and is worth
         * defending.
         *
         * Both tests look one move ahead only. That is the whole point: the
         * move that looks better one move ahead is the one a player reaches
         * for, and the recommendation is what the search prefers once the game
         * runs on past it.
         */
        private void find_temptation (Board board, ref Advice advice) {
            advice.tempting_house = -1;
            advice.tempting_captures = 0;
            advice.tempting_reply = 0;

            int best_gain = board.trace_move (advice.best_house, grand_slam_policy).captured;
            int best_exposure = worst_reply (board, advice.best_house, null);
            if (best_gain > 0 || best_exposure == 0) {
                return;
            }

            foreach (int move in board.legal_moves (grand_slam_policy)) {
                if (move == advice.best_house) {
                    continue;
                }
                int gain = board.trace_move (move, grand_slam_policy).captured;
                int exposure = worst_reply (board, move, null);
                if (gain == 0 && exposure > 0) {
                    // Shows no more for itself than the recommendation does.
                    continue;
                }
                bool more_tempting = advice.tempting_house < 0
                    || gain > advice.tempting_captures
                    || (gain == advice.tempting_captures
                        && exposure < advice.tempting_reply);
                if (more_tempting) {
                    advice.tempting_house = move;
                    advice.tempting_captures = gain;
                    advice.tempting_reply = exposure;
                }
            }
        }

        /** The chain walks backwards, so it is put back into board order. */
        private int[] in_row_order (int[] houses) {
            int[] sorted = houses;
            for (int i = 1; i < sorted.length; i++) {
                int moving = sorted[i];
                int j = i - 1;
                while (j >= 0 && sorted[j] > moving) {
                    sorted[j + 1] = sorted[j];
                    j--;
                }
                sorted[j + 1] = moving;
            }
            return sorted;
        }

        /**
         * The most the opponent could capture immediately after {@link move},
         * and the houses they would take it from.
         */
        private int worst_reply (Board board, int move, out int[] exposed_houses) {
            Board after = board.copy ();
            after.apply_move (move, grand_slam_policy);
            return best_capture (after, out exposed_houses);
        }

        /** The biggest capture open to whoever is to move, and where from. */
        private int best_capture (Board board, out int[] taken_from) {
            taken_from = new int[0];

            int most = 0;
            foreach (int move in board.legal_moves (grand_slam_policy)) {
                MoveTrace trace = board.trace_move (move, grand_slam_policy);
                if (trace.captured > most) {
                    most = trace.captured;
                    taken_from = trace.captured_houses;
                }
            }
            return most;
        }
    }
}
