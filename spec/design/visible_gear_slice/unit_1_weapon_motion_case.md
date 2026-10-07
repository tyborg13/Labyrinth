# Unit 1: Weapon and shield motion study (cutout cases)

## Header

- Use `$create-labyrinth-cutout` and the maintained toolkit `tools/cutout_workflow.py` (read `spec/cutout_workflow.md` and the skill's `references/motion-and-integration.md`).
- Read the [README](README.md) first. Joint maps: `mockups/front_joints.png`, `mockups/rear_joints.png` (4×, 10-px grid). Look at the stand-in art paths in `assets/units/protagonist_cutout/gear_visuals.json` and the existing sword attack in `scripts/protagonist_cutout/motion.gd` (`"attack"` branch, `_solve_leg`, `_separate_grip`, `_hold`, `_pulse`, `_curve`).
- You own only `experiments/cutouts/protagonist_gear/`. Do not edit production scripts, assets or tests; Unit 0 is editing production files in the same worktree at the same time. Unit 2 will port your sampler code into production `motion.gd`, so write it as self-contained branches and helpers inside the case's own `motion.gd`.

## Cases

Create three cases with `seed-protagonist` (fresh output directories):

| Case | Path | Gear in the case |
| --- | --- | --- |
| Heavy | `experiments/cutouts/protagonist_gear/heavy_v01` | `weapon_r` replaced with `assets/units/protagonist_cutout/gear/war_maul/{front,rear}_weapon_r.png` at the registry offsets (`replace-part`) |
| Stab | `experiments/cutouts/protagonist_gear/stab_v01` | `weapon_r` replaced with the sawtooth knife stand-ins |
| Shield | `experiments/cutouts/protagonist_gear/shield_v01` | default sword, plus the splintered-shield stand-in added as a layout part `gear_offhand` on bone `forearm_l` at the registry offset and `z_index` (front 50, rear 73) |

Copy the stand-in PNGs into each case. In heavy and stab, set the layout `weapon_grip` to the registry's `weapon_grip` for that weapon (`assembled`, `tip`, `pommel`). Read the weapon geometry from those landmarks in the sampler, not from hard-coded numbers, so final art with the same landmarks needs no code change.

## Clips to author

Add each clip to the case's `cutout.json` (frames, duration, `loop: false`) and to the case `motion.gd` `sample_pose` and `clip_specs`. Keep every existing clip of the seeded case unchanged.

Common rules:
- Coordinates are global 255-px source pixels at the bind pose.
- Both facings are authored (front and rear). Mirrored playback is the renderer's job; do not invent mirrored art.
- Keep painted segment lengths (use the existing two-bone `_solve_leg` style solve for arms), rigid gloves and rigid weapon/shield. Feet stay planted (same leg solve as the sword attack).
- **Owner rule:** no idle ripple, no traveling waves, no shimmer.
- A key's targets may be adjusted by up to ±6 px when needed for reach; prefer changing torso lean, hips drop or root shift over stretching anything. Report every deviation.
- Contact for both weapon clips is at authored phase 0.42 (the game's melee damage boundary). Use an identity phase curve.
- In the rear facing, "forward" is screen up-right; in the front facing it is screen down-left (the board's 2:1 projection; the stab line is `(-0.894, 0.447)` front and `(0.894, -0.447)` rear).

### `attack_heavy` (War Maul), 0.72 s, 43 frames: a chunky two-handed overhead slam

Front keys (phase: pose). "dir" is the unit haft direction from the right fist toward the hammer head. The left wrist always sits on the haft 9 px from the right fist toward the pommel (L = R − dir × 9) from 0.08 until it releases.

| Phase | Name | Right wrist R | dir | Torso rot (rad; + leans back/right) | Hips Δy | Root Δx |
| --- | --- | --- | --- | --- | --- | --- |
| 0.00 | rest | bind (86,132) | rest (−0.82, 0.57) | 0 | 0 | 0 |
| 0.12 | gather: hands meet at the belly, head swings up the forward side | (112,122) | (−0.70, −0.71) | +0.03 | +1 | 0 |
| 0.30 | apex: maul straight up and slightly back, hammer head above the hero's head | (132,84) | (0.11, −0.99) | +0.10 | −1 | +1 |
| 0.36 | apex hold (a heavy hang) | (132,83) | (0.13, −0.99) | +0.11 | −1 | +1 |
| 0.42 | contact: head strikes the floor ahead-left, body committed | (122,132) | (−0.60, 0.80) | −0.16 | +5 | −4 |
| 0.48 | impact settle | (122,133) | (−0.60, 0.80) | −0.17 | +6 | −4 |
| 0.58 | still planted | (122,132) | (−0.60, 0.80) | −0.15 | +5 | −4 |
| 0.72 | lift: left hand lets go (release from 0.68 to 0.80 back to its bind pose) | (104,128) | (−0.75, 0.66) | −0.06 | +2 | −2 |
| 1.00 | rest | bind | rest | 0 | 0 | 0 |

- The swing from apex (0.36) to contact (0.42) is the fastest movement in the clip: about four frames, passing over the top through the forward side, not through the body.
- Rear keys: mirror the logic with the rear joints. Rest is the rear bind. The gather swings the head up on the forward (screen-right) side. At the apex the maul is straight up and slightly toward the camera, above the head. At contact the head center is near (184,188) ahead-right on the floor, with hands near (138,128). The torso leans forward toward screen-right. The far (left) arm is hidden behind the body, as it is today.
- Cloth: reuse the sword attack's restrained cape follow-through amounts. No additional cloth motion.

### `attack_stab` (Sawtooth Knife), 0.40 s, 24 frames: a quick stab

| Phase | Name | Right wrist R | Knife dir | Torso rot | Hips Δy | Root Δx |
| --- | --- | --- | --- | --- | --- | --- |
| 0.00 | rest | bind (86,132) | rest (−0.82, 0.57) | 0 | 0 | 0 |
| 0.30 | cock: fist pulled back to the hip, blade level and pointing forward | (100,126) | (−0.96, 0.28) | +0.04 | +1 | +1 |
| 0.42 | contact: arm fully extended along the stab line at belly height | (66,121) | (−0.894, 0.447) | −0.06 | +1 | −3 |
| 0.54 | hold, 1 px drift back | (67,121) | same | −0.05 | +1 | −3 |
| 0.90 | settled to rest | bind | rest | 0 | 0 | 0 |

- The 0.30 to 0.42 thrust is about three frames and must read as a jab, not a swing.
- The off hand gives a small counter-motion: left forearm −0.10 rad at contact, back by 0.80.
- Rear: the cock is at the hip near (160,135) with the blade pointing up-right (0.96, −0.28). At contact the wrist is near (182,112) along (0.894, −0.447).

### `block_shield` (Shield case), 0.30 s, 25 frames: raise the shield instead of the sword

- Use the existing `block` reaction's timing envelope (`_hold(t, 0.0, 0.14, 0.32, 1.0)`) and its body recoil. Do **not** raise the sword: the sword arm stays at its bind pose.
- Front: the left wrist moves from bind (168,143) to (146,116) at full guard. The shield comes up in front of the left chest, still upright (it may tilt at most ±0.15 rad).
- Rear: the left wrist moves from (87,132) to (98,120). The shield stays over the cloak.

### Shield with existing clips (no new motion)

In the shield case, render the existing `cast`, `shoot`, `walk`, `hit` and `attack` with the shield attached, to show how it rides on the forearm. Make no motion changes for these; report anything that looks broken (for example the shield covering the face during the front cast) with captures.

## Proof

For each case:
- `validate --protect art` (with the replaced weapon or added part recorded as the case's art);
- `render` to a fresh `/private/tmp/protagonist-gear-<case>-v01` with `--task-id visible-equipment-on-the-protagonist-cutout-vertical-slice`;
- `verify-render`.

Copy into `experiments/cutouts/protagonist_gear/<case>/review/`:
- the timed reel;
- front and rear native pose PNGs at phases 0, 0.12, 0.30, 0.36, 0.42, 0.48, 0.58, 0.72, 0.90 and 1.0 (heavy); 0, 0.30, 0.42, 0.54 and 0.90 (stab); 0, 0.14, 0.25 and 0.32 (block_shield);
- for the shield case, `cast` and `shoot` at 0.42 and `walk` at two phases;
- one labeled contact sheet per clip with those poses side by side at 2×, with board-scale (0.77×) thumbnails underneath.

Report the board-scale readability of each key in one line, and every target you adjusted, with the reason.
