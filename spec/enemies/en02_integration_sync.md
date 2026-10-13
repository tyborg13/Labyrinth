# en-02 integration sync

Director started the merge from codex/peer-benchmark. Conflicts were resolved
on disk without running Git commands, staging, committing, changing branches,
peer review or windowed execution. The director owns staging and the merge commit.

## Resolved files

- data/enemies.json
- scripts/action_icon_library.gd
- scripts/enemy_intent_compass.gd
- scripts/combat_engine.gd
- scripts/combat_board_view.gd
- scripts/run_scene.gd
- tests/suites/contextual_cutout_suite.gd
- spec/card_balance_heuristic.md
- tools/card_heuristic.py
- spec/assets/enemies/raw_sha256.txt
- spec/assets/board_pixel_density/outputs.json
- spec/assets/board_pixel_density/registry.json
- assets/generated/unit_shadow_cache.res (regenerated, not hand-merged)

The unions retain all six director-authored enemy entries verbatim, all seven
approved icon identities, six portraits/static sprites/strike registrations,
all six balance rows, raw hash lines and density entries. Common registry
records were checked equal before union; duplicate IDs/paths were rejected.

Additional integration files: scripts/enemy_strike_points.gd,
scripts/cutout_context.gd, scripts/enemy_mechanics/wind.gd,
tests/suites/en02_enemies_suite.gd, tests/en02_enemies_test.gd,
tests/run_tests.gd, tests/suites/en02_enemy_integration_suite.gd,
tests/suites/encounter_tables_suite.gd, and this handoff.

## Shared mechanics

One forced-next-intent path retains held Icefall/Erupt through skips and Ambush's
existing impossible-strike fallback. Random choices exclude weight-zero and
unavailable Icefall/Burrow/Tether/Kindle intents. Intent plans and action steps
retain every unit's focused helper; redraw, status rows, animation routing and
snapshot application preserve all units.

Burrowed bodies are not moved by wind and are omitted from its affected-actor
preview. Burrow's empty floor occupancy remains intact; HP-free Ice Pillars
redirect Erupt through its existing landing fallback, with Rubble on the actual
landing. Wind uses normal forced movement into Rubble. Ice Pillars block held
Tether lines; displacement can cancel their cardinal alignment while retaining
the declared partner. Wind moves Veiled units without clearing Veil and does
not overwrite the last voluntary hero movement direction. These interactions
have 23 focused regression checks. The full suite now calls en-02 alongside
en-01 and en-03.

The initial encounter run reported three failing trim assertions: newly
expanded shadow pools invalidated the fixture's assumption that a shadow token
always selected the original three-unit helper group. The assertions are
unchanged. Their fixture now copies the existing shadow_helpers group into an
isolated table, then restores the production table. Production encounter data,
weights, enemy values and saves were not edited.

## Observed verification

Every Godot command ran through python3 tools/godot_task_runner.py
--task-id en-02 --stream -- godot --headless --path . --script <script>.
The full suite uses the previously established --timeout 900 runner setting.

- tests/en01_enemies_test.gd: EN01 ENEMIES TEST RESULT: PASS
- tests/en02_enemies_test.gd: EN02 ENEMIES TEST RESULT: PASS (235 checks, 0 failures)
- tests/en03_enemies_test.gd: EN03 ENEMIES TEST RESULT: PASS (210 checks, 0 failures)
- tests/encounter_tables_test.gd: Encounter tables suite: 0 failures
- Encounter regular renderer preparation: 13 groups, 26 enemies + 13 heroes checked
- tests/threats_at_rest_test.gd: THREATS AT REST TEST RESULT: PASS (444 assertions; includes compass suite)
- tests/sfx_bank_test.gd: SFX BANK TEST RESULT: PASS (0 failures)
- tests/test_icon_identity_policy.py: Ran 7 tests in 0.083s / OK
- tests/test_board_pixel_density.py: Ran 41 tests in 106.259s / OK
- Card heuristic Python suites: Ran 38 tests in 0.056s / OK
- tests/en02_enemies_probe.gd -- --check-only: EN02 ENEMIES PROBE CONTRACT: PASS (8 states, 1920x1080, UI scale 100%)
- tools/generate_unit_shadow_cache.gd: UNIT SHADOW CACHE GENERATED: res://assets/generated/unit_shadow_cache.res entries=48 sources=42
- python3 tools/process_board_density.py --record-rests: RECORDED-RESTS 64 file(s)
- python3 tools/process_board_density.py --check: CHECK-OK
- JSON PARSE: PASS (1548 files)
- SIX-ENEMY DENSITY/RAW UNION: PASS
- SIX-ENEMY HEURISTIC UNION: PASS
- RESOLVED/INTEGRATION WHITESPACE: PASS (20 text files; no Git commands)
- Conflict-marker line scan: no matches. A literal example inside the director's
  protected spec/peer_benchmark/feedback/en-03_sync.md is an instruction, not a
  conflict marker. No Git diff command was run under the director's prohibition.
- Full suite: TEST RESULT: PASS (runner exit 0), /private/tmp/en02-sync-full-suite.log.

Exact command output is retained in /private/tmp/en02-sync-*.log. The generated
shadow cache was recreated by its tool; outputs were unioned by identity and
regenerated/validated through rest recording and density checks.

Design placeholders: none. Existing approved timings/geometry/copy are retained.
Chosen debug defaults: integration partner ID 3 and existing seed 20261012;
focused minimum 235 checks; trim fixture group ID shadow_helpers. No player
values were chosen or changed. No new PNG captures exist from this sync.
