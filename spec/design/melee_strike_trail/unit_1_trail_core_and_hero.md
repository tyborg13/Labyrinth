# Unit 1: Strike-trail core, hero and illusions, spear haft depth

Read `README.md` in this folder and the review sheets first. The reference prototype is `prototype/trail_prototype.py`, which draws along paths sampled by `prototype/sample_paths.gd.txt`. Match its look; the README tables are normative.

## Background (code map)

**Old slash.** `_draw_melee_slash_effect` in `scripts/combat_board_view.gd` (about 12438–12464) is called from the melee branch of `_draw_effect_overlay` (about 10449 and 10483–10558).

**Hero dispatch:**
- `protagonist_melee` and `protagonist_weapon_motion` are set on the effect in `run_scene.gd` (about 23319–23334).
- Lash goes to `MeleeLashFx`; stab and thrust go to `MeleeThrustFx.draw_protagonist_stab`. Everything else gets the slash gated by `ProtagonistCutout.attack_trail_phase`.
- Clip routing is in `scripts/protagonist_cutout/renderer.gd` `present()`: `attack` becomes `attack_heavy`, `_stab`, `_thrust` or `_lash`, and the sword uses `attack_pose_phase`.
- Clocks come from `scripts/attack_fx_library.gd`.

**Illusion echoes.** Mirror Triptych echoes (`illusion_relic_rules.gd`, `run_scene.gd` about 22949) draw the raw slash from the illusion's tile. Illusions never play an attack clip.

**Geometry.** Weapon landmarks are `rig.layout["weapon_grip"]` (`tip`, `assembled`). The live point is `rig.to_local(bones["weapon_r"].to_global(landmark - joint))`, and the pure sample is `Motion.sample_pose(clip, phase, layout, facing)` with `Motion._world_transform`. Mirroring is `255 - x`. Source to board is `center + (src - (127.5, 202.7)) * 1.03W/255` (`protagonist_source_pixel_scale`), with the unit rect from `_unit_draw_rect_for_center`.

**Effects layer.** It redraws only when `effect` or `effect_progress` changes, so effects must be pure functions of progress. Its material is the art-treatment shader with mix blend; there is no additive blending yet.

## Change

### 1. New module `scripts/strike_trail_fx.gd`

Pure drawing functions with no clocks.

- **Inputs:**
  - a list of strike samples (progress, tip point, inner point), already in board space;
  - kind (`sweep`, `streak`, `rake` or `arc`);
  - effect progress;
  - contact progress (0.42);
  - strike window;
  - element;
  - a unit scale (board pixels per attacker source pixel);
  - an effect seed.
- **Geometry and timing:** tail length 0.10 progress; fade 0.06 after the window; crescent reach tapering toward the tail; streak lengths; rake of three lines; arc synthetic crescent. Use the README and prototype values: sweep reach sword 0.55, heavy 0.5, lash 0.09; streak length stab 48 and thrust 74 source px; side lines ±4 px.
- **Look:** treatment A. A wide low-alpha glow pass, then the core. Edge, core and rim colours come from the element palette table. Deterministic ember sparks. One four-point glint at contact, at the strike point, lasting 0.10 progress.
- **Primitives:** vertex-coloured triangle strips (`RenderingServer.canvas_item_add_triangle_array`, or `draw_polygon` with per-vertex colours), not bands. Reuse or extend `ElementalSpellFx._ribbon` where it fits.
- **Additive blend.** Draw the trail on a dedicated child canvas item of the effects render layer, with a `CanvasItemMaterial` set to `BLEND_MODE_ADD`, in the same z position the old slash had. It must be pure in progress, and copied or synced to retained layers like the existing effect state (see the layer sync lists, `combat_board_view.gd` about 2062–2111). Keep the `"effect_overlay"` render telemetry.

### 2. Hero strike samples

- Add `strike_samples(direction_delta, progress_from, progress_to, step)` to the hero renderer. It returns tip and inner points in 255 source space, mirrored as needed.
- Implement it with `Motion.sample_pose`, using the same clip routing and phase remap as `present()`. Do not touch the live rig.
- Inner point: along the weapon from tip toward the `assembled` grip, at the kind's reach. The board maps the points to screen space with the existing helpers.

**Per-motion settings** (effect progress window, kind):

| Motion | Window | Kind |
| --- | --- | --- |
| sword | 0.33–0.56 | sweep |
| heavy | 0.25–0.56 | sweep |
| stab | 0.33–0.54 | streak |
| thrust | 0.30–0.54 | streak |
| lash | 0.30–0.54 | sweep (whip reach) |
| bow / repeater bash | as sword | sweep |

Sample at 1/240 progress inside the window. Cache per effect identity, so a redraw does not resample.

### 3. Dispatch

- Replace the hero slash, `MeleeLashFx` and `MeleeThrustFx.draw_protagonist_stab` calls with the strike trail for all hero melee.
- Illusion echoes: the `arc` kind from the illusion's position toward the target, with the echo's element.
- Enemies are unit 2. Leave the enemy branches unchanged in this unit.
- Delete hero-only code that becomes dead, and update its tests.
  - `MeleeLashFx` and the hero stab helper are removable if no other caller remains.
  - `MeleeThrustFx.draw_streak` is still used by the harrier until unit 2.

### 4. Element

Use the effect's `element` (`ElementData`: none, fire, ice, lightning, air, earth) to choose the palette. Non-elemental melee uses `none`.

### 5. Spear haft depth (owner request)

- In `scripts/protagonist_cutout/gear_layers.gd` `weapon_depth`, the front-facing `attack_thrust` uses z 38 while the pole is level and driving. That is behind the torso (40) and hips (42), above the legs (≤ 22), and below the weapon arm (46), glove (65), grip piece (66) and fingers (67).
- Use the carry depth (8) during the lowering and recovery phases, while the butt passes the near foot. Pick the boundaries from the thrust clip's level window (0.20–0.62 in clip phase, per `unit_4_full_pass_motion.md`), mapped to the progress the renderer uses. Verify visually that no frame shows the butt over the near foot.
- The grip piece must stay visible over the palm and under the fingers whenever the weapon is not at 66.
- Rear facing is unchanged (5).
- Update `spec/protagonist_cutout_runtime.md` ("Carry and draw order" layering table) and the gear layer tests.

## Keep

- Contact progress 0.42 and every hero clock.
- Damage-once, sounds, camera kick, impact decals and analytics.
- Reduced motion: no trail drawn, the same as today.
- Effect layer ordering relative to HUD, floating text and status icons.
- The startup asset manifest probe's staged/synchronous parity. If the slash sheet stops being needed, remove it from both paths together.
- The Windows typed-array rule.

## Proof

**Unit tests:**
- `strike_samples` for every motion, front, rear and mirrored. The tip at contact matches the existing `source_socket`-style computation within 0.5 px.
- The trail envelope: nothing before the window, peak at contact, gone by window end + 0.06.
- Palette by element.
- Deterministic sparks: identical output for the same inputs.
- Dispatch per motion.
- The spear depth rule at representative phases.

**Probe.** Extend `tests/protagonist_gear_motion_probe.gd` (or add a focused `tests/strike_trail_probe.gd`) to capture 1920×1080 frames for:
- each hero motion, front and rear, at progress 0.36, 0.40, 0.42, 0.46 and 0.52;
- one fire-element and one ice-element melee;
- one illusion echo.

Add a sheet builder or reuse `tools/board_density_ab.py`-style crops. The design owner runs native captures; give the exact command.

**Suites and benchmark.** The full Godot suite and the existing gear motion suites. Also `tests/render_performance_benchmark.gd`; report its numbers before and after, since a trail adds draws.

**Final message:** files changed; how each requirement was met; result lines; native commands; open issues.
