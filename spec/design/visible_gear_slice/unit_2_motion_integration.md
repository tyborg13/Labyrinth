# Unit 2: Weapon and shield motion in combat

## Header

- Read the [README](README.md), [Unit 0](unit_0_gear_runtime.md) and [Unit 1](unit_1_weapon_motion_case.md) briefs first. Unit 0 is committed: `gear_visuals.gd`, the rig gear layer, the renderer's `set_gear`/`weapon_motion()`/`offhand_kind()`, board and Character wiring, and the final gear art.
- Source of the new clips: the Unit 1 study cases in `experiments/cutouts/protagonist_gear/{heavy,stab,shield}_v01/motion.gd` (the dispatch and helpers at the end of each file) and their review notes. Design-owner review captures of those cases: `review/unit1_heavy_front.png`, `review/unit1_heavy_rear.png`, `review/unit1_stab.png`, `review/unit1_shield_front.png`, `review/unit1_shield_rear.png` in this folder.
- Code involved: `scripts/protagonist_cutout/motion.gd`, `scripts/protagonist_cutout/rig.gd`, `scripts/protagonist_cutout/renderer.gd`, `scripts/attack_fx_library.gd`, `scripts/run_scene.gd` (the melee `effect` dictionary near `"protagonist_melee"`, and `_protagonist_attack_motion`), `scripts/combat_board_view.gd` (melee trail drawing near `harrier_thrust`).
- Production must not depend on `experiments/`: port the code, do not preload it.

## Change

1. **Rigid attachments never inherit bone scale or skew.** Today a gear attachment is a plain child of its Bone2D. In the rear `cast`/`shoot` the left-arm bones carry a foreshortening scale, which stretches the shield into a wide smear (see `review/unit1_shield_rear.png`, `cast 042` and `shoot 042`). Make every gear attachment follow its bone's position and rotation only, keeping its native pixel size and the rig's mirroring. Do it once per applied pose: no per-frame allocation, no change to bone transforms. Add a test asserting that the shield's effective scale stays (±1, 1) in rear `cast` and `shoot` at 0.42.
2. **Port the three clips** into production `motion.gd` (`clip_specs` and `sample_pose`): `attack_heavy` (43 frames, 0.72 s), `attack_stab` (24 frames, 0.40 s) and `block_shield` (25 frames, 0.30 s, through the reaction path like `block`). Existing clips must produce identical poses. Apply these design-owner changes to the Unit 1 keys:
   - **Heavy apex visibility.** At 0.30 and 0.36 the straight-up maul hides behind the hair, so the windup barely reads. Front apex direction is (0.55, −0.83): up and back over the screen-right side. Rear apex direction is (−0.55, −0.83). Most of the haft and the whole hammer head must be visible beside the head, not behind it. Keep both wrists on the haft with painted lengths (adjust the right wrist by at most 6 px and report it). The 0.36 → 0.42 slam then travels over the top in about four frames.
   - **Stab commitment.** Front cock at 0.30: root Δx +2, torso +0.06. Contact 0.42 to 0.54: root Δx −6, hips +2, torso −0.10. Rear: mirrored root, same hips, torso sign as the existing rear sword attack. Wrist targets stay as authored.
   - Everything else as authored in Unit 1.
3. **Weapon landmarks without mutating shared data.** The sampler reads `weapon_grip` (`assembled`, `tip`, `pommel`) from the rig layout. `layout` is shared through `RigData`'s cache. When `ops_for_facing` supplies a `weapon_grip`, the rig must use a per-rig copy carrying that override (copy-on-write) and must never write into the shared dictionary. With no gear override, the base layout is used unchanged.
4. **Renderer clip choice** (`renderer.gd` `present`):
   - A requested `attack` plays `attack` (`sword`, with the existing `attack_pose_phase` remap), `attack_heavy` (`heavy`) or `attack_stab` (`stab`). The two new clips use an identity phase. Phase ≥ 1 returns to idle exactly as `attack` does today.
   - A `block` reaction plays `block_shield` when `offhand_kind() == "shield"`, otherwise the existing `block`.
   - Reduced motion keeps today's behaviour: the neutral rest still, with gear.
   - `snapshot()` reports the clip actually played.
   - Self-centered weapon sweeps keep their existing 0.24 s / 0.38 timing and retime the archetype pose so its contact (authored 0.42) lands on the sweep's contact, exactly as `_protagonist_attack_motion` does now for the sword.
5. **Effect timing** (presentation only):
   - Where the melee `effect` is built in `run_scene.gd`, add `"protagonist_weapon_motion": GearVisuals.weapon_motion(_run_state.get("equipped_equipment", {}))`.
   - `AttackFxLibrary.animation_frame_count`/`animation_frame_seconds` for `protagonist_melee` single-target melee: `sword` 30 frames (unchanged), `heavy` 43, `stab` 24, all at 1/60 s. Reduced motion stays 1 frame / 0 s.
   - The damage/contact boundary stays at progress 0.42 for all three. Resolver results, damage application, sounds and analytics are unchanged.
6. **Stab trail.** For `stab`, replace the slash arc with a short straight thrust streak along the attack direction: from 22 px before the contact point to 8 px past it, 2 px wide, warm steel colour `Color(0.85, 0.80, 0.70)`, alpha `sin(t × π) × 0.6`, drawn only during the existing trail window. It is the same treatment as the existing `harrier_thrust` streak; share a helper rather than duplicating it. `sword` and `heavy` keep the existing slash arc.

## Keep

- All existing protagonist clips, timings, facings, reflection and idle-return rules (the existing pose-regression and ranged suites must pass unmodified).
- Gear layer behaviour from Unit 0, including visibility rules.
- Enemy cutouts, illusion action ownership, analytics, saves, rules text, input paths.
- No idle ripple. Windows typed-array rule.

## Proof

- Extend `tests/suites/protagonist_gear_suite.gd` (or a sibling focused suite):
  - heavy contact at 0.42, with both wrists on the haft within 1.5 px of L = R − dir × 9 from 0.08 to 0.68;
  - painted lengths and planted feet within the existing tolerances for all three clips;
  - frame counts per archetype;
  - renderer clip choice for each archetype, including `block_shield` only with a shield and never with a two-hander;
  - the attachment scale assertion;
  - the shared layout untouched after gear with a `weapon_grip`.
- Run the protagonist cutout suite, the gear suite and the full suite; report exact result lines.
- Write a real-renderer gameplay probe `tests/protagonist_gear_motion_probe.gd` (1920×1080 SubViewport, real card play through the existing selection and board-target handlers):
  - L0 Training Sword `quick_stab`, L1 War Maul `crushing_blow`, L2 Sawtooth Knife `sawtooth_flurry`, each attacking an adjacent enemy southwest (front facing) and northeast (rear facing). Capture board frames at effect progress 0.12, 0.30, 0.36, 0.42, 0.58 and 0.85.
  - An absorbed enemy hit with block up for L0 (shield block) and L1 (two-hander: sword-style block).
  - Rear-facing `cast` and `shoot` with L0 (no stretched shield).
  - L1 attack in reduced motion.
  - Assert single damage application per attack.

  Also write 3× hero crops as in Unit 0's probe. This host's Codex sandbox cannot start the macOS GUI renderer: check that the probe parses (`--check-only`), state that native capture is pending, and give the exact `visual_probe_runner.py` command. The design owner will run it.

## Revision after native review (round 2)

The first build's stab barely read at board scale (`review/unit2_stab_combat.png` shows the fix). The design owner replaced items 2 (stab commitment) and 6 (stab trail):
- **Stab body.** Cock at 0.30 keeps root +2 and torso +0.06. From 0.30 the leading foot (`foot_r` in both facings) steps 8 source px along the stab line, lifting 2 px mid-step, landing at 0.40, holding through 0.56 and returning from 0.62 to 0.88. The root moves 10 px along the same line at contact and returns by 0.90. The hips drop is the minimum the planted trailing foot needs: 0 px front, 7.8 px rear.
- **Stab streak.** It runs from 52 px behind to 16 px past contact, as a 7-px warm glow (alpha 0.28) under a 3-px core (alpha 0.85), with the existing trail envelope. A contact spark (two 12-px lines at ±45°) fades between progress 0.42 and 0.55. The harrier keeps its original thin streak.
