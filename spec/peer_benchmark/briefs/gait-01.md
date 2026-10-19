# gait-01 — Humanoid walk on the protagonist's model (shared), Thrall and Mirror

## Header
- Why: the owner rejected the stride + trailing shuffle (Mirror, 2026-10-19: "One leg is kind of shimmying and the
  other is mostly still like he's limping along"). Every v2 humanoid now walks with both legs stepping, on the
  protagonist's walk model.
- **Binding spec (director-updated, protected):** `spec/peer_benchmark/humanoid_cutout_rig.md`:
  - §3 "Walking: both legs step, on the protagonist's walk model" and "Walk gates";
  - §4 "Gait block".
- Reference implementation: `scripts/protagonist_cutout/motion.gd`:
  - `walk_foot_state`: stance and Hermite swing, lift, lanes;
  - `_solve_leg` and `_segment_transform`: projected segment scale that keeps the painted width;
  - `_fit_walk_pelvis`.
  Port the behaviour; don't call into the hero's code, and don't change the hero.
- Base `codex/peer-benchmark`. Owned:
  - the v2 humanoid compiler, gates and production gates: `tools/humanoid_cutout/**`;
  - the v2 humanoid runtime: `scripts/maquette_cutout_runtime/humanoid_*.gd`;
  - the Thrall case: `experiments/cutouts/arc_thrall/**`, `assets/units/arc_thrall_cutout/**`;
  - the Mirror case's motion and gates: `experiments/cutouts/glacial_mirror/**`,
    `assets/units/glacial_mirror_cutout/**`;
  - their tests.
- Three batch C rig units (rr-20, rr-21, rr-22) are parked. They adopt this unit's code after it lands, so keep the
  shared API data-driven, with no creature names.
- Proof captures stay gitignored under each case's existing `proof/.gitignore`.

## Data provided (protected; committed in the worktree before launch)
- `spec/peer_benchmark/staged/rr-11/motion_tracks.json`: the Thrall's `move` now holds a `gait` block and three keyed
  channels.
- `spec/peer_benchmark/staged/rr-18/motion_tracks.json`: the Mirror's `move`: a `gait` block with
  `leg_scale_max` 1.14 (rigid-piece legs) and one keyed channel.
- Other clips are unchanged.
- Import both byte for byte. Unclear semantics → `TODO_DESIGN_<what>`, and report it.

## Change
1. **Compiler:** expand `gait` exactly per §4: schedule, Hermite swing and lift, lanes, settle, arm swing, linear root.
   - Write the expanded tracks into the compiled motion, so the walk is inspectable data.
   - A director key on a generated channel is a compile error.
   - Unknown gait fields, a non-`protagonist_walk` model and odd step counts are errors.
2. **Runtime (gait clips only):**
   - lane anchors;
   - projected leg scale per §3: skinned legs scale along each segment and keep the painted width; rigid-piece legs
     keep each piece rigid and space their joints along the leg;
   - then the pelvis fit, after the authored offsets.
   - Everything else must stay byte-identical: non-gait clips, arms and the other v2 figures (Seer, Capacitor), and
     their poses.
3. **Gates:** the §3 walk gates replace the stride/trailing move gates, in shared code:
   - planted stances, both legs;
   - swing knee peak and apex, every swing;
   - no overreach;
   - pelvis fit ≤ 6 px; report the maximum fit and total drop per view;
   - rigid air ≤ 3 px per joint; report the maximum.
   - Retire `leg_roles` from the Thrall and the Mirror. Leave them readable for the parked units until they migrate,
     and list what still reads them.
4. **Thrall and Mirror:**
   - Re-import, recompile and rebuild.
   - Rest identity stays 0 px against both paintings; density and rest records are unchanged (motion only).
   - All existing non-move gates stay green.
5. **Proof sheet:** per figure and view, 12 evenly spaced `move` frames at native board scale, ×3 nearest-neighbour,
   in one row per view. Mark each foot's world target (green = planted, orange = swing). Under each row, print the
   per-frame pelvis drop and leg scales.

## Keep
- The protagonist: no change.
- The Seer and Capacitor: byte-identical.
- The Thrall and Mirror: non-move clips byte-identical.
- The rr-05 presentation: whole-pixel translations, 1.5° rotation steps; skinned meshes resample only in actions.

## Proof
- Headless:
  - focused tests, including mutations: a planted foot nudged 1 px, a swing with no lift, a rigid gap of 4 px, and a
    director key on a generated channel. Each must be caught.
  - The Seer, Thrall, Mirror and Capacitor sets green; the three SFX sync programs and the registration audit.
  - Don't run the full suites; the director runs them at merge.
- Windowed, run by the director: list the exact `production` and `review` commands for the Thrall and the Mirror,
  including the move sheet.

## Out of scope
- The Mirror's recut, fists, feet and guard draw order (rr-23, next).
- The Mimic, Weaver and Mortar (their units adopt this after it lands).
- New art. Any change to the protagonist.
