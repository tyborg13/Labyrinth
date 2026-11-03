# fix-18 — feedback 1

Implementation against reviewed HEAD `ebcb74843`, branch `codex/fix-18`.
All changes remain uncommitted. This round uses focused checks only, as the
director requested. The initial root-cause/path analysis remains in
[implementation_report.md](implementation_report.md); its old native commands
and unchanged-copy statements are historical and superseded below.

## 1. Draw-time allocations and HUD sort

`CombatBoardView._unit_center` now caches maquette centres in a shared table
borrowed by retained tile layers. A `Vector4` stores corrected xy and the
logical tile zw, so a warm lookup allocates neither a record nor an array.
The cache clears on presentation submission, asset preparation, board geometry
invalidation/population, and a renderer facing/reflection change. Comparing the
tile also rejects an in-place no-animation position change. Layout copying
shares the owner's table; it does not install an earlier layout's positions.

`MaquetteRenderer.borrow_canvas_geometry` resolves each concrete adapter's
immutable capacity once. The draw path borrows it; the public allocating
`canvas_geometry` API and protected adapter declarations are unchanged. HUD
sorting reads the centre already stored and refreshed in each retained HUD
entry instead of sampling the unit on every comparator invocation. Focus,
hero priority, y ordering, column and key tie-break rules are unchanged.

The unmodified review benchmark `/private/tmp/fix18-review/perf.py` completed
successfully (`/private/tmp/fix18-feedback1-perf-final.log`):

```text
current:        HUD 23.72 us/sort; 210 geometry lookups / 30 redraws
baseline:       HUD 27.47 us/sort; 210 geometry lookups / 30 redraws
current_repeat: HUD 23.95 us/sort; 210 geometry lookups / 30 redraws
```

The baseline restores the original HUD comparator as well as the original
origin functions and runtime sources; otherwise it would accidentally inherit
the new faster comparator. These committed original sources/functions are
hash-bound in `stale_path.json` and checked by the regression.

`performance.py` retains the review workload and median sampling and adds
counters at the allocating geometry declaration. It stages all source changes
in a temporary project and restores them between conditions. No production
or protected asset is temporarily edited. Observed command/result:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fix-18 && python3 tests/fix18/performance.py --output-dir /private/tmp/fix18-feedback1-performance
```

```text
current:        HUD 24.10 us/sort; 0 centre/HUD geometry allocations; 36 geometry allocations / 30 redraws
baseline:       HUD 22.31 us/sort; 0 centre/HUD geometry allocations; 186 geometry allocations / 30 redraws
current_repeat: HUD 19.18 us/sort; 0 centre/HUD geometry allocations; 36 geometry allocations / 30 redraws
FIX18 PERFORMANCE: PASS (zero added allocations/redraw; both HUD medians <= 110% of pre-fix)
```

The treatment ratios are 1.08023 and 0.85970. There are zero added geometry
allocations per redraw, and five fewer than before the fix; the remaining
36 allocations over 30 frames are the existing live pose/socket path.
Logs and machine-readable summary: `/private/tmp/fix18-feedback1-performance/`;
combined log: `/private/tmp/fix18-feedback1-performance.log`. Headless redraw
work is exercised; `Engine.get_frames_drawn()` is zero and no native frame is
claimed by this benchmark.

## 2. Exact travel anchoring and mutations

`travel_guard.gd` constructs its expected padded rect independently of both
methods under test. It uses the authored texture origin, the renderer's
geometry declaration and the source rect, then rounds the expected padded
origin. It reads the retained tile's actual draw unit and actual texture rect,
and requires exact position and size within 0.001 px. The retained body's
centre and HUD entry must both equal the raw body centre plus that same
correction. Each sample must have a nonzero correction, so disabling it cannot
escape through a whole-pixel fixture. It also checks the renderer snapshot is
presenting the requested clip and phase.

Samples use the production `Action.movement_frame` at phase 0.37 in two
facings, and the real contact-action lunge submission at half its authored
contact phase. The lunge's authored travel stays inside the rig; the test does
not add a whole-texture translation. A separate warmed-cache check changes
the actor's tile without a new submission.

The Python regression temporarily mutates copied scripts only. Both review
mutations must fail with the specific retained-renderer anchoring assertion,
without script errors. The old hash-bound stale-path control still must fail
for all four actors after Continue. Observed focused result (exit 0),
`/private/tmp/fix18-feedback1-regression.log`:

```text
Ran 5 tests in 59.086s
OK
FIX18 TRAVEL MUTATION: PASS (ignored_authored_origin rejected by retained-renderer oracle)
FIX18 TRAVEL MUTATION: PASS (disabled_center_correction rejected by retained-renderer oracle)
FIX18 STALE SOURCE MUTATION: PASS (all four Continue floor-containment failures observed)
```

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fix-18 && python3 -m unittest tests.test_fix18_draw_origin -v
```

The fixed entry-path runs also exited 0. Combined log:
`/private/tmp/fix18-feedback1-entries.log`. Per-entry logs:
`/private/tmp/fix18-feedback1-entry-{pre_battle,warband,snare}.log`.
Validate-only entry runs emit geometry in the logs; they do not save PNGs or manifests.

```text
pre_battle: FIX18 DRAW ORIGIN: PASS (20 actor checks; 0 failures)
warband:    FIX18 DRAW ORIGIN: PASS (45 actor checks; 0 failures)
snare:      FIX18 DRAW ORIGIN: PASS (25 actor checks; 0 failures)
FIX18 TRAVEL: sampled move in two facings and authored lunge
REAL FIGHT CAPTURE VALIDATION: PASS
```

The stale-path entry control still observes all four rigs failing in Warband,
Snare, resize/restore and no-animation moves; fresh Begin has no persistent
containment failure. Hero behavior and the original affected-path conclusions
are unchanged.

## 3. Director-authorized logical frame size

Only the fix-18 probe copy and its contracts implement the changed frame rule.
The source probe on `codex/pt14-03` is untouched. The copy still reads
`root.get_texture().get_image()` through the real MainMenu Continue path;
there is no new SubViewport, camera override or render rerouting. A source
guard compares every method outside the four frame-size/manifest methods to
the SHA-bound original copy; the one new method validates saved dimensions.

A saved full frame must exactly equal the logical window size and be at least
1600×900. UI scale remains 1.0; each collection checks content scale factor
1.0. Schema-4 manifests record requested size, actual window logical size,
saved frame size and the policy. Each resize stage records its own actual
size. Crops retain their approved actor-relative dimensions. Contracts require
a 1600×900 region and retain the runner's existing image-content checks;
the probe enforces saved/logical equality for every full-frame readback.

Headless checks accept 1600×900 and 1920×1080, reject smaller width/height and
saved/logical mismatches. The standard visual runner validator was also run
on the director's existing images, without altering them or claiming they
were captured on this revision. `/private/tmp/fix18-feedback1-frame-contract.log`:

```text
FIX18 FRAME CONTRACT: PASS mirror-separated [(1600, 900), (528, 528), (528, 528)]
FIX18 FRAME CONTRACT: PASS seer-natural [(1600, 900)]
FIX18 FRAME CONTRACT: PASS seer-separated-resize-diagnostic [(1600, 900), (1600, 900), (1920, 1080)]
FIX18 FRAME CONTRACT: PASS (undersized saved image rejected)
```

All seven supplied director images were inspected: Mirror's full frame and
two crops, natural Seers, and the three separated Seer resize stages.

## Preservation checks

All requested focused checks completed with exit 0. No full suite was run.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fix-18 && LABYRINTH_TASK_ID=fix-18 LABYRINTH_SWEEP_WORKERS=4 python3 -m unittest tests.test_native_frames tests.test_production_crop_plan tests.test_rr10_humanoid tests.test_rr12_delivery tests.test_rr17_cutout tests.test_rr20_cutout tests.test_rr21_cutout tests.test_rr22_humanoid tests.test_rr29_mimic tests.test_rr32_herald tests.test_rr35_cutout tests.test_rr37_lancer tests.test_rr37_production tests.test_rr40_feedback -v
cd /Users/borgerding/workspace/Labyrinth.worktrees/fix-18 && python3 tools/godot_task_runner.py --task-id fix-18 --timeout 180 --stream -- godot --headless --path . --script tests/prepared_unit_canvas_equivalence_test.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/fix-18 && python3 tools/godot_task_runner.py --task-id fix-18 --stream -- godot --headless --path . --script tests/maquette_cutout_test.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/fix-18 && LABYRINTH_TASK_ID=fix-18 LABYRINTH_SWEEP_WORKERS=4 python3 -m unittest tests.test_rr41_feedback3.WalkingTests.test_rest_and_density_evidence_reseal_to_identical_bytes -v
```

Exact result lines:

```text
/private/tmp/fix18-feedback1-references.log:
Ran 184 tests in 397.736s
OK
MAQUETTE PRODUCTION LOGIC: PASS (1634 frames)
MAQUETTE PRODUCTION LOGIC: PASS (1634 frames)

/private/tmp/fix18-feedback1-rr40.log:
V2 BOARD SPRITE GEOMETRY: {"cases":88,"errors":[],"native":false,"orientation_mutations_rejected":0,"placement_mutations_rejected":0}
PREPARED UNIT CANVAS RESULT: {"cases":64,"checks":4864,"errors":[],"native":false,"orphans":0,"pixel_differences":[]}

/private/tmp/fix18-feedback1-maquette.log:
MAQUETTE CUTOUT: PASS (40178 checks, 0 failures; headless logic only)

/private/tmp/fix18-feedback1-rest-seal.log:
Ran 1 test in 15.966s
OK
RR41 REST/DENSITY RESEAL: PASS (fresh poses byte-identical after pinned fix-18 source bindings; density evidence unchanged)
```

After simplifying the pure probe-guard test's method extraction, its focused
rerun also passed: `Ran 1 test in 0.012s`, `OK`
(`/private/tmp/fix18-feedback1-probe-guard.log`). No runtime, probe or assertion
changed after the successful checks above.

The rest-byte provenance adapter now permits the third explicitly hash-bound
runtime source (`renderer.gd`) in addition to the initial two. It still must
recover the complete original pose JSON hash, including every pose/scale,
protected input and serialized byte; no approved rest reports/art were edited.
The fixture pins the original renderer too. Unapproved inputs, altered poses
and unexpected source hashes remain rejected.

Import through the task runner exited 0; it generated only the new
`travel_guard.gd.uid`. No editor scan was used as a parser check; actual
headless executions above passed. Isolation audit exited 0:
`ISOLATION AUDIT: 225 modules; /private/tmp/fix18-feedback1-audit/isolation-audit.md`.
Final registration audit exited 0 (`/private/tmp/fix18-feedback1-registration-final.log`):
`TEST REGISTRATION AUDIT: PASS (869 scripts; full suite=508, quarantined=29, windowed probe=332)`.
Final `git diff --check` and `git diff --quiet HEAD -- assets experiments spec/assets`
both exited 0; branch/HEAD remain `codex/fix-18` / `ebcb74843`.
The Python module retains its audited temp-only resource declaration `[]`;
the benchmark helper writes only its explicit output directory and temp project.

## Files changed in this feedback round

- `scripts/combat_board_view.gd`: shared/invalidation-aware maquette centre cache,
  borrowed geometry and sorting through retained HUD centres.
- `scripts/maquette_cutout_runtime/renderer.gd`: immutable geometry borrow and
  facing/reflection cache invalidation.
- `tests/fix18/draw_origin_test.gd`, new `travel_guard.gd`/`.uid`: exact travel,
  retained body/HUD and frame-policy checks.
- `tests/test_fix18_draw_origin.py`: the two requested failing mutations and
  the approved probe-fork source guard.
- `tests/fix18/performance.py`: review benchmark with allocation/time gates.
- `tests/fix18/stale_path.json`, `rest_binding_changes.json`,
  `rest_provenance.py`: extend original baseline/provenance to the cache source.
- `tests/fix18/real_fight_capture_probe.gd`, its two contracts: authorized
  logical-window sizing and actual-size manifest fields.
- `tests/test_rr41_feedback3.py`: update the explanatory provenance comment; all assertions unchanged.
- `tests/windowed_test_allowlist.json`: correct the copy's description to fork;
  no registration or execution behavior changed.
- `tests/fix18/implementation_report.md`: mark the original report historical.
- This feedback report.

## Proof for the design owner

No windowed run was attempted: this sandbox has no macOS window-server access.
These are the four replacement native commands. They request 1920×1080 and
100% UI scale through the probe, accepting the actual logical window at a
minimum 1600×900. No `--expect-size` option overrides the new contract. Use
fresh directories; existing evidence is never overwritten.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fix-18 && LABYRINTH_REAL_FIGHT_CAPTURE_OUTPUT=/private/tmp/fix18-feedback1-native/mirror-separated python3 tools/visual_probe_runner.py --task-id fix-18 --no-headless --display-driver macos --audio-driver Dummy --min-images 1 --proof-contract tests/fix18/real_fight_capture_probe_contract.json --result-manifest /private/tmp/fix18-feedback1-native/mirror-separated/runner.json tests/fix18/real_fight_capture_probe.gd -- --label mirror-separated --player-position 4:4 --biome iskaldra --seed 7262026 --enemy-types glacial_mirror,glacial_mirror --enemy-positions 4:2,4:6 --crop enemy_1:3 --crop enemy_2:3

cd /Users/borgerding/workspace/Labyrinth.worktrees/fix-18 && LABYRINTH_REAL_FIGHT_CAPTURE_OUTPUT=/private/tmp/fix18-feedback1-native/seer-separated python3 tools/visual_probe_runner.py --task-id fix-18 --no-headless --display-driver macos --audio-driver Dummy --min-images 1 --proof-contract tests/fix18/real_fight_capture_probe_contract.json --result-manifest /private/tmp/fix18-feedback1-native/seer-separated/runner.json tests/fix18/real_fight_capture_probe.gd -- --label seer-separated --player-position 4:4 --biome iskaldra --seed 7262026 --enemy-types hoarfrost_seer,hoarfrost_seer --enemy-positions 4:2,4:6 --crop enemy_1:3 --crop enemy_2:3

cd /Users/borgerding/workspace/Labyrinth.worktrees/fix-18 && LABYRINTH_REAL_FIGHT_CAPTURE_OUTPUT=/private/tmp/fix18-feedback1-native/seer-natural python3 tools/visual_probe_runner.py --task-id fix-18 --no-headless --display-driver macos --audio-driver Dummy --min-images 1 --proof-contract tests/fix18/real_fight_capture_probe_contract.json --result-manifest /private/tmp/fix18-feedback1-native/seer-natural/runner.json tests/fix18/real_fight_capture_probe.gd -- --label seer-natural --biome iskaldra --seed 7262026 --enemy-types hoarfrost_seer,hoarfrost_seer

cd /Users/borgerding/workspace/Labyrinth.worktrees/fix-18 && LABYRINTH_REAL_FIGHT_CAPTURE_OUTPUT=/private/tmp/fix18-feedback1-native/seer-separated-resize-diagnostic python3 tools/visual_probe_runner.py --task-id fix-18 --no-headless --display-driver macos --audio-driver Dummy --min-images 3 --proof-contract tests/fix18/resize_contract.json --result-manifest /private/tmp/fix18-feedback1-native/seer-separated-resize-diagnostic/runner.json tests/fix18/real_fight_capture_probe.gd -- --label seer-separated-resize-diagnostic --player-position 4:4 --biome iskaldra --seed 7262026 --enemy-types hoarfrost_seer,hoarfrost_seer --enemy-positions 4:2,4:6 --resize-diagnostic
```

Each directory receives `<label>.png`, `<label>.json`, and `runner.json`.
The first two also receive actor crops; resize additionally receives
`<label>_resized.png` and `<label>_restored.png`. Inspect recorded logical and
saved sizes at each stage. These paths are pending director capture, not
worker-generated native evidence.

The initial brief's separate interactive wrapper check is unchanged:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fix-18 && python3 tools/inspection_fixture.py --task-id fix-18 --run-id fix18-feedback1-inspection --scenario combat --seed 7262026 --enemy-types hoarfrost_seer,hoarfrost_seer --player-position 4:4 --enemy-positions 4:2,4:6 --biome iskaldra --launch
```

Press Continue in MainMenu. The worker did not launch it, prepare/publish an
inspection fixture, request sign-off or run peer review.

## TODO_DESIGN placeholders and chosen defaults

TODO_DESIGN: none. No player-facing defaults chosen.
New test-only named values: travel sample phase 0.37 and tolerance 0.001 px;
lunge sample derives from half the protected contact phase. Frame minimum
1600×900 is the director's decision. Benchmark roster, seed 83, warmup,
seven median batches, 400 centre iterations, 100 sort iterations and 30
redraws are copied from the review benchmark. Evidence directory names and
counter names are test-only. Existing resize/layout/entry fixtures retain
their initial named values; the old synthetic travel offset was removed.

## Open issues

Native reruns of the revised copy remain for the director. Full suites are
intentionally not run in this round; the director runs them at merge. No
commits, branch changes, publication or queue edits were performed.
