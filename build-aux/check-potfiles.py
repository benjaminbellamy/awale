#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Benjamin Bellamy <benjamin@castopod.org>
# SPDX-License-Identifier: AGPL-3.0-or-later

"""Fails when a source file holds translatable strings but is not in POTFILES.in.

The brief asks for a missing entry to break the build rather than quietly ship
an untranslated string, so this runs as part of the test suite.
"""

import re
import sys
from pathlib import Path

# Files that carry user visible strings live here. The engine has none, and the
# command line tool is a developer tool whose output is deliberately English.
SEARCHED = [
    ("src/ui", ("*.vala", "*.blp")),
    ("data", ("*.desktop.in.in", "*.metainfo.xml.in.in")),
]

TRANSLATABLE = re.compile(r'(?<![\w.])(?:_|ngettext|C_|N_)\s*\(\s*"')


def main() -> int:
    root = Path(__file__).resolve().parent.parent
    listed = {
        line.strip()
        for line in (root / "po" / "POTFILES.in").read_text().splitlines()
        if line.strip() and not line.startswith("#")
    }

    missing = []
    for directory, patterns in SEARCHED:
        for pattern in patterns:
            for path in sorted((root / directory).glob(pattern)):
                relative = path.relative_to(root).as_posix()
                text = path.read_text(encoding="utf-8")
                # Desktop entries have no gettext calls, their keys are picked
                # up by name, so any of them counts as translatable.
                has_strings = TRANSLATABLE.search(text) or path.name.endswith(
                    (".desktop.in.in", ".metainfo.xml.in.in")
                )
                if has_strings and relative not in listed:
                    missing.append(relative)

    stale = sorted(entry for entry in listed if not (root / entry).exists())

    for entry in missing:
        print(f"po/POTFILES.in is missing {entry}", file=sys.stderr)
    for entry in stale:
        print(f"po/POTFILES.in lists {entry}, which does not exist", file=sys.stderr)

    return 1 if missing or stale else 0


if __name__ == "__main__":
    sys.exit(main())
