// SPDX-FileCopyrightText: 2026 Benjamin Bellamy <benjamin@castopod.org>
// SPDX-License-Identifier: AGPL-3.0-or-later

namespace Awale {

    /**
     * The capture arrows of learning mode, drawn over the board: one line per
     * house that would win seeds, running the way the seeds travel, from the
     * house played to the one the last seed lands in, with what it would win
     * in a bubble at its mouth.
     *
     * A layer of its own rather than a few lines inside the board, so that the
     * lines sit on top of every pit and so that their colour comes from the
     * stylesheet like every other colour in this game.
     *
     * Nothing here knows the rules. It is handed what each move would take and
     * draws that.
     */
    internal class CaptureArrows : Gtk.Widget {

        /**
         * How far the innermost line runs from the middle of its pits, and how
         * much further out each line beyond it goes, as a fraction of the pit.
         *
         * The step is fixed rather than a band shared out, so that any two
         * lines running beside each other are always the same distance apart,
         * however many there are. The band stays over the board: these are
         * drawn on top of it, so the pits never shrink to make way.
         */
        private const double INNER_REACH = 0.05;
        private const double LEVEL_STEP = 0.08;

        /** A sowing this long has been all the way round and closes its loop. */
        private const int FULL_CIRCLE = HOUSE_COUNT;

        private CapturePreview[] previews = {};
        private int[] levels = {};
        private Gtk.Label[] totals = {};
        private Graphene.Point[] centres = {};
        private Graphene.Point middle;
        private int side = 0;

        public CaptureArrows () {
            // Decoration laid over the board: the pits underneath keep the
            // clicks, and a screen reader is told the houses, not the drawing.
            Object (accessible_role: Gtk.AccessibleRole.PRESENTATION);
            add_css_class ("capture-arrow");
            can_target = false;
            can_focus = false;
        }

        public override void dispose () {
            foreach (Gtk.Label total in totals) {
                total.unparent ();
            }
            totals = {};
            base.dispose ();
        }

        /** Takes no room of its own: it is drawn over what is already there. */
        public override void measure (Gtk.Orientation orientation,
                                      int for_size,
                                      out int minimum,
                                      out int natural,
                                      out int minimum_baseline,
                                      out int natural_baseline) {
            minimum = 0;
            natural = 0;
            minimum_baseline = -1;
            natural_baseline = -1;
        }

        /** Where the twelve pits are, so the lines can be drawn against them. */
        public void set_board (Graphene.Point[] house_centres, int pit_side) {
            centres = house_centres;
            side = pit_side;
            // Worked out here rather than per point: every point of every line
            // is placed against it, and it only moves when the board does.
            middle = measure_middle ();
            queue_draw ();
        }

        public void set_previews (CapturePreview[] shown) {
            previews = shown;
            // Shortest line innermost. Any distinct reaches would keep the
            // lines apart, but nesting them by length keeps each one near the
            // pits it is about instead of wandering off across the board.
            sort_by_span ();
            assign_levels ();
            rebuild_totals ();
            queue_allocate ();
            queue_draw ();
        }

        public void clear () {
            previews = {};
            levels = {};
            rebuild_totals ();
            queue_draw ();
        }

        /**
         * Puts each line at a depth over the board.
         *
         * Two lines only need to be told apart where they run beside each
         * other, so lines that share no house are left at the same depth. That
         * is what keeps the spacing even: a line is never pushed out past an
         * empty depth just because some line at the far end of the board is
         * using that number.
         */
        private void assign_levels () {
            int ceiling = 2 * HOUSE_COUNT;
            bool[,] taken = new bool[ceiling, HOUSE_COUNT];
            levels = new int[previews.length];

            for (int i = 0; i < previews.length; i++) {
                bool[] covered = houses_covered (previews[i]);
                // A winding line is one depth further out on every lap, so it
                // stands in every depth it has wound through, and in the one
                // beyond the last of them: another line there would come closer
                // to its end than a whole depth.
                int depth = winding_depth (previews[i]);

                int level = 0;
                while (level + depth < ceiling
                       && !room_at (taken, covered, level, depth)) {
                    level++;
                }

                levels[i] = level;
                for (int step = 0; step < depth; step++) {
                    for (int house = 0; house < HOUSE_COUNT; house++) {
                        if (covered[house]) {
                            taken[level + step, house] = true;
                        }
                    }
                }
            }
        }

        /** Depths a line stands in: one, unless it winds out through more. */
        private int winding_depth (CapturePreview preview) {
            if (!wraps (preview)) {
                return 1;
            }
            int laps = (drawn_steps (preview) + HOUSE_COUNT - 1) / HOUSE_COUNT;
            return laps + 1;
        }

        private bool room_at (bool[,] taken, bool[] covered, int level, int depth) {
            for (int step = 0; step < depth; step++) {
                for (int house = 0; house < HOUSE_COUNT; house++) {
                    if (covered[house] && taken[level + step, house]) {
                        return false;
                    }
                }
            }
            return true;
        }

        private bool[] houses_covered (CapturePreview preview) {
            var covered = new bool[HOUSE_COUNT];
            int steps = drawn_steps (preview);
            for (int i = 0; i <= steps; i++) {
                covered[(preview.house + i) % HOUSE_COUNT] = true;
            }
            return covered;
        }

        private bool wraps (CapturePreview preview) {
            return preview.seeds_sown >= FULL_CIRCLE;
        }

        /**
         * Houses the line passes on its way from the house played to the house
         * the last seed lands in. A sowing that has been round the whole board
         * is drawn the whole way round and then on to where it stops.
         */
        private int drawn_steps (CapturePreview preview) {
            int round_trip = (preview.last_house - preview.house + HOUSE_COUNT) % HOUSE_COUNT;
            return wraps (preview) ? HOUSE_COUNT + round_trip : round_trip;
        }

        /** One bubble per line, so the stylesheet decides how it looks. */
        private void rebuild_totals () {
            foreach (Gtk.Label total in totals) {
                total.unparent ();
            }
            totals = {};

            foreach (CapturePreview preview in previews) {
                var total = new Gtk.Label (preview.captured.to_string ());
                total.add_css_class ("capture-total");
                total.set_parent (this);
                totals += total;
            }
        }

        /** Insertion sort: there are never more than twelve of these. */
        private void sort_by_span () {
            for (int i = 1; i < previews.length; i++) {
                CapturePreview moving = previews[i];
                int j = i - 1;
                while (j >= 0 && span (previews[j]) > span (moving)) {
                    previews[j + 1] = previews[j];
                    j--;
                }
                previews[j + 1] = moving;
            }
        }

        /** How many houses the sowing covers, counted the way it travels. */
        private int span (CapturePreview preview) {
            if (preview.seeds_sown >= FULL_CIRCLE) {
                return HOUSE_COUNT;
            }
            return (preview.last_house - preview.house + HOUSE_COUNT) % HOUSE_COUNT;
        }

        /** Every bubble sits on the mouth of its own line. */
        public override void size_allocate (int width, int height, int baseline) {
            if (!board_is_known ()) {
                return;
            }

            for (int i = 0; i < totals.length && i < levels.length; i++) {
                Gtk.Requisition natural;
                totals[i].get_preferred_size (null, out natural);

                Graphene.Point at = ring_point (previews[i].house, reach (levels[i]));
                var offset = Graphene.Point () {
                    x = at.x - natural.width / 2.0f,
                    y = at.y - natural.height / 2.0f,
                };
                totals[i].allocate (natural.width, natural.height, -1,
                                    new Gsk.Transform ().translate (offset));
            }
        }

        public override void snapshot (Gtk.Snapshot snapshot) {
            if (previews.length > 0 && board_is_known ()) {
                Gdk.RGBA colour = get_color ();
                var bounds = Graphene.Rect ().init (0, 0, get_width (), get_height ());
                Cairo.Context cr = snapshot.append_cairo (bounds);

                cr.set_source_rgba (colour.red, colour.green, colour.blue, colour.alpha);
                cr.set_line_width (1.0);
                cr.set_line_cap (Cairo.LineCap.ROUND);
                cr.set_line_join (Cairo.LineJoin.ROUND);

                for (int i = 0; i < previews.length && i < levels.length; i++) {
                    draw_arrow (cr, previews[i], levels[i]);
                }
            }

            // The bubbles are children, so they are drawn after the lines and
            // no line is ever drawn across one.
            base.snapshot (snapshot);
        }

        private bool board_is_known () {
            return centres.length == HOUSE_COUNT && side > 0;
        }

        /** How far a line at this depth runs from the middle of its pits. */
        private double reach (int level) {
            return (INNER_REACH + level * LEVEL_STEP) * side;
        }

        /**
         * A point beside a pit, on the far side of its row from the other row.
         *
         * The six houses of a row stand in a line, so a whole row's points move
         * together and stay in line: that is what makes every straight part of
         * a line straight, and what keeps two lines at different reaches from
         * ever meeting.
         */
        private Graphene.Point ring_point (int house, double out_by) {
            Graphene.Point pit = centres[house];
            Graphene.Point away = away_from_middle (house);

            return Graphene.Point () {
                x = (float) (pit.x + out_by * away.x),
                y = (float) (pit.y + out_by * away.y),
            };
        }

        /** Unit step from the middle of the board towards this house's row. */
        private Graphene.Point away_from_middle (int house) {
            Graphene.Point pit = centres[house];
            // Square to the row rather than straight out from the middle of the
            // board: the two rows are much further apart than they are long, so
            // a step out from the middle would drift along the row as well as
            // away from it, and the row's points would stop being in line.
            Graphene.Point along = row_step (house);
            double out_x = -along.y;
            double out_y = along.x;

            if ((pit.x - middle.x) * out_x + (pit.y - middle.y) * out_y < 0) {
                out_x = -out_x;
                out_y = -out_y;
            }
            return Graphene.Point () { x = (float) out_x, y = (float) out_y };
        }

        /** Unit step along this house's row, the way the seeds travel. */
        private Graphene.Point row_step (int house) {
            // Both ends of a row look at the same neighbouring pair as the
            // house next to them: the six are in line, so the direction is the
            // same all along.
            int back = (house == 0 || house == ROW_SIZE) ? house : house - 1;
            Graphene.Point from = centres[back];
            Graphene.Point to = centres[back + 1];

            double dx = to.x - from.x;
            double dy = to.y - from.y;
            double length = Math.sqrt (dx * dx + dy * dy);
            if (length < 0.5) {
                return Graphene.Point () { x = 1, y = 0 };
            }
            return Graphene.Point () {
                x = (float) (dx / length),
                y = (float) (dy / length),
            };
        }

        /**
         * One line, from the house played to the house the last seed lands in.
         *
         * It is drawn as the board is shaped: a straight run beside a row, a
         * half circle around the end where the seeds cross to the other row,
         * and a straight run back. Nothing else.
         *
         * A sowing long enough to pass its own house has been round the whole
         * board and out the other side. Its line winds out by one depth as it
         * goes, so the second half circle is wider than the first and the line
         * finishes beside where it began rather than back on top of it.
         */
        private void draw_arrow (Cairo.Context cr, CapturePreview preview, int level) {
            int steps = drawn_steps (preview);
            if (steps < 1) {
                return;
            }

            double from_reach = reach (level);
            // One lap of the board takes a winding line out by one whole depth,
            // which is the distance that separates two different lines running
            // beside each other. A line lying beside itself and two lines lying
            // beside each other are then the same distance apart.
            double per_house = wraps (preview)
                ? (LEVEL_STEP * side) / HOUSE_COUNT
                : 0;

            Graphene.Point start = ring_point (preview.house, from_reach);
            cr.move_to (start.x, start.y);

            for (int i = 0; i < steps; i++) {
                int here = (preview.house + i) % HOUSE_COUNT;
                int next = (here + 1) % HOUSE_COUNT;

                if (here == ROW_SIZE - 1 || here == HOUSE_COUNT - 1) {
                    half_circle (cr, here, next,
                                 from_reach + per_house * i,
                                 from_reach + per_house * (i + 1));
                } else {
                    Graphene.Point to = ring_point (next, from_reach + per_house * (i + 1));
                    cr.line_to (to.x, to.y);
                }
            }
            cr.stroke ();

            draw_head (cr, preview.last_house, from_reach + per_house * steps);
        }

        /**
         * The turn at one end of the board, from the last house of a row to the
         * first house of the other.
         *
         * Any two points are the ends of a half circle about their midpoint, so
         * the turn is exactly half a circle whether the line comes out of it at
         * the reach it went in at or one depth further out.
         */
        private void half_circle (Cairo.Context cr, int from, int to,
                                  double from_reach, double to_reach) {
            Graphene.Point leaving = ring_point (from, from_reach);
            Graphene.Point arriving = ring_point (to, to_reach);
            var pivot = Graphene.Point () {
                x = (leaving.x + arriving.x) / 2,
                y = (leaving.y + arriving.y) / 2,
            };

            double dx = leaving.x - pivot.x;
            double dy = leaving.y - pivot.y;
            double radius = Math.sqrt (dx * dx + dy * dy);
            double from_angle = Math.atan2 (dy, dx);
            double to_angle = Math.atan2 (arriving.y - pivot.y, arriving.x - pivot.x);

            // Either way round is half a circle. Take the way that leaves the
            // board rather than the one that cuts back across it.
            double outwards = Math.atan2 (pivot.y - middle.y, pivot.x - middle.x);
            if (turning ((outwards - from_angle)) < Math.PI) {
                cr.arc (pivot.x, pivot.y, radius, from_angle, to_angle);
            } else {
                cr.arc_negative (pivot.x, pivot.y, radius, from_angle, to_angle);
            }
        }

        /** An angle brought into nought to two pi. */
        private double turning (double angle) {
            double turn = 2 * Math.PI;
            return ((angle % turn) + turn) % turn;
        }

        /** The head, on the house the seeds stop in, pointing along its row. */
        private void draw_head (Cairo.Context cr, int house, double out_by) {
            Graphene.Point tip = ring_point (house, out_by);
            Graphene.Point along = row_step (house);

            double back = side * 0.08;
            double half = side * 0.04;
            double base_x = tip.x - along.x * back;
            double base_y = tip.y - along.y * back;

            cr.move_to (tip.x, tip.y);
            cr.line_to (base_x - along.y * half, base_y + along.x * half);
            cr.line_to (base_x + along.y * half, base_y - along.x * half);
            cr.close_path ();
            cr.fill ();
        }

        private Graphene.Point measure_middle () {
            if (centres.length != HOUSE_COUNT) {
                return Graphene.Point () { x = 0, y = 0 };
            }

            float left = centres[0].x;
            float right = left;
            float top = centres[0].y;
            float bottom = top;

            foreach (Graphene.Point centre in centres) {
                left = float.min (left, centre.x);
                right = float.max (right, centre.x);
                top = float.min (top, centre.y);
                bottom = float.max (bottom, centre.y);
            }

            return Graphene.Point () {
                x = (left + right) / 2,
                y = (top + bottom) / 2,
            };
        }
    }
}
