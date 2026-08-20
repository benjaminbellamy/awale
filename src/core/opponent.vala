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
     * Plies over which the computer chooses freely among its best openings.
     *
     * Without this, every game started from the opening position is the same
     * game: at the deeper levels the search almost never rates two moves
     * exactly equal, so the tie break below never has a tie to break and the
     * seed it was given changes nothing.
     */
    public const int OPENING_PLIES = 6;

    /**
     * How far below the best score an opening move may be and still be picked,
     * in evaluation units. A fifth of a banked seed.
     *
     * Measured rather than chosen: at this width thirty games from the opening
     * position came out as twenty three different games, and the side playing
     * its opening loosely scored 12 to 14 with 4 drawn against the same engine
     * playing its one best line, which is level. Half a banked seed varied the
     * games a little more and cost real ground, 8 to 19.
     */
    public const int OPENING_SCORE_TOLERANCE = WEIGHT_STORE_DIFFERENTIAL / 5;

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

        private Search engine = new Search ();
        private Rand random;

        public Opponent (Difficulty difficulty = Difficulty.MEDIUM, uint32 seed = 1) {
            Object (difficulty: difficulty);
            random = new Rand.with_seed (seed);
        }

        /**
         * Picks a house to play, or -1 when the position has no legal move.
         * Never returns a move the rules do not allow.
         *
         * {@link ply} is how many plies the game has run for. It decides
         * whether the position is still an opening the computer is free to
         * vary, and it is asked for rather than defaulted because a bare
         * position with no game behind it is not an opening and must not be
         * treated as one.
         */
        public int choose_move (Board board, int ply) {
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
            SearchResult result = engine.search (board,
                                                 difficulty.max_depth (),
                                                 difficulty.time_budget_ms ());
            if (result.moves.length == 0) {
                return legal[0];
            }

            int tolerance = difficulty == Difficulty.EASY ? EASY_SCORE_TOLERANCE : 0;
            if (ply < OPENING_PLIES) {
                tolerance = int.max (tolerance, OPENING_SCORE_TOLERANCE);
            }
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
        public async int choose_move_async (Board board, int ply) {
            SourceFunc resume = choose_move_async.callback;
            int chosen = -1;

            var worker = new Thread<void> ("awale-search", () => {
                chosen = choose_move (board, ply);
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
