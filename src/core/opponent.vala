// SPDX-FileCopyrightText: 2026 Benjamin Bellamy <benjamin@castopod.org>
// SPDX-License-Identifier: AGPL-3.0-or-later

namespace Awale {

    /** How hard the computer plays. Swappable at any point during a game. */
    public enum Difficulty {
        EASY,
        MEDIUM,
        HARD;

        /** Plies the search is allowed to look ahead. */
        public int max_depth () {
            switch (this) {
                case EASY:   return 2;
                case MEDIUM: return 6;
                default:     return 12;
            }
        }

        /** Wall clock the search is allowed to spend. */
        public int64 time_budget_ms () {
            switch (this) {
                case EASY:   return 100;
                case MEDIUM: return 300;
                default:     return 1000;
            }
        }

        /** Only the deepest level is given a transposition table. */
        public bool uses_transposition_table () {
            return this == HARD;
        }

        public string to_keyword () {
            switch (this) {
                case EASY:   return "easy";
                case MEDIUM: return "medium";
                default:     return "hard";
            }
        }

        /**
         * The reverse of {@link to_keyword}, so that the set of level names is
         * written down once. Callers decide what an unknown name means: the
         * settings fall back to a level, the command line refuses it.
         */
        public static bool from_keyword (string keyword, out Difficulty level) {
            switch (keyword) {
                case "easy":   level = EASY;   return true;
                case "medium": level = MEDIUM; return true;
                case "hard":   level = HARD;   return true;
                default:       level = MEDIUM; return false;
            }
        }
    }

    /**
     * How often Easy ignores the search altogether and plays any legal move.
     * This is what makes Easy beatable by a beginner rather than merely short
     * sighted.
     */
    public const double EASY_RANDOM_MOVE_CHANCE = 0.20;

    /**
     * How far below the best score a move may be and still be picked by Easy,
     * expressed in evaluation units. Two banked seeds.
     */
    public const int EASY_SCORE_TOLERANCE = 2 * WEIGHT_STORE_DIFFERENTIAL;

    /**
     * Chooses the computer's move. This is where difficulty lives, so that
     * {@link Search} stays deterministic and the levels differ only in how far
     * they look and how faithfully they follow what they found.
     *
     * Given the same seed and the same sequence of positions, an Opponent
     * always plays the same moves.
     */
    public class Opponent : Object {

        public Difficulty difficulty { get; set; default = Difficulty.MEDIUM; }

        public GrandSlamPolicy grand_slam_policy {
            get; set; default = GrandSlamPolicy.LEGAL_NO_CAPTURE;
        }

        /** Matches {@link Game.end_at_winning_score} of the game being played. */
        public bool end_at_winning_score { get; set; default = true; }

        private Search engine = new Search ();
        private Rand random;

        public Opponent (Difficulty difficulty = Difficulty.MEDIUM, uint32 seed = 1) {
            Object (difficulty: difficulty);
            random = new Rand.with_seed (seed);
        }

        /**
         * Picks a house to play, or -1 when the position has no legal move.
         * Never returns a move the rules do not allow.
         */
        public int choose_move (Board board) {
            int[] legal = board.legal_moves (grand_slam_policy);
            if (legal.length == 0) {
                return -1;
            }

            if (difficulty == Difficulty.EASY
                && random.next_double () < EASY_RANDOM_MOVE_CHANCE) {
                return legal[random.int_range (0, legal.length)];
            }

            engine.grand_slam_policy = grand_slam_policy;
            engine.use_transposition_table = difficulty.uses_transposition_table ();
            engine.end_at_winning_score = end_at_winning_score;
            SearchResult result = engine.search (board,
                                                 difficulty.max_depth (),
                                                 difficulty.time_budget_ms ());
            if (result.moves.length == 0) {
                return legal[0];
            }

            int tolerance = difficulty == Difficulty.EASY ? EASY_SCORE_TOLERANCE : 0;
            int cutoff = result.moves[0].score - tolerance;
            int candidates = 0;
            while (candidates < result.moves.length
                   && result.moves[candidates].score >= cutoff) {
                candidates++;
            }
            return result.moves[random.int_range (0, candidates)].house;
        }

        /**
         * Same as {@link choose_move}, run on a worker thread so that the
         * caller's main loop keeps turning while the engine thinks. The user
         * interface depends on this: a Hard search can take a full second and
         * the window must stay responsive throughout.
         */
        public async int choose_move_async (Board board) {
            SourceFunc resume = choose_move_async.callback;
            int chosen = -1;

            var worker = new Thread<void> ("awale-search", () => {
                chosen = choose_move (board);
                Idle.add ((owned) resume);
            });

            yield;
            worker.join ();
            return chosen;
        }

        /** Starts the search over with no memory of earlier positions. */
        public void reset () {
            engine.clear ();
        }
    }
}
