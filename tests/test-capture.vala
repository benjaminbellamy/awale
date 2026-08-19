// SPDX-FileCopyrightText: 2026 Benjamin Bellamy <benjamin@castopod.org>
// SPDX-License-Identifier: AGPL-3.0-or-later

using Awale;
using Awale.TestUtil;

/** RULES.md 7, "Capturing", covering RULES.md 3 and 3.1. */

/** RULES.md 7.10 */
private static void test_last_seed_brings_opponent_house_to_two () {
    Board board = position ("0,0,0,0,0,1 | 1,5,0,0,0,0 | S:20 N:21 | to_move=S");

    MoveResult result = board.apply_move (5);

    assert_cmpint (result.captured, CompareOperator.EQ, 2);
    assert_false (result.grand_slam_suppressed);
    assert_houses (board, { 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0 });
    assert_cmpint (board.south_store, CompareOperator.EQ, 22);
    assert_true (board.invariant_holds ());
}

/** RULES.md 7.11 */
private static void test_last_seed_brings_opponent_house_to_three () {
    Board board = position ("0,0,0,0,0,1 | 2,5,0,0,0,0 | S:19 N:21 | to_move=S");

    MoveResult result = board.apply_move (5);

    assert_cmpint (result.captured, CompareOperator.EQ, 3);
    assert_houses (board, { 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0 });
    assert_cmpint (board.south_store, CompareOperator.EQ, 22);
    assert_true (board.invariant_holds ());
}

/** RULES.md 7.12 */
private static void test_last_seed_brings_opponent_house_to_four () {
    Board board = position ("0,0,0,0,0,1 | 3,5,0,0,0,0 | S:18 N:21 | to_move=S");

    MoveResult result = board.apply_move (5);

    assert_cmpint (result.captured, CompareOperator.EQ, 0);
    assert_houses (board, { 0, 0, 0, 0, 0, 0, 4, 5, 0, 0, 0, 0 });
    assert_cmpint (board.south_store, CompareOperator.EQ, 18);
}

/** RULES.md 7.13 */
private static void test_last_seed_brings_opponent_house_to_one () {
    Board board = position ("0,0,0,0,0,1 | 0,5,0,0,0,0 | S:21 N:21 | to_move=S");

    MoveResult result = board.apply_move (5);

    assert_cmpint (result.captured, CompareOperator.EQ, 0);
    assert_houses (board, { 0, 0, 0, 0, 0, 0, 1, 5, 0, 0, 0, 0 });
    assert_cmpint (board.south_store, CompareOperator.EQ, 21);
}

/** RULES.md 7.14, you never capture from your own row. */
private static void test_last_seed_in_own_row_captures_nothing () {
    Board board = position ("0,0,0,0,1,1 | 5,0,0,0,0,0 | S:20 N:21 | to_move=S");

    MoveResult result = board.apply_move (4);

    assert_cmpint (result.last_house, CompareOperator.EQ, 5);
    assert_cmpint (result.captured, CompareOperator.EQ, 0);
    assert_houses (board, { 0, 0, 0, 0, 0, 2, 5, 0, 0, 0, 0, 0 });
    assert_cmpint (board.south_store, CompareOperator.EQ, 20);
}

/** RULES.md 7.15, three qualifying houses in a row are all taken. */
private static void test_chain_captures_three_consecutive_houses () {
    Board board = position ("0,0,0,0,0,3 | 1,1,1,4,0,0 | S:19 N:19 | to_move=S");

    MoveResult result = board.apply_move (5);

    assert_cmpint (result.last_house, CompareOperator.EQ, 8);
    assert_cmpint (result.captured, CompareOperator.EQ, 6);
    assert_false (result.grand_slam_suppressed);
    assert_houses (board, { 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 0, 0 });
    assert_cmpint (board.south_store, CompareOperator.EQ, 25);
    assert_true (board.invariant_holds ());
}

/**
 * RULES.md 7.16. House 8 qualifies and is taken, house 7 holds four seeds and
 * stops the walk, so house 6 keeps its two seeds even though it would qualify.
 */
private static void test_chain_stops_at_the_first_non_qualifying_house () {
    Board board = position ("0,0,0,0,0,3 | 1,3,1,4,0,0 | S:18 N:18 | to_move=S");

    MoveResult result = board.apply_move (5);

    assert_cmpint (result.captured, CompareOperator.EQ, 2);
    assert_houses (board, { 0, 0, 0, 0, 0, 0, 2, 4, 0, 4, 0, 0 });
    assert_cmpint (board.south_store, CompareOperator.EQ, 20);
}

/**
 * RULES.md 7.17, the worked example of RULES.md 3.1. South plays house 4 and
 * takes houses 7 and 6, then the walk reaches house 5, which is South's own,
 * and stops.
 */
private static void test_chain_never_crosses_into_the_movers_row () {
    Board board = position ("0,0,0,0,3,1 | 2,1,4,0,0,0 | S:19 N:18 | to_move=S");

    MoveResult result = board.apply_move (4);

    assert_cmpint (result.last_house, CompareOperator.EQ, 7);
    assert_cmpint (result.captured, CompareOperator.EQ, 5);
    assert_houses (board, { 0, 0, 0, 0, 0, 2, 0, 0, 4, 0, 0, 0 });
    assert_cmpint (board.south_store, CompareOperator.EQ, 24);
    assert_true (board.invariant_holds ());
}

/**
 * The trace is what the board animation is driven from, so it has to name every
 * house that receives a seed, in order, and every house the chain empties.
 */
private static void test_trace_reports_the_sowing_and_the_chain () {
    Board board = position ("0,0,0,0,3,1 | 2,1,4,0,0,0 | S:19 N:18 | to_move=S");

    MoveTrace trace = board.trace_move (4);

    assert_cmpint (trace.sown_houses.length, CompareOperator.EQ, 3);
    assert_cmpint (trace.sown_houses[0], CompareOperator.EQ, 5);
    assert_cmpint (trace.sown_houses[1], CompareOperator.EQ, 6);
    assert_cmpint (trace.sown_houses[2], CompareOperator.EQ, 7);

    // The chain walks backwards, so house 7 is taken before house 6.
    assert_cmpint (trace.captured_houses.length, CompareOperator.EQ, 2);
    assert_cmpint (trace.captured_houses[0], CompareOperator.EQ, 7);
    assert_cmpint (trace.captured_houses[1], CompareOperator.EQ, 6);
    assert_cmpint (trace.captured, CompareOperator.EQ, 5);
    assert_false (trace.grand_slam_suppressed);

    // Tracing must leave the board alone.
    assert_houses (board, { 0, 0, 0, 0, 3, 1, 2, 1, 4, 0, 0, 0 });
}

/** A suppressed grand slam traces as a sowing that takes nothing. */
private static void test_trace_of_a_grand_slam_captures_nothing () {
    Board board = position ("1,0,0,0,3,0 | 1,1,0,0,0,0 | S:20 N:22 | to_move=S");

    MoveTrace trace = board.trace_move (4);

    assert_true (trace.grand_slam_suppressed);
    assert_cmpint (trace.captured, CompareOperator.EQ, 0);
    assert_cmpint (trace.captured_houses.length, CompareOperator.EQ, 0);
    assert_cmpint (trace.sown_houses.length, CompareOperator.EQ, 3);
}

/** The trace shows the skip of RULES.md 2.1 rather than hiding it. */
private static void test_trace_never_names_the_house_of_origin () {
    Board board = position ("12,0,0,0,0,0 | 0,0,0,0,0,0 | S:36 N:0 | to_move=S");

    MoveTrace trace = board.trace_move (0);

    assert_cmpint (trace.sown_houses.length, CompareOperator.EQ, 12);
    foreach (int house in trace.sown_houses) {
        assert_cmpint (house, CompareOperator.NE, 0);
    }
    assert_cmpint (trace.sown_houses[11], CompareOperator.EQ, 1);
}

/** The preview for one house, or a fatal failure if it was not offered. */
private static CapturePreview preview_for (CapturePreview[] previews, int house) {
    foreach (CapturePreview preview in previews) {
        if (preview.house == house) {
            return preview;
        }
    }
    error ("no capture previewed for house %d", house);
}

/** Both rows are previewed, not just the row of the player to move. */
private static void test_previews_cover_both_rows () {
    Board board = position ("0,1,1,0,0,1 | 1,0,0,0,0,3 | S:20 N:21 | to_move=S");

    CapturePreview[] previews = board.capture_previews ();

    assert_cmpint (previews.length, CompareOperator.EQ, 2);

    CapturePreview mine = preview_for (previews, 5);
    assert_cmpint (mine.captured, CompareOperator.EQ, 2);
    // One seed, one house travelled: house 5 to house 6.
    assert_cmpint (mine.steps, CompareOperator.EQ, 1);

    // North is not to move, and this is still what North would take.
    CapturePreview theirs = preview_for (previews, 11);
    assert_cmpint (theirs.captured, CompareOperator.EQ, 4);
    assert_cmpint (theirs.steps, CompareOperator.EQ, 3);
}

/** Nothing is previewed from the opening position: no move there captures. */
private static void test_no_previews_when_nothing_can_be_won () {
    Board board = Board.initial ();

    assert_cmpint (board.capture_previews ().length, CompareOperator.EQ, 0);
}

/** A grand slam wins nothing under the default policy, so it is not previewed. */
private static void test_grand_slam_is_not_previewed () {
    Board board = position ("0,0,0,0,0,1 | 1,0,0,0,0,0 | S:23 N:23 | to_move=S");

    assert_cmpint (board.capture_previews ().length, CompareOperator.EQ, 0);
}

/** A sowing long enough to wrap past its own house reports every seed of it. */
private static void test_preview_of_a_sowing_that_wraps () {
    Board board = position ("17,0,0,0,0,0 | 0,0,0,0,0,0 | S:16 N:15 | to_move=S");

    CapturePreview[] previews = board.capture_previews ();

    assert_cmpint (previews.length, CompareOperator.EQ, 1);
    CapturePreview preview = previews[0];
    assert_cmpint (preview.house, CompareOperator.EQ, 0);
    // Seventeen seeds, but eighteen houses travelled: coming back round to its
    // own house, the sowing steps over it, and that house is travelled without
    // being sown. The last seed lands in house 0 + 18, which is house 6.
    assert_cmpint (preview.steps, CompareOperator.EQ, 18);
    assert_cmpint (preview.captured, CompareOperator.EQ, 2);
}

public static int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/capture/opponent-house-to-two", test_last_seed_brings_opponent_house_to_two);
    Test.add_func ("/capture/opponent-house-to-three", test_last_seed_brings_opponent_house_to_three);
    Test.add_func ("/capture/opponent-house-to-four", test_last_seed_brings_opponent_house_to_four);
    Test.add_func ("/capture/opponent-house-to-one", test_last_seed_brings_opponent_house_to_one);
    Test.add_func ("/capture/own-row-captures-nothing", test_last_seed_in_own_row_captures_nothing);
    Test.add_func ("/capture/chain-three-consecutive", test_chain_captures_three_consecutive_houses);
    Test.add_func ("/capture/chain-stops-at-non-qualifying", test_chain_stops_at_the_first_non_qualifying_house);
    Test.add_func ("/capture/chain-stays-out-of-own-row", test_chain_never_crosses_into_the_movers_row);
    Test.add_func ("/trace/reports-sowing-and-chain", test_trace_reports_the_sowing_and_the_chain);
    Test.add_func ("/trace/grand-slam-captures-nothing", test_trace_of_a_grand_slam_captures_nothing);
    Test.add_func ("/trace/never-names-house-of-origin", test_trace_never_names_the_house_of_origin);
    Test.add_func ("/preview/covers-both-rows", test_previews_cover_both_rows);
    Test.add_func ("/preview/none-when-nothing-can-be-won", test_no_previews_when_nothing_can_be_won);
    Test.add_func ("/preview/grand-slam-not-previewed", test_grand_slam_is_not_previewed);
    Test.add_func ("/preview/sowing-that-wraps", test_preview_of_a_sowing_that_wraps);
    return Test.run ();
}
