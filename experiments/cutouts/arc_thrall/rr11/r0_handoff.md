# rr-11 implementation handoff

Uncommitted implementation in the design-owner-prepared `codex/rr-11` worktree.
The design owner owns Git preflight/contract, commit, peer review, inspection
fixture and publication. This worker performed none of those Git lifecycle
operations. Risk: runtime/production art integration; focused headless proof
here, windowed proof and full suites reserved to the director by this brief.

## Acceptance contract and implementation

1. **Cut:** both approved mq-07 paintings are losslessly partitioned (0 px rest
   mismatch). Head, fused torso/collar/chain, upper near arm, tube, claw and feet
   are rigid. Far arm, each thigh/shin union and the loincloth are single skin
   fields, with hidden draw layers sharing those fields. The pelvis is at the
   native waist. No near hand or club exists. `tube_tip` is the geometric centre
   of the native sheath cap plane, parented to `fore_near`. Loincloth tips use
   the matching native front/back panel's bottom-row centre. Source paint,
   maquette inputs and protected motion remain untouched.
2. **Motion:** byte-identical director import and exact v2 compilation; explicit
   tube-tip IK chain, rr-14 foot IK and world-step channels, supplied weapon-arm
   lag, and rigid three-group idle. The supplied near rest knee bends against
   facing in both views. Preserving rr-14's bent-rest side and the supplied
   joints therefore cannot satisfy the facing requirement. Some protected
   swing targets also yield bends below 15 degrees. Jab pelvis shifts exceed
   fixed native leg reach while both feet are required to remain planted.
   These are explicit design blockers; channels and anatomy were not retuned.
3. **Production:** Thrall adapters and the existing presentation registration
   load `assets/units/arc_thrall_cutout/humanoid_v2`. Existing board, pre-battle,
   live portrait and reduced-motion consumers resolve that registration.
   `tether` selects only the acting Thrall; `arc_jab` selects move then jab.
   Durations, contacts, effects, analytics and gameplay outcomes are unchanged.
   Density paint was adopted/processed; native rest certification remains
   pending. Only the Thrall's two shadow records were refreshed.
4. **Case data:** anatomy, groups, ownership, hierarchy, tucks, skin recipes,
   source roots and integration metadata are in `anatomy.json`/`inputs.json`.
   No Thrall identity was added to the generic humanoid modules.
5. **Gates:** reuse the rr-10 structure, source, signed transform, limits,
   idle rigidity, native rigid-sprite, clean-piece, joint-hole and stray-pixel
   gates. The added knee gate checks every presented move frame whose authored
   foot lift is positive. It records angle and facing-side evidence for each
   side. Acceptance is currently **FAIL**, without exceptions or weakened
   thresholds. Native acceptance is unverified until the director captures it.

## Small shared extensions

- `source_view.py`: explicit `fused_occlusion` opt-in allows a fully covered
  constituent label only when another label in the same fused piece is visible.
  The Thrall's rear near thigh is covered; its shin supplies that same leg's
  existing painted surface. Disabling the flag reproduces the missing-paint
  guard. Existing cases retain their previous behavior.
- `mesh.py`: elementwise chain-field dot products avoid platform BLAS warnings
  on tiny rows; the mathematical field is unchanged. The Seer has no chain field.
- `humanoid_motion.gd`: layout-owned `planted_bones` supports can solve unkeyed
  feet against their rest floor outside move/death. Unreachable targets still
  clamp without stretching. Only this new layout opts in.
- `humanoid_presentation.gd`: enforce the existing relative head limit after
  independent world-angle snapping; this prevents a 20-degree authored death
  nod from presenting at 21 degrees when its torso rounds down.
- `bone_contracts.py`: scale the position serialization tolerance by chain
  length when checking the squared-pixel bend-side cross product. Full
  extension no longer reports a false reversed knee from float roundoff.

The Seer's 777 pinned files and 1,258 fresh sample poses pass byte identity
checks. Every other creature's production files are unchanged. The shadow
refresh preserves all records belonging to other units.

## Headless proof

Run from this worktree; all engine calls use `godot_task_runner.py --task-id rr-11`.
Exact observed results and unresolved acceptance failures are recorded in
`proof/verification.json`, `proof/gates.json`, `proof/knees.json`, `proof/supports.json` and the ignored
`proof/logs/` directory. Gameplay callback evidence is
`proof/production_logic/logic_frames.json`; transforms are `proof/samples.json`.
These reports contain no native renderer pixels. The full Python and Godot
suites were deliberately not run, as required by this unit's Proof section.

Rebuild commands (only after an owner-approved input/case correction):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-11 && python3 -B experiments/cutouts/arc_thrall/rr11_build.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-11 && python3 -B experiments/cutouts/arc_thrall/rr11_density.py --refresh-sources
```

`rr11_case.py` is the initial brief transcription; do not rerun it over subsequent
owner-approved case data. `--refresh-sources` deliberately replaces only this
unit's newly derived v2 density source closure after a rebuild. It cannot
refresh any older rr-07 paint.

## Proof for the design owner

No windowed command was attempted: this worker has no macOS window-server
access. Each wrapper contains the exact visual runner, source case, output
paths, timeout and 1920×1080 / 100% contracts. Run in this order after resolving
the three design placeholders. `native` captures before checking acceptance,
so a failed gate leaves renderer evidence available for diagnosis. `review`
and `sheets` refuse failed or stale native evidence.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-11 && sh experiments/cutouts/arc_thrall/rr11_proof.sh density
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-11 && sh experiments/cutouts/arc_thrall/rr11_proof.sh rest
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-11 && sh experiments/cutouts/arc_thrall/rr11_proof.sh native
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-11 && sh experiments/cutouts/arc_thrall/rr11_proof.sh sheets
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-11 && sh experiments/cutouts/arc_thrall/rr11_proof.sh idle
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-11 && sh experiments/cutouts/arc_thrall/rr11_proof.sh production
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-11 && sh experiments/cutouts/arc_thrall/rr11_proof.sh review
```

Captures go under this case's ignored `proof/native_rest/`, `proof/native/`,
`proof/contact_sheets/`, `proof/idle_native/` and `proof/production_native/`.
Movies are `proof/thrall_protagonist_idle.mp4` and `proof/arc_thrall_review.mp4`.
No inspection-fixture command is specified by this brief; fixture preparation
belongs to the design owner.

## TODO_DESIGN placeholders

- `TODO_DESIGN_near_knee_direction`: protected near knee joints bend against
  facing; rr-14 rejects a contrary policy on a bent rest leg.
- `TODO_DESIGN_move_foot_targets`: every swing frame must reach 15 degrees;
  current presented minima are 0.547 degrees front and 0.302 degrees rear.
  Authored stance targets also drift from their world-step floor by up to
  7.547053 px front and 9.812078 px rear at the proof's 48-source-pixel step.
  Parent-relative pelvis motion and fixed-length reach clamping both contribute;
  see `proof/supports.json`.
- `TODO_DESIGN_jab_planted_feet`: maximum sampled foot drift from length-clamped
  jab IK is 0.424316 px front and 1.478555 px rear. Approved anatomy or motion
  corrections are needed; fixed-length IK cannot reach those planted targets.

## Chosen defaults

No new player-visible tuning, paint, wording, sound, fonts or icons were chosen.
The piece fields and tuck values reuse the brief and rr-10 recipes. Native
pivots and endpoints are measurements from the supplied delivery.

Worker-chosen diagnostic values are plain named constants: cap coplanarity
`CAP_PLANE_EPSILON = 1e-8`; test timeout 180 s; idle test seed 0.37; diagnostic
reachable pelvis dip 1 px; mutation rotation 1 degree; synthetic knee chain
hip (100,100), ankle (100,140), forward knee (90,120), straight knee (100,120),
reversed knee (110,120). Proof defaults copied from rr-10 include 60 fps, 96 px
proof travel at source scale 2, source origin (128,128), eight settling frames,
30 HP reaction fixture, seed 91210, six representative screenshots, five idle
loops, and proof-only label/camera geometry. All player-visible values come
from the supplied tracks, native geometry, existing presentation or brief.
