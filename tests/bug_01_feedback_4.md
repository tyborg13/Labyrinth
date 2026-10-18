# bug-01 feedback 4 — classification and proof handoff

All 106 owner-provided reports are classified in
[bug_01_native_classification.md](bug_01_native_classification.md): 44 have a
difference in at least one pair, 62 are equal controls, and all 212 temporal
comparisons are exactly equal. Shader TIME is rejected as this run's cause.
The twelve supplied original/restored/fresh image triplets were inspected.

## Requirements met

1. Case 21 is a production retained-command bug: the brazier's obstruction data
   changes but its foreground pillar is not redrawn. Cases 10–14 are HP ghosts.
   The other 38 differing cases have obsolete elemental references or invalid
   fixture inputs (encounter closure, fresh HUD navigation, private nav writes).
   The classification records each case's definition and all three pixel counts.
2. `board_scene_prop_redraws.gd` reuses the existing depth/coverage rules and queues
   candidates whose old/new scene-prop obstruction differs. Only two integration
   lines are added to `combat_board_view.gd`. Root cause is `7d38b66ce`, predating
   baseline `816f5e68a`; the parent conservatively redrew all unknown presentation
   keys. The player impact is a new prop hidden behind an opaque pillar, or a
   pillar left faded after prop removal, until another redraw. No floor-light,
   zoom, pan, room, opacity or timing rules change.
3. Every native case compares complete retained pixels to independently fresh
   production. The original pixel baseline is kept only for empty/unchanged
   resubmission cases; existing structural reference and strict cached-floor
   comparisons remain. Health damage/healing transients finish through their real
   tracker clock before freezing. The test supplies its future warden encounter
   closure at room entry. Private zoom/pan setup is replaced with public
   navigation, and the fresh helper uses the complete transform refresh, including
   independent HUD/obstruction caches. No resolved geometry or rendered cache is
   copied into fresh.
4. Equality is strict and includes actors and alpha. The mutation additionally
   asserts exactly one changed cached-floor pixel and one changed board pixel,
   both at the named coordinate. Its distinct error remains
   `BUG_01_DELIBERATE_FLOOR_PIXEL_MUTATION` and cannot be hidden by other errors.
5. Headless results are below. Native proof and mutation remain owner-run because
   the worker has no window-server access; neither command was attempted here.

## Proof for the design owner

Positive proof, with all per-case diagnostics retained:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/bug-01 && LABYRINTH_BUG_01_DIFF_DUMP=1 python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --attempts 1 --timeout 600 tests/static_floor_cache_equivalence_test.gd --task-id bug-01 --expect-size 1920x1080 --proof-contract tests/proof_contracts/bug_01_floor_restore.json --result-manifest output/bug-01/floor-native-feedback-4.manifest.json
```

Mutation proof, expected exit 1 solely for the injected pixel:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/bug-01 && LABYRINTH_BUG_01_MUTATE_FLOOR=1 python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --attempts 1 --timeout 600 tests/static_floor_cache_equivalence_test.gd --task-id bug-01 --expect-size 1920x1080 --proof-contract tests/proof_contracts/bug_01_floor_restore.json --result-manifest output/bug-01/floor-mutation-feedback-4.manifest.json
```

Both commands enforce 1920x1080, 100% UI scale. The positive run should have 106
cases, no errors/pixel differences, and `RESTORED EMPTY BOARD NATIVE: PASS`.
The mutation run adds the deliberate-mutation case and should report
`FLOOR PIXEL MUTATION DIFF: floor=1 board=1 pixel=(...)` plus the distinct mutation
error; other comparison failures are unexpected. Removing the pixel must restore
exact equality in both runs. These are expected results, not observed results.

Printed capture paths:

- `user://bug_01_floor_{restored,fresh,reference,mutated}.png`
- Positive diagnostics: `user://bug_01_diff/index.json` and
  `user://bug_01_diff/case_NNN/report.json`, seven cropped PNGs and five lossless
  WebP masks per case. Absolute paths and exact RGBA metrics are printed/recorded.
  Original-reference differences remain visible as diagnostics but are not an
  assertion for changed presentations. Retained/fresh differences must all be 0.

No playable inspection fixture is needed: the changed behavior is fully addressed
by the native scene-prop onset/removal cases and retained/fresh/mutation proof.
The owner handles inspection, review and Git lifecycle.

## Observed verification

The focused floor regression was run before the production fix, after correcting
fixture inputs. It exited 1 with exactly these errors:

```text
Scene prop onset must redraw its obstructing pillar
Scene prop removal must redraw its obstructing pillar
```

Report: `output/bug-01/qa-07-floor-feedback-4-regression-before.json`;
106 cases, 163232 checks, zero orphan nodes. The corrected production code then
passed the same assertions through qa-07. All four programs passed together,
exit 0, 59.257 s total, report `output/bug-01/qa-07-feedback-4.json`:

```text
PREPARED OTHER CHARACTER VIEW RESULT: {"boundaries":{"equipment":12,"magic":26},"cancellation_boundaries":11,"cases":42,"checks":927,"differences":0,"errors":[],"orphans":0}
CHARACTER RETENTION RESULT: {"cases":107,"differences":0,"errors":[],"orphan_nodes":0,"preparation_frames":2894}
SHOP RETAINED CONTENT TEST RESULT: PASS
STATIC FLOOR CACHE RESULT: {"cases":106,"checks":163232,"errors":[],"native":false,"orphans":0,"pixel_differences":[]}
```

After adding the native one-pixel-count assertions, the floor program passed
again with dump mode enabled: exit 0, 13.101 s total;
`output/bug-01/qa-07-floor-feedback-4-final.json`, same floor result line.
Its end-to-end capture smoke and metrics/crop/mask/persistence checks also pass.

Full Godot suite: exit 0; log `output/bug-01/godot-full-feedback-4.log`:

```text
MAIN BODY RUNTIME: 303.795 seconds
MAIN BODY ASSERTIONS: 378785
FULL SUITE RUNTIME: 344.990 seconds (budget 900 seconds)
TEST RESULT: PASS
```

Its existing ObjectDB leak warnings remain; the focused bug-01 programs report
zero orphans. Prescribed sound-lab environment: exit 0, `Ran 39 tests in 27.859s`
and `OK`, log `output/bug-01/python-sfx-feedback-4.log`. UI identity lint: exit 0,
`Ran 25 tests in 3.421s` / `OK`, log `output/bug-01/ui-identity-feedback-4.log`.
Output hygiene: `OUTPUT GDIGNORE: PASS (14 folders; 3 referenced roots)`.
Full Python discovery: exit 0, log `output/bug-01/python-feedback-4.log`:

```text
Ran 698 tests in 632.785s
OK (skipped=63)
```

The skips are existing optional-environment checks: 6 classical-audio checks,
16 arrangement checks, 2 opt-in Blender checks and 39 sound-lab checks. Sound-lab
passed separately in its prescribed environment above. No dependencies were added.
`git diff --check` passed after final edits.

Commands executed:

```sh
LABYRINTH_BUG_01_DIFF_DUMP=1 python3 tools/program_suite_runner.py --task-id bug-01 --result-file output/bug-01/qa-07-feedback-4.json --suite prepared_other_character_view_test --suite retained_character_inventory_equivalence_test --suite shop_retained_content_test --suite static_floor_cache_equivalence_test
LABYRINTH_BUG_01_DIFF_DUMP=1 python3 tools/program_suite_runner.py --task-id bug-01 --result-file output/bug-01/qa-07-floor-feedback-4-final.json --suite static_floor_cache_equivalence_test
python3 tools/godot_task_runner.py --task-id bug-01 --timeout 900 --stream -- godot --headless --path . --script tests/run_tests.gd
python3 -m unittest discover -s tests -p 'test_*.py' -v
/Users/borgerding/.cache/umbra-sfx/venv/bin/python -m unittest discover -s tests -p 'test_sfx_lab.py' -v
python3 tests/test_ui_identity_lint.py
python3 tools/output_gdignore.py
```

## Files changed this pass

- `scripts/board_scene_prop_redraws.gd`: targeted obstruction invalidation helper.
- `scripts/combat_board_view.gd`: helper integration for scene-prop changes.
- `tests/static_floor_cache_equivalence_test.gd`: prop onset/removal regressions,
  proper navigation/encounter fixtures, strict fresh comparisons in all cases,
  unchanged-original controls and single-pixel negative-control checks.
- `tests/fixtures/static_floor_fresh_checks.gd`: all-case independent geometry,
  HUD, obstruction, floor-input and settled-health checks.
- `tests/fixtures/static_floor_diff_capture.gd`: complete fresh navigation setup.
- `tests/fixtures/static_floor_proof_clock.gd`: settle health transients.
- Classification, this handoff, findings and historical diagnostic pointer.
- `output/bug-01/`: contract, native inputs, source-history/audit evidence and logs.

## Chosen defaults / TODO_DESIGN / open issues

New fixture field: `PROOF_ENCOUNTER_TYPES = ["warden"]`, the actor already used
by the clock test. Existing proof-only navigation samples (0.83, (12,-9)) are
retained through the correct APIs. Health settling uses existing production
duration constants, with no new timing value. Earlier proof defaults remain in
[the findings](bug_01_findings.md) and [diagnostic handoff](bug_01_diff_dump.md).

TODO_DESIGN placeholders: none added. Open issue: the revised native proof and
mutation-only failure need the owner's run. No native pass is claimed. No
production assets, tuning, analytics, saves, supported inputs, task registration
or quarantine are changed. Everything remains uncommitted; no peer review or
Git lifecycle action was performed.
