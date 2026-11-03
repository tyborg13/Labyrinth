# pt14-01 — feedback 3 implementation handoff

Both remaining findings are addressed. All changes remain uncommitted on `codex/pt14-01`. No commit, publication, peer review, branch change, full suite or windowed run was performed.

## 1. Worker preparation and reveal readiness

`HeroRest.warm_loadout` now inspects cache identities and schedules work; it never constructs a rig or rasterizes. The existing owned `AssetLoader.prepare_cpu_value_for` path performs source JSON/mesh preparation, native PNG decoding, neutral pose projection, skinning, alpha composition, bitmap conversion and polygon extraction. The producer receives only private/read-only CPU data and images. It creates no Node or GPU object and does not touch the shared caches. Main-thread publication retains the board's existing `_unit_shadow_data_from_opaque_polygons` normalization.

The new `intent_chip_hero_recipe.gd` uses the production rest-pose sampler, source joint/mesh data, gear replacement operations and rigid attachment projection. Test-only original Node capture independently verifies twelve complete masks: the previous eight front/rear/loadout cases, plus both facings of a carried bow with armor/boot mesh replacements and a spear with shield/lantern. The prior eight-mask independent threshold oracle and float-boundary checks remain intact. Production uses approved art only. Raw PNG bytes are decoded natively through `FileAccess`, including PNG entries inside a PCK. When raw files are absent, the export-aware loader supplies CPU image snapshots on the main thread, one asset per presentation; the producer resumes on the worker.

The early empty-loadout asset job is removed. `GearBoard.sync` does not request neutral geometry when a newly attached board has no resolved equipment presentation. RunScene starts preparation immediately after resolving/repairing the run's equipment. Initial UI preparation awaits both facings, and the existing presentation-readiness contract also requires the current loadout to be ready before reveal. Pre-battle Begin awaits readiness before entering combat. The ordinary equip/loadout bridge dispatches asynchronously and keeps the opaque rest-rect fallback until completion. Existing fallback placement holds prevent completion alone from moving a badge.

Requests coalesce by resolved loadout/facing. First GPU publication of the same source art does not invalidate a warm entry; later source-art replacements still do. Cache identities retain loadout, facing, source revision, gear operations and part/overlay art identity. Layout remains lookup-only. The packed-rear and equipped rear shield/lantern regressions remain covered.

### Observed added main-thread maxima

`tests/pt14_01_preparation_check.gd` runs real menu transitions for New Run and Continue into a saved Air Warband, and invokes the normal Iron Cleaver equip callback. It clears the neutral caches for each transition, asserts exactly two resolved-loadout builds, zero empty-loadout builds, readiness before reveal and zero first-layout misses. Every recorded main-thread continuation, including dispatch/poll/join/publication, must remain below the director's 2 ms limit. Wait time is excluded.

```text
PT14 MAIN THREAD: new_run max=0.210 ms calls=19 builds=2
PT14 MAIN THREAD: equip max=0.398 ms calls=21 builds=4
PT14 MAIN THREAD: continue max=0.227 ms calls=24 builds=2
PT14 PREPARATION RESULT: PASS (19 assertions; 0 failures)
```

Equip's cumulative build count of four is the two ready New Run facings plus the two new equipped facings. These are maxima for added preparation/cache calls, not timings for the whole equipment UI callback, whole rendered frames, or native GPU rendering. The scene-level test emits the same ObjectDB teardown warning present in the director's supplied timing experiment; its assertions and process exit pass. The normal intent/HUD/hover runs do not report a script error.

## 2. Producer-thread regression

The raster producer returns `OS.get_thread_caller_id()` with its owned result. After the join, the main thread records that ID alongside the build count. The intent test checks every recorded producer against `OS.get_main_thread_id()`, including setup, loadout changes and a forced deferred layout miss.

The new `deferred_worker_inline` mutation replaces the dispatch inside `_deferred_build` with a synchronous `_produce_entry(...)`. It must fail the explicit assertion `Worker-thread mutation: every neutral raster producer runs off the main thread`. Removing warm-up must still fail first-layout/facing readiness assertions. The forced fallback still yields zero inline builds, identical layouts after completion, and releases its hold when placement inputs change.

```text
PT14 PREWARM: first_layout_misses=0 turned_layout_misses=0 event_layout_misses=0 inline_builds=0
PT14 DEFERRED FALLBACK: inline_builds=0 completed=true layout_unchanged=true hold_released=true
PT14 WORKER THREADS: builds=20 main_thread_builds=0
PT14 NATIVE ALPHA PARITY: 8 complete masks; float boundary probes match
```

## Focused checks and exact evidence

Run from this worktree. All Godot invocations used:

```sh
python3 tools/godot_task_runner.py --task-id pt14-01 --stream -- godot --headless --path . --script <script>
```

| Check | Observed result | Log |
| --- | --- | --- |
| `tests/pt14_01_preparation_check.gd` | `PT14 PREPARATION RESULT: PASS (19 assertions; 0 failures)` | `/private/tmp/pt14-01-feedback3-timing-final.log` |
| `tests/threats_at_rest_test.gd`, including intent/compass/source/runtime checks, 150-state sweep and live hand | `THREATS AT REST TEST RESULT: PASS (16446 assertions; includes compass suite)` | `/private/tmp/pt14-01-feedback3-intent-final.log` |
| `tests/board_status_plates_test.gd` | `BOARD STATUS PLATES TEST RESULT: PASS (33856 assertions; 0 failures)` | `/private/tmp/pt14-01-feedback3-hud-final.log` |
| `tests/perf/hover_equivalence_test.gd` | `PERF04 EQUIVALENCE RESULT: PASS (0 failures)` | `/private/tmp/pt14-01-feedback3-hover-final.log` |
| `python3 tests/test_pt14_01_coverage.py` | `PT14-01 MUTATION RESULT: PASS (11/11 killed; controls pass; production untouched)`; `Ran 2 tests in 205.072s` / `OK` | `/private/tmp/pt14-01-feedback3-python-final.log` |
| `python3 tests/test_ui_identity_lint.py` | `Ran 25 tests in 3.109s` / `OK` | `/private/tmp/pt14-01-feedback3-ui-final.log` |

The capture script was also parsed successfully with the Godot runner using `--headless --path . --check-only --script tests/intent_chip_placement_probe.gd` (exit 0; no capture attempted), log `/private/tmp/pt14-01-feedback3-probe-parse.log`. Its native preparation now awaits the current loadout before capture. The focused intent run exercises all new GDScript helpers. No new Python module was added; the existing `tools/python_suite_resources.json` entry `[]` remains accurate because mutation projects and pack files are confined to temporary projects and isolated runner HOMEs.

During development, the removed-warm-up mutation exposed an empty timing-array print in the test itself. That diagnostic now handles a genuinely absent producer, so the mutation fails its intended assertions without a script error. The aggregate mutation line also reports the actual killed count, including when a subtest fails. An additional PCK regression caught and removed an OS-globalized raw-resource path in the new decoder; raw packaged PNGs now decode through `FileAccess`.

## Layout and worker costs

Busiest decorated Air tier-3 Warband, six enemies, existing 12 warmups / 120 interleaved samples:

```text
INTENT CHIP LAYOUT COST: warband_air_3_crowd (6 enemies) median=4.537 ms p95=4.727 ms; before median=5.382 ms p95=5.599 ms
PT14 REST SILHOUETTE COST: first=1.613 ms median=0.269 ms p95=0.317 ms (cached shadow polygons and opaque prop rects; no live-frame readback)
PT14 VS PT13-02: median=4.537 ms p95=4.727 ms; pt13-02 median=4.187 ms p95=4.355 ms; recorded pt13-02=4.320/4.567 ms
PT14 NEUTRAL CACHE COST: worker=38.019 ms wait=49.900 ms dispatch=0.084 ms hit=0.010 ms
```

The existing current-layout budget guard passes against the matched `before` path. The pt13-02 comparison adds 0.350 ms median / 0.372 ms p95 on this run. The forced rear-art-identity miss is a single worker sample, not a percentile: 38.019 ms of producer work and 49.900 ms including presentation/poll waits. Neither duration runs as a main-thread build. Normal first-layout and facing-change misses remain zero.

[pt14_01_fixture_results.json](pt14_01_fixture_results.json) contains each board's mirror count and weighted coverage. All 150 sweep states and all 159 fixture checks retain zero coverage increases, 107 mirror chips, 49 counted fallbacks, weighted coverage 222482.520464 → 181249.774543, and maximum home distance 17.953527 px. The prepared-cache geometry results are unchanged from feedback 2. Historical ten-image headless preparation metadata remains explicitly labeled as revision `9eb80cf4b`; it is not current pixel proof. JSON paths remain portable.

## Files changed in this round

- `scripts/intent_chip_hero_rest.gd`: asynchronous cache requests, worker lifecycle, CPU image snapshots, stable art identities, thread/cost evidence and lookup-only layout.
- `scripts/intent_chip_hero_recipe.gd` (new): data-only neutral geometry/source-image preparation.
- `scripts/protagonist_cutout/gear_board.gd`: skip unresolved initial equipment; existing change event dispatches asynchronous preparation.
- `scripts/combat_board_view.gd`: remove the empty-loadout startup asset job.
- `scripts/run_scene.gd`: dispatch at resolved run load; await preparation at combat entry; include cache readiness in reveal contract.
- `scripts/run_initial_preparation.gd`: await the resolved loadout before initial UI/board refresh and reveal.
- `tests/pt14_01_preparation_check.gd` (new): real New Run/Continue/equip readiness and main-thread maxima.
- `tests/pt14_01_rig_oracle.gd` (new): independent original Node capture used only in tests.
- `tests/pt14_01_source_suite.gd`: asynchronous preparation, independent geometry parity, producer-thread assertions and raw-PCK regression.
- `tests/pt14_01_coverage_suite.gd`: move source tests into the existing asynchronous source/runtime entry point.
- `tests/intent_chip_placement_check.gd`, `tests/threats_at_rest_test.gd`: warm detached geometry fixtures through the worker before synchronous sweeps.
- `tests/intent_chip_placement_probe.gd`: await neutral readiness before native proof preparation.
- `tests/test_pt14_01_coverage.py`: synchronous-worker mutation, adapted warm-up mutation and accurate aggregate kill count.
- `tests/pt14_01_fixture_results.json`: current fixture and setup timing evidence with portable paths.
- `tests/pt14_01_implementation_report.md`: this handoff.

## Proof for the design owner

No PNG was captured and no windowed command was attempted. Exact existing native proof command:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/pt14-01 && sh tests/pt14_01_design_owner_proof.sh
```

The wrapper allocates a fresh manifest with `mktemp -d /private/tmp/pt14-01-native-proof.XXXXXX`, then runs:

```sh
python3 tools/visual_probe_runner.py tests/intent_chip_placement_probe.gd \
  --task-id pt14-01 --no-headless --display-driver macos --audio-driver Dummy \
  --timeout 180 --attempts 1 --min-images 10 --expect-size 1920x1080 \
  --proof-contract tests/pt14_01_placement_proof.json \
  --result-manifest "$manifest_dir/manifest.json"
```

Output remains under the isolated runner HOME's `user://probes/pt14-01/`, with owner, Air pre-battle/opening/mid-fight and Shadow Warband before/after `*_1920x1080.png` names, at 100% UI scale. No inspection-fixture command was requested for this feedback round.

## TODO_DESIGN, chosen defaults and open issues

No `TODO_DESIGN_*` or player-visible default was introduced. Art, chip/HUD appearance and placement tuning remain unchanged. Chosen test-only fields are `DEADLINE_MS=30000`, `SETTLE_FRAMES=4`, `CLEANUP_SECONDS=1.0`, and `PROJECTION_LOADOUTS` using approved bow/plate/boots and spear/shield/lantern combinations. `MAIN_CALL_BUDGET_USEC=2000` and Iron Cleaver are director-specified. `instrument_main_calls=false` is the internal opt-in timing flag. Previous proof-only defaults remain as recorded in the source suite.

The observed teardown warning above is reported without claiming a new renderer or full-suite proof. Both requested findings are fixed and the focused checks pass. `git diff --check` also passes. The director owns review, native inspection and publication.
