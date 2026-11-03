# rr-46 feedback 1 implementation and proof

Review base: `8477f8cf2ef27b459877bac8ce88781c30c76f14`. Runtime timing, depth, authored motion and assets are unchanged in this round. Changes remain uncommitted; the design owner retains review/publication ownership.

## 1. Native painted proof and Retina crops

The reviewed empty crop and full frame were inspected. The old crop is invalid evidence. The new native probe uses fixed 1920×1080 SubViewports with matching 2D logical overrides, independent of the window's Retina backing. Actor bounds map through the canvas transform and real capture/logical size ratio. Headless controls cover the reported 3024×1898 backing geometry and an empty crop with matching background pixels.

The production and reference passes both use the real retained board renderer, approved sprites, materials and procedural death children. The reference overrides only depth ownership with an independent ground-lattice calculation. A separate actor-alpha pass preserves retained scene layers so death dissolve pixels are included. Six transparent passes expose front/behind floor, wall and prop paint. Every sampled frame compares actual actor-support pixels with the independent reference and records alpha overlap and mismatches for each category. Missing actor pixels and terminal ghosts fail. Genuine empty fade endpoints are labelled separately.

The native inventory covers all 36 Warband boards and all ten rigs: eight move directions, a resolver-produced retreat segment and a complete death per board/rig (3,600 cases, 360 deaths and 360 retreats). Each sample retains its source frame, board/actor/clip, transformed crop rectangle, crop, reference crop and actor mask. First, last and failed samples retain full 1920×1080 frames. Before-order captures remove only the new depth-position input. Their painted mismatches are negative controls, separately counted from after-order errors.

The archive verifier requires all boards/rigs/clips, all directions, full clip endpoints, all six painted passes, nonempty actor masks and zero after-order errors, plus at least one rejected painted legacy-order case. It reports actual overlap counts; an empty category is not called painted overlap coverage. Synthetic verifier tests reject missing deaths, missing facings, empty actors, painted errors, non-native input and missing legacy rejection.

**Native result remains pending.** No windowed run was attempted in this sandbox. These changes implement the proof and its guards; headless results do not establish native pixel correctness. Exact bounded board/actor commands and the complete archive-verification command are in [proof_for_design_owner.md](proof_for_design_owner.md).

## 2. Independent death routing

`death_clocks.gd` runs the production blocking sequence runner and production overlap selection/sampler for Seer + Ember Tick + Ash Hound and Gaoler + Ember Tick + Ash Hound, at all three speed settings. Only the wall-clock source and presentation I/O are replaced. Virtual wall ticks integrate the installed production Engine scale; blocking uses the card scope, overlap uses the enemy-action scope, including its existing 0.8 factor.

The guard requires independent per-actor clocks, the legacy 1.036-second group total, unchanged Tick and Ash clocks, correct frame/progress at each production submission, retirement, and one-frame wall-time bounds. Gaoler's release (0.30) and landing (0.45) come from protected compiled metadata and must cross within the actual sample's phase increment. Removing the parity opt-in fails both Seer mixed routes.

## 3. Occupant order and retained reuse

For every rig, a moving actor crosses a stationary Ash Hound's displayed ground Y in the same depth tile, then crosses back. The cached array is the production body submission order. All 30 cases require the correct order and require identity reuse of the occupant dictionary, occupant array and visible-unit array on an identical submission. Disabling `sort_occupants` fails the behavioural order assertion.

## Focused observations

- `feedback1-focused.log`: `Ran 39 tests in 290.425s` / `OK` (rr-46 playback/paint/routing guards and the strict program-suite runner tests).
- `feedback1-mutations.log`: `Ran 29 tests in 126.461s` / `OK`; `RR46 ROUTING MUTATIONS: PASS (death opt-in and occupant sorting rejected)`.
- `feedback1-death-final.log`: `RR46 MIXED DEATH CLOCKS: PASS (12 blocking/overlap cases; three speeds; 12 authored event crossings)`.
- `feedback1-depth.log`: `RR46 DEPTH ORDER: PASS (36 boards; 173718 frames; 74248 old-routing failures; 30 retreat routes; native pixels=false)`; JSON includes 30 occupant crossings and retained reuse checks.
- `feedback1-paint-routing.log`: `RR46 PAINTED ORACLE: PASS (Retina transform; empty crops; six occluder classes; over/underdraw; terminal absence)`; additionally verifies independent reference routing and inherited retained-layer modes headlessly.
- `feedback1-inventory.log`: `RR46 NATIVE CASE INVENTORY: 36 boards; 3600 cases; 360 deaths; 360 resolver retreats`.
- `feedback1-native-parse.log`: direct Godot `--check-only` of the native probe exited 0. Import is only for UID/resource caches, not parser proof; `feedback1-import.log` exited 0.
- `feedback1-audit.log`: isolation audit exited 0 (238 modules). The existing rr-46 Python resource entry remains `[]`: new checks use only memory or per-test temporary directories.

## Chosen defaults and unresolved design

New proof/test defaults: fixed target 1920×1080 at UI scale 1.0 (required), two settle frames (existing), one blocker-adjacent legal move per direction, a Slag resolver route donor, a 5,000,000-usec virtual origin with 4,000-usec wall ticks, 4×4 in-memory red/gray/white pixel fixtures, a 0.1-tile-height ground-Y crossing offset, one 60 Hz frame as the hold tolerance, 0.0001-second rounding tolerance, 0.000001 phase/floor rounding epsilon, one byte of paint-channel rounding tolerance, and a 1,800-second per-board/actor native batch timeout. The no-blocker distance sentinel is 1,000,000. No player-facing tuning was chosen.

No new `TODO_DESIGN` placeholder. Existing `TODO_DESIGN_SEER_SIX_STEP_GAIT` remains: protected Seer motion has four shuffles.

## Files changed

- `tests/headless_test_programs.json`
- `tests/rr46/death_clock_pacing.gd`
- `tests/rr46/death_clock_pacing.gd.uid`
- `tests/rr46/death_clock_scene.gd`
- `tests/rr46/death_clock_scene.gd.uid`
- `tests/rr46/death_clocks.gd`
- `tests/rr46/death_clocks.gd.uid`
- `tests/rr46/depth_check.gd`
- `tests/rr46/depth_probe.gd`
- `tests/rr46/depth_proof_contract.json`
- `tests/rr46/feedback1_report.md`
- `tests/rr46/native_cases.gd`
- `tests/rr46/native_cases.gd.uid`
- `tests/rr46/paint_board.gd`
- `tests/rr46/paint_board.gd.uid`
- `tests/rr46/paint_checks.gd`
- `tests/rr46/paint_checks.gd.uid`
- `tests/rr46/paint_checks_test.gd`
- `tests/rr46/paint_checks_test.gd.uid`
- `tests/rr46/proof_for_design_owner.md`
- `tests/rr46/verify_native.py`
- `tests/test_program_suite_runner.py`
- `tests/test_rr46_playback.py`

## Final full Godot suite

Command: `python3 tools/godot_task_runner.py --task-id rr-46 --timeout 1800 --stream -- godot --headless --path . --script tests/run_tests.gd`.

`/private/tmp/labyrinth_codex/rr46/feedback1-full-godot.log` reports, exit 0:

```text
MAIN BODY ASSERTIONS: 495687
FULL SUITE RUNTIME: 882.309 seconds (budget 900 seconds)
TEST RESULT: PASS
```

All 236 registered programs passed, including both new guards. The existing ObjectDB leak-at-exit warning remains in the log; it did not fail the runner.

## Final full Python suite and checkout

Command: `python3 tools/run_python_suite.py --shards 4 --output-dir /private/tmp/labyrinth_codex/rr46/feedback1-full-python`.

`/private/tmp/labyrinth_codex/rr46/feedback1-full-python.log` reports, exit 0:

```text
Ran 2134 tests in 1545.705s
OK (skipped=66)
PYTHON SUITE WALL: 1545.705s; results: /private/tmp/labyrinth_codex/rr46/feedback1-full-python
```

All four shards passed: 932/204/511/487 tests, zero failures and zero errors. All 21 rr-46 tests passed, including both new routing mutation controls. The movement-plan probe passed in this full invocation. All 2,558 protected files remained byte-identical.

The runner reported a best-effort shared-Git cache write denial: `Cannot update untracked timing cache /Users/borgerding/workspace/Labyrinth/.git/labyrinth-test-timings/python-suite.json: [Errno 1] Operation not permitted: '/Users/borgerding/workspace/Labyrinth/.git/labyrinth-test-timings/tmp0a5w9xcx'`. Task-local logs and result files were saved; no permission escalation or workaround was attempted.

Final `git diff --check` passed. Branch remains `codex/rr-46`, HEAD remains `8477f8cf2ef27b459877bac8ce88781c30c76f14`; all 23 changed/new files are tests, proof helpers, proof contracts, registrations, UID sidecars or handoff documents. `git diff --name-only -- scripts assets spec tools` is empty. No commit, peer review or publication was performed. Native renders, their painted overlap counts and inspected crops remain pending for the design owner.
