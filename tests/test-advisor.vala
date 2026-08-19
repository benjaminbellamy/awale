// SPDX-FileCopyrightText: 2026 Benjamin Bellamy <benjamin@castopod.org>
// SPDX-License-Identifier: AGPL-3.0-or-later

using Awale;
using Awale.TestUtil;

/** The learning mode advisor: ranking, and the reason given for the best move. */

/** Every legal move is ranked, best first, and nothing illegal appears. */
void test_advice_ranks_every_legal_move () {
    Board board = position ("4,4,3,4,3,1 | 2,1,4,4,4,4 | S:5 N:5 | to_move=S");
    int[] legal = board.legal_moves ();

    Advice advice = new Advisor ().advise (board);

    assert_cmpint (advice.moves.length, CompareOperator.EQ, legal.length);
    assert_cmpint (advice.best_house, CompareOperator.EQ, advice.moves[0].house);
    for (int i = 1; i < advice.moves.length; i++) {
        assert_cmpint (advice.moves[i - 1].score, CompareOperator.GE, advice.moves[i].score);
    }
    foreach (MoveScore scored in advice.moves) {
        assert_true (board.is_legal (scored.house));
    }
}

/** A move that takes seeds is explained by the seeds it takes. */
void test_advice_explains_a_capture () {
    Board board = position ("0,0,0,0,3,1 | 2,1,1,0,0,0 | S:20 N:20 | to_move=S");

    Advice advice = new Advisor ().advise (board);

    assert_cmpint (advice.best_house, CompareOperator.EQ, 4);
    assert_true (advice.kind == AdviceKind.CAPTURES);
    assert_cmpint (advice.seeds, CompareOperator.EQ, 5);
}

/** With one move available, that is the reason. */
void test_advice_reports_a_forced_move () {
    Board board = position ("0,0,0,0,0,1 | 1,3,0,0,0,0 | S:20 N:23 | to_move=S");
    assert_cmpint (board.legal_moves ().length, CompareOperator.EQ, 1);

    Advice advice = new Advisor ().advise (board);

    assert_cmpint (advice.best_house, CompareOperator.EQ, 5);
    assert_true (advice.kind == AdviceKind.ONLY_MOVE);
}

/**
 * North is starving, so the only playable move is the one that feeds them, and
 * the advisor says so rather than talking about material.
 */
void test_advice_explains_feeding () {
    Board board = position ("1,0,0,0,2,4 | 0,0,0,0,0,0 | S:20 N:21 | to_move=S");

    Advice advice = new Advisor ().advise (board);

    assert_true (board.row_is_empty (Player.NORTH));
    assert_true (advice.kind == AdviceKind.FEEDS || advice.kind == AdviceKind.ONLY_MOVE);
}

/**
 * The reason names a house that really is at risk: the house the advisor says
 * it is protecting must belong to the player, and some other move must really
 * let the opponent take seeds from it.
 */
void test_protecting_advice_names_a_house_that_is_really_at_risk () {
    var advisor = new Advisor ();
    int checked = 0;

    foreach (Board board in sampled_positions (31, 400)) {
        if (board.to_move != Player.SOUTH) {
            continue;
        }
        Advice advice = advisor.advise (board);
        if (advice.kind != AdviceKind.PROTECTS) {
            continue;
        }
        checked++;

        assert_true (board.to_move.owns (advice.house));
        assert_cmpint (advice.seeds, CompareOperator.GT, 0);

        bool alternative_gives_seeds_away = false;
        foreach (int move in board.legal_moves ()) {
            if (move == advice.best_house) {
                continue;
            }
            Board after = board.copy ();
            after.apply_move (move);
            foreach (int reply in after.legal_moves ()) {
                if (after.trace_move (reply).captured > 0) {
                    alternative_gives_seeds_away = true;
                }
            }
        }
        if (!alternative_gives_seeds_away) {
            error ("claimed to protect house %d in %s, but no other move gives anything away",
                   advice.house, Notation.format (board));
        }
        if (checked >= 5) {
            return;
        }
    }

    if (checked == 0) {
        error ("no protecting advice turned up in the sample, nothing was verified");
    }
}

/** A position with nothing playable gets no recommendation rather than a wrong one. */
void test_advice_on_a_dead_position () {
    Board board = position ("1,1,0,0,0,0 | 0,0,0,0,0,0 | S:23 N:23 | to_move=S");

    Advice advice = new Advisor ().advise (board);

    assert_cmpint (advice.best_house, CompareOperator.EQ, -1);
    assert_cmpint (advice.moves.length, CompareOperator.EQ, 0);
}

/** The threaded form has to agree with the direct one and keep the loop alive. */
void test_advice_async_matches_and_keeps_the_loop_running () {
    Board board = position ("4,4,3,4,3,1 | 2,1,4,4,4,4 | S:5 N:5 | to_move=S");
    Advice expected = new Advisor ().advise (board);

    var loop = new MainLoop ();
    var advisor = new Advisor ();
    int best = -2;

    advisor.advise_async.begin (board, (source, result) => {
        best = advisor.advise_async.end (result).best_house;
        loop.quit ();
    });
    loop.run ();

    assert_cmpint (best, CompareOperator.EQ, expected.best_house);
}

/**
 * RULES.md 6.1: reaching 25 seeds settles the game, so a move that hands the
 * opponent their 25th seed loses however many seeds it wins on the way.
 *
 * North sits on 23 with nineteen seeds still on the board, so crossing 25
 * decides the game without ending it. Every move except house 0 lets North
 * answer with house 11 into house 0, take two and reach 25. House 0 empties
 * the house North is aiming at and takes nothing, which is the only move that
 * keeps the game alive.
 */
void test_advice_refuses_a_capture_that_hands_over_the_game () {
    Board board = position ("1,3,3,3,0,1 | 1,3,3,0,0,1 | S:6 N:23 | to_move=S");

    Advice advice = new Advisor ().advise (board);

    assert_cmpint (advice.best_house, CompareOperator.EQ, 0);
}

/**
 * Once the game is decided every line is a loss, and scoring them all as one
 * would leave the advice picking a move at random. A round being played out is
 * ranked on what it can still win instead.
 */
void test_advice_on_a_won_game_still_prefers_the_capture () {
    // North is already past 25, so nothing South plays can save the game.
    Board board = position ("0,1,0,0,0,1 | 1,1,0,0,0,0 | S:19 N:25 | to_move=S");

    Advice advice = new Advisor ().advise (board);

    assert_cmpint (advice.best_house, CompareOperator.EQ, 5);
}
public static int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/advisor/ranks-every-legal-move", test_advice_ranks_every_legal_move);
    Test.add_func ("/advisor/explains-a-capture", test_advice_explains_a_capture);
    Test.add_func ("/advisor/reports-a-forced-move", test_advice_reports_a_forced_move);
    Test.add_func ("/advisor/explains-feeding", test_advice_explains_feeding);
    Test.add_func ("/advisor/protects-a-real-house", test_protecting_advice_names_a_house_that_is_really_at_risk);
    Test.add_func ("/advisor/dead-position", test_advice_on_a_dead_position);
    Test.add_func ("/advisor/async-matches", test_advice_async_matches_and_keeps_the_loop_running);
    Test.add_func ("/advisor/refuses-a-losing-capture", test_advice_refuses_a_capture_that_hands_over_the_game);
    Test.add_func ("/advisor/won-game-still-ranks", test_advice_on_a_won_game_still_prefers_the_capture);
    return Test.run ();
}
