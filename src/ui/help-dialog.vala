// SPDX-FileCopyrightText: 2026 Benjamin Bellamy <benjamin@castopod.org>
// SPDX-License-Identifier: AGPL-3.0-or-later

namespace Awale {

    /**
     * Shows the "how to play" page for a language, read out of the resource
     * bundle so that it works uninstalled and never touches the network.
     *
     * The pages are Markdown because that is what they are kept as in docs/.
     * Rather than pull in a rendering library for six static files, the small
     * subset those files actually use is turned into widgets here: prose and
     * headings become labels with Pango markup, fenced blocks become monospace
     * labels so the board diagrams keep their spacing, and tables become real
     * grids rather than rows of pipe characters.
     */
    public class HelpDialog : Adw.Dialog {

        private const string RESOURCE_BASE = "/fr/benjaminbellamy/Awale/help/";
        private const string FALLBACK_LANGUAGE = "en";

        public HelpDialog (string language) {
            Object ();

            /// Title of the window that explains the rules.
            title = _("How to Play");
            content_width = 740;
            content_height = 640;

            var scroller = new Gtk.ScrolledWindow () {
                hscrollbar_policy = Gtk.PolicyType.NEVER,
                vexpand = true,
                child = build_page (load_page (language)),
            };

            var view = new Adw.ToolbarView ();
            view.add_top_bar (new Adw.HeaderBar ());
            view.content = scroller;
            child = view;

            // Without this the page opens at its foot: the only thing that can
            // take focus is the link at the very bottom, and the scroller
            // follows the focus. Giving the scroller itself the focus keeps it
            // at the top, and the link is still reachable with Tab.
            // Left to itself the dialog puts the focus on the first thing in
            // the page that can take it, which is the link at the very bottom,
            // and the scroller follows the focus. Naming the scroller as the
            // focus settles that before it happens; the reset afterwards is
            // there in case anything still moves it.
            scroller.focusable = true;
            set_focus (scroller);
            map.connect (() => {
                Idle.add_full (Priority.LOW, () => {
                    scroller.vadjustment.value = 0;
                    return Source.REMOVE;
                });
            });
        }

        /** Reads a page, falling back to English for anything not translated. */
        private static string load_page (string language) {
            foreach (string candidate in new string[] { language, FALLBACK_LANGUAGE }) {
                try {
                    // Read as a stream rather than cast from the resource's
                    // bytes: those are const, and the Vala binding drops the
                    // const, which C rightly objects to.
                    var reader = new DataInputStream (
                        resources_open_stream (RESOURCE_BASE + candidate + ".md",
                                               ResourceLookupFlags.NONE));
                    var page = new StringBuilder ();
                    string? line;
                    while ((line = reader.read_line_utf8 ()) != null) {
                        page.append (line);
                        page.append_c ('\n');
                    }
                    return page.str;
                } catch (Error e) {
                    // Try the fallback, then give up below.
                }
            }
            /// Shown when the help page is missing, which should not happen.
            return _("The help page could not be loaded.");
        }

        /**
         * Walks the page a line at a time, gathering prose until something that
         * is not prose turns up, and turning each run into its own widget.
         */
        private Gtk.Widget build_page (string markdown) {
            var page = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
                margin_top = 12,
                margin_bottom = 24,
                margin_start = 18,
                margin_end = 18,
            };

            var prose = new StringBuilder ();
            var fenced = new StringBuilder ();
            string[] table = {};
            bool in_fence = false;

            foreach (string line in markdown.split ("\n")) {
                if (line.has_prefix ("```")) {
                    flush_table (page, ref table);
                    if (in_fence) {
                        page.append (monospace_label (fenced.str));
                        fenced.erase ();
                    } else {
                        flush_prose (page, prose);
                    }
                    in_fence = !in_fence;
                    continue;
                }
                if (in_fence) {
                    fenced.append (line);
                    fenced.append_c ('\n');
                    continue;
                }

                if (line.has_prefix ("|")) {
                    flush_prose (page, prose);
                    // The dashed row under a header is markup, not content.
                    if (line.replace ("|", "").replace ("-", "").strip () != "") {
                        table += line;
                    }
                    continue;
                }
                flush_table (page, ref table);

                if (line.has_prefix ("# ")) {
                    prose.append_printf ("<span size=\"xx-large\" weight=\"bold\">%s</span>\n",
                                         inline (line.substring (2)));
                } else if (line.has_prefix ("## ")) {
                    prose.append_printf ("\n<span size=\"large\" weight=\"bold\">%s</span>\n",
                                         inline (line.substring (3)));
                } else if (line.has_prefix ("- ")) {
                    prose.append_printf ("  • %s\n", inline (line.substring (2)));
                } else if (line.strip () == "") {
                    prose.append_c ('\n');
                } else {
                    prose.append_printf ("%s\n", inline (line));
                }
            }

            flush_table (page, ref table);
            flush_prose (page, prose);
            return page;
        }

        private void flush_prose (Gtk.Box page, StringBuilder prose) {
            if (prose.str.strip () == "") {
                prose.erase ();
                return;
            }
            page.append (new Gtk.Label (prose.str.chomp ()) {
                use_markup = true,
                wrap = true,
                wrap_mode = Pango.WrapMode.WORD_CHAR,
                xalign = 0.0f,
            });
            prose.erase ();
        }

        private Gtk.Label monospace_label (string text) {
            // Board diagrams: every space matters, so no wrapping.
            return new Gtk.Label ("<span size=\"small\"><tt>%s</tt></span>"
                                      .printf (escape (text.chomp ()))) {
                use_markup = true,
                xalign = 0.0f,
                margin_top = 6,
                margin_bottom = 6,
            };
        }

        private void flush_table (Gtk.Box page, ref string[] rows) {
            if (rows.length == 0) {
                return;
            }
            page.append (build_table (rows));
            rows = {};
        }

        /** Turns collected pipe rows into a grid, the first row as its header. */
        private Gtk.Widget build_table (string[] rows) {
            var grid = new Gtk.Grid () {
                column_spacing = 24,
                row_spacing = 8,
                margin_top = 6,
                margin_bottom = 12,
                halign = Gtk.Align.FILL,
            };
            grid.add_css_class ("help-table");

            for (int row = 0; row < rows.length; row++) {
                string[] cells = split_row (rows[row]);
                for (int column = 0; column < cells.length; column++) {
                    var label = new Gtk.Label (inline (cells[column])) {
                        use_markup = true,
                        wrap = true,
                        wrap_mode = Pango.WrapMode.WORD_CHAR,
                        xalign = 0.0f,
                        hexpand = column == cells.length - 1,
                    };
                    if (row == 0) {
                        label.add_css_class ("help-table-header");
                    }
                    grid.attach (label, column, row, 1, 1);
                }
            }
            return grid;
        }

        /** The cells of a pipe delimited row, without the outer pipes. */
        private string[] split_row (string row) {
            string trimmed = row.strip ();
            if (trimmed.has_prefix ("|")) {
                trimmed = trimmed.substring (1);
            }
            if (trimmed.has_suffix ("|")) {
                trimmed = trimmed.substring (0, trimmed.length - 1);
            }

            string[] cells = {};
            foreach (string cell in trimmed.split ("|")) {
                cells += cell.strip ();
            }
            return cells;
        }

        /** Bold, inline code and links inside a line of prose. */
        private static string inline (string line) {
            string text = escape (line);
            text = wrap_pairs (text, "**", "<b>", "</b>");
            text = wrap_pairs (text, "`", "<tt>", "</tt>");
            return link (text);
        }

        /** Replaces matched pairs of a marker with an opening and closing tag. */
        private static string wrap_pairs (string text, string marker,
                                          string opening, string closing) {
            var output = new StringBuilder ();
            bool open = false;
            int index = 0;

            while (index < text.length) {
                if (text.substring (index).has_prefix (marker)) {
                    output.append (open ? closing : opening);
                    open = !open;
                    index += marker.length;
                } else {
                    output.append_c (text[index]);
                    index++;
                }
            }
            // An unmatched marker would leave the markup open and unparseable.
            if (open) {
                output.append (closing);
            }
            return output.str;
        }

        /** Turns [label](url) into a Pango link. */
        private static string link (string text) {
            var output = new StringBuilder ();
            int index = 0;

            while (index < text.length) {
                int open_bracket = text.index_of ("[", index);
                if (open_bracket < 0) {
                    output.append (text.substring (index));
                    break;
                }
                int close_bracket = text.index_of ("]", open_bracket);
                int open_paren = close_bracket + 1;
                int close_paren = close_bracket < 0 ? -1 : text.index_of (")", open_paren);

                bool well_formed = close_bracket > open_bracket
                    && close_paren > open_paren
                    && text.substring (open_paren, 1) == "(";
                if (!well_formed) {
                    output.append (text.substring (index, open_bracket - index + 1));
                    index = open_bracket + 1;
                    continue;
                }

                output.append (text.substring (index, open_bracket - index));
                string label = text.substring (open_bracket + 1, close_bracket - open_bracket - 1);
                string target = text.substring (open_paren + 1, close_paren - open_paren - 1);
                output.append_printf ("<a href=\"%s\">%s</a>", target, label);
                index = close_paren + 1;
            }
            return output.str;
        }

        private static string escape (string text) {
            return Markup.escape_text (text);
        }
    }
}
