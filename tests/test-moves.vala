// SPDX-FileCopyrightText: 2026 Benjamin Bellamy <benjamin@castopod.org>
// SPDX-License-Identifier: AGPL-3.0-or-later

using Awale;
using Awale.TestUtil;

/** RULES.md 7, "Move generation". */

/** RULES.md 7.3 */
private static void test_empty_house_is_never_selectable () {
    Board board = position ("0,4,4,4,4,4 | 4,4,4,4,4,4 | S:4 N:0 | to_move=S");

    assert_false (board.is_legal (0));
    assert_false (contains (board.legal_moves (), 0));
    assert_cmpint (board.legal_moves ().length, CompareOperator.EQ, 5);
}

/** RULES.md 7.4 */
private static void test_opponent_house_is_never_selectable () {
    Board south_to_move = Board.initial (Player.SOUTH);
    for (int house = ROW_SIZE; house < HOUSE_COUNT; house++) {
        assert_false (south_to_move.is_legal (house));
    }
    foreach (int house in south_to_move.legal_moves ()) {
        assert_cmpint (house, CompareOperator.LT, ROW_SIZE);
    }

    Board north_to_move = Board.initial (Player.NORTH);
    for (int house = 0; house < ROW_SIZE; house++) {
        assert_false (north_to_move.is_legal (house));
    }
    foreach (int house in north_to_move.legal_moves ()) {
        assert_cmpint (house, CompareOperator.GE, ROW_SIZE);
    }
}

private static void test_house_outside_the_board_is_never_selectable () {
    Board board = Board.initial ();

    assert_false (board.is_legal (-1));
    assert_false (board.is_legal (HOUSE_COUNT));
}

/**
 * RULES.md 7.5. North is starving, so only house 5 is playable: its four seeds
 * reach houses 6 to 9, while house 0 would drop its single seed in house 1 and
 * leave North with nothing.
 */
private static void test_only_feeding_moves_when_opponent_row_is_empty () {
    Board board = position ("1,0,0,0,0,4 | 0,0,0,0,0,0 | S:20 N:23 | to_move=S");

    int[] moves = board.legal_moves ();
    assert_cmpint (moves.length, CompareOperator.EQ, 1);
    assert_cmpint (moves[0], CompareOperator.EQ, 5);
    assert_false (board.is_legal (0));
}

/** RULES.md 7.6 */
private static void test_no_feeding_move_is_terminal () {
    Board board = position ("1,1,0,0,0,0 | 0,0,0,0,0,0 | S:23 N:23 | to_move=S");

    assert_cmpint (board.legal_moves ().length, CompareOperator.EQ, 0);

    var game = new Game.from_board (board);
    assert_true (game.outcome != Outcome.IN_PROGRESS);
    assert_true (game.end_reason == EndReason.STARVATION);
    assert_cmpint (game.legal_moves ().length, CompareOperator.EQ, 0);
}

/**
 * The feeding obligation only applies when the opponent is actually starving.
 * Here North still holds a seed, so South may keep playing at home.
 */
private static void test_no_feeding_obligation_when_opponent_has_seeds () {
    Board board = position ("1,0,0,0,0,4 | 1,0,0,0,0,0 | S:19 N:23 | to_move=S");

    assert_true (board.is_legal (0));
    assert_true (board.is_legal (5));
}

public static int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/moves/empty-house-never-selectable", test_empty_house_is_never_selectable);
    Test.add_func ("/moves/opponent-house-never-selectable", test_opponent_house_is_never_selectable);
    Test.add_func ("/moves/house-outside-board-never-selectable", test_house_outside_the_board_is_never_selectable);
    Test.add_func ("/moves/only-feeding-moves-when-opponent-empty", test_only_feeding_moves_when_opponent_row_is_empty);
    Test.add_func ("/moves/no-feeding-move-is-terminal", test_no_feeding_move_is_terminal);
    Test.add_func ("/moves/no-obligation-when-opponent-has-seeds", test_no_feeding_obligation_when_opponent_has_seeds);
    return Test.run ();
}
