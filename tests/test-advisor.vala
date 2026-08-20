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
    // Not necessarily the first of them: moves that tie for best are chosen
    // between by the position. It has to be one of the moves that tie.
    assert_cmpint (advice.moves[0].score, CompareOperator.EQ,
                   score_of (advice.moves, advice.best_house));
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
 * The reason describes the board the player is looking at.
 *
 * Every house it names is the player's own and holds seeds right now, so they
 * can be counted where they are named; nothing the opponent can reply with
 * takes any of them; and some other move really would leave one there to be
 * taken, or protecting them is not why this move was chosen.
 */
void test_protecting_advice_describes_the_board_in_front_of_the_player () {
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

        // Every house the capture would empty is named, they are the player's
        // own, and they hold seeds already. The seeds are counted as those
        // houses stand when the capture lands rather than as they stand now,
        // and RULES.md 3 only lets a house be taken holding two or three, so
        // the figure falls between two and three times the number named.
        int taken = advice.exposed_houses.length;
        assert_cmpint (taken, CompareOperator.GT, 0);
        foreach (int house in advice.exposed_houses) {
            assert_true (board.to_move.owns (house));
            if (board.houses[house] == 0) {
                error ("named house %d in %s, which holds nothing",
                       house, Notation.format (board));
            }
        }
        assert_cmpint (advice.seeds, CompareOperator.GE, 2 * taken);
        assert_cmpint (advice.seeds, CompareOperator.LE, 3 * taken);

        if (!houses_survive (board, advice.best_house, advice.exposed_houses)) {
            error ("claimed to protect houses in %s that house %d does not save",
                   Notation.format (board), advice.best_house);
        }

        bool another_leaves_them = false;
        foreach (int move in board.legal_moves ()) {
            if (move != advice.best_house
                && !houses_survive (board, move, advice.exposed_houses)) {
                another_leaves_them = true;
            }
        }
        if (!another_leaves_them) {
            error ("claimed to protect houses in %s that no move leaves open",
                   Notation.format (board));
        }
        if (checked >= 5) {
            return;
        }
    }

    if (checked == 0) {
        error ("no protecting advice turned up in the sample, nothing was verified");
    }
}

/** True when no reply to {@link move} takes any of {@link houses}. */
bool houses_survive (Board board, int move, int[] houses) {
    Board after = board.copy ();
    after.apply_move (move);
    foreach (int reply in after.legal_moves ()) {
        MoveTrace trace = after.trace_move (reply);
        foreach (int emptied in trace.captured_houses) {
            foreach (int house in houses) {
                if (emptied == house) {
                    return false;
                }
            }
        }
    }
    return true;
}

/**
 * The threat named is the one standing on the board, counted in a house the
 * player can look at.
 *
 * The first position is one the advisor used to get wrong: it pointed at
 * house 6, which holds nothing, and said two seeds were about to be lost from
 * it. The capture was real, but the seeds in it were the computer's own,
 * dropped there on the way past, so there was nothing on the board to count.
 */
void test_protecting_advice_counts_seeds_where_they_are () {
    Board nothing_to_count = position ("0,7,0,8,7,0 | 6,0,1,8,8,0 | S:3 N:0 | to_move=S");

    Advice advice = new Advisor ().advise (nothing_to_count);

    foreach (int house in advice.exposed_houses) {
        if (nothing_to_count.houses[house] == 0) {
            error ("named house %d, which holds nothing", house);
        }
    }

    // Where there is something to name it is named, with the count the capture
    // really takes: house 1 holds two seeds and the computer's own seed lands
    // there on top of them.
    Board real_threat = position ("2,4,2,10,0,2 | 0,3,4,2,11,3 | S:5 N:0 | to_move=S");

    advice = new Advisor ().advise (real_threat);

    assert_true (advice.kind == AdviceKind.PROTECTS);
    assert_cmpint (advice.exposed_houses.length, CompareOperator.EQ, 1);
    assert_cmpint (advice.exposed_houses[0], CompareOperator.EQ, 0);
    assert_cmpint (real_threat.houses[0], CompareOperator.EQ, 2);
    assert_cmpint (advice.seeds, CompareOperator.EQ, 3);
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

/** The score the ranking gave one house. */
private static int score_of (MoveScore[] moves, int house) {
    foreach (MoveScore scored in moves) {
        if (scored.house == house) {
            return scored.score;
        }
    }
    error ("house %d was not ranked", house);
}

/**
 * Moves the search cannot tell apart are chosen between by the position, so a
 * player looking at the same board is always told the same move. Here two
 * moves share the top score, which is the case the choice exists for.
 *
 * That the choice is spread across the tied moves rather than always landing
 * on one of them is a property of many positions at once, so it is measured by
 * playing games rather than asserted here.
 */
void test_equal_moves_are_chosen_between_by_the_position () {
    Board board = position ("1,2,2,1,1,0 | 1,0,0,0,0,0 | S:20 N:20 | to_move=S");

    Advice advice = new Advisor ().advise (board);

    int top = advice.moves[0].score;
    assert_cmpint (advice.moves[1].score, CompareOperator.EQ, top);
    assert_cmpint (score_of (advice.moves, advice.best_house), CompareOperator.EQ, top);

    for (int again = 0; again < 4; again++) {
        assert_cmpint (new Advisor ().advise (board).best_house,
                       CompareOperator.EQ, advice.best_house);
    }
}

/**
 * A capture that hands more back is still the best move on the board, but
 * calling it "captures 4 seeds" and stopping there reads as a gain when it is
 * not one. The reply has to travel with the advice so the hint can say it.
 */
void test_advice_reports_what_comes_straight_back () {
    Board board = position ("0,0,4,0,3,1 | 0,0,0,10,0,13 | S:9 N:8 | to_move=N");

    Advice advice = new Advisor ().advise (board);

    assert_true (advice.kind == AdviceKind.CAPTURES);
    assert_cmpint (advice.seeds, CompareOperator.GT, 0);
    assert_cmpint (advice.reply, CompareOperator.GT, advice.seeds);
}

/**
 * A capture that gives nothing back reports no reply, so the hint reads as the
 * plain gain it is. Here house 6 is taken and nothing North holds can reach
 * South's row in one sowing.
 */
void test_advice_reports_no_reply_when_there_is_none () {
    Board board = position ("0,0,0,2,1,1 | 1,2,2,1,1,0 | S:19 N:18 | to_move=S");

    Advice advice = new Advisor ().advise (board);

    assert_true (advice.kind == AdviceKind.CAPTURES);
    assert_cmpint (advice.reply, CompareOperator.EQ, 0);
}

/**
 * When the starred move shows nothing for itself and another move takes seeds,
 * the board can say what that other move really costs. Here the capture is
 * answered by a bigger one.
 */
void test_a_tempting_capture_is_named_with_its_cost () {
    Board board = position ("1,1,1,2,0,2 | 0,1,3,1,2,3 | S:15 N:16 | to_move=S");

    Advice advice = new Advisor ().advise (board);

    assert_cmpint (advice.tempting_house, CompareOperator.NE, -1);
    assert_cmpint (advice.tempting_house, CompareOperator.NE, advice.best_house);
    assert_cmpint (advice.tempting_captures, CompareOperator.GT, 0);
    assert_cmpint (advice.tempting_reply, CompareOperator.GT, advice.tempting_captures);
}

/** A recommendation that speaks for itself needs nothing defending against. */
void test_nothing_is_tempting_when_the_advice_captures () {
    Board board = position ("0,0,0,2,1,1 | 1,2,2,1,1,0 | S:19 N:18 | to_move=S");

    Advice advice = new Advisor ().advise (board);

    assert_true (advice.kind == AdviceKind.CAPTURES);
    assert_cmpint (advice.tempting_house, CompareOperator.EQ, -1);
}

public static int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/advisor/ranks-every-legal-move", test_advice_ranks_every_legal_move);
    Test.add_func ("/advisor/explains-a-capture", test_advice_explains_a_capture);
    Test.add_func ("/advisor/reports-a-forced-move", test_advice_reports_a_forced_move);
    Test.add_func ("/advisor/explains-feeding", test_advice_explains_feeding);
    Test.add_func ("/advisor/protects-a-real-house", test_protecting_advice_describes_the_board_in_front_of_the_player);
    Test.add_func ("/advisor/counts-seeds-where-they-are", test_protecting_advice_counts_seeds_where_they_are);
    Test.add_func ("/advisor/dead-position", test_advice_on_a_dead_position);
    Test.add_func ("/advisor/async-matches", test_advice_async_matches_and_keeps_the_loop_running);
    Test.add_func ("/advisor/refuses-a-losing-capture", test_advice_refuses_a_capture_that_hands_over_the_game);
    Test.add_func ("/advisor/won-game-still-ranks", test_advice_on_a_won_game_still_prefers_the_capture);
    Test.add_func ("/advisor/equal-moves-chosen-by-position", test_equal_moves_are_chosen_between_by_the_position);
    Test.add_func ("/advisor/reports-the-reply", test_advice_reports_what_comes_straight_back);
    Test.add_func ("/advisor/no-reply-to-report", test_advice_reports_no_reply_when_there_is_none);
    Test.add_func ("/advisor/tempting-capture-named", test_a_tempting_capture_is_named_with_its_cost);
    Test.add_func ("/advisor/nothing-tempting", test_nothing_is_tempting_when_the_advice_captures);
    return Test.run ();
}
