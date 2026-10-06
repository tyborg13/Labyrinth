# Unit 3 (round 2): one-handed weapons, main-hand crossbow, full boots

Owner review of round 1 (2026-10-06): the slice is a good first pass but not yet release quality. This unit covers the runtime and motion changes. Art fixes (held-perspective shields, a properly gripped parrying dagger, full boot shafts) arrive separately as data at the registry paths. The design owner has already updated `gear_visuals.json` for the maul and knife grips, the maul's `hands: 1`, and the dagger's removed `hide_in_clips`.

## Owner decisions

- **Every main-hand weapon is one-handed for now.** The offhand (shield, parrying dagger) stays equipped and visible in idle, walking, attacks, casting, shooting, blocking and reactions. Two-handed weapons may come back later; nothing in the slice uses `hands: 2`.
- **Ranged shots use the main hand.** In idle he holds his main weapon. When he shoots, the main weapon disappears and the crossbow appears in the RIGHT hand for the shot, then the weapon returns. The offhand never fires a secondary weapon.
- **Boots are complete boots.** The boot shaft is painted on the shin pieces, so the boots slot also owns `shin_r` and `shin_l`.

## Change

1. **One-handed heavy slam.** Rework `attack_heavy` (43 frames, 0.72 s, contact at 0.42) so only the right arm holds the maul.
   - Keep the U2 body keys (torso lean, hips drop, root shift), the maul directions and the timing curve: the owner liked the animation.
   - Delete the off-hand-on-haft solve.
   - Right-wrist targets, front facing:
     - gather 0.12: (106, 118);
     - apex 0.30–0.36: (118, 76), with the maul back over the shoulder as in U2 (direction (0.55, −0.83)), so the hammer head shows beside the hair;
     - contact 0.42–0.58: (96, 134), with the head on the floor ahead-left;
     - lift 0.72: (94, 130).
   - Rear: mirror the logic with the rear joints, as before.
   - Adjust any target by up to ±6 px for painted reach and report it.
   - The left arm braces with the shield: forearm_l −0.12 rad (front sign; mirror for rear) at contact, easing back by 0.80. The shield stays visible throughout.
   - The weapon geometry comes from the registry `weapon_grip`. The maul's landmarks changed: its grip now shows the pommel cap above the fist.
2. **Main-hand crossbow.**
   - Move the protagonist's crossbow from the off hand to the right hand. Reuse the existing painted crossbow PNGs, front and rear: their shapes already point forward (front: grip at the right end, muzzle down-left; rear: grip bottom-left, muzzle up-right). Register each crossbow's grip on the right fist (`weapon_r` joint).
   - You may move the `crossbow` layout part to a new `crossbow_r` bone under `hand_r` and update both layout JSONs. That changes only the crossbow's bone, offset and the attachment metadata; no other paint, part or rest source changes. Then update the rig-data and ranged tests that assert the old off-hand registration.
   - `shoot` now drives the RIGHT arm: raise and aim it at the target using the existing straight-arm solve. Front aim is (−1, −0.2), rear aim is (1, −0.3). Keep the existing timing, recoil and preparation. The left arm stays at its rest pose, with the offhand visible.
   - During the window where the crossbow is visible, hide the main weapon (`weapon_r`).
   - The projectile origin (`renderer.source_socket(shot=true)`, released and unreleased) now comes from the right-hand crossbow's muzzle. Keep reflection for mirrored facings, and keep projectiles starting at the visible muzzle.
   - Reduced motion: the still raised crossbow pose now uses the right arm.
   - `cast` is unchanged (left hand, offhand stays on).
3. **Offhand always visible.**
   - Remove the gear layer's `hide_in_clips` mechanism: it is now dead code.
   - Remove the two-handed offhand hiding: `is_two_handed` stays as an API for later but is false for every slice item, and the clip no longer needs a two-hand grip path.
   - `block_shield` still applies whenever a shield is drawn. A held offhand (dagger) uses the existing weapon-guard `block`.
4. **Boots own the shins.**
   - Add `shin_r` and `shin_l` to the boots slot's replaceable parts in `gear_visuals.gd`. Rear shins are skinned meshes, so the existing same-size validation applies.
   - The design owner adds the shin entries to the registry when the art is approved. Until then the suite must pass with the boots' current entries.

## Keep

- Sword and stab clips; contact boundaries; sweep timing; resolver, damage-once, sounds and analytics.
- Gear layer rules from U0 and U2: attachments ignore bone scale and skew, and `weapon_grip` is copied per rig.
- Enemy rigs unchanged.
- The cutout runtime must not depend on the rules/data layer (the production-only PCK smoke check must pass).
- Windows typed-array rule; no idle ripple.

## Proof

- Update and extend the gear, gear-motion, protagonist cutout and ranged suites:
  - one-handed heavy (right wrist on the grip landmark, painted lengths, planted feet, contact at 0.42);
  - the offhand visible in every clip for shield and dagger loadouts;
  - weapon_r hidden only while the right-hand crossbow is visible in `shoot`;
  - the muzzle socket at the right-hand crossbow muzzle, front, rear and mirrored;
  - boots replacing shins.
- Run the full suite and the production-only PCK build plus the export-template run, and report the exact PASS lines.
- Update `tests/protagonist_gear_motion_probe.gd` to capture:
  - L1 (War Maul + Ward-Kite) heavy attack southwest and northeast at 0.12, 0.30, 0.36, 0.42, 0.58 and 0.85, with the kite visible;
  - L0 and L2 `shoot` southwest and northeast at 0.42 (right-hand crossbow, offhand visible), plus mirrored southeast for L0;
  - L0 `cast` front.
- Native capture is pending with the design owner; check that the probe parses and give the runner command.
- Update `spec/protagonist_ranged_animations.md` (the crossbow is now main-hand) and the "Visible equipment" / "Weapon and shield motion" sections of `spec/protagonist_cutout_runtime.md`.
