// SPDX-FileCopyrightText: 2026 Benjamin Bellamy <benjamin@castopod.org>
// SPDX-License-Identifier: AGPL-3.0-or-later

namespace Awale {

    /** One position on the hexagonal lattice the seeds are laid out on. */
    private struct SeedSpot {
        public double x;
        public double y;
        public double distance;
    }

    /**
     * A round pit with seeds in it. Used both for the twelve houses and for the
     * two stores, so that a seed looks the same wherever it happens to be.
     *
     * The seeds sit on a hexagonal lattice, the packing round seeds fall into
     * on a real board, and every seed is drawn at the same fixed size whatever
     * the pit holds. The colour comes from the widget's resolved style, so it
     * follows the theme, the accent colour and high contrast without being told.
     */
    public class SeedField : Gtk.DrawingArea {

        /** Diameter of the seed field, as a share of the pit's diameter. */
        private const double FIELD = 0.80;

        /**
         * Seed radius as a share of the field's radius. Fixed, so a seed is the
         * same size in every pit. Sized so two full rings, nineteen seeds, fit;
         * a pit holding more is scaled down, and the count is written out.
         */
        private const double RADIUS = 0.17;

        /** Centre to centre spacing, as a share of a seed's diameter. */
        private const double PITCH = 1.16;

        private int seed_count = 0;

        /**
         * Where this pit puts its seeds, nearest first. Worked out once and
         * kept, so the seeds do not jump about on every redraw.
         */
        private SeedSpot[] spots;

        public SeedField () {
            spots = lattice ();
            set_draw_func (draw);
        }

        public int seeds {
            get { return seed_count; }
            set {
                if (seed_count == value) {
                    return;
                }
                seed_count = value;
                queue_draw ();
            }
        }

        private void draw (Gtk.DrawingArea area, Cairo.Context context, int width, int height) {
            if (seed_count <= 0) {
                return;
            }

            Gdk.RGBA colour = area.get_color ();
            Gdk.cairo_set_source_rgba (context, colour);

            double pit = double.min (width, height);
            double field = pit * FIELD / 2.0;
            double centre_x = width / 2.0;
            double centre_y = height / 2.0;

            double radius = field * RADIUS;
            double pitch = radius * 2.0 * PITCH;

            int drawn = int.min (seed_count, spots.length);

            // The chosen points sit wherever the anchor left them, so the
            // cluster is centred on itself rather than on the lattice. On its
            // mean, not on the middle of a box around it: turning the cluster
            // turns its mean with it, where the box around it changes shape, so
            // a box would make both the placing and the size below depend on
            // the angle this pit happens to have been given.
            double offset_x = 0.0;
            double offset_y = 0.0;
            for (int i = 0; i < drawn; i++) {
                offset_x += spots[i].x;
                offset_y += spots[i].y;
            }
            offset_x /= drawn;
            offset_y /= drawn;

            // A pit holding more than the field was sized for is scaled down
            // rather than allowed to spill over the rim.
            double furthest = 0.0;
            for (int i = 0; i < drawn; i++) {
                furthest = double.max (furthest,
                                       Math.hypot (spots[i].x - offset_x,
                                                   spots[i].y - offset_y));
            }
            double extent = furthest * pitch + radius;
            double scale = extent > field ? field / extent : 1.0;

            for (int i = 0; i < drawn; i++) {
                context.arc (centre_x + (spots[i].x - offset_x) * pitch * scale,
                             centre_y + (spots[i].y - offset_y) * pitch * scale,
                             radius * scale, 0, 2 * Math.PI);
                context.fill ();
            }
        }

        /**
         * The lattice points this pit draws its seeds on, nearest first. Unit
         * pitch: the caller scales them to the pit it is drawing.
         *
         * Nearest to an anchor taken anywhere in one cell of the lattice, not
         * to a lattice point. That is what varies the shape rather than only
         * the angle: grown from a lattice point, thirteen seeds fill three
         * whole rings and a full ring leaves no choice, so every pit would draw
         * the same figure. One cell covers every relation a cluster can have to
         * the lattice, on a seed, between two, between three.
         *
         * Then turned by a free angle, which has to be free because the lattice
         * maps onto itself under a sixth of a turn.
         */
        private SeedSpot[] lattice () {
            double row_height = Math.sqrt (3.0) / 2.0;
            double along = Random.next_double ();
            double across = Random.next_double ();
            double anchor_x = along + across / 2.0;
            double anchor_y = row_height * across;
            double rotation = Random.next_double () * 2.0 * Math.PI;

            // Eleven by eleven, comfortably more than the 48 seeds in the game
            // even measured from a corner of the cell.
            const int REACH = 5;
            int side = 2 * REACH + 1;
            var points = new SeedSpot[side * side];

            int next = 0;
            for (int q = -REACH; q <= REACH; q++) {
                for (int r = -REACH; r <= REACH; r++) {
                    SeedSpot spot = SeedSpot ();
                    spot.x = q + r / 2.0;
                    spot.y = row_height * r;
                    spot.distance = Math.hypot (spot.x - anchor_x, spot.y - anchor_y);
                    points[next++] = spot;
                }
            }

            // Selection sort, once for the life of the pit.
            for (int i = 0; i < points.length; i++) {
                int best = i;
                for (int j = i + 1; j < points.length; j++) {
                    if (closer (points[j], points[best])) {
                        best = j;
                    }
                }
                SeedSpot swap = points[i];
                points[i] = points[best];
                points[best] = swap;
            }

            // Turned once the order is settled: the order goes by distance from
            // the anchor, which turning does not change.
            double cosine = Math.cos (rotation);
            double sine = Math.sin (rotation);
            for (int i = 0; i < points.length; i++) {
                double x = points[i].x;
                double y = points[i].y;
                points[i].x = x * cosine - y * sine;
                points[i].y = x * sine + y * cosine;
            }
            return points;
        }

        private bool closer (SeedSpot a, SeedSpot b) {
            return a.distance < b.distance;
        }
    }
}
