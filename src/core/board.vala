// SPDX-FileCopyrightText: 2026 Benjamin Bellamy <benjamin@castopod.org>
// SPDX-License-Identifier: AGPL-3.0-or-later

namespace Awale {

    /** Result of sowing a move, before the grand slam policy is applied. */
    internal struct SowOutcome {
        public int[] sown_houses;
        public int[] captured_houses;
        public int captured;
        public bool grand_slam;
        public int last_house;
    }

    /**
     * A complete position: the twelve houses, both stores, and the side to
     * move. This is a plain struct rather than an object so the search can
     * copy it without allocating.
     */
    public struct Board {
        // The literal 12 is required here, a C array member needs a compile
        // time constant. It is HOUSE_COUNT.
        public int houses[12];
        public int south_store;
        public int north_store;
        public Player to_move;

        /** The opening position: four seeds in every house (RULES.md 1). */
        public static Board initial (Player first_to_move = Player.SOUTH) {
            Board board = Board ();
            for (int i = 0; i < HOUSE_COUNT; i++) {
                board.houses[i] = 4;
            }
            board.south_store = 0;
            board.north_store = 0;
            board.to_move = first_to_move;
            return board;
        }

        public Board copy () {
            Board other = Board ();
            for (int i = 0; i < HOUSE_COUNT; i++) {
                other.houses[i] = houses[i];
            }
            other.south_store = south_store;
            other.north_store = north_store;
            other.to_move = to_move;
            return other;
        }

        public bool equals (Board other) {
            for (int i = 0; i < HOUSE_COUNT; i++) {
                if (houses[i] != other.houses[i]) {
                    return false;
                }
            }
            return south_store == other.south_store
                && north_store == other.north_store
                && to_move == other.to_move;
        }

        public int store (Player player) {
            return player == Player.SOUTH ? south_store : north_store;
        }

        public void add_to_store (Player player, int seeds) {
            if (player == Player.SOUTH) {
                south_store += seeds;
            } else {
                north_store += seeds;
            }
        }

        public int seeds_in_row (Player player) {
            int total = 0;
            int start = player.row_start ();
            for (int i = start; i < start + ROW_SIZE; i++) {
                total += houses[i];
            }
            return total;
        }

        /**
         * True once a store holds enough to settle the game (RULES.md 6.1).
         * Whose win it is depends on the stores; that a win exists does not.
         */
        public bool is_decided () {
            return south_store >= WINNING_SEEDS || north_store >= WINNING_SEEDS;
        }

        public bool row_is_empty (Player player) {
            return seeds_in_row (player) == 0;
        }

        public int seeds_on_board () {
            int total = 0;
            for (int i = 0; i < HOUSE_COUNT; i++) {
                total += houses[i];
            }
            return total;
        }

        /**
         * A number standing for this position, for callers that need to index
         * or choose by it. FNV-1a over the houses, the stores and the side to
         * move. Not a substitute for {@link equals}: two positions can land on
         * the same number, so anything that must be exact still compares.
         */
        public uint64 fingerprint () {
            uint64 hash = 14695981039346656037U;
            for (int house = 0; house < HOUSE_COUNT; house++) {
                hash = (hash ^ (uint64) houses[house]) * 1099511628211U;
            }
            hash = (hash ^ (uint64) south_store) * 1099511628211U;
            hash = (hash ^ (uint64) north_store) * 1099511628211U;
            hash = (hash ^ (uint64) to_move) * 1099511628211U;
            return hash;
        }

        /** The 48 seed invariant of RULES.md 1. */
        public bool invariant_holds () {
            return seeds_on_board () + south_store + north_store == TOTAL_SEEDS;
        }

        /** Empties every house and hands its seeds to the row's owner. */
        public void collect_rows () {
            add_to_store (Player.SOUTH, seeds_in_row (Player.SOUTH));
            add_to_store (Player.NORTH, seeds_in_row (Player.NORTH));
            for (int i = 0; i < HOUSE_COUNT; i++) {
                houses[i] = 0;
            }
        }

        /** Empties every house and hands all of its seeds to one player. */
        public void collect_board (Player player) {
            add_to_store (player, seeds_on_board ());
            for (int i = 0; i < HOUSE_COUNT; i++) {
                houses[i] = 0;
            }
        }

        /**
         * Why a house may or may not be played. Callers that only need a yes
         * or no want {@link is_legal}; this is for the ones that have to say
         * why, so that the reasons stay with the rules they come from.
         */
        public Legality legality (int house,
                                  GrandSlamPolicy policy = GrandSlamPolicy.LEGAL_NO_CAPTURE) {
            if (house < 0 || house >= HOUSE_COUNT) {
                return Legality.NO_SUCH_HOUSE;
            }
            if (!to_move.owns (house)) {
                return Legality.NOT_YOUR_HOUSE;
            }
            if (houses[house] == 0) {
                return Legality.EMPTY_HOUSE;
            }
            if (row_is_empty (to_move.opponent ()) && !feeds (house)) {
                return Legality.WOULD_NOT_FEED;
            }
            if (policy == GrandSlamPolicy.FORBIDDEN && is_grand_slam (house)) {
                return Legality.GRAND_SLAM_FORBIDDEN;
            }
            return Legality.LEGAL;
        }

        public bool is_legal (int house, GrandSlamPolicy policy = GrandSlamPolicy.LEGAL_NO_CAPTURE) {
            return legality (house, policy) == Legality.LEGAL;
        }

        public int[] legal_moves (GrandSlamPolicy policy = GrandSlamPolicy.LEGAL_NO_CAPTURE) {
            int[] moves = {};
            int start = to_move.row_start ();
            for (int house = start; house < start + ROW_SIZE; house++) {
                if (is_legal (house, policy)) {
                    moves += house;
                }
            }
            return moves;
        }

        /** Same question as {@link legal_moves}, without building the array. */
        public bool has_legal_move (GrandSlamPolicy policy = GrandSlamPolicy.LEGAL_NO_CAPTURE) {
            int start = to_move.row_start ();
            for (int house = start; house < start + ROW_SIZE; house++) {
                if (is_legal (house, policy)) {
                    return true;
                }
            }
            return false;
        }

        /**
         * True when the player to move has a move that satisfies the feeding
         * obligation. This ignores the grand slam policy, which is what tells a
         * starvation ending (RULES.md 6.3) apart from a dead end where only
         * forbidden grand slams remain (RULES.md 6.4).
         */
        public bool has_sowable_move () {
            return has_legal_move (GrandSlamPolicy.LEGAL_NO_CAPTURE);
        }

        /**
         * True when the move would capture every seed left in the opponent's
         * row (RULES.md 5).
         */
        public bool is_grand_slam (int house) {
            Board probe = copy ();
            return probe.sow_and_probe (house).grand_slam;
        }

        /**
         * Describes what playing {@link house} would do, seed by seed, without
         * touching this board. Callers that have to show the move happening use
         * this so that they never have to work out the rules for themselves.
         */
        public MoveTrace trace_move (int house, GrandSlamPolicy policy = GrandSlamPolicy.LEGAL_NO_CAPTURE) {
            assert (is_legal (house, policy));

            Board probe = copy ();
            SowOutcome outcome = probe.sow_and_probe (house);

            MoveTrace trace = MoveTrace ();
            trace.sown_houses = outcome.sown_houses;
            trace.grand_slam_suppressed = outcome.grand_slam;
            trace.captured_houses = outcome.grand_slam ? new int[0] : outcome.captured_houses;
            trace.captured = outcome.grand_slam ? 0 : outcome.captured;
            return trace;
        }

        /**
         * Every house that would win seeds for its owner, from both rows at
         * once and whichever side is to move: what the opponent could take
         * next is worth seeing before choosing, not after. Moves that win
         * nothing are left out, and so is a grand slam whenever the policy
         * makes it capture nothing.
         */
        public CapturePreview[] capture_previews (GrandSlamPolicy policy = GrandSlamPolicy.LEGAL_NO_CAPTURE) {
            CapturePreview[] previews = {};
            Player[] both = { Player.SOUTH, Player.NORTH };

            foreach (Player player in both) {
                // Asking what a player would take when it is not their turn is
                // the whole point, so the question goes to a board that says it
                // is: their legal moves, and the feeding obligation, are the
                // ones that would apply on their turn.
                Board probe = copy ();
                probe.to_move = player;

                foreach (int house in probe.legal_moves (policy)) {
                    MoveTrace trace = probe.trace_move (house, policy);
                    if (trace.captured == 0) {
                        continue;
                    }

                    CapturePreview preview = CapturePreview ();
                    preview.house = house;
                    preview.steps = ring_steps (house, trace.sown_houses);
                    preview.captured = trace.captured;
                    previews += preview;
                }
            }
            return previews;
        }

        /**
         * Plays {@link house} and returns what it did. The move must be legal
         * under {@link policy}.
         */
        public MoveResult apply_move (int house, GrandSlamPolicy policy = GrandSlamPolicy.LEGAL_NO_CAPTURE) {
            assert (is_legal (house, policy));

            Player mover = to_move;
            SowOutcome outcome = sow_and_probe (house);

            MoveResult result = MoveResult ();
            result.last_house = outcome.last_house;
            // A forbidden grand slam is never legal, so reaching here with
            // grand_slam set means the policy is LEGAL_NO_CAPTURE.
            result.grand_slam_suppressed = outcome.grand_slam;

            if (outcome.grand_slam) {
                result.captured = 0;
            } else {
                foreach (int captured_house in outcome.captured_houses) {
                    houses[captured_house] = 0;
                }
                add_to_store (mover, outcome.captured);
                result.captured = outcome.captured;
            }

            to_move = mover.opponent ();
            assert (invariant_holds ());
            return result;
        }

        /**
         * Sows from {@link house} and works out what the sowing would capture.
         * The board keeps the sown state, the captures are not applied.
         */
        private SowOutcome sow_and_probe (int house) {
            Player mover = to_move;
            int[] sown = sow (house);

            SowOutcome outcome = SowOutcome ();
            outcome.last_house = sown.length > 0 ? sown[sown.length - 1] : house;
            outcome.captured_houses = capture_chain (sown, mover);
            outcome.sown_houses = sown;
            outcome.captured = 0;
            foreach (int captured_house in outcome.captured_houses) {
                outcome.captured += houses[captured_house];
            }
            outcome.grand_slam = outcome.captured > 0
                && outcome.captured == seeds_in_row (mover.opponent ());
            return outcome;
        }

        /**
         * How far round the board a sowing travels, counted in houses from the
         * one it started in.
         *
         * Longer than the sowing has seeds whenever it comes back round to its
         * own house, because stepping over that house (RULES.md 2.1) covers a
         * house that no seed lands in.
         */
        private int ring_steps (int house, int[] sown) {
            int steps = 0;
            int at = house;
            foreach (int landed in sown) {
                steps += (landed - at + HOUSE_COUNT) % HOUSE_COUNT;
                at = landed;
            }
            return steps;
        }

        /**
         * Lifts every seed out of {@link house} and drops them one by one into
         * the following houses, skipping the house of origin (RULES.md 2.1).
         * Returns the houses that received a seed, in sowing order.
         */
        private int[] sow (int house) {
            int seeds = houses[house];
            houses[house] = 0;

            int[] sown = new int[seeds];
            int position = house;
            for (int i = 0; i < seeds; i++) {
                position = (position + 1) % HOUSE_COUNT;
                if (position == house) {
                    position = (position + 1) % HOUSE_COUNT;
                }
                houses[position]++;
                sown[i] = position;
            }
            return sown;
        }

        /**
         * Walks the sowing backwards from its last seed and collects the houses
         * that qualify for capture (RULES.md 3 and 3.1). Must be called on the
         * board as it stands after sowing, before any seed is removed.
         */
        private int[] capture_chain (int[] sown, Player mover) {
            int[] chain = {};
            bool[] already_taken = new bool[HOUSE_COUNT];
            Player victim = mover.opponent ();

            for (int i = sown.length - 1; i >= 0; i--) {
                int house = sown[i];
                if (!victim.owns (house)) {
                    break;
                }
                // A house the chain already emptied holds nothing, which is not
                // 2 or 3, so the walk stops there. This only comes up when the
                // sowing wrapped around and visited a house twice.
                if (already_taken[house]) {
                    break;
                }
                if (houses[house] != 2 && houses[house] != 3) {
                    break;
                }
                already_taken[house] = true;
                chain += house;
            }
            return chain;
        }

        /**
         * True when sowing from {@link house} drops at least one seed in the
         * opponent's row, which is what the feeding obligation asks for
         * (RULES.md 4).
         */
        private bool feeds (int house) {
            Player victim = to_move.opponent ();
            Board probe = copy ();
            foreach (int sown_house in probe.sow (house)) {
                if (victim.owns (sown_house)) {
                    return true;
                }
            }
            return false;
        }
    }
}
