// SPDX-FileCopyrightText: 2026 Benjamin Bellamy <benjamin@castopod.org>
// SPDX-License-Identifier: AGPL-3.0-or-later

namespace Awale {

    /**
     * A player's store: the captured seeds drawn in a round pit like the
     * houses, the count written inside it and the owner's name below.
     */
    public class StoreView : Gtk.Box {

        private const int GAP = 4;

        private Gtk.Label count_label;
        private Gtk.Label title_label;
        private SeedField field;
        private bool mine;

        public StoreView (bool mine) {
            Object (orientation: Gtk.Orientation.VERTICAL, spacing: GAP);
            this.mine = mine;

            halign = Gtk.Align.CENTER;
            valign = Gtk.Align.CENTER;

            count_label = new Gtk.Label ("0") {
                halign = Gtk.Align.CENTER,
                valign = Gtk.Align.END,
            };
            count_label.add_css_class ("store-count");

            field = new SeedField () { halign = Gtk.Align.CENTER };
            field.add_css_class ("store");

            // The count goes inside the store, as it does inside a house.
            var overlay = new Gtk.Overlay ();
            overlay.child = field;
            overlay.add_overlay (count_label);

            /// Name under the player's own store, and under the computer's.
            title_label = new Gtk.Label (mine ? _("You") : _("Computer")) {
                halign = Gtk.Align.CENTER,
                // Otherwise the width of this word would put a floor under the
                // size of every pit on the board.
                ellipsize = Pango.EllipsizeMode.END,
            };
            title_label.add_css_class ("store-title");

            append (overlay);
            append (title_label);
            set_seeds (0);
        }

        /** Makes the pit exactly {@link side} across, which keeps it round. */
        public void set_pit_size (int side) {
            field.set_size_request (side, side);
        }

        /** Height this widget needs on top of the pit itself: its name. */
        public int extra_height () {
            return natural_height (title_label) + GAP;
        }

        private int natural_height (Gtk.Widget widget) {
            int minimum, natural, ignored_a, ignored_b;
            widget.measure (Gtk.Orientation.VERTICAL, -1, out minimum, out natural,
                            out ignored_a, out ignored_b);
            return natural;
        }

        /** Whether the seed count is written inside the store. */
        public bool show_count {
            get { return count_label.visible; }
            set { count_label.visible = value; }
        }

        public void set_seeds (int seeds) {
            count_label.label = seeds.to_string ();
            field.seeds = seeds;

            // Written out twice rather than built from a name and a noun: the
            // two read differently in most languages.
            string label;
            if (mine) {
                /// Accessibility label for the player's own store.
                /// %d is how many seeds they have captured.
                label = ngettext ("Your store, %d seed captured",
                                  "Your store, %d seeds captured", seeds).printf (seeds);
            } else {
                /// Accessibility label for the computer's store.
                /// %d is how many seeds it has captured.
                label = ngettext ("The computer's store, %d seed captured",
                                  "The computer's store, %d seeds captured", seeds).printf (seeds);
            }
            update_property (Gtk.AccessibleProperty.LABEL, label, -1);
        }
    }

    /**
     * The board: twelve houses and two stores. It knows nothing about the
     * rules, everything it displays is handed to it.
     *
     * The layout is done here by hand rather than with a Gtk.Grid. A grid hands
     * its layout to a layout manager, and GTK then never calls the widget's own
     * size_allocate, so there is no way to see how much room the board has been
     * given. Doing it here means the pits can be sized from the space actually
     * available: across the window when the board is flat, down it when the
     * board is turned.
     */
    public class BoardView : Gtk.Widget {

        private const int SPACING = 8;
        private const int MIN_SIDE = 40;
        private const int MAX_SIDE = 160;

        public signal void house_activated (int house);

        /**
         * Turns the board a quarter turn for narrow windows: the two rows
         * become two columns and the stores move to the top and the bottom,
         * which keeps the counterclockwise cycle readable instead of clipping
         * the board.
         */
        public bool compact { get; set; default = false; }

        private HouseButton[] houses = new HouseButton[HOUSE_COUNT];
        private StoreView south_store;
        private StoreView north_store;
        private CaptureArrows arrows;
        private Graphene.Point[] house_centres = new Graphene.Point[HOUSE_COUNT];
        private int applied_side = 0;

        construct {
            add_css_class ("board");
            hexpand = true;
            vexpand = true;

            for (int house = 0; house < HOUSE_COUNT; house++) {
                var button = new HouseButton (house, house < ROW_SIZE);
                int played = house;
                button.activated.connect (() => house_activated (played));
                button.set_parent (this);
                houses[house] = button;
            }

            south_store = new StoreView (true);
            north_store = new StoreView (false);
            south_store.set_parent (this);
            north_store.set_parent (this);

            // Last child, so its arcs are drawn over every pit.
            arrows = new CaptureArrows ();
            arrows.set_parent (this);

            notify["compact"].connect (() => queue_resize ());
        }

        public override void dispose () {
            foreach (HouseButton button in houses) {
                button.unparent ();
            }
            south_store.unparent ();
            north_store.unparent ();
            arrows.unparent ();
            base.dispose ();
        }

        public override Gtk.SizeRequestMode get_request_mode () {
            return Gtk.SizeRequestMode.CONSTANT_SIZE;
        }

        public override void measure (Gtk.Orientation orientation,
                                      int for_size,
                                      out int minimum,
                                      out int natural,
                                      out int minimum_baseline,
                                      out int natural_baseline) {
            minimum_baseline = -1;
            natural_baseline = -1;

            if (orientation == Gtk.Orientation.HORIZONTAL) {
                minimum = board_width (MIN_SIDE);
                natural = board_width (MAX_SIDE);
            } else {
                minimum = board_height (MIN_SIDE);
                natural = board_height (MAX_SIDE);
            }
        }

        public override void size_allocate (int width, int height, int baseline) {
            int side = fit_side (width, height);
            if (side != applied_side) {
                applied_side = side;
                foreach (HouseButton button in houses) {
                    button.set_pit_size (side);
                }
                south_store.set_pit_size (side);
                north_store.set_pit_size (side);
            }

            // The whole board is centred in whatever room it was given.
            int left = (width - board_width (side)) / 2;
            int top = (height - board_height (side)) / 2;

            if (compact) {
                allocate_turned (side, left, top);
            } else {
                allocate_flat (side, left, top);
            }

            // Told where the pits ended up before it is given its own room:
            // the arrows are drawn and their bubbles placed against the pits,
            // so the pits have to be settled first.
            arrows.set_board (house_centres, side);
            place (arrows, 0, 0, width, height);
        }

        /** Six houses across, two rows, a store at each end. */
        private void allocate_flat (int side, int left, int top) {
            int step = side + SPACING;
            int row_height = side + houses[0].extra_height ();

            for (int i = 0; i < ROW_SIZE; i++) {
                // North's row reads right to left, which is the direction
                // sowing travels along the top of the board.
                place_house (HOUSE_COUNT - 1 - i, left + (i + 1) * step, top, side, row_height);
                place_house (i, left + (i + 1) * step, top + row_height + SPACING,
                             side, row_height);
            }

            int store_height = side + north_store.extra_height ();
            int store_top = top + (2 * row_height + SPACING - store_height) / 2;
            place (north_store, left, store_top, side, store_height);
            place (south_store, left + (ROW_SIZE + 1) * step, store_top, side, store_height);
        }

        /** Two columns of six, a store above and a store below. */
        private void allocate_turned (int side, int left, int top) {
            int row_height = side + houses[0].extra_height ();
            int store_height = side + north_store.extra_height ();
            int board = board_width (side);

            place (north_store, left, top, board, store_height);
            int y = top + store_height + SPACING;

            for (int i = 0; i < ROW_SIZE; i++) {
                // Left column runs 11 down to 6, right column 0 up to 5, so
                // that 5 -> 6 and 11 -> 0 still meet at the ends.
                place_house (HOUSE_COUNT - 1 - i, left, y, side, row_height);
                place_house (i, left + side + SPACING, y, side, row_height);
                y += row_height + SPACING;
            }

            place (south_store, left, y, board, store_height);
        }

        /**
         * Places a house and remembers where its pit landed. The pit is the
         * square at the top of the allocation, which is the whole of it while
         * nothing is written underneath.
         */
        private void place_house (int house, int x, int y, int side, int height) {
            place (houses[house], x, y, side, height);
            house_centres[house] = Graphene.Point () {
                x = (float) (x + side / 2.0),
                y = (float) (y + side / 2.0),
            };
        }

        private void place (Gtk.Widget child, int x, int y, int width, int height) {
            var offset = Graphene.Point () {
                x = (float) x,
                y = (float) y,
            };
            child.allocate (width, height, -1, new Gsk.Transform ().translate (offset));
        }

        private int columns () {
            return compact ? 2 : ROW_SIZE + 2;
        }

        private int board_width (int side) {
            return columns () * side + (columns () - 1) * SPACING;
        }

        private int board_height (int side) {
            int row_height = side + houses[0].extra_height ();
            int store_height = side + north_store.extra_height ();
            if (compact) {
                return 2 * store_height + ROW_SIZE * row_height
                    + (ROW_SIZE + 1) * SPACING;
            }
            return int.max (2 * row_height + SPACING, store_height);
        }

        /**
         * The largest square pit that fits both ways. Across a wide window the
         * width is what binds; with the board turned it is the height.
         */
        private int fit_side (int width, int height) {
            int by_width = (width - (columns () - 1) * SPACING) / columns ();

            int extras = compact
                ? ROW_SIZE * houses[0].extra_height () + 2 * north_store.extra_height ()
                : houses[0].extra_height ();
            int rows = compact ? ROW_SIZE + 2 : 2;
            int by_height = (height - (rows - 1) * SPACING - extras) / rows;

            int side = int.min (by_width, by_height);
            return int.min (MAX_SIDE, int.max (MIN_SIDE, side));
        }

        /** Shows a whole position at once. */
        public void display (Board board) {
            for (int house = 0; house < HOUSE_COUNT; house++) {
                houses[house].seeds = board.houses[house];
                houses[house].mark_capture (false);
                houses[house].mark_drop (false);
                houses[house].mark_chosen (false);
            }
            south_store.set_seeds (board.south_store);
            north_store.set_seeds (board.north_store);
        }

        public void set_house (int house, int seeds) {
            houses[house].seeds = seeds;
        }

        public void set_store (Player player, int seeds) {
            if (player == Player.SOUTH) {
                south_store.set_seeds (seeds);
            } else {
                north_store.set_seeds (seeds);
            }
        }

        public void mark_chosen (int house, bool chosen) {
            houses[house].mark_chosen (chosen);
        }

        public void mark_drop (int house, bool dropping) {
            houses[house].mark_drop (dropping);
        }

        public void mark_capture (int house, bool capturing) {
            houses[house].mark_capture (capturing);
        }

        /** Marks which houses the rules currently allow. */
        public void set_legal_moves (int[] moves) {
            var legal = new bool[HOUSE_COUNT];
            foreach (int house in moves) {
                legal[house] = true;
            }

            // Nothing is greyed out when it is not the player's turn: with no
            // move to choose, dimming the board would only say that the game
            // is busy, which the message under it already says.
            bool choosing = moves.length > 0;

            for (int house = 0; house < HOUSE_COUNT; house++) {
                houses[house].legal = legal[house];
                houses[house].unplayable = choosing && !legal[house];
            }
        }

        /** Nothing is playable, used while the computer thinks and after the end. */
        public void clear_legal_moves () {
            set_legal_moves (new int[0]);
        }

        /**
         * Hides the written seed counts, leaving only the drawn seeds, which is
         * what the hardest level asks of a player. The counts stay in the
         * accessibility labels either way, so nothing is lost to a screen
         * reader.
         */
        public void set_counts_visible (bool visible) {
            foreach (HouseButton button in houses) {
                button.show_count = visible;
            }
            south_store.show_count = visible;
            north_store.show_count = visible;
            queue_resize ();
        }

        /**
         * Stars the moves the advisor rates highest. The ranking behind them is
         * not shown: a player wants to know what to play, not to read a table
         * of figures over the board.
         */
        public void show_advice (Advice advice) {
            clear_advice ();
            if (advice.moves.length == 0) {
                return;
            }

            // Every move that ties with the best is starred, not just the first
            // of them: singling one out would suggest a difference that the
            // search did not find.
            int best_score = advice.moves[0].score;

            foreach (MoveScore scored in advice.moves) {
                if (scored.score == best_score) {
                    /// Spoken description of a house the advisor recommends.
                    houses[scored.house].set_best (true, _("Recommended move."));
                }
            }
        }

        public void clear_advice () {
            foreach (HouseButton button in houses) {
                button.set_best (false, null);
            }
        }

        /**
         * Draws what every house would win for its owner, both rows at once.
         * The board is handed the answers and never works them out.
         */
        public void show_captures (CapturePreview[] previews) {
            arrows.set_previews (previews);
        }

        public void clear_captures () {
            arrows.set_previews (new CapturePreview[0]);
        }


    }
}
