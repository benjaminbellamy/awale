# SPDX-FileCopyrightText: 2026 Benjamin Bellamy <benjamin@castopod.org>
# SPDX-License-Identifier: AGPL-3.0-or-later

engine_tests = [
  'setup',
  'moves',
  'sowing',
  'capture',
  'grandslam',
  'termination',
  'search',
  'advisor',
]

foreach name : engine_tests
  test(name,
    executable('test-' + name,
      files('test-' + name + '.vala', 'test-util.vala'),
      dependencies: [core_dep],
      install: false,
    ),
    args: ['--tap'],
    protocol: 'tap',
    # The search tests spend real wall clock inside the engine's time budgets.
    timeout: 120,
  )
endforeach
