// SPDX-FileCopyrightText: 2026 Benjamin Bellamy <benjamin@castopod.org>
// SPDX-License-Identifier: AGPL-3.0-or-later

using Awale;
using Awale.TestUtil;

/** RULES.md 7, "Sowing", covering the skip rule of RULES.md 2.1. */

/** RULES.md 7.7, eleven seeds fill every other house exactly once, no skip. */
private static void test_sowing_eleven_seeds_fills_every_other_house () {
    Board board = position ("11,0,0,0,0,0 | 0,0,0,0,0,0 | S:37 N:0 | to_move=S");

    MoveResult result = board.apply_move (0);

    assert_houses (board, { 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 });
    assert_cmpint (result.last_house, CompareOperator.EQ, 11);
    assert_cmpint (result.captured, CompareOperator.EQ, 0);
    assert_true (board.invariant_holds ());
}

/**
 * RULES.md 7.8, twelve seeds wrap once. The twelfth seed would land back on
 * the house of origin, so it is skipped and house 1 receives two seeds.
 */
private static void test_sowing_twelve_seeds_skips_the_house_of_origin () {
    Board board = position ("12,0,0,0,0,0 | 0,0,0,0,0,0 | S:36 N:0 | to_move=S");

    MoveResult result = board.apply_move (0);

    assert_houses (board, { 0, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 });
    assert_cmpint (result.last_house, CompareOperator.EQ, 1);
    assert_cmpint (result.captured, CompareOperator.EQ, 0);
    assert_true (board.invariant_holds ());
}

/**
 * RULES.md 7.9, twenty three seeds wrap twice. Every other house is filled
 * twice and house 1 takes the odd seed, which only adds up if the house of
 * origin was skipped on both passes.
 */
private static void test_sowing_twenty_three_seeds_skips_the_origin_twice () {
    Board board = position ("23,1,0,0,0,0 | 0,0,0,0,0,0 | S:24 N:0 | to_move=S");

    MoveResult result = board.apply_move (0);

    assert_houses (board, { 0, 4, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2 });
    assert_cmpint (result.last_house, CompareOperator.EQ, 1);
    assert_cmpint (result.captured, CompareOperator.EQ, 0);
    assert_true (board.invariant_holds ());
}

public static int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/sowing/eleven-seeds", test_sowing_eleven_seeds_fills_every_other_house);
    Test.add_func ("/sowing/twelve-seeds-skips-origin", test_sowing_twelve_seeds_skips_the_house_of_origin);
    Test.add_func ("/sowing/twenty-three-seeds-skips-origin-twice", test_sowing_twenty_three_seeds_skips_the_origin_twice);
    return Test.run ();
}
