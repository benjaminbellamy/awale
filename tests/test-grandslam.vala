// SPDX-FileCopyrightText: 2026 Benjamin Bellamy <benjamin@castopod.org>
// SPDX-License-Identifier: AGPL-3.0-or-later

using Awale;
using Awale.TestUtil;

/** RULES.md 7, "Grand slam", covering RULES.md 5. */

/**
 * South plays house 4 and the chain would take houses 7 and 6, which is
 * everything North has left.
 */
private const string GRAND_SLAM = "1,0,0,0,3,0 | 1,1,0,0,0,0 | S:20 N:22 | to_move=S";

/** RULES.md 7.18 */
private static void test_grand_slam_is_playable_and_captures_nothing () {
    Board board = position (GRAND_SLAM);

    assert_true (board.is_grand_slam (4));
    assert_true (board.is_legal (4, GrandSlamPolicy.LEGAL_NO_CAPTURE));
    assert_true (contains (board.legal_moves (GrandSlamPolicy.LEGAL_NO_CAPTURE), 4));

    MoveResult result = board.apply_move (4, GrandSlamPolicy.LEGAL_NO_CAPTURE);

    assert_true (result.grand_slam_suppressed);
    assert_cmpint (result.captured, CompareOperator.EQ, 0);
    assert_cmpint (board.south_store, CompareOperator.EQ, 20);
    assert_houses (board, { 1, 0, 0, 0, 0, 1, 2, 2, 0, 0, 0, 0 });
    assert_cmpint (board.seeds_in_row (Player.NORTH), CompareOperator.EQ, 4);
    assert_true (board.invariant_holds ());
}

/** RULES.md 7.19 */
private static void test_forbidden_grand_slam_is_not_generated () {
    Board board = position (GRAND_SLAM);

    assert_false (board.is_legal (4, GrandSlamPolicy.FORBIDDEN));

    int[] moves = board.legal_moves (GrandSlamPolicy.FORBIDDEN);
    assert_false (contains (moves, 4));
    assert_cmpint (moves.length, CompareOperator.EQ, 1);
    assert_cmpint (moves[0], CompareOperator.EQ, 0);
}

/**
 * RULES.md 7.20. The same move, but North keeps a seed in house 8, so this is
 * an ordinary capture of four seeds under either policy.
 */
private static void test_capturing_all_but_one_seed_is_not_a_grand_slam () {
    Board board = position ("1,0,0,0,3,0 | 1,1,1,0,0,0 | S:20 N:21 | to_move=S");

    assert_false (board.is_grand_slam (4));
    assert_true (contains (board.legal_moves (GrandSlamPolicy.FORBIDDEN), 4));

    MoveResult result = board.apply_move (4, GrandSlamPolicy.FORBIDDEN);

    assert_false (result.grand_slam_suppressed);
    assert_cmpint (result.captured, CompareOperator.EQ, 4);
    assert_cmpint (board.south_store, CompareOperator.EQ, 24);
    assert_houses (board, { 1, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0 });
    assert_true (board.invariant_holds ());
}

public static int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/grandslam/legal-and-captures-nothing", test_grand_slam_is_playable_and_captures_nothing);
    Test.add_func ("/grandslam/forbidden-is-not-generated", test_forbidden_grand_slam_is_not_generated);
    Test.add_func ("/grandslam/all-but-one-is-a-normal-capture", test_capturing_all_but_one_seed_is_not_a_grand_slam);
    return Test.run ();
}
