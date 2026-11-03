# fix-17 integration regression repair

Base: `ecbb6e2f1`, branch `codex/fix-17`. Changes are intentionally uncommitted;
the design owner owns review, inspection and publication.

## Requirement results

1. Gaoler's public `WALK_CYCLE_SECONDS` is a static property derived from
   `Action.frames_for("chainbound_gaoler", "move") * WALK_FRAME_SECONDS`.
   GDScript cannot evaluate a data-loading function in a constant initializer,
   so the presentation suite reads this property through `Script.get`, which
   also supports the legacy constant adapters. No timing value was duplicated.
   All existing pace and authored-clock assertions remain intact.
   The fixed board fixture measures **0.610577 × player** for one resolved tile,
   below the legacy **0.77–1.20** band. The signed-off humanoid-v2 adapter uses
   its protected **0.85-second resolved-step clock**, already covered by the
   suite's v2 branch; this repair does not change that design. The historical
   proportional stride table in `spec/actor_presentation.md` predates v2.

2. Heirloom notifications are appended after rr-38 runtime checks in both
   registration manifests. The accepted prefix is accurately pinned at 130;
   both additional suffix programs are independently ordered and covered by
   the removal/mode mutation guards. There are 177 supplemental programs.

3. The merged `humanoid_motion.gd` retains rr-42's optional held-drop, planted
   support and orientation paths plus rr-43's optional painted `source_grip`.
   The prior rr-43 pin is
   `f13ad6e5f1e5bc51d92eb5e02adba3b15f1146f9e92386dfa7a143151ebb223d`;
   the merged file is
   `8db4fe462d45cfe131b02d1c03928a6fb1e0343777ba33f1bb4f5bcf1c74fc80`.
   Cross-rig proof compares exact serialized world transforms against
   `2542b120d` (before both optional changes): **8 other rigs, 6,170 frame
   poses, exact bytes**. All clips and both facings are sampled. The old
   implementation is loaded with current unchanged dependencies, so this
   comparison specifically isolates `humanoid_motion.gd`.

4. The cache restoration does not fix the rest evidence failure. The sole
   differing field in `rr37/proof/rest_equivalence.json` is `pose_sha256`:
   `38b9a018e35ef4c413a85f46aa1896188f2360a87288bc79b3df0d96c451bb7b`
   becomes
   `227fdfcb48c690d122f3d04ea2cacef44e15432375af89f304f94ffb893ac6c4`.
   Fresh sample files bind the rr-42 merged runtime/compiler/proof helpers,
   including the optional shared motion additions. This invalidates the old
   whole-sample digest. Replacing only the 13 changed `inputs` bindings in the
   fresh sample JSON exactly reproduces the prior whole-sample SHA256; all
   sampled transforms and other fields are byte-identical. The binding diff
   is retained in `output/fix-17/rest-bindings-diff.json`. The thirteenth
   binding is the intentional merged-motion pin update in
   `rr43/outline_baseline.json`; the final reseal follows that update.
   Both rest assemblies still have zero mismatched pixels;
   both production PNG hashes are unchanged. Only the two Lancer rest entries'
   `evidence.report_sha256` fields in the density output manifest change:
   `fd586662e5d72dc20b753eab4e300b43a4201f5044a48e942324153a26da7c69`
   becomes
   `ed36dfd25a892dd6423142e0904046d2f382a229e4a75392bad6133d395f81d1`.
   `native_pixels` remains false. The regression copies the report into a
   temporary directory and sends the reseal report, partition diagnostics and
   fresh rest poses there, preserving the canonical tracked report even if the
   byte assertion fails.

5. Encounter golden: only seed **19**, fields **`combat`** and
   **`save_roundtrip`**, differ. The sole underlying snapshot addition is
   **`combat[13].surface_events[0].source.causal_source_kind = "trap"`**.
   Removing just this field restores every previous hash, including every
   seed's maps/rooms and seed 19's save roundtrip. This is the intended
   pt13-01 analytics change in **68df4200c**, documented in
   `spec/analytics.md`, “Surface and movement relics”. No gameplay, map, room,
   heirloom, rig or save-pipeline behavior changed in this unit.

   - `19.combat`: `8badfa2381012f44f72b1d83c2842417863e901a9333b6926b8d86935bcf1101`
     → `698c0b7763db0d98ed5d530afbf072c6844356b316abd1af69d7589711df8a12`.
   - `19.save_roundtrip`: `6bcfdadca0ec0ebe980779bd075135d68ae4630be99fd263b34e4a0c47a7479e`
     → `01f0206c75fb424bc440f032acf8f486c0677e17fb897e71ff110e6ec9d41d59`.

6. Encounter measurement had one failing assertion: the same golden equality.
   The focused program now reports **2,662 checks, 0 failures**, retaining the
   actual ProgressionStore roundtrip and all sweep/policy assertions.

7. FIX-14: for each of `ordinary` and `retaliate`, the only inserted bytes are
   `,"causal_source_kind":"trap"` at
   **`surface_events[0].source`** and
   **`steps[1].surface_events[0].source`**. Removing these two substrings from
   each new resolution string exactly restores the supplied base
   **23b4f251f** string. This is the same documented **68df4200c** change.
   All playback strings and all remaining resolution/analytics bytes are
   unchanged. No assertion was relaxed or metadata excluded from comparisons.

The adapter's new source hash is pinned separately in
`fixtures/fix_17_gaoler_adapter.json`, chained from rr-42's accepted cleanup
hash. Its historical review receipt is preserved.

## Proof

Logs, transient proof scripts, fresh transforms and JSON inventories are under
`output/fix-17/`. This local output folder is excluded from Godot import by
`tools/output_gdignore.py`.

Observed focused results:

- `actor.log`: `ACTOR PRESENTATION TEST: PASS` and the pace line above.
- `encounter.log`: `ENCOUNTER GOLDEN: PASS (3 seeds; maps, rooms, combat, saves)`;
  `ENCOUNTER MEASUREMENT: PASS (2662 checks; 0 failures)`.
- `fix14.log`: `FIX-14 TEST RESULT: PASS (2539 checks, 0 failures)`.
- `heirloom.log`: `HEIRLOOM NOTIFICATION TEST RESULT: PASS`.
- `registration-python.log`: `Ran 30 tests in 23.867s`, `OK`; covers the
  program-runner suite, repository audit and both approved relic-copy subcases.
- `registration.log`: `TEST REGISTRATION AUDIT: PASS (865 scripts; full suite=505,
  quarantined=29, windowed probe=331)`.
- `quarantine.log`: `QUARANTINE CHECK: PASS (29 entries; 28 programs; 0 now passing)`.
- `merge-focused.log`: `Ran 27 tests in 85.931s`, `OK`; rr-42 Gaoler and its two
  feedback modules, plus rr-43 Lancer.
- `lancer-inventories.log`: `RR37 FRONT PRODUCTION FRAMES: PASS (512 frames;
  0 failures; software raster, native runtime poses)` and the identical rear
  result. Full metrics are in `lancer-inventories.json`.
- `gaoler-gates.log`: `RR42 CALIBRATED SWEEP: PASS (892 frames; 0 findings;
  painted_exposure=True; native_pixels=False)` and
  `RR42 ALL GATES: PASS (0 errors; native=False)`.
- `transforms.log`: `FIX17 CROSS-RIG TRANSFORMS: PASS (8 other humanoid rigs;
  6170 frame poses; exact bytes; baseline 2542b120d)`.
- `final-pin-rest-tests.log`: all five rr-43 outline tests passed. The rest
  subtest correctly caught the pin's additional input-binding change, without
  rewriting its tracked report. After the final reseal, `final-rest-test.log`
  reports `Ran 1 test in 21.341s`, `OK`, and
  `RR41 REST/DENSITY RESEAL: PASS (fresh Godot rest-pose digest and both density
  evidence hashes byte-identical)`.
- `rig-tests.log`: the long combined run reports `Ran 54 tests in 3190.906s`,
  `FAILED (failures=1)`. All 22 rr-41 checks and all five rr-43 outline checks
  passed, including `RR41 FRONT PAINT PROVENANCE: PASS (512 frames; every clip;
  0 procedural leg texels)`, `RR41 ALL FRONT ROUNDING: PASS (2048 UV/pose cases;
  512 poses x 4 choices; every clip including move; no fresh native capture)`,
  all 26 real procedural restorations, and all three disabled-guard controls.
  The only failure was `test_production_motion_paint_and_render_code_remain_byte_identical`:
  that process imported the old test before the fix-17 adapter fixture was
  wired, and therefore still compared the adapter against `e4942e45...`.
  The current test passed in the clean 27-test group above and again in
  `final-adapter-test.log`: `Ran 1 test in 0.019s`, `OK`. Every unique focused
  rig check therefore has a passing final result; the aggregate log's earlier
  failure is preserved rather than relabelled as a passing run.

The exact Godot invocations are retained in each log's runner header. The
required Python group commands were:

```sh
LABYRINTH_TASK_ID=fix-17 python3 -m unittest tests.test_program_suite_runner tests.test_test_registration_audit.RegistrationAuditTests.test_repository_headless_registration_guard tests.text_budget_test.TextBudgetTest.test_relics_match_approved_copy_and_budget -v
LABYRINTH_TASK_ID=fix-17 python3 -m unittest tests.test_rr41_lancer tests.test_rr41_feedback1 tests.test_rr41_feedback2 tests.test_rr41_feedback3 tests.test_rr42_gaoler tests.test_rr42_feedback2 tests.test_rr42_feedback3 tests.test_rr43_lancer tests.test_rr43_outline -v
LABYRINTH_TASK_ID=fix-17 python3 -m unittest tests.test_rr42_gaoler tests.test_rr42_feedback2 tests.test_rr42_feedback3 tests.test_rr43_lancer -v
LABYRINTH_TASK_ID=fix-17 python3 -m unittest tests.test_rr42_feedback2.Feedback2Tests.test_production_motion_paint_and_render_code_remain_byte_identical -v
LABYRINTH_TASK_ID=fix-17 python3 -m unittest tests.test_rr41_feedback3.WalkingTests.test_rest_and_density_evidence_reseal_to_identical_bytes -v
```

### Full Godot acceptance: not met in this worker's single run

`full-godot.log` records:

```text
TEST REGISTRATION AUDIT: PASS (865 scripts; full suite=505, quarantined=29, windowed probe=331)
MAIN BODY RUNTIME: 271.486 seconds
MAIN BODY ASSERTIONS: 495687
FULL SUITE RUNTIME: 723.727 seconds (budget 900 seconds)
TEST RESULT: FAIL (4 failure(s))
```

All original fix-17 failures pass in that run: `en04_enemies_test`,
`suites/full_scene_presentation_program`, encounter golden/measurement,
FIX-14 and heirloom notifications. There are 225 passing children of 229.

The four other failures came from this cold checkout's missing generated
import/global-class cache. `special_encounter_test` could not load the Warband
and Snare `.ctex` files; `enemy_no_action_test`, `fix_11_test` and
`fix_11_probe` could not resolve the global `GameData` class. The no-action
program then timed out. The affected source/tests are unchanged from the task
base. Individual logs are copied into `output/fix-17/full-failures/`, and the
complete scheduler report is `output/fix-17/full-godot-results.json`.

The documented `godot --headless --import` bootstrap completed with exit 0
through the task runner (`headless-import.log`), with **Git status unchanged**.
Focused reruns then passed, without source or assertion changes:

```text
SPX special encounter suite: 0 failures
ENEMY NO ACTION TEST RESULT: PASS (1043 assertions; 0 failures)
FIX-11 TEST RESULT: PASS (162 checks, 0 failures)
FIX-11 PROBE CONTRACT: PASS (128 checks; 1920x1080, UI scale 100%)
```

Logs are `special-encounter-after-import.log`,
`enemy-no-action-after-import.log`, `fix11-after-import.log`, and
`fix11-probe-after-import.log`. The worker did not repeat the full suite,
respecting the explicit one-run limit. The contract's full-suite PASS remains
an open proof item for the design owner; no full Python discovery was run.

### Task-contract acceptance

- **Full Godot PASS and the six former Python failures:** the six former
  Python failures have passing final results. The worker's one full Godot
  run did **not** pass; all four cold-cache failures passed focused reruns
  after the successful import bootstrap. A clean full-suite PASS is pending.
- **Re-record only named, intended merged changes and identify exact fields:**
  met. The exact pt13-01 trap-causality fields, rr-42/rr-43 shared-motion pin,
  and rest-evidence binding fields are enumerated above, with byte-for-byte
  restoration proofs. No protected design values or assertions were weakened.

## Files changed

- `assets/units/chainbound_gaoler_cutout/renderer.gd` — data-derived public clock.
- `tests/suites/actor_presentation_suite.gd` — static/constant contract access,
  plus diagnostic pace reporting without changing the v2 clock assertions.
- `tests/headless_test_programs.json`, `tests/test_program_suite_runner.py` —
  notification registration, complete count and ordered suffix guards.
- `tests/fixtures/fix_17_gaoler_adapter.json`, `tests/test_rr42_feedback2.py` —
  exact adapter hash chain after the contract restoration.
- `experiments/cutouts/frostglass_lancer/rr37/rr43/outline_baseline.json`,
  `tests/test_rr43_outline.py` — merged sampler hash and proof rationale.
- `experiments/cutouts/frostglass_lancer/rr39_density.py`,
  `tests/test_rr41_feedback3.py` — temporary reseal outputs and unchanged
  canonical-report assertion.
- `experiments/cutouts/frostglass_lancer/rr37/proof/rest_equivalence.json`,
  `spec/assets/board_pixel_density/outputs.json` — final input-binding digest
  and only its two Lancer evidence references.
- `tests/fixtures/encounter_measurement_golden.json`,
  `tests/encounter_measurement_test.gd` — two seed-19 hashes and exact attribution.
- `tests/fixtures/fix_14_legacy_presentation.json`,
  `tests/helpers/fix_14_legacy_compatibility.gd` — four intended additive trap
  causality fields and their documented base provenance.
- `tests/fix_17_implementation.md` — this implementation/proof handoff.

`output/fix-17/` contains local diagnostic scripts, captured headless JSON and
logs. Its `.gdignore` is a local marker, not an intended source change.

## Proof for the design owner

This brief requires headless regression proof. No new windowed probe or fixture
was needed. For optional confirmation of the preserved live Gaoler travel,
the existing production probe runs all four views at 1920×1080 and 100% scale:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fix-17 && LABYRINTH_PRESENTATION_ACTORS=chainbound_gaoler python3 tools/visual_probe_runner.py tests/actor_presentation_probe.gd --task-id fix-17 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 --expect-size 1920x1080 --result-manifest output/fix-17/owner-gaoler-travel.json
```

The 180-second cap allows the existing multi-facing movement/bounds/transition
probe to complete. The probe writes its PNGs and `manifest.json` under its
isolated `user://probes/actor_presentation_v1`; the runner's result manifest
records their resolved paths. This command was **not run** by this worker.
No `tools/inspection_fixture.py` command is requested by this unit.

The cache is now bootstrapped. The required clean full-suite result can be
obtained in the design owner's merge round with:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fix-17 && python3 tools/godot_task_runner.py --task-id fix-17 --timeout 900 --stream -- godot --headless --path . --script tests/run_tests.gd
```

## Design and defaults

- `TODO_DESIGN` placeholders: none. No art, fonts, icons or audio were created
  or modified; no protected design values were rewritten.
- Chosen defaults: the diagnostic cross-rig comparison uses named
  `PROOF_SOURCE_STEP = 131.52` source pixels and `PROOF_PIXEL_SCALE = 1.0`.
  These affect only the transient proof, not production motion or tuning.
  `OWNER_PROBE_TIMEOUT_SECONDS = 180` is the optional windowed proof cap.
- Windowed capture was not attempted: this worker has no window-server access.
  Inspection fixture is not applicable to this regression repair, as recorded
  in the owner-created task contract.
