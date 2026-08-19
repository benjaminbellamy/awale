// SPDX-FileCopyrightText: 2026 Benjamin Bellamy <benjamin@castopod.org>
// SPDX-License-Identifier: AGPL-3.0-or-later

namespace Awale {

    /** Number of houses on the board, six per row. */
    public const int HOUSE_COUNT = 12;

    /** Number of houses in one player's row. */
    public const int ROW_SIZE = 6;

    /** Total number of seeds in play. This never changes (RULES.md 1). */
    public const int TOTAL_SEEDS = 48;

    /** Seeds a player must collect to win outright (RULES.md 6.1). */
    public const int WINNING_SEEDS = 25;

    /** Plies without a capture after which the game is stopped (RULES.md 6.2). */
    public const int NO_CAPTURE_PLY_LIMIT = 100;

    /** Occurrences of one position that end the game (RULES.md 6.2). */
    public const int REPETITION_LIMIT = 3;

    /**
     * The two sides. South owns houses 0 to 5, North owns houses 6 to 11.
     * Sowing runs 0 -> 1 -> ... -> 11 -> 0.
     */
    public enum Player {
        SOUTH,
        NORTH;

        public Player opponent () {
            return this == SOUTH ? NORTH : SOUTH;
        }

        /** Index of the leftmost house of this player's row. */
        public int row_start () {
            return this == SOUTH ? 0 : ROW_SIZE;
        }

        public bool owns (int house) {
            int start = row_start ();
            return house >= start && house < start + ROW_SIZE;
        }

        /** Single letter used by the position notation (RULES.md 8). */
        public string to_letter () {
            return this == SOUTH ? "S" : "N";
        }
    }

    /**
     * What to do with a move that would capture every seed left in the
     * opponent's row (RULES.md 5). Rulesets disagree, so the choice is
     * explicit and never hard-coded in the sowing logic.
     */
    public enum GrandSlamPolicy {
        /** Abapa, the project default: the move is legal but captures nothing. */
        LEGAL_NO_CAPTURE,
        /** The move cannot be played at all. */
        FORBIDDEN
    }

    /**
     * Why a move may not be played, so that the reason is decided by the rules
     * rather than re-derived from the board by whoever wants to explain it.
     */
    public enum Legality {
        LEGAL,
        /** Off the board entirely. */
        NO_SUCH_HOUSE,
        /** The house belongs to the other player. */
        NOT_YOUR_HOUSE,
        /** The house holds nothing to sow. */
        EMPTY_HOUSE,
        /** The opponent is starving and this move does not reach their row. */
        WOULD_NOT_FEED,
        /** The move would take every seed the opponent has, and the policy
            forbids that (RULES.md 5). */
        GRAND_SLAM_FORBIDDEN
    }

    /** Who won, once the game is over. */
    public enum Outcome {
        IN_PROGRESS,
        SOUTH_WINS,
        NORTH_WINS,
        DRAW
    }

    /** Why the game ended. */
    public enum EndReason {
        NONE,
        /** A store reached 25, or the board ran out of seeds (RULES.md 6.1). */
        SEED_MAJORITY,
        /** The same position occurred three times (RULES.md 6.2). */
        REPETITION,
        /** 100 plies went by without a capture (RULES.md 6.2). */
        NO_CAPTURE_LIMIT,
        /** The player to move could not feed a starving opponent (RULES.md 6.3). */
        STARVATION,
        /**
         * Every remaining move is a grand slam and the policy forbids them, so
         * the player to move has nothing legal left. RULES.md 5 does not cover
         * this, the project rules it a draw.
         */
        DEAD_END
    }

    /** What a move actually did, reported by {@link Board.apply_move}. */
    public struct MoveResult {
        /** Seeds added to the mover's store. Zero when a grand slam was suppressed. */
        public int captured;
        /** House the last seed of the sowing landed in. */
        public int last_house;
        /** True when the move was a grand slam and captured nothing because of it. */
        public bool grand_slam_suppressed;
    }

    /**
     * Step by step account of what a move would do, for callers that have to
     * show it happening rather than just apply it. The user interface animates
     * from this, which is what keeps it from having to know any of the rules.
     */
    public struct MoveTrace {
        /** Houses that receive a seed, in sowing order (RULES.md 2). */
        public int[] sown_houses;
        /** Houses emptied into the mover's store, in the order the chain took them. */
        public int[] captured_houses;
        public int captured;
        public bool grand_slam_suppressed;
    }

    /**
     * What one house would win for its owner if they played it. Learning mode
     * shows these before they are played, and from both rows at once, so what
     * a move would take is answered by the rules rather than read off the
     * board by whoever draws it.
     */
    public struct CapturePreview {
        /** House that would be played. */
        public int house;
        /**
         * How far round the board the sowing travels, counted in houses from
         * the one played, so the last seed lands in house + steps.
         *
         * This is not the number of seeds. A sowing steps over its own house
         * every time it comes back round to it (RULES.md 2.1), and each of
         * those is a house travelled that no seed landed in. Twelve or more
         * means the sowing went right round the board at least once.
         */
        public int steps;
        /** Seeds the move would win. Never zero. */
        public int captured;
    }

    /** Raised when a position string does not follow RULES.md 8. */
    public errordomain NotationError {
        MALFORMED,
        OUT_OF_RANGE,
        BAD_TOTAL
    }
}
