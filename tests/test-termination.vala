// SPDX-FileCopyrightText: 2026 Benjamin Bellamy <benjamin@castopod.org>
// SPDX-License-Identifier: AGPL-3.0-or-later

using Awale;
using Awale.TestUtil;

/** RULES.md 7, "Termination", covering RULES.md 6. */

/** RULES.md 7.21, crossing 25 seeds ends the game on the spot. */
private static void test_twenty_five_seeds_wins_immediately () {
    var game = new Game.from_board (position ("0,0,0,0,3,1 | 2,1,4,0,0,0 | S:20 N:17 | to_move=S"));

    assert_true (game.play (4));

    assert_cmpint (game.board.south_store, CompareOperator.EQ, 25);
    assert_true (game.outcome == Outcome.SOUTH_WINS);
    assert_true (game.end_reason == EndReason.SEED_MAJORITY);
    assert_cmpint (game.legal_moves ().length, CompareOperator.EQ, 0);
    assert_false (game.play (5));
}

/** RULES.md 7.22 */
private static void test_twenty_four_all_is_a_draw () {
    var game = new Game.from_board (position ("0,0,0,0,0,0 | 0,0,0,0,0,0 | S:24 N:24 | to_move=S"));

    assert_true (game.outcome == Outcome.DRAW);
    assert_true (game.end_reason == EndReason.SEED_MAJORITY);
}

/** RULES.md 7.22 again, reached through a starvation ending. */
private static void test_twenty_four_all_by_starvation_is_a_draw () {
    var game = new Game.from_board (position ("0,0,1,0,0,0 | 0,0,0,0,0,0 | S:23 N:24 | to_move=S"));

    assert_cmpint (game.board.south_store, CompareOperator.EQ, 24);
    assert_cmpint (game.board.north_store, CompareOperator.EQ, 24);
    assert_true (game.outcome == Outcome.DRAW);
    assert_true (game.end_reason == EndReason.STARVATION);
}

/**
 * RULES.md 7.23. Each side owns a single seed and walks it forward one house
 * per ply, so the position comes back every twelve plies. The third occurrence
 * ends the game and each player takes the seed sitting in their own row.
 */
private static void test_threefold_repetition_ends_the_game () {
    var game = new Game.from_board (position ("0,0,0,0,0,1 | 0,0,0,0,0,1 | S:23 N:23 | to_move=S"));
    int[] cycle = { 5, 11, 0, 6, 1, 7, 2, 8, 3, 9, 4, 10 };

    for (int pass = 0; pass < 2; pass++) {
        foreach (int house in cycle) {
            assert_true (game.outcome == Outcome.IN_PROGRESS);
            assert_true (game.play (house));
        }
    }

    assert_cmpint (game.ply_count, CompareOperator.EQ, 24);
    assert_true (game.end_reason == EndReason.REPETITION);
    assert_cmpint (game.board.south_store, CompareOperator.EQ, 24);
    assert_cmpint (game.board.north_store, CompareOperator.EQ, 24);
    assert_cmpint (game.board.seeds_on_board (), CompareOperator.EQ, 0);
    assert_true (game.outcome == Outcome.DRAW);
}

/**
 * Looks for a line of {@link NO_CAPTURE_PLY_LIMIT} plies from the opening in
 * which nothing is ever captured and no position comes up three times, so that
 * the ply counter is the only guard that can fire. Picking the first quiet move
 * available is not enough, a player can be left holding a single move that
 * captures, so the search backtracks.
 */
private class QuietLineSearch : Object {

    private Game game = new Game ();
    private HashTable<string, int> seen = new HashTable<string, int> (str_hash, str_equal);
    private int[] line = {};
    private int budget = 200000;

    /** The houses to play, or an empty array when no such line was found. */
    public int[] run () {
        seen.set (Notation.format (game.board), 1);
        return search () ? line : new int[0];
    }

    private bool search () {
        if (line.length >= NO_CAPTURE_PLY_LIMIT) {
            return true;
        }
        if (budget-- <= 0) {
            return false;
        }

        foreach (int house in game.legal_moves ()) {
            Board probe = game.board.copy ();
            if (probe.apply_move (house, game.grand_slam_policy).captured > 0) {
                continue;
            }
            string key = Notation.format (probe);
            if (seen.lookup (key) >= REPETITION_LIMIT - 1) {
                continue;
            }

            seen.set (key, seen.lookup (key) + 1);
            line += house;
            game.play (house);

            if (search ()) {
                return true;
            }

            game.undo ();
            line.resize (line.length - 1);
            seen.set (key, seen.lookup (key) - 1);
        }
        return false;
    }
}

/** RULES.md 7.24 */
private static void test_hundred_plies_without_capture_ends_the_game () {
    int[] line = new QuietLineSearch ().run ();
    if (line.length < NO_CAPTURE_PLY_LIMIT) {
        error ("no capture free line of %d plies was found", NO_CAPTURE_PLY_LIMIT);
    }

    var game = new Game ();
    for (int i = 0; i < line.length - 1; i++) {
        assert_true (game.play (line[i]));
        assert_true (game.outcome == Outcome.IN_PROGRESS);
    }
    assert_cmpint (game.board.south_store, CompareOperator.EQ, 0);
    assert_cmpint (game.board.north_store, CompareOperator.EQ, 0);

    int last = line[line.length - 1];
    Board probe = game.board.copy ();
    probe.apply_move (last, game.grand_slam_policy);
    int expected_south = probe.south_store + probe.seeds_in_row (Player.SOUTH);
    int expected_north = probe.north_store + probe.seeds_in_row (Player.NORTH);

    assert_true (game.play (last));

    assert_cmpint (game.ply_count, CompareOperator.EQ, NO_CAPTURE_PLY_LIMIT);
    assert_cmpint (game.plies_since_capture, CompareOperator.EQ, NO_CAPTURE_PLY_LIMIT);
    assert_true (game.end_reason == EndReason.NO_CAPTURE_LIMIT);
    assert_cmpint (game.board.seeds_on_board (), CompareOperator.EQ, 0);
    assert_cmpint (game.board.south_store, CompareOperator.EQ, expected_south);
    assert_cmpint (game.board.north_store, CompareOperator.EQ, expected_north);
    assert_true (game.board.invariant_holds ());
}

/** RULES.md 7.25 */
private static void test_starvation_gives_the_board_to_the_player_to_move () {
    var game = new Game.from_board (position ("2,1,0,0,0,0 | 0,0,0,0,0,0 | S:22 N:23 | to_move=S"));

    assert_cmpint (game.board.seeds_on_board (), CompareOperator.EQ, 0);
    assert_cmpint (game.board.south_store, CompareOperator.EQ, 25);
    assert_cmpint (game.board.north_store, CompareOperator.EQ, 23);
    assert_true (game.outcome == Outcome.SOUTH_WINS);
    assert_true (game.end_reason == EndReason.STARVATION);
}

/** RULES.md 7.30, the dead end of RULES.md 6.4. */
private static void test_forbidden_grand_slam_dead_end_is_a_draw () {
    Board board = position ("0,0,0,0,3,0 | 1,1,0,0,0,0 | S:21 N:22 | to_move=S");

    var playable = new Game.from_board (board, GrandSlamPolicy.LEGAL_NO_CAPTURE);
    assert_true (playable.outcome == Outcome.IN_PROGRESS);
    assert_cmpint (playable.legal_moves ().length, CompareOperator.EQ, 1);

    var stuck = new Game.from_board (board, GrandSlamPolicy.FORBIDDEN);
    assert_cmpint (stuck.legal_moves ().length, CompareOperator.EQ, 0);
    assert_true (stuck.outcome == Outcome.DRAW);
    assert_true (stuck.end_reason == EndReason.DEAD_END);
}

private static void test_undo_restores_the_previous_position () {
    var game = new Game ();
    string before = Notation.format (game.board);

    assert_true (game.play (2));
    assert_cmpstr (Notation.format (game.board), CompareOperator.NE, before);
    assert_true (game.undo ());
    assert_cmpstr (Notation.format (game.board), CompareOperator.EQ, before);
    assert_false (game.undo ());
}

private static void test_redo_puts_a_taken_back_move_back () {
    var game = new Game ();

    assert_true (game.play (2));
    string after_move = Notation.format (game.board);

    assert_false (game.can_redo);
    assert_true (game.undo ());
    assert_true (game.can_redo);

    assert_true (game.redo ());
    assert_cmpstr (Notation.format (game.board), CompareOperator.EQ, after_move);
    assert_false (game.can_redo);
    assert_false (game.redo ());
}

/** Taken back moves belong to a game that is no longer the one being played. */
private static void test_playing_on_abandons_what_was_taken_back () {
    var game = new Game ();

    assert_true (game.play (2));
    assert_true (game.undo ());
    assert_true (game.can_redo);

    assert_true (game.play (3));

    assert_false (game.can_redo);
    assert_false (game.redo ());
}

/** Redo replays the whole run that was taken back, most recent move first. */
private static void test_redo_walks_back_through_several_moves () {
    var game = new Game ();

    assert_true (game.play (2));
    assert_true (game.play (7));
    string after_two = Notation.format (game.board);

    assert_true (game.undo ());
    assert_true (game.undo ());
    assert_cmpint (game.ply_count, CompareOperator.EQ, 0);

    assert_true (game.redo ());
    assert_true (game.redo ());
    assert_cmpstr (Notation.format (game.board), CompareOperator.EQ, after_two);
    assert_cmpint (game.ply_count, CompareOperator.EQ, 2);
}

private static void test_undo_reopens_a_finished_game () {
    var game = new Game.from_board (position ("0,0,0,0,3,1 | 2,1,4,0,0,0 | S:20 N:17 | to_move=S"));

    assert_true (game.play (4));
    assert_true (game.outcome == Outcome.SOUTH_WINS);

    assert_true (game.undo ());
    assert_true (game.outcome == Outcome.IN_PROGRESS);
    assert_true (game.end_reason == EndReason.NONE);
    assert_cmpint (game.board.south_store, CompareOperator.EQ, 20);
    assert_cmpint (game.board.seeds_on_board (), CompareOperator.EQ, 11);
}

/**
 * With end_at_winning_score off, crossing 25 is announced but does not stop
 * play: the game runs on until one of the other endings of RULES.md 6 arrives.
 */
private static void test_a_decided_game_can_be_played_on () {
    var game = new Game.from_board (position ("0,0,0,0,3,1 | 2,1,4,0,0,0 | S:20 N:17 | to_move=S"));
    game.end_at_winning_score = false;

    assert_true (game.play (4));

    assert_cmpint (game.board.south_store, CompareOperator.EQ, 25);
    assert_true (game.decided_outcome == Outcome.SOUTH_WINS);
    // Decided, but not over.
    assert_true (game.outcome == Outcome.IN_PROGRESS);
    assert_cmpint (game.legal_moves ().length, CompareOperator.GT, 0);

    // Taking the move back withdraws the verdict too.
    assert_true (game.undo ());
    assert_true (game.decided_outcome == Outcome.IN_PROGRESS);
}

/** Playing a decided game on still stops at a real ending. */
private static void test_a_decided_game_still_ends_when_the_board_runs_out () {
    var game = new Game.from_board (position ("2,1,0,0,0,0 | 0,0,0,0,0,0 | S:22 N:23 | to_move=S"));
    game.end_at_winning_score = false;

    // South cannot feed North, so RULES.md 6.3 ends it whatever the score.
    assert_true (game.outcome != Outcome.IN_PROGRESS);
    assert_true (game.end_reason == EndReason.STARVATION);
    assert_cmpint (game.board.south_store, CompareOperator.EQ, 25);
}

/** The default is still the rule as written: 25 ends the game. */
private static void test_winning_score_ends_the_game_by_default () {
    var game = new Game.from_board (position ("0,0,0,0,3,1 | 2,1,4,0,0,0 | S:20 N:17 | to_move=S"));

    assert_true (game.end_at_winning_score);
    assert_true (game.play (4));
    assert_true (game.outcome == Outcome.SOUTH_WINS);
    assert_true (game.end_reason == EndReason.SEED_MAJORITY);
}

public static int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/termination/twenty-five-seeds-wins", test_twenty_five_seeds_wins_immediately);
    Test.add_func ("/termination/twenty-four-all-is-a-draw", test_twenty_four_all_is_a_draw);
    Test.add_func ("/termination/twenty-four-all-by-starvation", test_twenty_four_all_by_starvation_is_a_draw);
    Test.add_func ("/termination/threefold-repetition", test_threefold_repetition_ends_the_game);
    Test.add_func ("/termination/hundred-plies-without-capture", test_hundred_plies_without_capture_ends_the_game);
    Test.add_func ("/termination/starvation-collects-the-board", test_starvation_gives_the_board_to_the_player_to_move);
    Test.add_func ("/termination/forbidden-grand-slam-dead-end", test_forbidden_grand_slam_dead_end_is_a_draw);
    Test.add_func ("/termination/decided-game-plays-on", test_a_decided_game_can_be_played_on);
    Test.add_func ("/termination/decided-game-still-ends", test_a_decided_game_still_ends_when_the_board_runs_out);
    Test.add_func ("/termination/winning-score-ends-by-default", test_winning_score_ends_the_game_by_default);
    Test.add_func ("/termination/undo-restores-position", test_undo_restores_the_previous_position);
    Test.add_func ("/termination/undo-reopens-finished-game", test_undo_reopens_a_finished_game);
    Test.add_func ("/termination/redo-restores-a-taken-back-move", test_redo_puts_a_taken_back_move_back);
    Test.add_func ("/termination/playing-on-abandons-redo", test_playing_on_abandons_what_was_taken_back);
    Test.add_func ("/termination/redo-walks-several-moves", test_redo_walks_back_through_several_moves);
    return Test.run ();
}
