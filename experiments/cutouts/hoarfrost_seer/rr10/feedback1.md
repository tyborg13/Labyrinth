# rr-10 — director feedback 1 handoff

Historical delivery. [Feedback 2](feedback2.md) supplies the protected exact rope
mask and resolves the ownership ambiguity recorded at this stage.

Front candidate only, `codex/rr-10`, changes uncommitted. The owner handles
commits, review, fixtures and publication. No windowed worker runs. Director
captures from `963d00f61` remain intact as historical evidence; their input
bindings are stale after these changes.

## Feedback acceptance

1. **Protected tracks:** imported the integration worktree's file byte for byte
   into the staged source and both copies, then recompiled. It also changes
   mark's recovery lifts from 5/4 to 8/6 px and its notes; those supplied values
   are preserved. Idle channels are unchanged and pinned by
   `tests/rr10/feedback1/approved_idle.json`. The original native idle groups
   compare at **0 mismatches** (`proof/feedback1_baseline.json`).
2. **Gate calibration:** exposed continuation is allowed; exposed outline
   pixels and dark slabs fail. Holes use GPU-transported seam masks at
   shoulders, elbows, cuffs/grip, neck, belt and hem/foot joins. An enclosed
   hole must lie within the 3 px seam neighbourhood to count as a joint gap;
   large unjoined negative-space openings may change. Native mesh masks use
   actual `joint_meshes`, without a CPU skin oracle. Both metadata and physical
   2 px tuck mutations fail, as does the split-robe mutation.
3. **Defects:**
   - Specks came from hidden-fill seeds split into unsupported fragments by
     maquette/occlusion clipping. Connectivity is checked before and after
     clipping. Hidden-only islands are removed; visible painting texels are
     unchanged. Each final garment has one connected source surface. The new
     <=8 px detached-component gate rejects all five supplied native defect
     frames. Outline pixels >1 px outside posed silhouettes fail too.
   - The grey line was the lower edge of the old flat robe-fill band. Robe
     continuation now uses one exact rr-05 nearest non-outline painted-cloth
     field. A source-space cloth continuity gate rejects the historical band,
     even when its colours also occur elsewhere in the cloth. This adds no
     CPU posed-mesh comparison.
   - Staff depth is per-view data: front behind torso, sleeves and robe; rear
     in front of the body; gripping hand in front of staff. Both policies and
     mutations are tested, without fabricating rear art.
   - Whole rope ownership was unfinished at this stage. Feedback 2 replaces the
     colour selector with the director's protected exact mask, assigns the full
     rope to torso and fills the cloth beneath its tails. The obsolete colour
     diagnostic and its placeholder have been removed.
4. **Rear:** still stopped at `TODO_DESIGN_mq6_rear_delivery_and_paint`.
   `inputs.json` retains one rear job path and one delivery path. No obsolete
   mirrored rear is loaded. Production promotion remains deferred until both
   approved views are built/proven, as required by the original brief.

Fresh native proof must establish that these source repairs remove the defects
in motion and that seam masks calibrate every clip correctly. Current native
gate/contact-sheet success is **not** claimed. The sheet composer passes a
headless fixture test and continues to reject failed/stale native proof. Run
`native` before `sheets` to replace the old captures.

## Original numbered contract

Risk remains **high**. (1) Front rest identity is 0 px, fusion/hierarchy and
three meshes hold; whole rope ownership is open. (2) The 2 px grids and exact
authored weight rules hold; native fold/tear inspection is pending. (3) Required
3 px tucks have 0 missing source texels; outline-free fills and continuous robe
cloth are checked. (4) Source-unit channels, inward motion, IK/FK, world-relative
staff/release, world steps, approved idle and snapped presentation are unchanged.
(5) Production-shaped data remains staged, with real callback/phase-seed/portrait
proof adapters; board/pre-battle/portrait promotion waits for the rear.
(6) Headless source/bone/limits/mutations are checked; current native pixel gates
and both-view acceptance remain for the director.

## Changed files and runtime boundaries

- `rr10_build.py`, case `inputs.json`, regenerated pieces/checks/tucks, seam
  masks/mesh templates, layout, motion and staged asset configuration.
- `tools/humanoid_cutout/materials.py`: connected continuations and staff depth.
- `tools/humanoid_cutout/seams.py`: GPU seam proof masks.
- `tools/humanoid_cutout/gates.py`: calibrated fill/hole/stray/cloth gates.
- `tests/rr10/native_capture.gd`: native seam captures; focused tests and known
  failing director-frame/flat-band fixtures under `tests/rr10/feedback1/`.
- Protected staged motion source: authorized byte-for-byte reimport only.

This feedback adds **no common runtime hooks**. Original hooks remain
`motion.gd` (explicit v2 dispatch), `rig.gd` (v2 presentation) and `renderer.gd`
(overridable rig/view factory), all under `scripts/maquette_cutout_runtime/`.
No Lancer, Herald, Gloam, Thrall, Bloomer, Wisp or Shrike art/data was changed.

## Proof for the design owner

Exact 1920×1080 / 100% commands through the mandatory visual runner:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-10 && sh experiments/cutouts/hoarfrost_seer/rr10_proof.sh rest
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-10 && sh experiments/cutouts/hoarfrost_seer/rr10_proof.sh native
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-10 && sh experiments/cutouts/hoarfrost_seer/rr10_proof.sh sheets
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-10 && sh experiments/cutouts/hoarfrost_seer/rr10_proof.sh production
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-10 && sh experiments/cutouts/hoarfrost_seer/rr10_proof.sh idle
```

After both views are built, rerun `native`, then:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-10 && sh experiments/cutouts/hoarfrost_seer/rr10_proof.sh review
```

Outputs are `proof/native_rest/`, `proof/native/` (main frames, pairs, isolated
pieces/checks, rest-hole and joint-seam masks), `proof/native_gates.json`,
`proof/native_failures/`, `proof/contact_sheets/<view>_<clip>_3x.png`,
`proof/production_native/`, `proof/seer_protagonist_idle.mp4`, and the rear-dependent
`proof/hoarfrost_seer_review.mp4`. The MP4 framing/repeats remain the brief's.
The owner prepares the inspection fixture after both-view promotion; the brief
requires no front-only inspection-fixture command.

## TODO_DESIGN / open issues

- Rope ownership: resolved by the protected mask in feedback 2.
- `TODO_DESIGN_mq6_rear_delivery_and_paint`: rear build/proof and production
  promotion/density adoption after both approved inputs arrive.
- Fresh native gates, actual sheets and fold/tear inspection are unverified
  in this sandbox. Old captures are preserved and remain stale.

## Chosen defaults

The obsolete source-only colour diagnostic was removed in feedback 2. Synthetic cases and sheet-verifier
mocks are test-only. No player-visible defaults were chosen. Existing proof
layout, encoder, fixture, tolerance and timeout defaults remain as listed in
the original README and their named constants. Gate thresholds come directly
from the director feedback.

Exact observed results/logs: [feedback verification](proof/feedback1_verification.md).
