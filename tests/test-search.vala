// SPDX-FileCopyrightText: 2026 Benjamin Bellamy <benjamin@castopod.org>
// SPDX-License-Identifier: AGPL-3.0-or-later

using Awale;
using Awale.TestUtil;

/** RULES.md 7, "Search", plus the evaluation function behind it. */

/**
 * South can play house 4, whose three seeds bring houses 7 and 6 to 2 and 3 and
 * take five seeds, which carries South to 25 and wins on the spot (RULES.md
 * 6.1). The alternative, house 5, takes three seeds and lets the game go on, so
 * the capture really is the only good move at any depth.
 */
private const string FORCED_CAPTURE = "0,0,0,0,3,1 | 2,1,1,0,0,0 | S:20 N:20 | to_move=S";

private static Difficulty[] all_levels () {
    return { Difficulty.EASY, Difficulty.MEDIUM, Difficulty.HARD };
}

private static Search fresh_search (Difficulty level) {
    var engine = new Search ();
    engine.use_transposition_table = level.uses_transposition_table ();
    return engine;
}

/** The difficulty table of the project brief. */
private static void test_difficulty_levels_match_the_brief () {
    assert_cmpint (Difficulty.EASY.max_depth (), CompareOperator.EQ, 2);
    assert_cmpint (Difficulty.MEDIUM.max_depth (), CompareOperator.EQ, 6);
    assert_cmpint (Difficulty.HARD.max_depth (), CompareOperator.EQ, 12);

    assert_true (Difficulty.EASY.time_budget_ms () == 100);
    assert_true (Difficulty.MEDIUM.time_budget_ms () == 300);
    assert_true (Difficulty.HARD.time_budget_ms () == 1000);

    assert_false (Difficulty.EASY.uses_transposition_table ());
    assert_false (Difficulty.MEDIUM.uses_transposition_table ());
    assert_true (Difficulty.HARD.uses_transposition_table ());

    assert_true (EASY_RANDOM_MOVE_CHANCE == 0.20);
    assert_cmpint (EASY_SCORE_TOLERANCE, CompareOperator.EQ, 2 * WEIGHT_STORE_DIFFERENTIAL);
}

/** RULES.md 7.26 */
private static void test_every_level_finds_the_forced_capture () {
    Board board = position (FORCED_CAPTURE);
    assert_cmpint (board.legal_moves ().length, CompareOperator.EQ, 2);

    foreach (Difficulty level in all_levels ()) {
        SearchResult result = fresh_search (level).search (board,
                                                           level.max_depth (),
                                                           level.time_budget_ms ());
        if (result.best_move != 4) {
            error ("%s picked house %d instead of the winning capture",
                   level.to_keyword (), result.best_move);
        }
        assert_cmpint (result.score, CompareOperator.GE, Search.DECISIVE_THRESHOLD);
        assert_cmpint (result.moves.length, CompareOperator.EQ, 2);
        assert_cmpint (result.moves[0].house, CompareOperator.EQ, 4);
    }
}

/** RULES.md 7.26, the levels that follow their search play it too. */
private static void test_medium_and_hard_play_the_forced_capture () {
    Board board = position (FORCED_CAPTURE);

    foreach (Difficulty level in new Difficulty[] { Difficulty.MEDIUM, Difficulty.HARD }) {
        var opponent = new Opponent (level, 12345);
        for (int attempt = 0; attempt < 20; attempt++) {
            assert_cmpint (opponent.choose_move (board), CompareOperator.EQ, 4);
        }
    }
}

/** RULES.md 7.27 */
private static void test_hard_reaches_depth_twelve_inside_its_budget () {
    string[] positions = {
        "4,4,4,4,4,4 | 4,4,4,4,4,4 | S:0 N:0 | to_move=S",
        "4,4,3,4,3,1 | 2,1,4,4,4,4 | S:5 N:5 | to_move=S",
        "2,2,2,2,3,1 | 2,1,4,4,4,4 | S:9 N:8 | to_move=S",
        "1,7,0,3,2,5 | 6,0,4,2,1,3 | S:7 N:7 | to_move=N",
    };

    foreach (string text in positions) {
        SearchResult result = fresh_search (Difficulty.HARD).search (
            position (text),
            Difficulty.HARD.max_depth (),
            Difficulty.HARD.time_budget_ms ());

        if (result.elapsed_ms > Difficulty.HARD.time_budget_ms ()) {
            error ("hard search took %s ms on %s, budget is %s ms",
                   result.elapsed_ms.to_string (), text,
                   Difficulty.HARD.time_budget_ms ().to_string ());
        }
        if (result.depth_reached != Difficulty.HARD.max_depth ()) {
            error ("hard search only reached depth %d on %s in %s ms",
                   result.depth_reached, text, result.elapsed_ms.to_string ());
        }
    }
}

/** RULES.md 7.28, swept across positions taken from a real game. */
private static void test_search_never_returns_an_illegal_move () {
    foreach (Board board in sampled_positions (99, 200)) {
        SearchResult result = new Search ().search (board, 6, 100);
        assert_cmpint (result.best_move, CompareOperator.GE, 0);
        if (!board.is_legal (result.best_move)) {
            error ("search returned illegal house %d for %s",
                   result.best_move, Notation.format (board));
        }
        foreach (MoveScore scored in result.moves) {
            assert_true (board.is_legal (scored.house));
        }
    }
}

/** RULES.md 7.28, the same guarantee through the difficulty levels. */
private static void test_no_level_ever_returns_an_illegal_move () {
    Board[] positions = sampled_positions (7, 12);
    foreach (Difficulty level in all_levels ()) {
        var opponent = new Opponent (level, 4321);
        foreach (Board board in positions) {
            int house = opponent.choose_move (board);
            if (!board.is_legal (house)) {
                error ("%s returned illegal house %d for %s",
                       level.to_keyword (), house, Notation.format (board));
            }
        }
    }
}

private static void test_search_reports_no_move_in_a_dead_position () {
    Board board = position ("1,1,0,0,0,0 | 0,0,0,0,0,0 | S:23 N:23 | to_move=S");

    SearchResult result = new Search ().search (board, 6, 100);

    assert_cmpint (result.best_move, CompareOperator.EQ, -1);
    assert_cmpint (result.moves.length, CompareOperator.EQ, 0);
}

/**
 * The only move South has empties their row, and North cannot feed them back,
 * so RULES.md 6.3 hands North the three seeds still on the board and the game
 * with them. The search has to score that as a decided loss rather than as a
 * quiet position two seeds to the good.
 */
private static void test_search_sees_a_starvation_ending () {
    Board board = position ("0,0,0,0,0,1 | 1,3,0,0,0,0 | S:20 N:23 | to_move=S");

    SearchResult result = new Search ().search (board, 6, 500);

    assert_cmpint (result.best_move, CompareOperator.EQ, 5);
    assert_cmpint (result.score, CompareOperator.LE, -Search.DECISIVE_THRESHOLD);
}

/** RULES.md 7.29, the search itself. */
private static void test_search_is_reproducible () {
    Board board = position ("4,4,3,4,3,1 | 2,1,4,4,4,4 | S:5 N:5 | to_move=S");

    SearchResult first = fresh_search (Difficulty.HARD).search (board, 8, 1000);
    SearchResult second = fresh_search (Difficulty.HARD).search (board, 8, 1000);

    assert_cmpint (first.best_move, CompareOperator.EQ, second.best_move);
    assert_cmpint (first.score, CompareOperator.EQ, second.score);
    assert_cmpint (first.depth_reached, CompareOperator.EQ, second.depth_reached);
    assert_cmpint (first.moves.length, CompareOperator.EQ, second.moves.length);
    for (int i = 0; i < first.moves.length; i++) {
        assert_cmpint (first.moves[i].house, CompareOperator.EQ, second.moves[i].house);
        assert_cmpint (first.moves[i].score, CompareOperator.EQ, second.moves[i].score);
    }
}

/**
 * RULES.md 7.29, the whole opponent. Easy is used on purpose: it is the level
 * that rolls dice, so a matching game proves the seed governs everything.
 */
private static void test_opponent_replays_the_same_game_from_the_same_seed () {
    int[] first = play_out (2026);
    int[] second = play_out (2026);

    assert_cmpint (first.length, CompareOperator.GT, 20);
    assert_cmpint (first.length, CompareOperator.EQ, second.length);
    for (int i = 0; i < first.length; i++) {
        assert_cmpint (first[i], CompareOperator.EQ, second[i]);
    }
}

private static int[] play_out (uint32 seed) {
    var opponent = new Opponent (Difficulty.EASY, seed);
    var game = new Game ();
    int[] played = {};

    while (game.outcome == Outcome.IN_PROGRESS && played.length < 150) {
        int house = opponent.choose_move (game.board);
        assert_true (game.play (house));
        played += house;
    }
    return played;
}

/**
 * Easy is meant to be beatable: it plays a random legal move a fifth of the
 * time. In this position it has two moves, so it should stray from the winning
 * one on roughly a tenth of its turns.
 */
private static void test_easy_strays_from_the_best_move () {
    Board board = position (FORCED_CAPTURE);
    var opponent = new Opponent (Difficulty.EASY, 2026);

    int samples = 2000;
    int strayed = 0;
    for (int i = 0; i < samples; i++) {
        if (opponent.choose_move (board) != 4) {
            strayed++;
        }
    }

    // A fifth of Easy's turns are played at random, and half of those land on
    // the losing move of the two, so about one turn in ten should go astray.
    // The bounds are written out rather than derived from the constants, so
    // that changing a constant fails this test instead of moving its target.
    double rate = (double) strayed / samples;
    if (rate < 0.06 || rate > 0.15) {
        error ("easy strayed on %.1f%% of turns, expected around 10%%", rate * 100.0);
    }
}

/** Medium follows its search every single time. */
private static void test_medium_never_strays () {
    Board board = position (FORCED_CAPTURE);
    var opponent = new Opponent (Difficulty.MEDIUM, 2026);

    for (int i = 0; i < 200; i++) {
        assert_cmpint (opponent.choose_move (board), CompareOperator.EQ, 4);
    }
}

/** Thinking off the main thread must not change what the opponent decides. */
private static void test_async_search_agrees_with_the_direct_search () {
    Board board = position (FORCED_CAPTURE);
    int expected = new Opponent (Difficulty.MEDIUM, 77).choose_move (board);

    var loop = new MainLoop ();
    var opponent = new Opponent (Difficulty.MEDIUM, 77);
    int chosen = -2;

    opponent.choose_move_async.begin (board, (source, result) => {
        chosen = opponent.choose_move_async.end (result);
        loop.quit ();
    });
    loop.run ();

    assert_cmpint (chosen, CompareOperator.EQ, expected);
}

/**
 * The whole point of the async search: the caller's main loop has to keep
 * running while the engine thinks, or the window would freeze. The tick is
 * finer than the search is long, so it fires whatever the search costs.
 */
private static void test_async_search_leaves_the_main_loop_running () {
    var loop = new MainLoop ();
    var opponent = new Opponent (Difficulty.HARD, 1);
    Board board = Board.initial ();

    int ticks = 0;
    uint ticker = Timeout.add (1, () => {
        ticks++;
        return Source.CONTINUE;
    });

    int chosen = -2;
    opponent.choose_move_async.begin (board, (source, result) => {
        chosen = opponent.choose_move_async.end (result);
        loop.quit ();
    });
    loop.run ();
    Source.remove (ticker);

    assert_true (board.is_legal (chosen));
    if (ticks == 0) {
        error ("the main loop never ran while the engine was thinking");
    }
}

/** Negamax needs the evaluation to be the same size and opposite sign per side. */
private static void test_evaluation_is_antisymmetric () {
    foreach (Board board in sampled_positions (55, 300)) {
        int south = evaluate (board, Player.SOUTH);
        int north = evaluate (board, Player.NORTH);
        if (south != -north) {
            error ("evaluation is not antisymmetric on %s: S %d, N %d",
                   Notation.format (board), south, north);
        }
    }
}

private static void test_evaluation_of_the_opening_is_level () {
    assert_cmpint (evaluate (Board.initial (), Player.SOUTH), CompareOperator.EQ, 0);
    assert_cmpint (evaluate (Board.initial (Player.NORTH), Player.NORTH), CompareOperator.EQ, 0);
}

/**
 * Banked seeds still outweigh the rest, but no longer everything put together.
 *
 * The bound was two banked seeds while a seed in your own row was worth 3, and
 * that is exactly what left the engine willing to hand its whole row across:
 * twenty four seeds it could still sow were worth less to it than one capture.
 * With the row weighted properly the soft terms reach 373 over this sample, so
 * the bound they are held to is four banked seeds rather than two.
 */
private static void test_banked_seeds_dominate_the_evaluation () {
    int largest = 0;
    foreach (Board board in sampled_positions (55, 300)) {
        int without_store = evaluate (board, Player.SOUTH)
            - (board.south_store - board.north_store) * WEIGHT_STORE_DIFFERENTIAL;
        int size = without_store < 0 ? -without_store : without_store;
        largest = int.max (largest, size);
    }
    assert_cmpint (largest, CompareOperator.LT, 4 * WEIGHT_STORE_DIFFERENTIAL);

    // Concretely: South holds every seed left on the board, North is starving,
    // and every soft term there is favours South. Five banked seeds still turn
    // the score around, which is what the store term dominating means.
    Board behind = position ("4,4,4,4,4,4 | 0,0,0,0,0,0 | S:9 N:15 | to_move=S");
    assert_cmpint (evaluate (behind, Player.SOUTH), CompareOperator.LT, 0);

    Board ahead = position ("1,1,1,1,1,1 | 0,0,0,0,0,0 | S:22 N:20 | to_move=S");
    assert_cmpint (evaluate (ahead, Player.SOUTH), CompareOperator.GT, 0);
}

public static int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/search/difficulty-table", test_difficulty_levels_match_the_brief);
    Test.add_func ("/search/every-level-finds-forced-capture", test_every_level_finds_the_forced_capture);
    Test.add_func ("/search/medium-and-hard-play-forced-capture", test_medium_and_hard_play_the_forced_capture);
    Test.add_func ("/search/hard-reaches-depth-twelve-in-budget", test_hard_reaches_depth_twelve_inside_its_budget);
    Test.add_func ("/search/never-returns-illegal-move", test_search_never_returns_an_illegal_move);
    Test.add_func ("/search/no-level-returns-illegal-move", test_no_level_ever_returns_an_illegal_move);
    Test.add_func ("/search/dead-position-has-no-move", test_search_reports_no_move_in_a_dead_position);
    Test.add_func ("/search/sees-starvation-ending", test_search_sees_a_starvation_ending);
    Test.add_func ("/search/is-reproducible", test_search_is_reproducible);
    Test.add_func ("/search/opponent-replays-same-game", test_opponent_replays_the_same_game_from_the_same_seed);
    Test.add_func ("/search/easy-strays", test_easy_strays_from_the_best_move);
    Test.add_func ("/search/medium-never-strays", test_medium_never_strays);
    Test.add_func ("/search/async-agrees-with-direct", test_async_search_agrees_with_the_direct_search);
    Test.add_func ("/search/async-leaves-loop-running", test_async_search_leaves_the_main_loop_running);
    Test.add_func ("/evaluation/antisymmetric", test_evaluation_is_antisymmetric);
    Test.add_func ("/evaluation/opening-is-level", test_evaluation_of_the_opening_is_level);
    Test.add_func ("/evaluation/banked-seeds-dominate", test_banked_seeds_dominate_the_evaluation);
    return Test.run ();
}
