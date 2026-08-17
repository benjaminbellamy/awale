// SPDX-FileCopyrightText: 2026 Benjamin Bellamy <benjamin@castopod.org>
// SPDX-License-Identifier: AGPL-3.0-or-later

namespace Awale {

    /** Why the advisor recommends a move. */
    public enum AdviceKind {
        /** It takes seeds straight away. */
        CAPTURES,
        /** It keeps the opponent from taking one of your houses next turn. */
        PROTECTS,
        /** The opponent is starving and this move feeds them (RULES.md 4). */
        FEEDS,
        /** Nothing else is legal. */
        ONLY_MOVE,
        /** No tactic either way, it simply leaves the better position. */
        BUILDS
    }

    /** A ranking of the moves available, and a reason for the best of them. */
    public struct Advice {
        /** House to recommend, or -1 when there is nothing to play. */
        public int best_house;
        public AdviceKind kind;
        /** Seeds captured, or seeds kept out of the opponent's reach. */
        public int seeds;
        /** The house being protected, when {@link kind} is PROTECTS. */
        public int house;
        /** Every legal move with its score, best first. */
        public MoveScore[] moves;
    }

    /**
     * Ranks the player's moves and works out, in engine terms, why the best one
     * is best. The reason comes back as data rather than as a sentence: turning
     * it into words is the user interface's job, because the words have to be
     * translated and this layer has no business knowing about language.
     *
     * Always searches at the Hard depth, whatever the opponent's difficulty is
     * set to, because a hint that is worse than the opponent would be useless.
     */
    public class Advisor : Object {

        public GrandSlamPolicy grand_slam_policy {
            get; set; default = GrandSlamPolicy.LEGAL_NO_CAPTURE;
        }

        /** Matches {@link Game.end_at_winning_score} of the game being advised. */
        public bool end_at_winning_score { get; set; default = true; }

        private Search engine = new Search ();

        public Advice advise (Board board) {
            Advice advice = Advice ();
            advice.best_house = -1;
            advice.kind = AdviceKind.BUILDS;
            advice.moves = new MoveScore[0];

            engine.grand_slam_policy = grand_slam_policy;
            engine.use_transposition_table = true;
            engine.end_at_winning_score = end_at_winning_score;

            SearchResult result = engine.search (board,
                                                 Difficulty.HARD.max_depth (),
                                                 Difficulty.HARD.time_budget_ms ());
            if (result.best_move < 0) {
                return advice;
            }

            advice.moves = result.moves;
            advice.best_house = result.best_move;
            explain (board, ref advice);
            return advice;
        }

        /** Runs {@link advise} on a worker thread so the window stays alive. */
        public async Advice advise_async (Board board) {
            SourceFunc resume = advise_async.callback;
            Advice advice = Advice ();

            var worker = new Thread<void> ("awale-advisor", () => {
                advice = advise (board);
                Idle.add ((owned) resume);
            });

            yield;
            worker.join ();
            return advice;
        }

        public void reset () {
            engine.clear ();
        }

        private void explain (Board board, ref Advice advice) {
            int[] legal = board.legal_moves (grand_slam_policy);

            // Being forced comes first: when there is no choice to make, that
            // is more use to the player than anything about the move itself.
            if (legal.length == 1) {
                advice.kind = AdviceKind.ONLY_MOVE;
                return;
            }

            MoveTrace trace = board.trace_move (advice.best_house, grand_slam_policy);
            if (trace.captured > 0) {
                advice.kind = AdviceKind.CAPTURES;
                advice.seeds = trace.captured;
                return;
            }
            if (board.row_is_empty (board.to_move.opponent ())) {
                advice.kind = AdviceKind.FEEDS;
                return;
            }

            // Compare what the opponent could take in reply to the recommended
            // move against what they could take in reply to anything else. If
            // the recommendation gives away less, that is the reason for it.
            int ignored;
            int recommended_threat = worst_reply (board, advice.best_house, out ignored);

            int alternative_threat = 0;
            int exposed_house = -1;
            foreach (int move in legal) {
                if (move == advice.best_house) {
                    continue;
                }
                int at_risk;
                int threat = worst_reply (board, move, out at_risk);
                if (threat > alternative_threat) {
                    alternative_threat = threat;
                    exposed_house = at_risk;
                }
            }

            if (alternative_threat > recommended_threat && exposed_house >= 0) {
                advice.kind = AdviceKind.PROTECTS;
                advice.seeds = alternative_threat - recommended_threat;
                advice.house = exposed_house;
                return;
            }

            advice.kind = AdviceKind.BUILDS;
            advice.seeds = 0;
        }

        /**
         * The most the opponent could capture immediately after {@link move},
         * and the house they would take it from.
         */
        private int worst_reply (Board board, int move, out int exposed_house) {
            exposed_house = -1;

            Board after = board.copy ();
            after.apply_move (move, grand_slam_policy);

            int worst = 0;
            foreach (int reply in after.legal_moves (grand_slam_policy)) {
                MoveTrace trace = after.trace_move (reply, grand_slam_policy);
                if (trace.captured > worst) {
                    worst = trace.captured;
                    exposed_house = trace.captured_houses.length > 0
                        ? trace.captured_houses[0] : -1;
                }
            }
            return worst;
        }
    }
}
