// SPDX-FileCopyrightText: 2026 Benjamin Bellamy <benjamin@castopod.org>
// SPDX-License-Identifier: AGPL-3.0-or-later

namespace Awale.TestUtil {

    /**
     * Reads a position written in the notation of RULES.md 8. A test position
     * that does not parse is a mistake in the test, so it aborts rather than
     * reporting a failure somewhere further down.
     */
    public Board position (string text) {
        try {
            return Notation.parse (text);
        } catch (NotationError e) {
            error ("bad test position \"%s\": %s", text, e.message);
        }
    }

    /** Whether a move list holds a given house. */
    public bool contains (int[] moves, int house) {
        foreach (int candidate in moves) {
            if (candidate == house) {
                return true;
            }
        }
        return false;
    }

    /**
     * Positions drawn from a random game, for sweeping the search or the
     * advisor over boards that actually occur rather than made up ones.
     */
    public Board[] sampled_positions (uint32 seed, int count) {
        var random = new Rand.with_seed (seed);
        var game = new Game ();
        Board[] positions = {};

        while (positions.length < count) {
            if (game.outcome != Outcome.IN_PROGRESS) {
                game.reset ();
                continue;
            }
            positions += game.board.copy ();
            int[] moves = game.legal_moves ();
            game.play (moves[random.int_range (0, moves.length)]);
        }
        return positions;
    }

    /** Asserts the seed counts of the whole board, houses 0 to 11 in order. */
    public void assert_houses (Board board, int[] expected) {
        assert_cmpint (expected.length, CompareOperator.EQ, HOUSE_COUNT);
        for (int house = 0; house < HOUSE_COUNT; house++) {
            if (board.houses[house] != expected[house]) {
                error ("house %d holds %d seeds, expected %d, in %s",
                       house, board.houses[house], expected[house],
                       Notation.format (board));
            }
        }
    }
}
