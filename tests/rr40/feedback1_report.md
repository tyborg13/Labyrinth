# rr-40 adopted feedback 1

Historical round-one record, committed by the owner at `ad552f543`. Current visual-defect work is recorded in [feedback2_report.md](feedback2_report.md).

Base: `20f9b2e06` on `codex/rr-40`. Changes remain uncommitted. No peer review, publication or windowed run was performed by this worker. The initial handoff is historical; its four import-ignore markers are now tracked by the owner's commit.

## Files changed

- `scripts/maquette_cutout_runtime/renderer.gd`: generic constructor-state capture and subclass reset hook.
- `scripts/enemy_strike_points.gd`: remove the unused maquette action-pose branch.
- `tests/prepared_unit_canvas_equivalence_test.gd`: expanded roster/matrix and direct transform comparison.
- `tests/frostglass_lancer_cutout_pack_test.gd`, `tests/fixtures/frostglass_lancer_cutout_export_smoke.gd`: production v2 package closure, topology and timing guard.
- `tests/enemy_cutout_roster_pack_test.gd`, `tests/fixtures/enemy_cutout_roster_export_smoke.gd`: ship and resolve registered asset adapters in the roster package.
- `tests/frostglass_lancer_cutout_gameplay_probe.gd`: production renderer, v2 clips/contact/gait and current debug fixtures.
- `tests/test_rr40_feedback.py`: isolated positive/missing-adapter package regression.
- `tests/rr40/gameplay_proof_contract.json`: exact-size required owner captures.
- `tests/rr40/feedback1_report.md`: this handoff and proof record.
- `tests/rr40/implementation_report.md`: mark the first handoff historical and link this follow-up.

## Unit brief acceptance

1. Source repairs preserve the same shared v2 registration, canvas, pose, perf and crop-plan contracts; no assertion was weakened or pinned to broken output. Original integration-failure causes are listed in [the initial root-cause record](implementation_report.md#root-causes). All formerly failing programs and Python cases pass in the final focused/full runs.
2. Both full suites pass on this worktree; exact results and empty failure lists are below. No `fix_12_test` exemption was used.
3. The Lancer art, underlay, motion, cuts and fills are untouched; the final Git check verifies all asset and authoring trees unchanged.

## Adopted feedback and root causes

1. **Prepared Capacitor:** shared reset restored only base fields, retaining subclass reflection and idle seed. A generic subclass hook now runs before the base reset and pose application; its default restores captured constructor values for subclass fields, including Capacitor reflection and idle seed. Subclasses may override that hook for custom ownership. No figure-name branch was added. Exact visible rig transforms, visibility, modulation and depth are compared alongside snapshots for all ten v2 figures, retaining Crawler and Harrier coverage. The 64-case matrix covers normal/reduced motion, four preparation directions, reaction-first/idle-first adoption, and idle/hit/block/death. Hit 0.12 and death 0.5 reproduce the reported pose.
2. **Package/export:** the old guard packed and instantiated the retired 19-bone renderer, so a missing production adapter escaped detection. Build, empty-project verification and export smoke now use the registered v2 adapter, full authored topology, skinned/rigid parts, clip selectors and director timing. The ordinary roster package also ships and resolves production asset adapters generically. A new isolated Python regression checks both the real package and the `extends Node` adapter mutation.
   **Gameplay probe:** removed pool access, legacy clips/gait and old initiative assumptions no longer described production. It now resolves the registered renderer, checks its authored snapped body root and v2 planted-foot anchors with the unchanged 0.2px drift limit, and uses the actual action phase for contact checks even when reduced motion displays rest. Debug fixtures isolate one activation, place the lunge within its existing range and derive lethal HP from Quick Stab's current data; input, outcome, texture ownership, direction and death assertions remain.
3. **Unused branch:** removed the unreachable shared maquette `action_pose` branch; production continues through its existing action adapter.
4. **Hover timings:** the reviewer reported ordinary 5.652ms (5ms budget), air T2 9.695ms (8ms), lightning T3 8.404ms (8ms). Their respective p95 values were 0.377/0.627/0.390ms. These are headless CPU submission measurements, with budgets reported but not enforced. Matched unchanged-base comparison and current results are recorded below.

The Lancer's art, underlay, director/compiled motion, cuts, fills and production adapter values are unchanged. No design placeholders were needed.

## Verification

The first reference run found the Herald's unchanged prior-byte guard rejecting an asset-local Capacitor override. That override was removed; constructor-state capture/restoration now lives entirely in the shared renderer, preserving every prior asset byte and the original assertion. Both final full suites pass. The final reference set passed `Ran 184 tests in 399.929s` / `OK` (`references-final.log`). All three pre-battle programs and `full_scene_cutouts_program` passed; the latter retained 646895 assertions. `RR37 RUNTIME: PASS (282 checks; headless registration, views, portraits and clocks)`. Logs use `/private/tmp/labyrinth_codex/rr-40-feedback1-*.log`.

Focused results already observed:

- Expanded equivalence: `PREPARED UNIT CANVAS RESULT: {"cases":64,"checks":4864,"errors":[],"native":false,"orphans":0,"pixel_differences":[]}` (`prepared-exact.log`).
- Reset-hook mutation: exit 1, six Capacitor transform failures, zero orphan nodes (`reset-mutation-exact.log`); only an in-process adapter resource was replaced.
- Adapter mutation: `Ran 1 test in 1.820s`; `OK` (`package-mutation.log`). The real package succeeds and the placeholder adapter fails for missing production methods.
- Both final source-package stages pass; artifacts are `/private/tmp/labyrinth_codex/rr-40-feedback1-lancer.pck` and `/private/tmp/labyrinth_codex/rr-40-feedback1-roster-template.pck`; `FROSTGLASS CUTOUT EXPORT RUNTIME: PASS (editor=false)` and `ENEMY CUTOUT ROSTER EXPORT TEST RESULT: PASS (editor=false)` (`pack-build-final`, `pack-verify-final`, `export-final`, `roster-build-final`, `roster-export-final` logs). The stock template disables path overrides, so the PCK was placed beside its executable with the matching basename. No binary was changed.
- Gameplay: `FROSTGLASS GAMEPLAY PROBE: PASS` (`gameplay-support.log`), 1,006 planted-foot comparisons, maximum drift 0.000125827195006423px. Manifest: `/private/tmp/labyrinth-godot-home/rr-40-1792941550623875000-20775/Library/Application Support/Escape the Umbra Parallel rr-40-1792941550623875000-20775/probes/frostglass_gameplay_v01/manifest.json`. This run emits an ObjectDB shutdown warning. The final verbose run (`gameplay-verbose.log`) also passes and instead reports one unclaimed `BAYER` StringName at shutdown, without an ObjectDB warning or script error. No native pixel claim is made.

## Final full suites

Full Godot (`rr-40-feedback1-godot-full.log`): `FULL SUITE RUNTIME: 596.865 seconds (budget 900 seconds)`; `TEST RESULT: PASS`; task runner exit 0. All 206 program results pass; failure list `[]`; zero script-error/load-error markers. The main body completed 495455 assertions. A nonfatal ObjectDB shutdown warning remains in the log (also present in the prior reviewed full-suite log). `fix_12_test` is absent from this rr-39-based worktree, so no pass or timeout is claimed for it and no exemption was needed.

Full Python (`rr-40-feedback1-python-full.log`), run serially after Godot: `Ran 1893 tests in 3553.501s`; `OK (skipped=66)`; exit 0; failure/error lists `[]`. The 66 skips retain their reasons in the verbose log: 63 require audio environments/modules, two require opt-in Blender proof, and one concerns the unadopted rr-27 Tether study. The previously blocking tracked-sidecar guard, all four formerly failing native-frame/crop-plan tests, the Herald prior-byte guard and the new missing-adapter regression all pass in this actual full discovery. No staged-inventory substitute or test exclusion was used.

Commands:

```sh
python3 tools/godot_task_runner.py --task-id rr-40 --timeout 900 --stream -- godot --headless --path . --script tests/run_tests.gd
LABYRINTH_TASK_ID=rr-40 python3 -m unittest discover -s tests -p 'test_*.py' -v
```

## Matched headless perf comparison

Both full 18-case runs report `PERF03 FRAME RESULT: PASS (0 failures)` and final `orphan_nodes=0`. Default three passes, clocks, fixture seeds, 1920x1080, UI scale 1.0 and uncapped headless CPU sampling were retained. Base was an unchanged Git archive of `a5394dac9` runtime inputs under ignored `output/qa-04/rr40/base-a5394dac9`; no branch was changed. Runs were serial with no other worker-owned validations alongside them.

| Hover case | Budget max ms | Reviewer max / p95 ms | Base full max / p95 ms | Current full max / p95 ms |
|---|---:|---:|---:|---:|
| Ordinary | 5 | 5.652 / 0.377 | 5.462 / 0.369 | 5.527 / 0.371 |
| Air T2 | 8 | 9.695 / 0.627 | 8.939 / 0.534 | 8.557 / 0.541 |
| Lightning T3 | 8 | 8.404 / 0.390 | 7.971 / 0.396 | 8.195 / 0.394 |

Values follow the existing minimum-of-three-maxima selection rule. Thus the initial base run has **two** budget misses; current has **three**. To resolve lightning's near-threshold difference, an additional three-pass lightning-only comparison ran in reverse order: **current 7.984 / 0.390ms, budget PASS; base 8.264 / 0.395ms, budget FAIL**. Both repeats pass their functional checks with zero orphans. All three reviewer misses are therefore also observed on base on this machine, with lightning crossing the boundary across unchanged runs. No repeatable new rr-40 timing regression was established. The selected original lightning slow frames both have 14 draws; their inclusive hover-stage refresh work is 4.548ms base / 4.779ms current, with 0.379 / 0.369ms uncovered. This supports existing hover-work/timing variation, not a new constructor/reset path during measured hover. No budget, assertion or runtime tuning was altered. Budgets remain reported but unenforced for headless CPU evidence; this is not native performance acceptance.

Full data and exact commands: `/private/tmp/labyrinth_codex/rr-40-feedback1-perf-comparison.json`, with `rr-40-feedback1-perf-base.json`, `rr-40-feedback1-perf-current.json`, `rr-40-feedback1-perf-current-repeat.json`, `rr-40-feedback1-perf-base-repeat.json` beside it. Logs retain `PERF03 BUDGET RESULT: FAIL (2 misses)`, `FAIL (3 misses)`, `PASS (0 misses)`, `FAIL (1 misses)` respectively.

## Proof for the design owner

This sandbox has no window-server access; no windowed attempt was made. Both probes and their proof contracts are ready at 1920x1080, 100% UI scale:

```sh
python3 tools/visual_probe_runner.py --task-id rr-40 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 --expect-size 1920x1080 --proof-contract tests/rr40/prepared_canvas_proof_contract.json --result-manifest /private/tmp/labyrinth-inspection-manifests/rr-40-feedback1-prepared.json tests/prepared_unit_canvas_equivalence_test.gd
python3 tools/visual_probe_runner.py --task-id rr-40 --no-headless --display-driver macos --audio-driver Dummy --timeout 300 --expect-size 1920x1080 --proof-contract tests/rr40/gameplay_proof_contract.json --result-manifest /private/tmp/labyrinth-inspection-manifests/rr-40-feedback1-gameplay.json tests/frostglass_lancer_cutout_gameplay_probe.gd
```

Prepared capture: `user://prepared_unit_canvas.png`. Gameplay captures: `user://probes/frostglass_gameplay_v01/`, including contact, death, controller and pointer captures required by the contract. No native captures exist from this worker. No inspection-fixture command was requested in this unit; fixture preparation remains with the owner.

## TODO_DESIGN placeholders

None.

## Chosen defaults

All are test-only:

- `ACTOR_TYPES`: ten v2 figures plus Crawler and Harrier.
- `FIXTURE_GRID_SIZE=17`, `FIXTURE_CENTER=(8,8)` keep the expanded debug board in bounds.
- Preparation directions use the existing four cardinal offsets; `idle_first` exercises both adoption entry paths. Block phase remains 0.04; the requested regression phases are hit 0.12/death 0.5.
- `PROOF_PHASE=0.42` retains the old package probe sample.
- `FIXTURE_ACTION_LEAD_TICKS=1`, `FIXTURE_OTHER_DELAY_TICKS=1000`: schedule the selected debug activation immediately before the resolver's next player deadline and keep the second actor outside that interval.
- `FIXTURE_LUNGE_DISTANCE_TILES=4`: matches the existing rr-37 lunge proof distance.
- Package mutation: only a temporary project receives `extends Node`; production source is untouched.
- Owner probe timeouts remain 180s prepared / 300s gameplay; full Godot uses the workflow's 900s budget.

## Open issues

Native renderer proof remains for the design owner because this sandbox has no window-server access. The three headless hover timing misses also occur on the unchanged base, with lightning varying around its threshold; these existing timing-budget issues remain reported, not hidden or retuned. Nonfatal shutdown diagnostics are recorded above; the full Godot log already had ObjectDB warnings before this feedback. No functional-suite failures remain.

Final hygiene: `OUTPUT GDIGNORE: PASS (16 folders; 6 referenced roots)`; `git diff --check` passes. `git diff --quiet HEAD -- assets/units experiments/cutouts` returns 0: every asset and authoring case remains byte-unchanged. Branch/HEAD remain `codex/rr-40` / `20f9b2e06575ae74b11d6b8cae6e7ee9355e4b42`; all twelve changed files are uncommitted.
