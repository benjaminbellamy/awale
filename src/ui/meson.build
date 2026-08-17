# SPDX-FileCopyrightText: 2026 Benjamin Bellamy <benjamin@castopod.org>
# SPDX-License-Identifier: AGPL-3.0-or-later

blueprint_compiler = find_program('blueprint-compiler')

window_ui = custom_target('window.ui',
  input: files('window.blp'),
  output: 'window.ui',
  command: [blueprint_compiler, 'compile', '--output', '@OUTPUT@', '@INPUT@'],
)

awale_resources = gnome.compile_resources('awale-resources',
  'awale.gresource.xml',
  c_name: 'awale',
  dependencies: [window_ui],
  source_dir: [
    meson.current_build_dir(),
    meson.current_source_dir(),
    meson.project_source_root() / 'docs',
    meson.project_source_root() / 'data',
  ],
)

ui_sources = files(
  'config.vapi',
  'main.vala',
  'application.vala',
  'window.vala',
  'board-view.vala',
  'house-button.vala',
  'help-dialog.vala',
  'seed-field.vala',
)

executable('awale',
  ui_sources,
  awale_resources,
  dependencies: [core_dep, gtk_dep, adw_dep, math_dep],
  include_directories: config_inc,
  install: true,
)
