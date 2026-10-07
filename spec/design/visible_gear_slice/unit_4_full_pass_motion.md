# Unit 4: Weapon archetypes for the full gear pass

## Context

The owner approved round 2 and asked for all 72 items before the work counts as done. The design owner has registered every new weapon and offhand in `assets/units/protagonist_cutout/gear_visuals.json`, with art, `weapon_grip` landmarks (`assembled` = fist, `tip`, `pommel`) and a `motion` per weapon. The existing archetypes are unchanged: `sword` (cut), `heavy` (one-handed slam) and `stab`. Four new `motion` values need clips. Read the README "Round 2" section, `unit_3_round2_motion.md`, `spec/protagonist_cutout_runtime.md` ("Visible equipment", "Weapon and shield motion") and `spec/protagonist_ranged_animations.md` first.

Owner rules that still apply:
- Every weapon is one-handed; the offhand stays visible in every clip.
- Physical ranged shots use the main hand.
- No idle ripple.
- Each weapon type's attack must fit what the weapon is.
- Damage contact stays at effect progress 0.42 for melee, and self-centred sweeps keep their 0.24 s / 0.38 boundary.

## New motions

Polearms (`thrust`) and the bow rest UPRIGHT at the hero's side: tip up, butt near the ground, the fist mid-shaft. Read each weapon's rest axis from its landmarks; do not assume the sword's down-left angle. Every attack returns to that rest pose. Clip weapon directions are absolute screen-space directions, as in `_attack_heavy_pose` (`_gear_place_weapon(pose, layout, key_angle - rest_angle)`).

1. **`thrust` — `attack_thrust`** (hunting_spear, tourney_lance, hookspine_halberd). 34 frames, 0.56 s, contact 0.42.
   - 0.00–0.20: lower the pole from upright to level along the attack line, held at hip height, butt pulled back. Front stab line (−0.894, 0.447); rear (0.894, −0.447).
   - 0.20–0.30: cock. The fist draws back 8 source px along the line; torso +0.06.
   - 0.30–0.42: drive. The fist travels about 26 px forward along the line, with the step-in lunge from `attack_stab` (leading foot 8 px, root 10 px, trailing foot planted).
   - Hold to 0.56, then recover through the lowered pose to upright by 1.0.
   - The pole stays level along the line from 0.20 to 0.62. The offhand braces with forearm_l −0.10 (mirrored for rear) at contact.
   - Effect: reuse the stab thrust streak (`MeleeThrustFx.draw_protagonist_stab`).
2. **`lash` — `attack_lash`** (galewhip). 29 frames, 0.48 s, contact 0.42.
   - The whip hangs down at rest.
   - 0.00–0.30: wind-up. The right arm rises up and back, the wrist about 20 px above and 6 px behind the shoulder, and the whip direction swings up and back over the weapon-side shoulder: front (−0.30, −0.95), rear (0.30, −0.95).
   - 0.30–0.42: snap. The arm whips forward to shoulder height along the attack line, and the whip direction swings over the top to the line.
   - Then follow-through low and recover by 0.90.
   - Effect: a new `MeleeLashFx` draws, from 0.36 to 0.62, a curved crack from the hand to the target. Make it a quadratic curve bowed 18 px upward, 3 px warm-white core under a 6 px teal (`Color(0.55, 0.85, 0.80)`) glow with the existing envelope, plus a small crack burst at the target at 0.42.
3. **`bow` — physical ranged shots** (stormstring_bow).
   - Keep the existing `shoot` timing and right-arm aim, but do NOT show the generic crossbow; the bow stays visible.
   - While aiming, hold the bow perpendicular to the aim (limbs vertical on screen, string toward the hero) by setting the weapon angle relative to the hand.
   - The LEFT hand reaches to the string beside the bow grip by phase 0.24, draws back 10 px toward the chest by 0.38, and releases at 0.42. The shield or dagger stays on the left forearm.
   - The projectile origin is the bow grip plus 6 px forward along the aim, released and unreleased, front, rear and mirrored. Extend `renderer.source_socket`.
4. **`repeater` — physical ranged shots** (windlass_repeater). This weapon IS a crossbow.
   - The existing right-arm `shoot` aim, with the generic crossbow hidden and the repeater kept visible and aimed along the aim direction (the weapon angle follows the aim).
   - The projectile origin is the repeater's `weapon_grip.tip` (muzzle).
   - Recoil as in `shoot`.
5. **Melee cards with a bow or repeater equipped** use the `sword` cut (a bash) with the equipped weapon. Magic ranged attacks keep `cast` for every weapon.

## Wiring

- `gear_visuals.gd`: accept the motions `thrust`, `lash`, `bow` and `repeater`. Add `ranged_motion(equipped) -> String` returning `"bow"`, `"repeater"` or `""`.
- `motion.gd`: add `attack_thrust` and `attack_lash` to `clip_specs` and `sample_pose`, and add a bow/repeater shooting variant. Existing clips must be byte-identical, as the existing pose regression tests check.
- `renderer.gd`: map `attack` to the weapon's clip as now (`thrust` → `attack_thrust`, `lash` → `attack_lash`; `bow`/`repeater` → `attack`). Map `shoot` to the bow/repeater variant when that weapon is equipped.
- `attack_fx_library.gd`: frame counts come from `clip_specs`.
- `run_scene.gd`: carry the weapon motion and ranged motion on the effect, as `protagonist_weapon_motion` is carried today.
- `combat_board_view.gd`: dispatch the thrust and lash effects.
- Do not change resolver results, damage-once, sounds, analytics or saves.

## Proof

- Suites:
  - landmark-driven tests for each new clip: grip registration within 0.001 px, painted lengths, planted feet, contact at 0.42, the offhand visible throughout;
  - pole level from 0.20 to 0.62;
  - lash snap direction;
  - bow perpendicular to aim and string-hand position;
  - repeater aimed and generic crossbow hidden;
  - muzzle sockets for bow and repeater, including mirrored.
- The full suite, the production-only PCK build and the export-template run, with exact PASS lines.
- Extend `tests/protagonist_gear_motion_probe.gd`:
  - spear, lance, halberd thrust southwest and northeast at 0.20, 0.30, 0.42, 0.58;
  - galewhip lash at 0.20, 0.36, 0.42, 0.58;
  - stormstring bow and windlass repeater shots southwest/northeast at 0.24, 0.42, plus one mirrored southeast;
  - Worldbreaker heavy and Duelist Rapier stab at 0.42.
- Native capture is the design owner's: confirm the probe parses and give the runner command.

## Revision after native review

The design owner replaced item 3's two-hand bow draw with a one-arm aim, because the hero's left arm cannot reach a bow held at arm's length and the pulled-in compromise did not read. The poles and bow now rest in the owner's steep outward carry instead of upright (unit 5). See `spec/protagonist_ranged_animations.md` and `spec/protagonist_cutout_runtime.md`.
