// SPDX-FileCopyrightText: 2026 Benjamin Bellamy <benjamin@castopod.org>
// SPDX-License-Identifier: AGPL-3.0-or-later

/**
 * Whether a directory holds this application's message catalogues. One
 * language is enough to tell an installed tree from an empty one.
 */
private static bool has_catalogues (string directory) {
    string probe = Path.build_filename (directory, "fr", "LC_MESSAGES",
                                        Config.GETTEXT_PACKAGE + ".mo");
    return FileUtils.test (probe, FileTest.IS_REGULAR);
}

/**
 * Where to read translations from. Normally that is the directory Meson
 * installed them into, but the game is often run straight out of its build
 * tree, where nothing has been installed and that directory is empty. Meson
 * lays the catalogues out under po/ in the build tree in exactly the shape
 * gettext expects, so fall back to those and the interface is translated
 * either way.
 */
private static string locale_directory () {
    if (has_catalogues (Config.LOCALEDIR)) {
        return Config.LOCALEDIR;
    }

    try {
        // The binary sits at <build>/src/ui/awale, the catalogues at <build>/po.
        string binary = FileUtils.read_link ("/proc/self/exe");
        string build_root = Path.get_dirname (Path.get_dirname (Path.get_dirname (binary)));
        string uninstalled = Path.build_filename (build_root, "po");
        if (has_catalogues (uninstalled)) {
            return uninstalled;
        }
    } catch (FileError e) {
        // Not readable, so there is nothing better than the installed path.
    }

    return Config.LOCALEDIR;
}

public static int main (string[] args) {
    // The interface language is read before gettext loads any catalogue, which
    // is why choosing one only takes effect the next time the game starts.
    string language = new Settings ("fr.benjaminbellamy.Awale").get_string ("language");
    if (language != "system") {
        Environment.set_variable ("LANGUAGE", language, true);
    }

    Intl.setlocale (LocaleCategory.ALL, "");
    Intl.bindtextdomain (Config.GETTEXT_PACKAGE, locale_directory ());
    Intl.bind_textdomain_codeset (Config.GETTEXT_PACKAGE, "UTF-8");
    Intl.textdomain (Config.GETTEXT_PACKAGE);

    return new Awale.Application ().run (args);
}
