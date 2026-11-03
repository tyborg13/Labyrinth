# rr-49 implementation and validation

Base: `5ec882b011b00acbb7fcdaf7639245e19eb1a0c1`, branch `codex/rr-49`.
All work remains uncommitted. The design owner owns commit, peer review,
inspection and publication. No windowed command has been attempted.

## Acceptance and evidence boundaries

1. **Final rr-44 findings reproduced before the fix.** The original native
   archive, production proof case, sheets diagnostic, both gate reports and
   `/private/tmp/labyrinth_codex/rr44-proof-*.log` were copied into
   `proof/baseline/`. Its `manifest.json` hashes 101,206 preserved files.
   `fixtures/native_final_rr44/` is the small, hash-bound regression input:
   source archive, all 892 presented poses, every failed isolated source layer,
   and all failed idle groups/rests. Its manifest SHA256 is
   `b623f59da8e6507ee68f44bd828d37fdb36049442d7f6418f683f056981dcf68`.

   `rr49_calibration.py` reproduces exactly 52 archived findings: 24 source
   RGBA failures, 24 idle failures, and 4 released-chain failures. The brief's
   22-source summary omits rear move 38 `coat_far` and move 40 `leg_near`;
   both are included. Idle is independently CPU-rendered, reproducing the
   native counts exactly. Source/release calibration feeds immutable native
   isolated pixels into the exact-source CPU oracle. This replay is **not** a
   claim that a legacy CPU-only raster predicts those 28 native observations.
   Current-frame coverage additionally checks the actual submitted geometry,
   exact-source release, all rigid idle groups and the existing complete sweep.

2. **Root corrections.** Paint, source crops, meshes/UVs/weights, motion keys,
   pivots, release times and every gate tolerance are unchanged.

   - **Source texels/coverage:** native and sampled node matrices agree, but
     the former GPU geometry path and CPU source oracle used different numeric
     paths. The old mesh renderer packs/normalizes skin weights and blends
     transforms in float32; the oracle also had a float64 sprite-quad path.
     A differing fixed-subpixel vertex changes triangle edge coverage or source
     UV selection. Front guard 12 has native transparency at `(366,278)` where
     all old legal candidates are opaque; the two rear-walk failures select a
     different source colour. Released rear death 75 changes one quad vertex
     when float32 placement replaces float64 placement. These are geometry /
     sampling failures, not requests for new paint.

     Optional `stable_source_raster` submits the original source triangles and
     UVs after explicit source-space skinning and snapping to the **existing
     1/256-pixel raster lattice**. It avoids GPU weight repacking and native
     reconstruction of rotated sprite quads. Original Sprite2D names, textures,
     transforms and input paths remain authoritative; a child Polygon2D submits
     their exact source quad. Python independently computes the vertex buffers.
     Bone/grip/oracle gates remain independent and unchanged.

     The old numeric path is documented in [Godot's skeleton shader](https://github.com/godotengine/godot/blob/4.6-stable/servers/rendering/renderer_rd/shaders/skeleton.glsl).
     Fresh native proof is still required to confirm every original failure is
     absent with the new submission path.

   - **Idle:** caps cross idle-group boundaries. A cap assigned to the stationary
     weapon group blended the bobbing torso, and the torso cap blended an arm
     belonging to another group. Native and CPU expose exactly front 10/9 and
     rear 6/14 changed pixels during frames 6–11. Rest/idle mesh submission now
     uses the original source vertices and its owning group's integer offset.
     The CPU sweep compares isolated RGBA of all three groups on every idle
     frame; bone offsets alone no longer establish pixel rigidity.

   - **Released chain:** source-space rigid quad submission retains the full
     sampled transform, integer origin and declared pivot rotation, and
     precomputes its subpixel vertices before native draw. No gate exemption,
     tolerance or pivot/drop change was added.

   No new clamps. The inherited death `coat_near_tip.lift_px` budget stays
   `4 -> 2.5px` in both views; press remains `22px`.

3. **Sheets:** the preserved diagnostic contains 26 errors: the 24 idle errors
   plus two false body-seam reports at rear death 30/31. The composer called the
   generic release policy, while the Gaoler gate used its exact-source policy.
   `rr49_compose.py` now forwards that same strict policy through an optional
   generic composer parameter. Only the authored released grip adjacency is
   retired; every body seam and exact-source/component test stays active.
   A focused routing regression proves the generic default is unchanged. A
   fresh native `sheets` PASS remains a design-owner proof obligation.

## Files and scope

- Gaoler source and production layouts opt in; `rr44_build.py` retains the field
  on rebuild. No PNG, approved director file, or motion file changed.
- `scripts/maquette_cutout_runtime/stable_paint.gd` and its `.uid`, plus four
  guarded calls in `rig.gd`: deterministic mesh/quad submission, rigid idle,
  bounded shared cache and submitted-buffer evidence. Immutable geometry is
  hashed once at registration, and rigid idle buffers are reused by group offset.
  The cache refinement preserves all 1,784 frame/origin records byte for byte;
  `proof/cache_preservation.json` records that comparison.
- `tools/humanoid_cutout/stable_paint.py`, opt-in CPU mesh/quad routing, and the
  optional composer parameter are the shared root corrections. Other rigs
  retain their old code path and their original proof field inventory.
- Gaoler `rr49_*` fixture/calibration/check/composition modules; extended rr-44
  sampling, sweep, exact-native and gate binding; proof shell routes sheets and
  review to the correct policy. The final-native receipt is mandatory and its
  omitted-category mutations fail validation.
- The Python and Godot v1 proof dependency inventories both bind
  `stable_paint.gd`; the transitive-preload closure gate caught the initial omission.
  Correcting this changes no v2 proof inputs or submitted buffers.
- `tests/rr38/{samples,native_capture}.gd` record submitted buffers only for the
  opt-in. `tests/test_rr49_native.py` covers frozen truth, actual buffers, idle,
  corruption and policy/transform/texture/skin mutations. It declares `gaoler`
  in `tools/python_suite_resources.json` because its geometry helper reads the
  live production rig while constructing the board fixture; it writes only
  per-test temp directories. Existing rr-44 Godot wrappers use task rr-49.

The nine other rigs have 10,294 byte-identical sampled poses. Their existing
elbow findings remain report-only and unchanged. Identity/density preservation
retains all 147 unrelated art records, 112 density entries and 2,187 outputs.

## Validation records

Final observed results (full detail, commands and preserved logs:
`proof/results.json`, `proof/final_round.json`, `proof/changed_files.txt`):

```text
RR49 BASELINE: PASS (52/52; source=24 idle=24 released=4)
RR44 CPU/NATIVE CALIBRATION: PASS (1336/1336 native signatures; 892 fresh frames)
RR44 SHARD EXECUTION: 448 shards; 0 process failures
RR44 CPU SWEEP: PASS (892 frames; 0 findings; native_calibrated=True)
RR44 ALL GATES: PASS (0 errors; native=False)
RR38 RUNTIME: PASS (239 checks; headless registration, views, portraits and clocks)
RR44 TWO-LEG WALK: PASS (254 poses; 0 errors)
V2 BOARD SPRITE GEOMETRY: 88 cases, 0 errors, native=false
PREPARED UNIT CANVAS: 64 cases, 4864 checks, 0 errors, native=false
RR49 NATIVE REFERENCE LOAD: PASS (45 real reference rigs; rest + idle hold; headless geometry only)
CHECK-OK (board density)
```

The existing 39 rr-44 tests pass, the new four rr-49 tests pass, and all seven
proof-path tests pass, including dependency mutations. Final full-Python shard
results contain **2,141 tests, zero failures/errors, 66 skips**. The capacity
interruption disconnected the coordinator after launching its workers. All four
workers completed. `python_recovered_summary.log` was produced with the existing
suite summary function after checking all 230 assigned modules, all 2,141 test
identities (including multiplicity), four fresh invocation IDs, zero import-guard
violations, current source locks, and each shard's original 2,400s deadline:

```text
Ran 2141 tests in 1736.229s
OK (skipped=66)
```

That elapsed value is reconstructed from plan/result timestamps. No coordinator
exit code is asserted. `python_summary.json` retains the four original records
and the recovery validations; no passing test was rerun for aggregation.

The final full Godot suite records:

```text
MAIN BODY RUNTIME: 236.545 seconds
MAIN BODY ASSERTIONS: 495687
FULL SUITE RUNTIME: 686.020 seconds (budget 900 seconds)
TEST RESULT: FAIL (3 failure(s))
```

Its three failed children are `enemy_no_action_test`, `fix_11_test`, and
`fix_11_probe`. All fail through the existing undeclared `GameData` at
`tests/suites/enemy_no_action_suite.gd:36,128`; the first waits until its 180s
child deadline after that compile error. All relevant helper/test files are
byte-identical to HEAD and pre-rr-44 `e7913f0`, recorded in
`master_failure_bindings.json`. The other 227 child suites pass. No assertion or
budget was changed. The final failure logs are preserved separately.

An earlier special-encounter failure was missing eight generated emblem `.ctex`
files. A PNG-only isolated import project used the existing approved PNGs and
original sidecars; only the expected ignored cache files were copied back. The
original PNGs/sidecars stayed unchanged. The focused follow-up and final full-run
special-encounter child both pass. `emblem_cache_bootstrap.json` records the inputs.

Earlier complete and interrupted attempts remain preserved under
`initial_full_round.json` and `before_binder_fix_*`. The former Python attempt
was interrupted for the cache refinement; the next completed run's sole missing
proof-dependency failure was corrected in both inventories. The final run above
follows that last code change. No fresh renderer capture is claimed.

Final preservation: 90 non-report files match their pre-suite locks, all protected
art/motion is unchanged, no foreign rig files changed, HEAD remains `5ec882b01`,
and all changes remain uncommitted. The read-only preservation audit retains
147 unrelated art records, 112 density entries, and 2,187 density outputs.

Chosen defaults: `CACHE_CAPACITY = 128`; a 1px rejection-fixture translation;
100 held calls in the headless cost diagnostic; and two diagnostic overview
layouts (1600×1600 / four columns, 1200×800 / three columns). Exact thumbnail,
caption and colour values are in `chosen_defaults.json`. The raster grid (256),
per-sampler timeout (85s), and full-Godot outer timeout (1800s) are inherited;
the full suite keeps its original 900s budget. There are no new `TODO_DESIGN_*`
fields and no new motion clamps.

## Proof for the design owner

Run from this worktree, with window-server access. The existing contracts
require 1920×1080, UI scale 1.0. Native and sheets must both pass at the final
committed HEAD. These commands regenerate the existing probe outputs; their
sources and proof contracts are already wired. No new inspection-fixture
command was requested by the brief.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-49 && LABYRINTH_TASK_ID=rr-49 sh experiments/cutouts/chainbound_gaoler/rr44_proof.sh density
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-49 && LABYRINTH_TASK_ID=rr-49 sh experiments/cutouts/chainbound_gaoler/rr44_proof.sh rest
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-49 && LABYRINTH_TASK_ID=rr-49 sh experiments/cutouts/chainbound_gaoler/rr44_proof.sh native
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-49 && LABYRINTH_TASK_ID=rr-49 sh experiments/cutouts/chainbound_gaoler/rr44_proof.sh sheets
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-49 && LABYRINTH_TASK_ID=rr-49 sh experiments/cutouts/chainbound_gaoler/rr44_proof.sh idle
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-49 && LABYRINTH_TASK_ID=rr-49 sh experiments/cutouts/chainbound_gaoler/rr44_proof.sh production
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-49 && LABYRINTH_TASK_ID=rr-49 sh experiments/cutouts/chainbound_gaoler/rr44_proof.sh review
```

Expected output paths under `../rr44/proof/`: `native/`, `native_rest/`,
`contact_sheets/`, `idle_native/`, `production_native/{front,rear}/`,
`chainbound_gaoler_protagonist_idle.mp4`, `chainbound_gaoler_review.mp4`,
`rr44_native_gates.json`, and `logs/rr44/native_current_gates.json`.
The preserved `rr49/proof/baseline/` is never a current-proof input.
