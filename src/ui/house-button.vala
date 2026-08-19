// SPDX-FileCopyrightText: 2026 Benjamin Bellamy <benjamin@castopod.org>
// SPDX-License-Identifier: AGPL-3.0-or-later

namespace Awale {

    /**
     * One house of the board: a round pit with the seeds drawn in it, centred
     * whatever else the pit carries, and the count written inside the circle
     * along the bottom.
     *
     * The pit itself is a button, so that keyboard focus, activation and the
     * accessibility tree all come from GTK instead of being reinvented.
     */
    public class HouseButton : Gtk.Box {

        public signal void activated ();

        /** Index on the board, 0 to 11. */
        public int house { get; construct; }

        /** True when this house belongs to the person at the keyboard. */
        public bool mine { get; construct; }

        private Gtk.Button pit;
        private SeedField field;
        private Gtk.Label count_label;
        private Gtk.Image star;
        private int seed_count = 0;
        private bool playable = false;
        private string? hint_description = null;

        public HouseButton (int house, bool mine) {
            Object (house: house, mine: mine,
                    orientation: Gtk.Orientation.VERTICAL, spacing: 0);
        }

        construct {
            halign = Gtk.Align.CENTER;
            valign = Gtk.Align.START;

            field = new SeedField ();

            star = new Gtk.Image.from_icon_name ("awale-best-move-symbolic") {
                halign = Gtk.Align.END,
                valign = Gtk.Align.START,
                visible = false,
            };
            star.add_css_class ("best-move");

            count_label = new Gtk.Label ("0") {
                halign = Gtk.Align.CENTER,
                valign = Gtk.Align.END,
            };
            count_label.add_css_class ("house-count");

            var overlay = new Gtk.Overlay ();
            overlay.child = field;
            overlay.add_overlay (star);
            overlay.add_overlay (count_label);

            pit = new Gtk.Button () { child = overlay };
            pit.add_css_class ("house");
            pit.clicked.connect (() => activated ());

            append (pit);
            update_accessible_label ();
        }

        /** Makes the pit exactly {@link side} across, which keeps it round. */
        public void set_pit_size (int side) {
            pit.set_size_request (side, side);
            // The star is sized off the pit rather than the font, so it stays
            // in proportion as the board grows and shrinks.
            star.pixel_size = int.max (12, int.min (side / 4, 32));
        }

        /**
         * Height this widget needs on top of the pit itself. The count is
         * written inside the circle, so a house is exactly its pit.
         */
        public int extra_height () {
            return 0;
        }

        public new void grab_focus () {
            pit.grab_focus ();
        }

        /** Seeds currently shown. The animation drives this one step at a time. */
        public int seeds {
            get { return seed_count; }
            set {
                if (seed_count == value) {
                    return;
                }
                seed_count = value;
                count_label.label = value.to_string ();
                field.seeds = value;
                update_accessible_label ();
            }
        }

        /** Whether the seed count is written inside the pit. */
        public bool show_count {
            get { return count_label.visible; }
            set { count_label.visible = value; }
        }

        /**
         * Whether the rules allow this house to be played right now. This never
         * makes the button insensitive: an insensitive button drops out of the
         * focus chain, and a player using the keyboard has to be able to walk
         * over every house on the board, including the computer's.
         */
        public bool legal {
            get { return playable; }
            set {
                playable = value;
                if (value) {
                    pit.add_css_class ("legal");
                } else {
                    pit.remove_css_class ("legal");
                }
                update_accessible_label ();
            }
        }

        /**
         * Greys the house back into the board. Set only on the houses that
         * cannot be played while the player is choosing, so that the ones they
         * can play stand out by being ordinary rather than by being decorated.
         */
        public bool unplayable {
            set {
                if (value) {
                    pit.add_css_class ("unplayable");
                } else {
                    pit.remove_css_class ("unplayable");
                }
            }
        }

        /**
         * Stars the house in learning mode as one of the best moves, with the
         * sentence a screen reader reads out in {@link description}. Only the
         * best moves are marked at all: the rest are left plain rather than
         * ranked, so the eye goes straight to what is worth playing.
         */
        public void set_best (bool best, string? description) {
            star.visible = best;
            set_hint (description);
        }

        /**
         * What learning mode has to say about this house, starred or not: the
         * reason the recommendation is the recommendation, or the reason a
         * house that looks better than it is not.
         */
        public void set_hint (string? description) {
            hint_description = description;
            update_accessible_label ();
        }

        /** Lights the house up as the one about to be played, by either side. */
        public void mark_chosen (bool chosen) {
            if (chosen) {
                pit.add_css_class ("chosen");
            } else {
                pit.remove_css_class ("chosen");
            }
        }

        /** Thickens the rim while a seed is being dropped into this house. */
        public void mark_drop (bool dropping) {
            if (dropping) {
                pit.add_css_class ("dropping");
            } else {
                pit.remove_css_class ("dropping");
            }
        }

        /** Marks the house while the capture animation empties it. */
        public void mark_capture (bool capturing) {
            if (capturing) {
                pit.add_css_class ("capturing");
            } else {
                pit.remove_css_class ("capturing");
            }
        }

        /** The house as the player counts it, 1 to 6 within their own row. */
        public int display_number {
            get { return (house % ROW_SIZE) + 1; }
        }

        private void update_accessible_label () {
            string label;
            if (mine && playable) {
                /// Accessibility label. %1$d is the house number 1 to 6,
                /// %2$d is how many seeds it holds.
                label = ngettext ("Your house %1$d, %2$d seed, legal move",
                                  "Your house %1$d, %2$d seeds, legal move",
                                  seed_count).printf (display_number, seed_count);
            } else if (mine) {
                /// Accessibility label for a house the player cannot play.
                label = ngettext ("Your house %1$d, %2$d seed",
                                  "Your house %1$d, %2$d seeds",
                                  seed_count).printf (display_number, seed_count);
            } else {
                /// Accessibility label for one of the computer's houses.
                label = ngettext ("Computer's house %1$d, %2$d seed",
                                  "Computer's house %1$d, %2$d seeds",
                                  seed_count).printf (display_number, seed_count);
            }
            pit.update_property (Gtk.AccessibleProperty.LABEL, label, -1);

            // The tooltip carries only what learning mode has to say. Which
            // house this is and how many seeds it holds are on the board
            // already and in the spoken label above, so a tooltip repeating
            // them would only be in the way of the part worth reading.
            pit.tooltip_text = hint_description;

            // The hint goes in the description rather than being glued onto the
            // label, so neither sentence is built out of pieces.
            pit.update_property (Gtk.AccessibleProperty.DESCRIPTION,
                                 hint_description ?? "", -1);
        }
    }
}
