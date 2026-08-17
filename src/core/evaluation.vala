// SPDX-FileCopyrightText: 2026 Benjamin Bellamy <benjamin@castopod.org>
// SPDX-License-Identifier: AGPL-3.0-or-later

namespace Awale {

    /**
     * How much one seed already banked in a store is worth. This is the
     * dominant term on purpose: banked seeds are the only ones that decide the
     * game, everything else is a guess about which seeds will end up banked.
     * Every other weight is expressed as a fraction of this one.
     */
    public const int WEIGHT_STORE_DIFFERENTIAL = 100;

    /**
     * How much one seed sitting in your own row is worth. Positive, because
     * those seeds are yours to sow and cannot be captured until you move them
     * across, but far below a banked seed because the opponent's next move can
     * still reach them.
     */
    public const int WEIGHT_SEEDS_ON_OWN_SIDE = 3;

    /**
     * How much one opponent house holding 1 or 2 seeds is worth to you. Those
     * are the houses a single sowing can bring to 2 or 3 and capture, so they
     * are the raw material of every capture (RULES.md 3).
     */
    public const int WEIGHT_VULNERABLE_HOUSE = 5;

    /**
     * How much one extra legal move is worth. Being short of moves is how a
     * player gets forced into feeding the opponent or into a starvation
     * ending (RULES.md 4 and 6.3).
     */
    public const int WEIGHT_MOBILITY = 2;

    /**
     * Scores a position from {@link point_of_view}, in the units set by
     * {@link WEIGHT_STORE_DIFFERENTIAL}, where 100 is one banked seed. Higher
     * is better for that player.
     *
     * Every term is a difference between the two sides, so the function is
     * antisymmetric: evaluating from South always gives the negative of
     * evaluating the same board from North. Negamax relies on that.
     *
     * This is a heuristic for positions that are still being played. Terminal
     * positions are recognised and scored by {@link Search}, not here.
     */
    public int evaluate (Board board,
                         Player point_of_view,
                         GrandSlamPolicy policy = GrandSlamPolicy.LEGAL_NO_CAPTURE) {
        Player other = point_of_view.opponent ();

        int score = 0;
        score += (board.store (point_of_view) - board.store (other))
               * WEIGHT_STORE_DIFFERENTIAL;
        score += (board.seeds_in_row (point_of_view) - board.seeds_in_row (other))
               * WEIGHT_SEEDS_ON_OWN_SIDE;
        score += (vulnerable_houses (board, other) - vulnerable_houses (board, point_of_view))
               * WEIGHT_VULNERABLE_HOUSE;
        score += (mobility (board, point_of_view, policy) - mobility (board, other, policy))
               * WEIGHT_MOBILITY;
        return score;
    }

    /** Houses of {@link owner} that a single seed could bring to 2 or 3. */
    private int vulnerable_houses (Board board, Player owner) {
        int count = 0;
        int start = owner.row_start ();
        for (int house = start; house < start + ROW_SIZE; house++) {
            if (board.houses[house] == 1 || board.houses[house] == 2) {
                count++;
            }
        }
        return count;
    }

    /** Moves {@link player} would have if it were their turn. */
    private int mobility (Board board, Player player, GrandSlamPolicy policy) {
        // The board arrives by value, so it can be pointed at the player whose
        // moves are being counted without disturbing the caller's copy.
        board.to_move = player;

        int count = 0;
        int start = player.row_start ();
        for (int house = start; house < start + ROW_SIZE; house++) {
            if (board.is_legal (house, policy)) {
                count++;
            }
        }
        return count;
    }
}
