// SPDX-FileCopyrightText: 2026 Benjamin Bellamy <benjamin@castopod.org>
// SPDX-License-Identifier: AGPL-3.0-or-later

namespace Awale {

    /*
     * gtk_style_context_add_provider_for_display() is GDK_AVAILABLE_IN_ALL and
     * declared in gtkstyleprovider.h, but the Vala binding files it as a static
     * method of GtkStyleContext, which was deprecated in 4.10. Using it through
     * that binding raises a deprecation warning for an API that is not actually
     * deprecated, so bind the function where it really lives.
     */
    [CCode (cname = "gtk_style_context_add_provider_for_display")]
    private extern void add_provider_for_display (Gdk.Display display,
                                                  Gtk.StyleProvider provider,
                                                  uint priority);

    /*
     * Same idea for the accelerator list. GTK takes const char * const *, the
     * stock binding declares char **, and C rejects that conversion, so spell
     * out the parameter's real C type here.
     */
    [CCode (cname = "gtk_application_set_accels_for_action")]
    private extern void set_action_accels (Gtk.Application application,
                                           string detailed_action_name,
                                           [CCode (type = "const char * const *", array_length = false, array_null_terminated = true)] string[] accels);

    public class Application : Adw.Application {

        public Application () {
            Object (application_id: Config.APP_ID,
                    flags: ApplicationFlags.DEFAULT_FLAGS);
        }

        construct {
            var quit_action = new SimpleAction ("quit", null);
            quit_action.activate.connect (() => quit ());
            add_action (quit_action);

            var about_action = new SimpleAction ("about", null);
            about_action.activate.connect (show_about);
            add_action (about_action);

            set_action_accels (this, "app.quit", { "<Control>q" });
            set_action_accels (this, "win.new-game", { "<Control>n" });
            set_action_accels (this, "win.undo", { "<Control>z" });
            set_action_accels (this, "win.cancel", { "Escape" });

            // Keys 1 to 6 play the matching house of the player's own row,
            // from the number row and from the keypad alike: those are separate
            // keyvals, so both have to be bound.
            for (int house = 0; house < ROW_SIZE; house++) {
                set_action_accels (this, "win.play-house(%d)".printf (house),
                                   { "%d".printf (house + 1),
                                     "KP_%d".printf (house + 1) });
            }
        }

        public override void startup () {
            base.startup ();

            // Makes the application icon findable from the resource bundle, so
            // the About window shows the logo even when running uninstalled.
            Gtk.IconTheme.get_for_display (Gdk.Display.get_default ())
                .add_resource_path ("/fr/benjaminbellamy/Awale/icons");

            var provider = new Gtk.CssProvider ();
            provider.load_from_resource ("/fr/benjaminbellamy/Awale/style.css");
            add_provider_for_display (Gdk.Display.get_default (),
                                      provider,
                                      Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        }

        public override void activate () {
            Gtk.Window? window = active_window;
            if (window == null) {
                window = new Awale.Window (this);
            }
            window.present ();
        }

        private void show_about () {
            var dialog = new Adw.AboutDialog () {
                application_name = Config.APP_NAME,
                application_icon = Config.APP_ID,
                version = Config.VERSION,
                developer_name = "Benjamin Bellamy",
                license_type = Gtk.License.AGPL_3_0,
                /// Short description shown in the About window.
                comments = _("Play Awalé, a game of the mancala family, against the computer."),
                website = "https://github.com/benjaminbellamy/awale",
                issue_url = "https://github.com/benjaminbellamy/awale/issues/new",
            };
            dialog.present (active_window);
        }
    }
}
