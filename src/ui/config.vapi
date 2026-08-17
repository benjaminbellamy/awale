// SPDX-FileCopyrightText: 2026 Benjamin Bellamy <benjamin@castopod.org>
// SPDX-License-Identifier: AGPL-3.0-or-later

/** Values baked in by Meson, see config.h in the build directory. */
[CCode (cheader_filename = "config.h", lower_case_cprefix = "", cprefix = "")]
namespace Config {
    public const string APP_ID;
    public const string APP_NAME;
    public const string VERSION;
    public const string GETTEXT_PACKAGE;
    public const string LOCALEDIR;
}
