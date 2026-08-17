# SPDX-FileCopyrightText: 2026 Benjamin Bellamy <benjamin@castopod.org>
# SPDX-License-Identifier: AGPL-3.0-or-later

# The engine is deliberately free of GTK and libadwaita. Keep this dependency
# list restricted to GLib, it is what enforces the layering.
core_deps = [glib_dep, gobject_dep, gio_dep]

core_sources = files(
  'types.vala',
  'board.vala',
  'notation.vala',
  'game.vala',
  'evaluation.vala',
  'search.vala',
  'opponent.vala',
  'advisor.vala',
)

core_lib = static_library('awale-core',
  core_sources,
  dependencies: core_deps,
  vala_header: 'awale-core.h',
  vala_vapi: 'awale-core.vapi',
  install: false,
)

core_dep = declare_dependency(
  link_with: core_lib,
  include_directories: include_directories('.'),
  dependencies: core_deps,
)
