# SPDX-FileCopyrightText: 2026 Benjamin Bellamy <benjamin@castopod.org>
# SPDX-License-Identifier: AGPL-3.0-or-later

i18n.gettext(gettext_package,
  preset: 'glib',
  args: [
    '--from-code=UTF-8',
    '--add-comments',
    '--keyword=_',
    '--keyword=ngettext:1,2',
    '--package-name=' + meson.project_name(),
  ],
)

# The brief asks for a source file with translatable strings that is missing
# from POTFILES.in to break the build rather than ship untranslated.
python = find_program('python3', required: false)
if python.found()
  test('potfiles-complete', python,
    args: [meson.project_source_root() / 'build-aux' / 'check-potfiles.py'])
endif
