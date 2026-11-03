# pt14-04 implementation handoff

## Feedback 1 — fixes on 8b1f59d8a (uncommitted)

1. Generated all 11 missing `.gd.uid` files through the task-local `godot --headless --path . --import` command. They are present beside their scripts. The tracked-sidecar guard still fails solely because this sandbox cannot stage them: `git add` fails with `fatal: Unable to create '/Users/borgerding/workspace/Labyrinth/.git/worktrees/pt14-04/index.lock': Operation not permitted`. A read-only prospective-inventory invocation of the unchanged guard passes when these 11 actual files are included. No alternate index or Git metadata was created.
2. Added projected-bounds assertions and an 8×8 grid of reflected query comparisons for both hero facings. The whole projected silhouette is queried and checked against independently computed opaque area minus transparent holes. The offline coverage check now queries both real dilated shapes as well. Both `mirrored_bounds` and `hole_subtraction` are retained in `tests/test_pt14_01_coverage.py`; they fail assertion checks without script errors.
3. Removed the trailing blank lines from `tests/pt14_01_before_badges.gd` and `tools/hero_rest_coverage_raster.gd`. Regenerated `hero_rest_coverage.tres` because it fingerprints the rasterizer; only that source hash changed, with identical polygons. `git diff --check codex/peer-benchmark` passes for the cumulative candidate. `git diff --check codex/peer-benchmark...HEAD` necessarily still reports the old committed blank lines until the design owner commits these uncommitted fixes.

Changed files this round: the two GDScript test suites, the existing Python mutation runner, the two whitespace-only scripts, the generated resource's rasterizer hash, this handoff and the 11 UID files listed below. No runtime layout code or visual assets changed. No new Python test module was added; the existing temporary-only resource registration remains valid.

```text
scripts/intent_chip_hero_coverage_resource.gd.uid
scripts/intent_chip_hero_rest.gd.uid
tests/pt14_01_before_badges.gd.uid
tests/pt14_01_coverage_suite.gd.uid
tests/pt14_01_preparation_check.gd.uid
tests/pt14_01_source_suite.gd.uid
tests/pt14_04_coverage_check.gd.uid
tests/pt14_04_runtime_check.gd.uid
tests/pt14_04_runtime_counters.gd.uid
tools/generate_hero_rest_coverage.gd.uid
tools/hero_rest_coverage_raster.gd.uid
```

The blocked staging command, for the design owner to run from this worktree:

```sh
git add -- scripts/intent_chip_hero_*.gd.uid tests/pt14_01_*.gd.uid tests/pt14_04_*.gd.uid tools/generate_hero_rest_coverage.gd.uid tools/hero_rest_coverage_raster.gd.uid
python3 tests/test_godot_sidecars.py
```

Focused checks for feedback 1:

| Check | Result | Log |
| --- | --- | --- |
| Task-runner `godot --headless --path . --import` (completion, `--timeout 1200`) | exit 0; all 11 UID files generated | `/private/tmp/pt14-04-feedback1-import-complete.log` |
| `python3 tests/test_pt14_01_coverage.py` | `PT14-01 MUTATION RESULT: PASS (10/10 killed; controls pass; production untouched)`; `Ran 2 tests in 220.776s` / `OK` | `/private/tmp/pt14-04-feedback1-mutations.log` |
| `tests/threats_at_rest_test.gd` through task runner, isolated after import | `THREATS AT REST TEST RESULT: PASS (16560 assertions; includes compass suite)` | `/private/tmp/pt14-04-feedback1-intent-final.log` |
| `tests/pt14_04_coverage_check.gd` through task runner | `PT14-04 COVERAGE RESULT: PASS (14 assertions; 0 failures)` | `/private/tmp/pt14-04-feedback1-geometry.log` |
| `tests/intent_chip_placement_check.gd -- --mutation-only` through task runner | `INTENT CHIP PLACEMENT RESULT: PASS (296 assertions; 0 failures)` | `/private/tmp/pt14-04-feedback1-placement-control.log` |
| Selected freshness, staleness-mutation and offline-parity/dilation checks in `test_pt14_04_coverage.py` | `Ran 3 tests in 4.458s` / `OK`; 66 exact source hashes fresh | `/private/tmp/pt14-04-feedback1-static-tests.log` |
| `python3 tests/test_godot_sidecars.py` | `Ran 19 tests in 7.181s` / `FAILED (failures=1)` — only 11 untracked UIDs | `/private/tmp/pt14-04-feedback1-sidecars.log` |
| Prospective sidecar inventory, using the unchanged guard plus the 11 generated files | `GODOT SIDECARS PROSPECTIVE INVENTORY: PASS (11 generated UID files awaiting staging)` | `/private/tmp/pt14-04-feedback1-sidecar-inventory.log` |

The first import timed out after 300 seconds while processing 12,167 assets, after generating all 11 sidecars. The completion run passed with exit 0 using a 1200-second timeout sized for that observed workload (7,882 remaining import steps). The first focused intent run had one p95 timing failure during the import (`10.441/20.962 ms` candidate versus `12.012/19.660 ms` matched baseline); all functional assertions passed. Its log remains `/private/tmp/pt14-04-feedback1-intent.log`; the timing assertion is unchanged and the final invocation passed all 16,560 assertions, including the unchanged timing gate, without concurrent engine work after the import (`/private/tmp/pt14-04-feedback1-intent-final.log`).

Chosen test-only defaults: `REFLECTION_QUERY_GRID=8`, `COVERAGE_AREA_EPSILON=0.05` weighted square pixels (allows floating-coordinate clipping error and remains below the real holes' contribution), and `COVERAGE_QUERY_PADDING=1.0` pixel. Tool-only completion import timeout: 1200 seconds for the observed 12,167-asset workload. No `TODO_DESIGN_*` placeholders. No windowed probe, review, commit or publication was performed in this round. The original native proof command below remains available.

## Original implementation handoff

All changes are uncommitted on `codex/pt14-04`. No commit, review, signoff, queue mutation, publication or windowed run was performed. The design owner owns those steps.

## Acceptance criteria

1. **Offline rest coverage:** `tools/generate_hero_rest_coverage.gd` loads the production front/rear rigs, clears equipment and poses `rest` at phase zero. `tools/hero_rest_coverage_raster.gd` composites their sprites and skinned meshes on the existing rig canvas. It uses the board shadow alpha threshold, simplification, retry and minimum polygon area. `assets/generated/hero_rest_coverage.tres` contains the two opaque contours in logical coordinates and SHA256 fingerprints for 66 inputs, including the loaded art, both layout JSONs, rig implementation and extraction code. Freshness checks also audit the exact source inventory, so dropping an input does not bypass staleness. The `.tres` is preloaded as a normal resource and follows Godot's export dependency graph without changing export filters.
2. **Runtime coverage:** the stored contours receive the specified 6 logical px native round dilation once per facing. Coordinate transformation preserves existing facing, mirroring and board registration. Transparent holes returned by dilation are subtracted from coverage. Runtime has no rig/recipe/image dependencies, rasterizer, worker, deferred request, warm-up, readiness gate or loadout identity/cache. Layout is independent of gear and animation in both facings and both mirrors.
3. **Removal and exact reverts:** `intent_chip_hero_recipe.gd` and the exceptional deferred-build placement hold (`intent_chip_fallback.gd`) are removed. All four integration files (`run_scene.gd`, `run_initial_preparation.gd`, `protagonist_cutout/gear_board.gd`, `combat_board_view.gd`) are byte-identical to `codex/peer-benchmark`; no exception was required. Old worker projection/threshold test helpers and their worker/warm-up/fallback mutations are removed.
4. **Preserved placement:** hero/unit/prop weights remain 2.0/1.0/0.5; margin remains 15%; export-aware rear loading for other units, HUD reservations, 24 px preferred-side slide and chosen-home `above_everything` fallback remain unchanged. Owner-left, mirror-covered, near-tie, HUD-conflict, hero-weight and animation assertions remain active. The retained mutation runner additionally tests ignoring the static hero.

## Instrumentation and timing

`tests/test_pt14_04_coverage.py` copies scripts to unique temporary projects and installs bounded counters around hero polygon initialization, hero coordinate transformation and hero coverage intersection. Hooks instrument actual rig construction, source-image decoding/readback and worker dispatch; ordinary renderer asset work outside hero coverage is excluded. The same real New Run / Continue / Iron Cleaver equip script runs against the candidate and `codex/peer-benchmark` implementation. These are attributed main-thread call maxima, not total scene transition durations or rendered frame timings.

```text
CANDIDATE PT14 MAIN THREAD: initialization max=0.229 ms calls=2 events={ "rig": 0, "image": 0, "thread": 0 }
CANDIDATE PT14 MAIN THREAD: new_run max=0.000 ms calls=0 events={ "rig": 0, "image": 0, "thread": 0 }
CANDIDATE PT14 MAIN THREAD: equip max=0.000 ms calls=0 events={ "rig": 0, "image": 0, "thread": 0 }
CANDIDATE PT14 MAIN THREAD: continue max=0.042 ms calls=2 events={ "rig": 0, "image": 0, "thread": 0 }
BASELINE: all four contexts max=0.000 ms calls=0; all events zero
PT14-04 MAIN THREAD RESULT: PASS (New Run/Continue/equip added <= 0.5 ms)
```

Real setup and equip do not dispatch coverage work. The detached board regression also explicitly exercises combat asset setup, first layout, facing/reflection changes and four loadouts. Mutations that instantiate a rig, read an image or start a thread in hero layout are each killed by the counters. Counter state is test-only and bounded; production has no diagnostics arrays.

## Focused verification

All Godot commands use `python3 tools/godot_task_runner.py --task-id pt14-04 --stream -- godot --headless --path . --script <script>`. Full Godot and Python suites were not run, as directed.

| Check | Observed result | Log |
| --- | --- | --- |
| `python3 tests/test_pt14_04_coverage.py` | `Ran 6 tests in 151.596s` / `OK`; exact 66-source staleness inventory; recorded-hash/art/layout mutations killed; dilation mutation killed; 3/3 zero-runtime mutations killed | `/private/tmp/pt14-04-python.log` |
| `python3 tests/test_pt14_01_coverage.py` | `PT14-01 MUTATION RESULT: PASS (8/8 killed; controls pass; production untouched)`; `Ran 2 tests in 194.201s` / `OK` | `/private/tmp/pt14-04-placement-mutations-final.log` |
| `tests/intent_chip_placement_check.gd -- --mutation-only` | `INTENT CHIP PLACEMENT RESULT: PASS (158 assertions; 0 failures)` | runner HOME `/private/tmp/labyrinth-godot-home/pt14-04-1793121502926601000-57571/godot.log` |
| `tests/threats_at_rest_test.gd` | `THREATS AT REST TEST RESULT: PASS (16422 assertions; includes compass suite)` | `/private/tmp/pt14-04-intent.log` |
| `tests/board_status_plates_test.gd` | `BOARD STATUS PLATES TEST RESULT: PASS (33856 assertions; 0 failures)` | `/private/tmp/pt14-04-hud.log` |
| `tests/perf/hover_equivalence_test.gd` | `PERF04 EQUIVALENCE RESULT: PASS (0 failures)` | `/private/tmp/pt14-04-hover.log` |
| `python3 tests/test_ui_identity_lint.py` | `Ran 25 tests in 8.137s` / `OK` | observed tool result |
| `python3 tools/run_python_suite.py --shards 4 --audit-only --output-dir /private/tmp/pt14-04-python-audit` | exit 0; `ISOLATION AUDIT: 226 modules` | `/private/tmp/pt14-04-python-audit/isolation-audit.md` |
| Godot `--check-only --script tests/intent_chip_placement_probe.gd` | exit 0; parser check only | `/private/tmp/pt14-04-probe-parse.log` |
| `sh -n tests/pt14_01_design_owner_proof.sh` | exit 0 | observed tool result |
| `git diff --check` | exit 0 | observed tool result |

The headless engine emits the macOS CA-certificate `ret != noErr` message in both candidate and baseline runs. Headless results do not constitute renderer proof. No assertion was changed to hide a baseline failure. During development, the animated-bounds mutation reached the new static-polygon check without polygons and caused a test script error. That check now asserts the missing data instead of indexing it; the existing animation-determinism assertion remains unchanged and still catches the mutant. The final complete retained-mutation run passes all 8/8 kills, with passing control and restored runs and no script errors.

## Placement and cost evidence

The 150-state sweep and live/owner fixtures retain the exact 24 px bound, HUD rules and nonincreasing weighted coverage. The per-board mirror counts and before/after weighted coverage are in `/private/tmp/pt14-04-intent.log`.

```text
INTENT CHIP LAYOUT COST: warband_air_3_crowd (6 enemies) median=8.860 ms p95=10.794 ms; before median=10.150 ms p95=11.738 ms
PT14 REST SILHOUETTE COST: first=2.906 ms median=0.472 ms p95=1.164 ms (cached shadow polygons and opaque prop rects; no live-frame readback)
PT14 VS PT13-02: median=8.860 ms p95=10.794 ms; pt13-02 median=7.934 ms p95=9.773 ms; recorded pt13-02=4.320/4.567 ms
INTENT CHIP SWEEP: 150 fixtures; maximum distance 17.954 px
```

Across all 159 emitted fixture reports: 115 mirror chips, maximum distance 17.953527 px, weighted coverage 195784.527578 → 152596.344207; zero fixture coverage increases. The current-layout budget assertion passes against the matched existing `before` implementation.

## Files changed

- Added generated data: `assets/generated/hero_rest_coverage.tres`.
- Added runtime data schema: `scripts/intent_chip_hero_coverage_resource.gd`.
- Changed runtime: `scripts/intent_chip_hero_rest.gd`, `scripts/intent_chip_placement.gd`, `scripts/intent_badges.gd`.
- Deleted runtime: `scripts/intent_chip_hero_recipe.gd`, `scripts/intent_chip_fallback.gd`.
- Reverted exactly to the peer baseline: `scripts/run_scene.gd`, `scripts/run_initial_preparation.gd`, `scripts/protagonist_cutout/gear_board.gd`, `scripts/combat_board_view.gd`.
- Added offline tools: `tools/generate_hero_rest_coverage.gd`, `tools/hero_rest_coverage_raster.gd`.
- Changed existing tests/proof: `tests/pt14_01_source_suite.gd`, `tests/pt14_01_preparation_check.gd`, `tests/test_pt14_01_coverage.py`, `tests/intent_chip_placement_probe.gd`, `tests/pt14_01_design_owner_proof.sh`.
- Deleted superseded test helpers: `tests/pt14_01_rig_oracle.gd`, `tests/pt14_01_legacy_threshold.gd`.
- Added focused tests: `tests/test_pt14_04_coverage.py`, `tests/pt14_04_coverage_check.gd`, `tests/pt14_04_runtime_check.gd`, `tests/pt14_04_runtime_counters.gd`.
- Updated Python registration: `tools/python_suite_resources.json` (`test_pt14_04_coverage: []`, audited temporary-only writes).
- Added this handoff: `tests/pt14_04_implementation_report.md`.

Regenerate after changing any recorded source:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/pt14-04 && python3 tools/godot_task_runner.py --task-id pt14-04 --stream -- godot --headless --path . --script tools/generate_hero_rest_coverage.gd
```

## Proof for the design owner

No PNG was captured and no windowed run was attempted: this worker has no window-server access. Exact requested command:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/pt14-04 && sh tests/pt14_01_design_owner_proof.sh
```

The wrapper creates a fresh `/private/tmp/pt14-04-native-proof.XXXXXX/manifest.json` and invokes:

```sh
python3 tools/visual_probe_runner.py tests/intent_chip_placement_probe.gd \
  --task-id pt14-04 --no-headless --display-driver macos --audio-driver Dummy \
  --timeout 180 --attempts 1 --min-images 10 --expect-size 1920x1080 \
  --proof-contract tests/pt14_01_placement_proof.json \
  --result-manifest "$manifest_dir/manifest.json"
```

Capture output is the isolated runner HOME's `user://probes/pt14-04/`, with before/after pairs for owner, Air pre-battle/opening/mid-fight and Shadow Warband (`*_1920x1080.png`), at 100% UI scale. Its existing proof contract remains in place. No `inspection_fixture.py` command was requested; the design owner prepares the inspection fixture.

## TODO_DESIGN, chosen defaults and open issues

No `TODO_DESIGN_*` placeholder or new player-visible default was needed. No art, icon, font or audio was created or changed. The raw approved front/rear assembled-rest references were inspected.

Chosen implementation defaults: normal preloaded `.tres` data format and bounded, opt-in private-copy test counters. Test-only defaults retained from pt14-01: `SETTLE_FRAMES=4`, `CLEANUP_SECONDS=1.0`, Iron Cleaver equip fixture and the four existing gear cases. The 500 microsecond budget and 6 logical px dilation are specified by the brief. The new storage/log namespaces use `pt14_04`/`pt14-04`; all mutation projects use unique temporary directories. There are no new proof-camera or layout values.

Open work for the design owner: native capture inspection, its independent visual judgment, commit, peer review and publication. These are intentionally outside this worker's authorization.
