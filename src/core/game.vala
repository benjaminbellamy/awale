// SPDX-FileCopyrightText: 2026 Benjamin Bellamy <benjamin@castopod.org>
// SPDX-License-Identifier: AGPL-3.0-or-later

namespace Awale {

    /**
     * One game: the current position plus everything the rules need to look
     * back on, namely the position history for the threefold repetition guard
     * and the run of plies without a capture (RULES.md 6.2).
     */
    public class Game : Object {

        /**
         * Takes effect on the next move. Changing it does not re-examine the
         * position that is already on the board.
         */
        public GrandSlamPolicy grand_slam_policy { get; set; default = GrandSlamPolicy.LEGAL_NO_CAPTURE; }

        public Outcome outcome { get; private set; default = Outcome.IN_PROGRESS; }
        public EndReason end_reason { get; private set; default = EndReason.NONE; }

        /**
         * Whether crossing {@link WINNING_SEEDS} ends the game there and then,
         * as RULES.md 6.1 says it does. Turning it off lets a decided game be
         * played out: the winner is known, reported by {@link decided_outcome},
         * but the board carries on until one of the other endings of RULES.md 6
         * arrives.
         */
        public bool end_at_winning_score { get; set; default = true; }

        /**
         * Who has already won on seed count, whether or not play has stopped.
         * Computed from the board, so taking a move back withdraws it again.
         */
        public Outcome decided_outcome {
            get {
                if (current.south_store >= WINNING_SEEDS) {
                    return Outcome.SOUTH_WINS;
                }
                if (current.north_store >= WINNING_SEEDS) {
                    return Outcome.NORTH_WINS;
                }
                return Outcome.IN_PROGRESS;
            }
        }

        public Board board {
            get { return current; }
        }

        /** Plies played so far. */
        public int ply_count {
            get { return moves.length; }
        }

        /** Length of the current run of plies without a capture. */
        public int plies_since_capture {
            get { return no_capture_runs[no_capture_runs.length - 1]; }
        }

        public bool can_undo {
            get { return moves.length > 0; }
        }

        /** Emitted after a move has been applied to the board. */
        public signal void moved (int house, MoveResult result);

        /** Emitted after a move has been taken back. */
        public signal void undone ();

        /** Emitted once, when the game reaches a terminal position. */
        public signal void finished (Outcome outcome, EndReason reason);

        private Board current;
        // positions[i] is the position before moves[i] was played, and the last
        // entry is the position on the board right now.
        private Board[] positions;
        private int[] moves;
        private int[] no_capture_runs;

        public Game (Player first_to_move = Player.SOUTH,
                     GrandSlamPolicy policy = GrandSlamPolicy.LEGAL_NO_CAPTURE) {
            Object (grand_slam_policy: policy);
            set_position (Board.initial (first_to_move));
        }

        public Game.from_board (Board start,
                                GrandSlamPolicy policy = GrandSlamPolicy.LEGAL_NO_CAPTURE) {
            Object (grand_slam_policy: policy);
            set_position (start);
        }

        public void reset (Player first_to_move = Player.SOUTH) {
            set_position (Board.initial (first_to_move));
        }

        /** Starts afresh from {@link start}, dropping all history. */
        public void set_position (Board start) {
            current = start.copy ();
            positions = new Board[] { current.copy () };
            moves = new int[0];
            no_capture_runs = new int[] { 0 };
            outcome = Outcome.IN_PROGRESS;
            end_reason = EndReason.NONE;
            evaluate_termination ();
        }

        /** The position this game started from, before any move was played. */
        public Board start_position () {
            return positions[0].copy ();
        }

        /**
         * The houses played so far, in order. Together with
         * {@link start_position} this is everything needed to rebuild the game,
         * which is how it survives being closed and reopened.
         */
        public int[] moves_played () {
            var played = new int[moves.length];
            for (int i = 0; i < moves.length; i++) {
                played[i] = moves[i];
            }
            return played;
        }

        public int[] legal_moves () {
            if (outcome != Outcome.IN_PROGRESS) {
                return new int[0];
            }
            return current.legal_moves (grand_slam_policy);
        }

        /** Plays {@link house}. Returns false when the move is not available. */
        public bool play (int house) {
            if (outcome != Outcome.IN_PROGRESS) {
                return false;
            }
            if (!current.is_legal (house, grand_slam_policy)) {
                return false;
            }

            MoveResult result = current.apply_move (house, grand_slam_policy);

            positions += current.copy ();
            moves += house;
            no_capture_runs += result.captured > 0 ? 0 : plies_since_capture + 1;

            moved (house, result);
            evaluate_termination ();
            return true;
        }

        /** Takes back the last move. Returns false when there is none. */
        public bool undo () {
            if (moves.length == 0) {
                return false;
            }

            positions.resize (positions.length - 1);
            moves.resize (moves.length - 1);
            no_capture_runs.resize (no_capture_runs.length - 1);
            current = positions[positions.length - 1].copy ();
            outcome = Outcome.IN_PROGRESS;
            end_reason = EndReason.NONE;

            undone ();
            return true;
        }

        private void evaluate_termination () {
            // 6.1, the game stops the moment a store crosses the threshold,
            // unless the caller has asked to play a decided game out.
            if (end_at_winning_score && decided_outcome != Outcome.IN_PROGRESS) {
                finish (decided_outcome, EndReason.SEED_MAJORITY);
                return;
            }
            // Nothing left to play for. No legal move can bring this about,
            // since emptying the opponent's row is a grand slam, but a position
            // can be loaded in this state. This is where 24 to 24 is a draw.
            if (current.seeds_on_board () == 0) {
                finish (outcome_from_stores (), EndReason.SEED_MAJORITY);
                return;
            }

            // 6.2, the two guards against endless play. Both stop the game the
            // same way: each player keeps what is left in their own row.
            if (repetition_count () >= REPETITION_LIMIT) {
                end_by_collecting_rows (EndReason.REPETITION);
                return;
            }
            if (plies_since_capture >= NO_CAPTURE_PLY_LIMIT) {
                end_by_collecting_rows (EndReason.NO_CAPTURE_LIMIT);
                return;
            }

            if (current.legal_moves (grand_slam_policy).length > 0) {
                return;
            }
            if (current.has_sowable_move ()) {
                // Only forbidden grand slams remain. RULES.md 5 does not cover
                // it, the project rules it a draw.
                finish (Outcome.DRAW, EndReason.DEAD_END);
                return;
            }
            // 6.3, the starving opponent cannot be fed, so everything left on
            // the board goes to the player who cannot move.
            Player stuck = current.to_move;
            current.collect_board (stuck);
            sync_current_position ();
            finish (outcome_from_stores (), EndReason.STARVATION);
        }

        /** Ends the game with each player keeping the seeds in their own row. */
        private void end_by_collecting_rows (EndReason reason) {
            current.collect_rows ();
            sync_current_position ();
            finish (outcome_from_stores (), reason);
        }

        private void finish (Outcome result, EndReason reason) {
            outcome = result;
            end_reason = reason;
            finished (result, reason);
        }

        private Outcome outcome_from_stores () {
            if (current.south_store > current.north_store) {
                return Outcome.SOUTH_WINS;
            }
            if (current.north_store > current.south_store) {
                return Outcome.NORTH_WINS;
            }
            return Outcome.DRAW;
        }

        /**
         * Keeps the history in step after the rules have handed out the seeds
         * left on the board, so that undo restores what was really there.
         */
        private void sync_current_position () {
            positions[positions.length - 1] = current.copy ();
        }

        private int repetition_count () {
            int count = 0;
            foreach (Board seen in positions) {
                if (seen.equals (current)) {
                    count++;
                }
            }
            return count;
        }
    }
}
