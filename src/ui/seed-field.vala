// SPDX-FileCopyrightText: 2026 Benjamin Bellamy <benjamin@castopod.org>
// SPDX-License-Identifier: AGPL-3.0-or-later

namespace Awale {

    /** One position on the hexagonal lattice the seeds are laid out on. */
    private struct SeedSpot {
        public double x;
        public double y;
        public double distance;
        public double angle;
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
         * Which of the twelve equivalent ways round this pit lays its seeds
         * out. The hexagonal lattice maps onto itself under a sixth of a turn
         * and under a reflection, so picking one at random changes which points
         * of a part filled ring get used, without tilting the rows: five seeds
         * come out as 2+2+1 in one pit and 1+2+2 in the next. Fixed for the
         * life of the pit, so seeds do not jump about on every redraw.
         */
        private double angle_offset;
        private bool mirrored;

        /**
         * The lattice at unit pitch, nearest the centre first. Where the points
         * fall depends only on this pit's orientation, and their order only on
         * their distance from the centre, so neither changes when the pit is
         * resized: it is laid out once here and scaled to the pit when drawn.
         */
        private SeedSpot[] spots;

        public SeedField () {
            angle_offset = Random.int_range (0, 6) * Math.PI / 3.0;
            mirrored = Random.boolean ();
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

            // A count that does not fill a ring leaves the chosen points
            // lopsided about the lattice origin, so the cluster is centred on
            // its own extent rather than on that origin.
            double left = spots[0].x;
            double right = spots[0].x;
            double top = spots[0].y;
            double bottom = spots[0].y;
            for (int i = 1; i < drawn; i++) {
                left = double.min (left, spots[i].x);
                right = double.max (right, spots[i].x);
                top = double.min (top, spots[i].y);
                bottom = double.max (bottom, spots[i].y);
            }
            double offset_x = (left + right) / 2.0;
            double offset_y = (top + bottom) / 2.0;

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
         * The lattice points nearest the centre, closest first and then by
         * angle, which grows the cluster outwards ring by ring and keeps it
         * symmetric however many seeds there are. Unit pitch: the caller
         * scales it to the pit it is drawing.
         */
        private SeedSpot[] lattice () {
            // Five rings is 91 points, more than the 48 seeds in the game.
            const int RINGS = 5;
            int side = 2 * RINGS + 1;
            var points = new SeedSpot[side * side];

            int next = 0;
            for (int q = -RINGS; q <= RINGS; q++) {
                for (int r = -RINGS; r <= RINGS; r++) {
                    SeedSpot spot = SeedSpot ();
                    spot.x = q + r / 2.0;
                    spot.y = (Math.sqrt (3.0) / 2.0) * r;
                    spot.distance = Math.hypot (spot.x, spot.y);
                    spot.angle = turned (Math.atan2 (spot.y, spot.x));
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
            return points;
        }

        /** An angle in this pit's own frame, from zero up to a full turn. */
        private double turned (double angle) {
            double turn = 2 * Math.PI;
            double result = (mirrored ? -angle : angle) - angle_offset;
            while (result < 0) {
                result += turn;
            }
            while (result >= turn) {
                result -= turn;
            }
            return result;
        }

        private bool closer (SeedSpot a, SeedSpot b) {
            // A hair of tolerance, so that points on the same ring compare by
            // angle rather than by floating point noise.
            if (a.distance < b.distance - 0.0001) {
                return true;
            }
            if (a.distance > b.distance + 0.0001) {
                return false;
            }
            return a.angle < b.angle;
        }
    }
}
