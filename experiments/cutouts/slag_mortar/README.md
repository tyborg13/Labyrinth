# rr-22 — Slag Mortar humanoid v2, feedback 3

Changes are uncommitted. The director owns commits, review, inspection and
publication. No windowed process or full suite was run by this worker.

## Feedback 3 coverage

1. The regenerated director masks are imported byte for byte. The added 31
   front / 100 rear rim pixels belong to the crucible. Visible mortar ownership
   remains exactly the opaque mask. The resolved design TODO is removed.
   Both source rests still match at **0 px**. Remaining outside fragments are
   reported in `rr22/proof/mask_fragments.json`, with every source coordinate
   and native owner; they have not been reassigned. See the open issue below.
2. Shared `tools/humanoid_cutout/source_space.py` implements the new source-air
   rule for rigid and skinned pieces. Transported immutable paint/tuck checks
   answer the inverse-source occupancy question using the same triangles as
   each presented piece. Every pocket is reported with bounds. Any missing
   immutable texel, including one pixel, fails; independently identified joint
   tears still fail. Originally detached painted components pass only with
   their single rigid owner and its sampled transform. Cut-induced islands,
   skinned islands and frozen fragments do not acquire that allowance.

   CPU records put all per-frame passed pockets and failures in ignored
   `proof/logs/seams_full.json`; `proof/seams.json` holds counts and unique
   pocket bounds. Native checks write `source_space_pockets.json` into the
   ignored capture folder, and compact native gate reports include its summary.
   Focused mutations cover natural air, one-pixel paint/tuck loss, joint tears,
   detached source paint, wrong transforms, cut-induced islands and unrelated
   strays. No clip/frame exceptions were added.
3. Headless checks and exact result lines are recorded in
   `rr22/proof/results.json`. The rear ownership fragments still fail the
   strict connectivity/stray gates, so all-gates acceptance is not claimed.
   The exact windowed sequence below includes `walk`. No full suite, windowed
   process, peer review or inspection fixture was run by this worker.

   All 862 presented frames were checked: **zero joint holes**, 2,242 front
   and 1,317 rear air pockets passed (3,559 total). Bounds and occurrence counts
   are in `proof/seams.json`, in 512×512 proof coordinates with source origin
   (128,128). Largest passed pockets are 578 px front / 1,001 px rear. The
   remaining detached-paint failures affect 8 front and 75 rear frames.
   Source tracing identifies the front texel (200,108), four covered arm
   continuation texels beside it, and the exact 62 reported rear texels.
   `proof/{front,rear}_stray_sources.json` contains the unique source pixels;
   full frame traces are in ignored `proof/logs/feedback3_*_stray_sources.json`.

   Focused rr-22 tests: `Ran 26 tests in 16.686s` / `FAILED (failures=1)`;
   only `test_ownership_replays_and_logical_pieces_are_connected` fails.
   Reference/gait tests: `Ran 92 tests in 186.107s` / `OK`. Runtime 475 checks,
   affected suites 513 checks, production logic 1,516 frames per view, native
   probe load and exported two-view smoke pass. All three SFX sync programs,
   registration audit, art identity (111 tests) and icon identity (7 tests) pass.

## Retained implementation

1. **Integration/shadows.** The merged gait-01 implementation is reused.
   `tests/rr22/shadow_refresh.gd` restores exactly the two Slag Mortar v2 rest
   records and asserts that every unrelated shadow entry/fingerprint is retained.
2. **Protected gait.** The new staged motion file is imported byte for byte.
   `leg_roles` is removed from anatomy, case/production layouts and compiled
   data. Shared gait compiler, actual board geometry, projected skinned leg
   scale, pelvis fit and walk gates are used. Both views have six swings, zero
   stance drift and 3.5 px maximum total pelvis drop. Maximum extra fit is
   0.091893 px front and 0.098218 px rear. The director's 0.85 s clock, 5 px
   lift, torso jolt and 2 px apron trail are unchanged.
3. **Protected crucible ownership.** Both supplied masks are copied unchanged
   to `rr22/source/<view>/crucible_mask.png`. Every opaque masked texel is
   mortar; none outside is mortar. The rear bracer lower-rim rule is retained.
   Logical-piece components smaller than six pixels join their surrounding
   non-mortar piece where compatible with the exact mask. Conflicting rim
   fragments remain visible in the failing gate; see the open issue below.

   Hidden pot paint comes only from the pot's own visible edge texels. Its
   covered domain includes the shoulders/head as well as the torso. Hidden-only
   unsupported islands are removed. Hidden rigid layers use the visible piece's
   presentation anchor so changing coverage does not move the sampled carrier.
   Both offline source rests still have **0 px mismatch**. Original paintings,
   maquette inputs, protected masks and their generator remain unchanged.
4. **Native-failure root causes.** The supplied isolated native layers identify
   the detached front death/scatter paint as near-arm material. The strict pot
   mask removes the former literal-HSV ownership islands. The remaining mask
   boundary conflict is not silently assigned to the pot.

   The reported tears are at head↔torso and torso↔pelvis joins. Their actual
   protected Bone2D poses sweep the existing three-pixel seam bands into each
   other's source frames. Covered rest texels copy the receiving piece's own
   paint. Waist tears that map into originally transparent rest space require
   action-only continuation; the existing gait continuation mechanism now
   optionally accepts a `clips` list. The neck uses lob/death and the pelvis
   uses death. They copy nearest non-outline paint from their own piece,
   including density-treated production donors. Rest and idle restore their
   exact original textures. No motion key, gate threshold or exception changed.

   `rr22_continuations.py` retains hashed source-space calibration masks in
   `rr22/continuations/`, bound to director data, paint, ownership and joints.
   A fresh checkout can rebuild without ignored full pose data. A new director
   revision needs the initial build → sample → rebuild sequence below.

   `rr22_seams.py` checks every presented frame with the shared CPU skin/rigid,
   clean-piece and joint-hole diagnostics, without exemptions. This is headless
   coverage evidence; it is not fresh native renderer proof. The old capture is
   rejected as stale for the new masks and gait. Native acceptance needs the
   director's recapture.
5. **Compact records.** Tracked `proof/samples.json`, `gates.json` and
   `native_gates.json` contain inventories, extrema and failures only. Full poses
   and gate reports live in ignored `proof/logs/`. Shared native gates and proof
   composition accept the hashed compact bone inventory while legacy full
   records retain their existing behavior. Production logic records are also
   compacted, with full reports retained under logs. Old failure crops are
   preserved under ignored `proof/logs/feedback1_native_failures/`.
6. **Proof.** Focused tests, live runtime/production probes, package smoke,
   regression checks, shadow scope and identity checks are recorded in
   `rr22/proof/results.json`. Every gate remains strict. Captures and full
   diagnostics are gitignored. See the unresolved criteria below.

## Remaining mask fragments and native proof

There are no unresolved `TODO_DESIGN` fields. The updated masks leave one
front source texel at (200,108), and 62 rear texels in eight near-arm islands.
All currently belong to native `upper_near` / logical `arm_near`. Rear island
bounds (exclusive right/bottom) are (40,76)-(52,91), 49 px;
(55,102)-(59,104), 5 px; (38,73)-(39,75), 2 px;
(53,99)-(54,101), 2 px; and single pixels (36,69), (38,69), (40,73),
(55,99). `proof/mask_fragments.json` lists every exact pixel and owner.
The front island is connected by covered material; all eight rear islands
remain separate, producing nine components including the main arm. Neither
painting has an originally detached opaque component, so the new painted-speck
rule cannot exempt these cut-induced islands. Ownership remains unchanged,
as explicitly required by feedback 3.

The source-cut diagnostic is
`rr22/proof/contact_sheets/source_cuts_outlined.png`: front row = source,
crucible, torso, near arm; rear row = source, near forearm, fist, whole near arm.
Its white outlines are diagnostic annotations only.

The old native capture cannot certify the changed cut/gait. The worker has no
window-server access and has not attempted a windowed run. Density rests must
be rebaked after the new cut; then refresh the unit shadows again. No native
seam, stray-pixel or appearance acceptance is claimed from CPU diagnostics.

## Owned files and generic extensions

- `rr22_case.py`, `rr22_build.py`, `rr22_surfaces.py`, `rr22_continuations.py`:
  anatomy, source cuts, covered paint, protected imports and production closure.
- `rr22_gates.py`, `rr22_surface_gates.py`, `rr22_residue_gate.py`,
  `rr22_records.py`, `rr22_seams.py`, `rr22_cpu.py`, `rr22_fragments.py`, `rr22_proof.sh`: strict gates, compact
  records, diagnostics and director proof sequence.
- `tests/rr22/`, `tests/test_rr22_humanoid.py`, generated `rr22/` data,
  `assets/units/slag_mortar_cutout/`, Slag density/identity/shadow records.
- This round's generic changes are the additive `source_space.py` classifier
  and its integration in native `gates.py`. Earlier continuation/compact-reader
  changes are already on the director's merged baseline. Reference production
  assets and case data remain byte-identical to HEAD.

## Chosen defaults

Only proof/test values are engineer-selected. Existing named values remain in
`rr22/proof/chosen_defaults.json`: fixture tiles, seed .37, action phase .6,
source-sheet 4×2 layout at 3× with one-pixel white outlines, and timeouts. Additional source-only diagnostics record a 6×3 failure sheet,
2× head comparison and 6× padded seam crops.
CPU progress uses the reference's 50-frame interval. A one-pixel UV support
guard only culls fully transparent CPU triangles; parity tests compare every
paint/check pixel and transported hole/seam mask with the original raster. Material extents are
computed from the protected poses and source texel footprints, not tuned.
Actual board step/scale are measured at 1920×1080/100%; the old synthetic
96 px / 2× values are no longer used for this unit's gait evidence.

## Headless reproduction

Run from the rr-22 worktree. The initial build imports a new director revision;
its sample allows deriving the motion coverage on the next build. Subsequent
builds reuse the hashed calibration if full evidence is unavailable. Building
promotes raw paint, so density processing follows every build.

```sh
python3 experiments/cutouts/slag_mortar/rr22_build.py
python3 tools/godot_task_runner.py --task-id rr-22 --stream -- godot --headless --path . --script tests/rr22/samples.gd -- --case res://experiments/cutouts/slag_mortar/rr22 --output res://experiments/cutouts/slag_mortar/rr22/proof/logs/samples_full.json
python3 experiments/cutouts/slag_mortar/rr22_build.py
python3 experiments/cutouts/slag_mortar/rr22_density.py --refresh-sources
python3 tools/godot_task_runner.py --task-id rr-22 --stream -- godot --headless --path . --script tests/rr22/samples.gd -- --case res://experiments/cutouts/slag_mortar/rr22 --output res://experiments/cutouts/slag_mortar/rr22/proof/logs/samples_full.json
python3 experiments/cutouts/slag_mortar/rr22_records.py samples
python3 experiments/cutouts/slag_mortar/rr22_gates.py
python3 experiments/cutouts/slag_mortar/rr22_seams.py
python3 -m unittest discover -s tests -p 'test_rr22*.py' -v
python3 tools/godot_task_runner.py --task-id rr-22 --stream -- godot --headless --path . --script tests/rr22/runtime_checks.gd
python3 tools/godot_task_runner.py --task-id rr-22 --stream -- godot --headless --path . --script tests/rr22/affected_suites.gd
python3 tools/godot_task_runner.py --task-id rr-22 --stream -- godot --headless --path . --script tests/rr22/native_capture.gd -- --output res://experiments/cutouts/slag_mortar/rr22/proof/native --validate-only
python3 tools/godot_task_runner.py --task-id rr-22 --stream -- godot --headless --path . --script tests/rr22/shadow_refresh.gd
```

## Proof for the design owner

Run from `/Users/borgerding/workspace/Labyrinth.worktrees/rr-22`. Remaining mask
fragments will keep native sheets/review gated until resolved. The driver contains the exact visual-runner commands,
semantic proof contracts and manifests at 1920×1080/100%.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-22 && sh experiments/cutouts/slag_mortar/rr22_proof.sh density
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-22 && sh experiments/cutouts/slag_mortar/rr22_proof.sh rest
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-22 && sh experiments/cutouts/slag_mortar/rr22_proof.sh native
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-22 && sh experiments/cutouts/slag_mortar/rr22_proof.sh sheets
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-22 && sh experiments/cutouts/slag_mortar/rr22_proof.sh walk
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-22 && sh experiments/cutouts/slag_mortar/rr22_proof.sh idle
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-22 && sh experiments/cutouts/slag_mortar/rr22_proof.sh production
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-22 && sh experiments/cutouts/slag_mortar/rr22_proof.sh review
```

`density` processes the pieces, rebakes/records native rests, seals metadata,
refreshes scoped shadows and checks density. `native` regenerates full bone
samples plus a compact inventory before capturing and gating all native frames.
Capture paths are `proof/native_rest/`, `proof/native/` (including feature masks,
seams and isolated layers), `proof/contact_sheets/`, `proof/gait_move_native/`,
`proof/gait_move_sheet.png`, `proof/idle_native/`,
`proof/production_native/{front,rear}/` and the idle/review MP4s. They are ignored.
The director owns the inspection fixture; none was created by this worker.
