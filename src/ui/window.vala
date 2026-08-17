// SPDX-FileCopyrightText: 2026 Benjamin Bellamy <benjamin@castopod.org>
// SPDX-License-Identifier: AGPL-3.0-or-later

namespace Awale {

    /**
     * The game window. It owns a {@link Game} and an {@link Opponent}, turns
     * clicks and key presses into moves, and animates what the engine reports.
     * It contains no rule logic: every question about legality, capture or
     * termination is answered by the engine.
     */
    [GtkTemplate (ui = "/fr/benjaminbellamy/Awale/window.ui")]
    public class Window : Adw.ApplicationWindow {

        /** A move that lands instantly reads as a glitch rather than as a move. */
        private const uint THINKING_DELAY_MS = 400;
        private const uint SOWING_TOTAL_MS = 420;
        private const uint SOWING_MIN_STEP_MS = 45;
        private const uint SOWING_MAX_STEP_MS = 110;
        private const uint CAPTURE_STEP_MS = 130;

        /**
         * How long the computer's chosen house is held lit before the seeds
         * leave it, so the house it picked is seen rather than only the sowing
         * that follows.
         */
        private const uint CHOICE_PAUSE_MS = 450;

        /**
         * The same for the player's own move. Much shorter: they are not
         * waiting to find out which house was chosen, so this only has to be
         * long enough to see the house light up before the seeds move.
         */
        private const uint PLAYER_CHOICE_PAUSE_MS = 120;

        /**
         * How much the sowing animation is stretched at each level. A beginner
         * needs time to follow the seeds round the board; someone playing the
         * hardest level has watched it often enough and wants to get on.
         */
        private const double EASY_ANIMATION_SCALE = 3.0;
        private const double MEDIUM_ANIMATION_SCALE = 1.4;
        private const double HARD_ANIMATION_SCALE = 1.0;


        [GtkChild] private unowned Gtk.Box board_container;
        [GtkChild] private unowned Gtk.Label status_label;
        [GtkChild] private unowned Gtk.Label detail_label;

        private BoardView board_view;
        private Game game;
        private Opponent opponent;

        /** The person at the keyboard plays South. */
        private Player human = Player.SOUTH;

        /**
         * Who opens the next game. The player opens the first one, and every
         * new game after that swaps sides.
         */
        private Player next_opening_player = Player.SOUTH;

        private SimpleAction undo_action;
        private Settings settings;
        private Advisor advisor;

        /** True while a move is being applied or animated, when input is ignored. */
        private bool busy = false;

        /**
         * Outside learning mode the brief allows a single step undo, so this is
         * raised when a move completes and lowered as soon as it is used. In
         * learning mode undo is unlimited and this is ignored.
         */
        private bool undo_offered = false;

        /**
         * Bumped whenever the position changes, so that advice arriving from a
         * search that is no longer about the board on screen is thrown away.
         */
        private uint advice_generation = 0;

        public Window (Adw.Application application) {
            Object (application: application);
        }

        construct {
            settings = new Settings ("fr.benjaminbellamy.Awale");
            game = new Game ();
            // The winner is announced as soon as they reach 25, but the round
            // can be played out. See RULES.md 6.1.1.
            game.end_at_winning_score = false;
            advisor = new Advisor () { end_at_winning_score = false };
            opponent = new Opponent (
                difficulty_from_keyword (settings.get_string ("difficulty")),
                Random.next_int ());
            opponent.end_at_winning_score = false;

            board_view = new BoardView ();
            board_view.house_activated.connect (on_house_activated);

            // No clamp: the board measures itself against the room it is given
            // and sizes its pits from that, so anything wrapping it would only
            // get in the way.
            board_container.append (board_view);

            install_actions ();
            install_breakpoint ();
            install_settings ();
            apply_seed_counts ();

            if (!restore_saved_game ()) {
                game.reset (take_opening_player ());
            }
            refresh ();

            // A restored game, or a new one the computer opens, may already be
            // waiting on the computer.
            if (game.outcome == Outcome.IN_PROGRESS && game.board.to_move != human) {
                let_the_computer_move.begin ();
            }
        }

        private void install_settings () {
            settings.bind ("window-width", this, "default-width", SettingsBindFlags.DEFAULT);
            settings.bind ("window-height", this, "default-height", SettingsBindFlags.DEFAULT);
            settings.bind ("window-maximized", this, "maximized", SettingsBindFlags.DEFAULT);

            // Letting GSettings own these actions keeps the menu, the stored
            // value and the running game from drifting apart.
            add_action (settings.create_action ("difficulty"));
            add_action (settings.create_action ("learning-mode"));
            add_action (settings.create_action ("show-seed-counts"));
            add_action (settings.create_action ("language"));

            settings.changed["difficulty"].connect (() => {
                // Swappable in the middle of a game, as the brief asks.
                opponent.difficulty = difficulty_from_keyword (
                    settings.get_string ("difficulty"));
            });
            settings.changed["show-seed-counts"].connect (apply_seed_counts);
            settings.changed["learning-mode"].connect (() => refresh ());
            settings.changed["language"].connect (() => {
                // gettext picks its catalogue up once, before any of this
                // window exists, so a new language has to wait for a restart.
                show_detail (_("The new language will be used the next time Awalé is started."));
            });

            close_request.connect (() => {
                save_game ();
                return false;
            });
        }

        /**
         * Whether the seed counts are written out. Its own setting, independent
         * of difficulty: a player who wants the numbers can have them at any
         * level, and a player who does not can play without them at any level.
         */
        private void apply_seed_counts () {
            board_view.set_counts_visible (settings.get_boolean ("show-seed-counts"));
        }

        private bool learning_mode {
            get { return settings.get_boolean ("learning-mode"); }
        }

        /** Returns who opens now, and swaps sides for the game after this one. */
        private Player take_opening_player () {
            Player opening = next_opening_player;
            next_opening_player = opening.opponent ();
            return opening;
        }

        /** The language the help pages should be shown in. */
        private string help_language () {
            string chosen = settings.get_string ("language");
            if (chosen != "system") {
                return chosen;
            }
            foreach (string variable in new string[] { "LANGUAGE", "LC_ALL", "LC_MESSAGES", "LANG" }) {
                string? value = Environment.get_variable (variable);
                if (value == null || value.length < 2) {
                    continue;
                }
                string code = value.substring (0, 2);
                switch (code) {
                    case "en":
                    case "fr":
                    case "es":
                    case "de":
                    case "it":
                    case "nl":
                        return code;
                    default:
                        break;
                }
            }
            return "en";
        }

        /** Writes the game in progress out so the next launch can pick it up. */
        private void save_game () {
            if (game.outcome != Outcome.IN_PROGRESS || game.ply_count == 0) {
                settings.set_string ("saved-start", "");
                settings.set_value ("saved-moves", new VariantBuilder (new VariantType ("ai")).end ());
                return;
            }

            settings.set_string ("saved-start", Notation.format (game.start_position ()));
            var builder = new VariantBuilder (new VariantType ("ai"));
            foreach (int move in game.moves_played ()) {
                builder.add ("i", move);
            }
            settings.set_value ("saved-moves", builder.end ());
        }

        /**
         * Rebuilds the stored game by replaying its moves over its starting
         * position, which restores the undo history and the repetition count
         * along with the board. Anything that does not replay cleanly is
         * discarded rather than half applied.
         */
        private bool restore_saved_game () {
            string start = settings.get_string ("saved-start");
            if (start == "") {
                return false;
            }

            try {
                game.set_position (Notation.parse (start));
            } catch (NotationError e) {
                warning ("discarding the saved game, its position does not parse: %s", e.message);
                return false;
            }

            VariantIter moves = settings.get_value ("saved-moves").iterator ();
            int house = 0;
            while (moves.next ("i", out house)) {
                if (!game.play (house)) {
                    warning ("discarding the saved game, house %d is not a legal move", house);
                    game.reset (take_opening_player ());
                    return false;
                }
            }
            return game.outcome == Outcome.IN_PROGRESS;
        }

        private void install_actions () {
            var new_game = new SimpleAction ("new-game", null);
            new_game.activate.connect (() => start_new_game ());
            add_action (new_game);

            undo_action = new SimpleAction ("undo", null);
            undo_action.activate.connect (() => take_back ());
            add_action (undo_action);

            var play_house = new SimpleAction ("play-house", VariantType.INT32);
            play_house.activate.connect ((parameter) => {
                on_house_activated (human.row_start () + parameter.get_int32 ());
            });
            add_action (play_house);

            var help = new SimpleAction ("help", null);
            help.activate.connect (() => new HelpDialog (help_language ()).present (this));
            add_action (help);

            var cancel = new SimpleAction ("cancel", null);
            cancel.activate.connect (() => {
                // Nothing is half chosen in this mode, so Escape simply steps
                // back out of the board and clears any message.
                set_focus (null);
                show_detail (null);
            });
            add_action (cancel);

        }

        private void install_breakpoint () {
            var condition = Adw.BreakpointCondition.parse ("max-width: 560sp");
            if (condition == null) {
                return;
            }
            var breakpoint = new Adw.Breakpoint ((owned) condition);
            var compact = Value (typeof (bool));
            compact.set_boolean (true);
            breakpoint.add_setter (board_view, "compact", compact);
            add_breakpoint (breakpoint);
        }

        /** An unreadable setting falls back to the middle level rather than failing. */
        private Difficulty difficulty_from_keyword (string keyword) {
            Difficulty level;
            Difficulty.from_keyword (keyword, out level);
            return level;
        }

        private void start_new_game () {
            if (busy) {
                return;
            }
            game.reset (take_opening_player ());
            opponent.reset ();
            advisor.reset ();
            undo_offered = false;
            show_detail (null);
            save_game ();
            refresh ();

            if (game.board.to_move != human) {
                let_the_computer_move.begin ();
            }
        }

        private bool undo_available {
            // Unlimited in learning mode, a single step otherwise.
            get { return game.can_undo && (learning_mode || undo_offered); }
        }

        private void take_back () {
            if (busy || !undo_available) {
                return;
            }
            // Undo the computer's reply as well, so the board comes back to the
            // last moment it was the player's turn.
            game.undo ();
            if (game.can_undo && game.board.to_move != human) {
                game.undo ();
            }
            undo_offered = false;
            show_detail (null);
            refresh ();
        }

        private void on_house_activated (int house) {
            if (busy || game.outcome != Outcome.IN_PROGRESS) {
                return;
            }
            if (game.board.to_move != human) {
                return;
            }
            if (!game.board.is_legal (house, game.grand_slam_policy)) {
                explain_illegal_move (house);
                return;
            }
            show_detail (null);
            take_turn.begin (house);
        }

        /**
         * Says why a house cannot be played, rather than ignoring the click.
         * The engine decides the reason; this only puts it into words.
         */
        private void explain_illegal_move (int house) {
            string reason;
            switch (game.board.legality (house, game.grand_slam_policy)) {
                case Legality.NOT_YOUR_HOUSE:
                    reason = _("That house belongs to the computer.");
                    break;
                case Legality.EMPTY_HOUSE:
                    reason = _("That house is empty.");
                    break;
                case Legality.WOULD_NOT_FEED:
                    reason = _("The computer has no seeds left, so you must play a house whose seeds reach their row.");
                    break;
                case Legality.GRAND_SLAM_FORBIDDEN:
                    reason = _("That move would capture every seed the computer has left, which the rules do not allow.");
                    break;
                default:
                    return;
            }
            show_detail (reason);
        }

        private async void take_turn (int house) {
            yield play_out (house);
        }

        /** Used when the computer opens a game, or resumes a restored one. */
        private async void let_the_computer_move () {
            yield play_out (null);
        }

        /**
         * Plays the human's move if there is one, then the computer's reply,
         * holding input shut for the whole exchange. Both ways into a turn come
         * through here so that the board, the undo state and the saved game are
         * settled in one place.
         */
        private async void play_out (int? human_house) {
            busy = true;
            advice_generation++;
            refresh_controls ();
            board_view.clear_legal_moves ();
            set_advice (null);

            if (human_house != null) {
                yield apply_move (human_house);
            }

            if (game.outcome == Outcome.IN_PROGRESS && game.board.to_move != human) {
                yield computer_turn ();
            }

            busy = false;
            undo_offered = game.can_undo;
            save_game ();
            refresh ();
        }

        private async void computer_turn () {
            status_label.label = _("The computer is thinking…");

            int64 started = get_monotonic_time ();
            int house = yield opponent.choose_move_async (game.board);
            int64 spent_ms = (get_monotonic_time () - started) / 1000;
            if (spent_ms < THINKING_DELAY_MS) {
                yield pause ((uint) (THINKING_DELAY_MS - spent_ms));
            }

            if (house < 0) {
                return;
            }

            /// Said when the computer has chosen its move and is about to play
            /// it. %d is the computer's house, numbered 1 to 6 along its row.
            status_label.label = _("The computer plays house %d.").printf (
                house_number (house));

            yield apply_move (house);
        }

        /**
         * Applies a move to the game, then replays it on the board a seed at a
         * time. The order matters: the engine decides everything first, and the
         * animation is only a retelling of what it reported.
         */
        private async void apply_move (int house) {
            Board before = game.board.copy ();
            Player mover = before.to_move;
            MoveTrace trace = before.trace_move (house, game.grand_slam_policy);

            game.play (house);
            Board after = game.board.copy ();

            if (!animations_enabled ()) {
                board_view.display (after);
                return;
            }

            // Both sides light the house up before the seeds leave it, but the
            // computer's choice is held long enough to be read as a decision,
            // where the player only needs their own click acknowledged.
            uint hold = mover == human ? PLAYER_CHOICE_PAUSE_MS : CHOICE_PAUSE_MS;
            board_view.mark_chosen (house, true);
            yield pause (scaled (hold, animation_scale ()));
            board_view.mark_chosen (house, false);

            Board shown = before.copy ();
            shown.houses[house] = 0;
            board_view.set_house (house, 0);

            double pace = animation_scale ();
            uint step = scaled (SOWING_TOTAL_MS, pace) / uint.max (1, trace.sown_houses.length);
            step = uint.min (scaled (SOWING_MAX_STEP_MS, pace),
                             uint.max (scaled (SOWING_MIN_STEP_MS, pace), step));
            uint capture_step = scaled (CAPTURE_STEP_MS, pace);

            // The house taking the seed wears a thicker rim for as long as it
            // is the one being sown into, so the eye can follow the sowing
            // round the board.
            int previous = -1;
            foreach (int sown in trace.sown_houses) {
                yield pause (step);
                if (previous >= 0) {
                    board_view.mark_drop (previous, false);
                }
                shown.houses[sown] = shown.houses[sown] + 1;
                board_view.set_house (sown, shown.houses[sown]);
                board_view.mark_drop (sown, true);
                previous = sown;
            }
            if (previous >= 0) {
                yield pause (step);
                board_view.mark_drop (previous, false);
            }

            int store = before.store (mover);
            foreach (int taken in trace.captured_houses) {
                yield pause (capture_step);
                board_view.mark_capture (taken, true);
                store += shown.houses[taken];
                shown.houses[taken] = 0;
                board_view.set_house (taken, 0);
                board_view.set_store (mover, store);
            }
            if (trace.captured_houses.length > 0) {
                yield pause (capture_step);
            }

            // The engine may also have handed out the seeds left on the board,
            // so the final word on the position is always the game's.
            board_view.display (after);
        }

        /** How far the sowing animation is stretched for the level being played. */
        private double animation_scale () {
            switch (difficulty_from_keyword (settings.get_string ("difficulty"))) {
                case Difficulty.EASY:
                    return EASY_ANIMATION_SCALE;
                case Difficulty.MEDIUM:
                    return MEDIUM_ANIMATION_SCALE;
                default:
                    return HARD_ANIMATION_SCALE;
            }
        }

        private uint scaled (uint milliseconds, double pace) {
            return (uint) Math.round (milliseconds * pace);
        }

        private async void pause (uint milliseconds) {
            Timeout.add (milliseconds, pause.callback);
            yield;
        }

        private bool animations_enabled () {
            Gtk.Settings? settings = Gtk.Settings.get_default ();
            return settings == null || settings.gtk_enable_animations;
        }

        private void refresh () {
            Board board = game.board;
            board_view.display (board);

            if (game.outcome != Outcome.IN_PROGRESS) {
                board_view.clear_legal_moves ();
                board_view.clear_advice ();
                status_label.label = describe_outcome ();
                show_detail (describe_end_reason ());
                refresh_controls ();
                return;
            }

            // A game can be decided and still worth finishing, so the verdict
            // and whose turn it is are two separate things to say.
            if (game.decided_outcome != Outcome.IN_PROGRESS) {
                status_label.label = describe_decided ();
            } else if (board.to_move == human) {
                status_label.label = _("Your turn.");
            } else {
                status_label.label = _("The computer is thinking…");
            }

            if (board.to_move == human) {
                board_view.set_legal_moves (game.legal_moves ());
                if (learning_mode && !busy) {
                    offer_advice.begin ();
                } else {
                    set_advice (null);
                }
            } else {
                board_view.clear_legal_moves ();
            }

            refresh_controls ();
        }

        /**
         * Ranks the player's moves at the Hard depth and says why the best one
         * is best. The search runs off the main thread, and anything that comes
         * back about a position the player has already left is dropped.
         */
        private async void offer_advice () {
            uint generation = ++advice_generation;
            advisor.grand_slam_policy = game.grand_slam_policy;

            Advice advice = yield advisor.advise_async (game.board);
            if (generation != advice_generation || advice.best_house < 0) {
                return;
            }

            set_advice (advice);
        }

        /**
         * The star on the board and the sentence explaining it are one piece of
         * advice, so they are put up and taken down together. Other messages
         * borrow the same line without touching the star: an illegal move or
         * the reason a game ended replaces the sentence and leaves the
         * recommendation standing.
         */
        private void set_advice (Advice? advice) {
            if (advice == null) {
                board_view.clear_advice ();
                show_detail (null);
                return;
            }
            board_view.show_advice (advice);
            show_detail (describe_advice (advice));
        }

        private string describe_advice (Advice advice) {
            int best = house_number (advice.best_house);
            switch (advice.kind) {
                case AdviceKind.CAPTURES:
                    /// Learning mode hint. %1$d is the recommended house, 1 to 6.
                    /// %2$d is how many seeds it captures.
                    return ngettext ("Play house %1$d: it captures %2$d seed.",
                                     "Play house %1$d: it captures %2$d seeds.",
                                     advice.seeds).printf (best, advice.seeds);
                case AdviceKind.PROTECTS:
                    /// Learning mode hint. %1$d is the recommended house and
                    /// %2$d one of your own houses, both numbered 1 to 6.
                    /// %3$d is how many seeds it keeps out of reach.
                    return ngettext ("Play house %1$d: it avoids leaving your house %2$d open to a capture of %3$d seed.",
                                     "Play house %1$d: it avoids leaving your house %2$d open to a capture of %3$d seeds.",
                                     advice.seeds).printf (best, house_number (advice.house), advice.seeds);
                case AdviceKind.FEEDS:
                    /// Learning mode hint. %d is the recommended house, 1 to 6.
                    return _("Play house %d: the computer is out of seeds and this feeds them, which the rules require.").printf (best);
                case AdviceKind.ONLY_MOVE:
                    /// Learning mode hint. %d is the recommended house, 1 to 6.
                    return _("Play house %d: it is your only legal move.").printf (best);
                default:
                    /// Learning mode hint. %d is the recommended house, 1 to 6.
                    return _("Play house %d: it leaves you the strongest position.").printf (best);
            }
        }

        /** A house as the player counts it, 1 to 6 within their own row. */
        private int house_number (int house) {
            return (house % ROW_SIZE) + 1;
        }

        private void refresh_controls () {
            undo_action.set_enabled (!busy && undo_available);
        }

        /**
         * A message is put in and taken out by changing the text, never by
         * hiding the label: the height it reserves is what holds the board in
         * the middle of the window, and hiding it would move the board.
         */
        private void show_detail (string? text) {
            detail_label.label = text ?? "";
        }

        /** The verdict on a game that is won but still being played out. */
        private string describe_decided () {
            Board board = game.board;
            int mine = board.store (human);
            int theirs = board.store (human.opponent ());
            bool human_won = (game.decided_outcome == Outcome.SOUTH_WINS)
                == (human == Player.SOUTH);

            if (human_won) {
                /// Shown once the player has reached 25 seeds while the round
                /// is still being played. %1$d is their seeds, %2$d the computer's.
                return _("You have won, %1$d seeds to %2$d. You can still finish the round.").printf (mine, theirs);
            }
            /// Shown once the computer has reached 25 seeds while the round is
            /// still being played. %1$d is the computer's seeds, %2$d the player's.
            return _("The computer has won, %1$d seeds to %2$d. You can still finish the round.").printf (theirs, mine);
        }

        private string describe_outcome () {
            Board board = game.board;
            int mine = board.store (human);
            int theirs = board.store (human.opponent ());

            switch (game.outcome) {
                case Outcome.DRAW:
                    /// Final result. %d is the number of seeds each player collected.
                    return _("A draw, %d seeds each.").printf (mine);
                case Outcome.SOUTH_WINS:
                case Outcome.NORTH_WINS:
                    if ((game.outcome == Outcome.SOUTH_WINS) == (human == Player.SOUTH)) {
                        /// Final result. %1$d is the player's seeds, %2$d the computer's.
                        return _("You win, %1$d seeds to %2$d.").printf (mine, theirs);
                    }
                    /// Final result. %1$d is the computer's seeds, %2$d the player's.
                    return _("The computer wins, %1$d seeds to %2$d.").printf (theirs, mine);
                default:
                    return "";
            }
        }

        private string describe_end_reason () {
            switch (game.end_reason) {
                case EndReason.REPETITION:
                    return _("The same position came up three times, so each player took the seeds in their own row.");
                case EndReason.NO_CAPTURE_LIMIT:
                    return _("A hundred moves went by without a capture, so each player took the seeds in their own row.");
                case EndReason.STARVATION:
                    if (game.board.to_move == human) {
                        return _("You could not feed the computer, so you took the seeds left on the board.");
                    }
                    return _("The computer could not feed you, so it took the seeds left on the board.");
                case EndReason.DEAD_END:
                    return _("There was no legal move left to play.");
                default:
                    return "";
            }
        }
    }
}
