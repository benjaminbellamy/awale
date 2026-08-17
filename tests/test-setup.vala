// SPDX-FileCopyrightText: 2026 Benjamin Bellamy <benjamin@castopod.org>
// SPDX-License-Identifier: AGPL-3.0-or-later

using Awale;
using Awale.TestUtil;

/** RULES.md 7, "Setup and invariants", plus the notation of RULES.md 8. */

private const string OPENING = "4,4,4,4,4,4 | 4,4,4,4,4,4 | S:0 N:0 | to_move=S";

/** RULES.md 7.1 */
private static void test_initial_position () {
    Board board = Board.initial ();

    assert_houses (board, { 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4 });
    assert_cmpint (board.south_store, CompareOperator.EQ, 0);
    assert_cmpint (board.north_store, CompareOperator.EQ, 0);
    assert_cmpint (board.seeds_on_board (), CompareOperator.EQ, TOTAL_SEEDS);
    assert_true (board.invariant_holds ());
    assert_true (board.to_move == Player.SOUTH);
}

/** RULES.md 1, the opening side is configurable. */
private static void test_initial_position_north_opens () {
    Board board = Board.initial (Player.NORTH);

    assert_true (board.to_move == Player.NORTH);
    assert_cmpint (board.seeds_on_board (), CompareOperator.EQ, TOTAL_SEEDS);
}

/** RULES.md 7.2 */
private static void test_invariant_holds_over_random_self_play () {
    var random = new Rand.with_seed (20260816);
    var game = new Game ();

    int plies = 0;
    while (plies < 1000) {
        if (game.outcome != Outcome.IN_PROGRESS) {
            game.reset ();
            continue;
        }

        int[] moves = game.legal_moves ();
        assert_cmpint (moves.length, CompareOperator.GT, 0);
        assert_true (game.play (moves[random.int_range (0, moves.length)]));
        plies++;

        Board board = game.board;
        if (!board.invariant_holds ()) {
            error ("invariant broken after ply %d: %s", plies, Notation.format (board));
        }
    }
}

private static void test_notation_round_trip () {
    Board board = position (OPENING);

    assert_true (board.equals (Board.initial ()));
    assert_cmpstr (Notation.format (board), CompareOperator.EQ, OPENING);
}

private static void test_notation_reads_stores_and_side () {
    Board board = position ("0,1,2,3,4,5 | 5,4,3,2,1,0 | S:9 N:9 | to_move=N");

    assert_houses (board, { 0, 1, 2, 3, 4, 5, 5, 4, 3, 2, 1, 0 });
    assert_cmpint (board.south_store, CompareOperator.EQ, 9);
    assert_cmpint (board.north_store, CompareOperator.EQ, 9);
    assert_true (board.to_move == Player.NORTH);
}

private static void test_notation_rejects_wrong_seed_total () {
    try {
        Notation.parse ("0,0,0,0,0,0 | 0,0,0,0,0,0 | S:0 N:0 | to_move=S");
        assert_not_reached ();
    } catch (NotationError e) {
        assert_true (e.code == NotationError.BAD_TOTAL);
    }
}

private static void test_notation_rejects_malformed_string () {
    try {
        Notation.parse ("4,4,4,4,4,4 | 4,4,4,4,4,4 | S:0 N:0");
        assert_not_reached ();
    } catch (NotationError e) {
        assert_true (e.code == NotationError.MALFORMED);
    }
}

public static int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/setup/initial-position", test_initial_position);
    Test.add_func ("/setup/initial-position-north-opens", test_initial_position_north_opens);
    Test.add_func ("/setup/invariant-over-random-self-play", test_invariant_holds_over_random_self_play);
    Test.add_func ("/notation/round-trip", test_notation_round_trip);
    Test.add_func ("/notation/stores-and-side", test_notation_reads_stores_and_side);
    Test.add_func ("/notation/rejects-wrong-seed-total", test_notation_rejects_wrong_seed_total);
    Test.add_func ("/notation/rejects-malformed-string", test_notation_rejects_malformed_string);
    return Test.run ();
}
