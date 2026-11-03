# rr-40 initial implementation proof

Historical first handoff. The owner committed its changes at `20f9b2e06`; current adopted feedback and verification are recorded in [feedback1_report.md](feedback1_report.md). The marker-tracking blocker described below was resolved by that commit.

Base: `086650ae5` (`codex/rr-39`). Worktree: `codex/rr-40`.
All implementation changes remain uncommitted. Review, inspection and publication belong to the design owner.

## Acceptance

1. Repair integration failures at their source without changing accepted paint or motion. Shared v2 registration now supports preparation/adoption; tests resolve production renderers, geometry, authored clocks and snapped weapon points. Existing assertion tolerances and full-canvas requirements remain intact.
2. Full Godot and Python discovery were both run to completion. Godot passes. Python has one remaining repository-metadata failure because this sandbox cannot stage the four new `.gdignore` markers; the requirement for both suites to be green is therefore not fully met. Exact results and failure lists are below.
3. Preserve the Lancer art, underlay, motion, cuts and fills. No asset pixels, case values, director data or art-identity values are edited; offline evidence folders gain import-ignore markers only.

## Files changed

Runtime:

- `scripts/combat_board_view.gd`: shared v2 preparation and adapter-owned reset/adoption.
- `scripts/maquette_cutout_runtime/presentation.gd`: consume prepared canvases through the ordinary roster path.
- `scripts/maquette_cutout_runtime/renderer.gd`: restore constructor-equivalent state after warming.
- `scripts/enemy_strike_points.gd`: registered v2 spear landmark and protected action mapping.

Regression coverage and fixtures:

- `tests/helpers/enemy_strike_fixture.gd`
- `tests/maquette_cutout/capture_storage_test.gd`
- `tests/maquette_cutout/production_crop_plan_test.gd`
- `tests/perf/hover_board_reference.gd`
- `tests/prepared_unit_canvas_equivalence_test.gd`
- `tests/rr37/renderer_sockets.gd`
- `tests/suites/actor_presentation_suite.gd`
- `tests/suites/enemy_strike_trail_suite.gd`
- `tests/suites/pre_battle_ui_suite.gd`
- `tests/test_native_frames.py`
- `tests/mq11_preservation.py`
- `tests/test_mq11_accessories.py`
- `tests/test_mq12_successor.py`
- `experiments/cutouts/frostglass_lancer/rr39_fixture/.gdignore`
- `experiments/cutouts/frostglass_lancer/rr39_tie_fixture/.gdignore`
- `spec/art_identity/jobs/frostglass_lancer/.gdignore`
- `spec/peer_benchmark/staged/rr-39/.gdignore`
- `tests/rr40/prepared_canvas_proof_contract.json`
- `tests/rr40/implementation_report.md`

## Root causes

- `test_godot_sidecars`: rr-39 committed retained proof images without offline import markers; four `.gdignore` files cover only those evidence/input folders. The unchanged guard passes for the proposed tracked inventory, but the actual index cannot be updated in this sandbox.
- Historical mq-11/mq-12 preservation checks: mq-14 deliberately superseded the Lancer delivery; fixtures now verify its complete immutable accepted Git inventory before supplying the older view, with edit/add/delete rejection tests and every unrelated pin still live.

- `pre_battle_semantics_test`, `pre_battle_true_scale_test`, `pre_battle_view_test`: their shared full-source assertion hardcoded the legacy 128px atlas offset; it now verifies the complete 255px source rectangle and viewport size against the registered renderer geometry.
- `prepared_unit_canvas_equivalence_test`: it read the removed `_frostglass_renderers` pool, and production preparation omitted shared v2 renderers; preparation and adoption now use the common registration and reset warmed canvases to constructor state.
- `perf/combat_frame_scenarios`: its inherited reference called removed `_sync_frostglass_renderers`, making dependent scripts fail compilation and `new()` calls cascade; the existing generic roster loop now owns that renderer in the reference too.
- `suites/full_scene_cutouts_program`: the strike suite used the removed Lancer model-map entry, old motion key, legacy weapon bone/landmark and bone-only contact oracle; it now uses production registration, protected action selectors and the actual snapped sprite transform, retaining the original contact tolerance.
- Main actor-presentation suite: it queried legacy distance-based gait methods on the v2 fixed-duration adapter and support checks relied on that travel test to warm textures; v2 clocks are now checked against protected director data for arbitrary distances, and support fixtures explicitly prepare each actor asset.
- `test_native_frames.test_native_gate_rest_loader_all_codecs`: its synthetic case omitted the required `cutout.json` consumed by the new proof-canvas context; the fixture now supplies the default configuration.
- `test_native_frames.test_godot_storage_roundtrips_through_task_runner`: its mock board omitted the new `unit_cutout_renderer` interface; it now supplies the explicit no-renderer case and also checks a declared wider canvas.
- `test_production_crop_plan.test_fixture_only_plan_mutation_is_rejected`, `test_moving_actor_across_scenarios_has_one_covering_crop`: their moving mock board omitted that same interface; supplying the no-renderer result restores the original covering-crop and omitted-frame mutation assertions.

## Focused results

Logs are in `/private/tmp/labyrinth_codex/`.

- `rr-40-pre_battle_semantics_test.log`: `TEST RESULT: PASS`
- `rr-40-pre_battle_true_scale_test.log`: `TEST RESULT: PASS`
- `rr-40-pre_battle_view_test.log`: `TEST RESULT: PASS`
- `rr-40-prepared-final.log`: `PREPARED UNIT CANVAS RESULT: {"cases":32,"checks":928,"errors":[],"native":false,"orphans":0,"pixel_differences":[]}`
- `rr-40-full_scene_cutouts_program-r3.log`: `MAIN DOMAIN ASSERTIONS full_scene_cutouts_program: 646895`; `TEST RESULT: PASS`
- `rr-40-runtime-final.log`: `RR37 RUNTIME: PASS (282 checks; headless registration, views, portraits and clocks)`
- `rr-40-combat_frame_scenarios.log`: exit 0; 18 cases, `failures=[]`, final `orphan_nodes=0`. Summary: `/private/tmp/labyrinth_codex/rr-40-perf-summary.json`; complete data: `/private/tmp/labyrinth_codex/rr-40-perf-output/before.json`. Headless CPU timings are not native performance proof.
- `rr-40-native-frames.log`: `Ran 15 tests in 6.049s`; `OK`.
- `rr-40-crop-plan.log`: `Ran 3 tests in 10.345s`; `OK`.
- `rr-40-actor-presentation.log`: `ACTOR PRESENTATION: PASS (398 checks; 0 failures)`.
- `rr-40-special-encounter.log`: `SPX special encounter suite: 0 failures` (after isolated import-cache bootstrap).
- `rr-40-art-identity.log`: `Ran 111 tests in 38.978s`; `OK`.
- `rr-40-rr21-review-final.log`: `Ran 2 tests in 32.016s`; `OK`; `RR21 REVIEW PREFLIGHT: PASS (headless evidence; native pixels and encoding not run)`. Two unchanged tests also present on master initially lacked the ignored `experiments/cutouts/briar_weaver/mq9/proof/logs/` scratch directory; creating that directory resolved the fixture precondition without editing their assertions.
- Proposed marker inventory: `PROPOSED TRACKED MARKER INVENTORY: PASS (actual Git index unchanged)`; this is not an actual full-suite pass.
- `tools/output_gdignore.py --check`: `OUTPUT GDIGNORE: PASS (15 folders; 6 referenced roots)` (`rr-40-gdignore-final.log`); `git diff --check` also passed.

The early `full_scene_cutouts_program` attempts exposed stale fixture selectors and landmark lookup; their errors were fixed and the entire program rerun. No failed assertion was removed or tolerance expanded.

## Full-suite results

Final Godot: `FULL SUITE RUNTIME: 665.144 seconds (budget 900 seconds)`; `TEST RESULT: PASS`; runner exit 0, all 206 child programs passed, zero script-error markers. `fix_12_test` is absent from this rr-39 base and was not run; its integration timeout exemption was not exercised. Log: `/private/tmp/labyrinth_codex/rr-40-godot-full-final.log`.

Final Python (`rr-40-python-full-final.log`, runner exit 1):

```text
Ran 1892 tests in 3500.376s
FAILED (failures=1, skipped=66)
```

Sole failure: `test_godot_sidecars.GodotSidecarRepositoryTests.test_tracked_sources_have_sidecars_and_sidecars_have_sources` — the four new offline import markers exist but are not in the Git index. Every other test passed. The 66 skips retain their verbose reasons in the log. The two additional tests are the strict accepted-successor fixture regressions.

No staged-inventory override was applied to either full discovery. The unchanged sidecar guard separately passed for the proposed inventory containing the four markers; that focused proposal check is not represented as a full-suite pass.

First full Python attempt (`rr-40-python-full.log`, runner exit 1):

```text
Ran 1890 tests in 3847.274s
FAILED (failures=3, errors=6, skipped=66)
```

Complete failure list:

- `test_godot_sidecars.GodotSidecarRepositoryTests.test_tracked_sources_have_sidecars_and_sidecars_have_sources`
- `test_mq11_accessories.AccessoryGeometryTests.test_todos_stop_the_whole_batch_before_writes_or_native_submission` (two subtests: `hollow_mimic`, `slag_mortar`)
- `test_mq11_accessories.AccessoryProofTests.test_before_iou_and_every_existing_delivery_remain_byte_identical`
- `test_mq11_accessories.AccessoryProofTests.test_unresolved_status_uses_test_owned_design_files`
- `test_mq12_successor.GloamSuccessorTests.test_exact_receipts_replace_only_the_complete_gloam_delivery`
- `test_mq12_successor.SuccessorTests.test_receipt_matches_the_exact_reviewed_trees_and_original_baseline`
- `test_rr21_review.ReviewTests.test_native_preflight_requires_current_capture_and_never_rebinds_it`
- `test_rr21_review.ReviewTests.test_review_from_clean_proof_state_regenerates_real_direction_evidence`

The first Python discovery also exposed rr-39 evidence directories without `.gdignore` markers and four historical maquette-preservation tests seeing the already accepted mq-14 Lancer successor. The test fixture now independently verifies the complete live Lancer delivery against immutable accepted commit `0982b96d4e4b1f2383c3b0a300eaa06c36bb4a97`, then supplies mq-11's historical view while retaining every other live pin. New mutations prove edited, added and deleted successor files fail before normalization. The production guard and all historical receipts remain unchanged. Focused result: `Ran 41 tests in 2.131s`; `OK` (`rr-40-preservation-final-r2.log`).

The four offline `.gdignore` markers are ready, but the repository guard requires them tracked. Staging failed exactly with `fatal: Unable to create '/Users/borgerding/workspace/Labyrinth/.git/worktrees/rr-40/index.lock': Operation not permitted`. The owner was asked to stage only those four marker files, without committing. No reply or index change was observed. No alternative Git metadata or test bypass was used.

Required owner action (from the task worktree):

```sh
git add -- experiments/cutouts/frostglass_lancer/rr39_fixture/.gdignore experiments/cutouts/frostglass_lancer/rr39_tie_fixture/.gdignore spec/art_identity/jobs/frostglass_lancer/.gdignore spec/peer_benchmark/staged/rr-39/.gdignore
```

Then rerun the actual sidecar guard and full Python command shown below. The implementation worker leaves every change uncommitted.

First full Godot attempt (`rr-40-godot-full.log`): `FULL SUITE RUNTIME: 751.542 seconds (budget 900 seconds)`; `TEST RESULT: FAIL (5 failure(s))`. Failure list: neutral support-centroid fixture checks for `glacial_mirror`, `hoarfrost_seer`, `arc_thrall`, `frostglass_lancer`, plus `special_encounter_test`. The support fixtures are now explicit about preparing their textures. The special encounter test intentionally requires real Godot imports; a new worktree has none. Eight unchanged approved emblem sources and their sidecars were copied into `/private/tmp/labyrinth_codex/rr-40-emblem-imports`, imported headlessly through the task runner there, and only their generated `.ctex` caches copied into this worktree's ignored `.godot/imported/`. No production sidecar or assertion was changed. Import log: `rr-40-emblem-imports.log`. This is asset-cache bootstrap, not parser validation. The last finishing child was `perf/transition_failure_case`. An early progress update incorrectly identified it as `fix_12_test`; that test is absent from this base and no pass is claimed for it.

## Proof for the design owner

No windowed run was attempted: this worker has no macOS window-server access. The prepared-canvas program already implements exact native renderer and composed-board pixel equality for all 32 cases, writes `user://prepared_unit_canvas.png`, and emits its absolute path. The new proof contract requires that capture at 1920x1080.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-40 && python3 tools/visual_probe_runner.py --task-id rr-40 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 --expect-size 1920x1080 --proof-contract tests/rr40/prepared_canvas_proof_contract.json --result-manifest /private/tmp/labyrinth-inspection-manifests/rr-40-prepared-canvas.json tests/prepared_unit_canvas_equivalence_test.gd
```

UI scale is the default 100% in the runner's isolated configuration. No inspection-fixture command is required by this unit brief; preparation and publication remain owner tasks.

The final full-suite commands are:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-40 && python3 tools/godot_task_runner.py --task-id rr-40 --timeout 900 --stream -- godot --headless --path . --script tests/run_tests.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-40 && LABYRINTH_TASK_ID=rr-40 python3 -m unittest discover -s tests -p 'test_*.py' -v
```

## TODO_DESIGN and chosen defaults

- TODO_DESIGN placeholders: none; no missing player-facing design was invented.
- `NATIVE_PREPARED_PROOF_TIMEOUT_SECONDS`: 180 for the owner's 32-case native equivalence run (the existing program-child timeout).
- `ACTOR_TYPES`: debug-only equivalence roster includes Crawler, Harrier, Lancer, Gloam and Herald.
- Full-suite timeout uses the existing 900-second workflow cap. The first attempt used a 1200-second outer runner cap but retained the scheduler's 900-second budget and completed in 751.542 seconds; the final run uses 900 throughout.
- Strike-fixture default: choose the first catalog melee/area intent with a registered weapon trail; explicit variants retain their authored selector.
- `WideCanvasRenderer`: test-only geometry copies the accepted Lancer capacity (640px canvas, 192px source offset); it does not configure production art.

## Open issues

Tracking the four import-ignore markers and obtaining an actual green full Python result remain blocked on owner Git access. Native pixel proof was not run because this worker has no window-server access; the exact owner command and contract are above. The owner performs review, commits and inspection after this uncommitted implementation handoff. No peer review, commit, push, merge, rebase, stash, branch change or queue edit was performed. Final branch/HEAD remain `codex/rr-40` / `086650ae58b9d943480d759d873256e654a6bb7e`.
