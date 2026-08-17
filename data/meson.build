# SPDX-FileCopyrightText: 2026 Benjamin Bellamy <benjamin@castopod.org>
# SPDX-License-Identifier: AGPL-3.0-or-later

desktop_conf = configuration_data()
desktop_conf.set('app_id', app_id)

# Two stages: Meson substitutes the application id, then gettext merges the
# translated Name, Comment and Keywords in.
desktop_in = configure_file(
  input: 'fr.benjaminbellamy.Awale.desktop.in.in',
  output: app_id + '.desktop.in',
  configuration: desktop_conf,
)

desktop_file = i18n.merge_file(
  input: desktop_in,
  output: app_id + '.desktop',
  type: 'desktop',
  po_dir: meson.project_source_root() / 'po',
  install: true,
  install_dir: get_option('datadir') / 'applications',
)

metainfo_in = configure_file(
  input: 'fr.benjaminbellamy.Awale.metainfo.xml.in.in',
  output: app_id + '.metainfo.xml.in',
  configuration: desktop_conf,
)

metainfo_file = i18n.merge_file(
  input: metainfo_in,
  output: app_id + '.metainfo.xml',
  type: 'xml',
  po_dir: meson.project_source_root() / 'po',
  install: true,
  install_dir: get_option('datadir') / 'metainfo',
)

install_data(
  'icons/hicolor/scalable/apps/fr.benjaminbellamy.Awale.svg',
  install_dir: get_option('datadir') / 'icons/hicolor/scalable/apps',
  rename: app_id + '.svg',
)

install_data(
  'icons/hicolor/symbolic/apps/fr.benjaminbellamy.Awale-symbolic.svg',
  install_dir: get_option('datadir') / 'icons/hicolor/symbolic/apps',
  rename: app_id + '-symbolic.svg',
)

appstreamcli = find_program('appstreamcli', required: false)
if appstreamcli.found()
  test('metainfo', appstreamcli,
    args: ['validate', '--no-net', '--strict', metainfo_file])
endif

install_data(
  'fr.benjaminbellamy.Awale.gschema.xml',
  install_dir: get_option('datadir') / 'glib-2.0' / 'schemas',
)

# Compiled into the build tree as well, so the app can be run without being
# installed by pointing GSETTINGS_SCHEMA_DIR at it.
gnome.compile_schemas(
  build_by_default: true,
  depend_files: files('fr.benjaminbellamy.Awale.gschema.xml'),
)

compile_schemas = find_program('glib-compile-schemas', required: false)
if compile_schemas.found()
  test('gsettings-schema', compile_schemas,
    args: ['--strict', '--dry-run', meson.current_source_dir()])
endif

desktop_file_validate = find_program('desktop-file-validate', required: false)
if desktop_file_validate.found()
  test('desktop-file', desktop_file_validate, args: [desktop_file])
endif
