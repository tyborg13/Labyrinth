# Unit 6: Side carry depth and a real grip

Owner review of the full pass (2026-10-06): "generally they look quite good ... pretty close to a place where I'm happy getting this into the game". Two layering fixes, both approved on mockups:

1. **Side carry.** A carried weapon is held off to his side, so its lower end (a pole's butt, a hanging censer, a bow's lower limb) must pass BEHIND his near leg and foot, not in front of them. In the FRONT facing, while carrying, the weapon body draws at z 8: behind both legs (foot_r 9, thigh_r 10, shin_r 11, knee_cover_r 12), the hips, the torso and the arms, and in front of the cape (0). It returns to z 66 for any clip in which the weapon is used in front of him. Owner-approved mock: `review/unit6_side_carry_spear.png`.
2. **Grip: shaft over the palm, under the fingers.** "It needs to be drawn over the palm but under the fingers essentially." Owner-approved mock: `review/unit6_grip_mock.png` (top row).

## Layers (both facings)

| Layer | z | Node |
| --- | --- | --- |
| Glove (`hand_r`, the whole painted fist) | 65 (was 67) | existing sprite |
| Weapon grip piece | 66 | new Sprite2D child of `weapon_r`, same offset as the weapon texture |
| Weapon body | per-clip policy below | existing `weapon_r` sprite (gear replacement or default sword) |
| Fingers (`hand_r` lit knuckles and their outline) | 67 | new Sprite2D child of `hand_r`, same offset as the glove |
| Main-hand crossbow (`crossbow_r`) | 66 (unchanged) | the shaft crosses the palm under the fingers like any weapon |

Textures are derived by `tools/process_gear_visual_assets.py` (already done):
- **Fingers:** `assets/units/protagonist_cutout/{front,rear}/hand_r_fingers.png`.
- **Default-sword grip piece:** `{front,rear}/weapon_r_grip.png`.
- **Every registered weapon's grip piece:** the replacement file's stem plus `_grip.png`, e.g. `gear/war_maul/front_weapon_r_grip.png`. Derive the path by that convention; no registry key is needed.

All are `keep` imports. The grip piece is the weapon texture masked to the handle zone, so it is pixel-aligned with the weapon. Show it only while the weapon body is NOT at z 66; at 66 the full weapon already covers the palm.

## Weapon body depth policy

- **Front, carry clips** (`rest`, `idle`, `walk`, `hit`, `death`, `cast`, `block_shield`): z 8.
- **Front, use clips** (`attack`, `attack_heavy`, `attack_stab`, `attack_thrust`, `attack_lash`, `block` (the weapon guard), `shoot`, `shoot_bow`, `shoot_repeater`): z 66.
- **Rear:** unchanged. z 5 in every clip, except z 66 while `shoot_bow`/`shoot_repeater` is active (the existing override).
- **Reduced motion:** use the shown clip's policy (the rest still is a carry clip; the ranged still is a use clip).

Generalise the existing rear shot override into this per-facing, per-clip policy in one place (`gear_carry.gd` or a small new helper). Restore it on clip exit, on rig hide and on `apply_gear({})`. Apply it to the default sword and to every registered weapon. The repeater and bow follow the same rules.

## Keep

- All poses, timings, contact boundaries, sockets, analytics and saves unchanged. This unit is draw order and two overlay sprites only.
- Enemy rigs unchanged. Rules-free cutout runtime. Windows typed-array rule.

## Proof

- Update the suites for:
  - the front carry z 8 and use z 66 per clip;
  - rear z 5 except the bow/repeater shot at 66;
  - the grip piece visible only while the body is not at 66, and aligned with the weapon (same parent and offset);
  - the glove at 65 and the fingers at 67 in both facings;
  - the restore on clear and on rig hide;
  - legacy poses unchanged.
- The default rest image changes (the sword now sits behind the leg, with the grip), so the design owner re-bakes it with the gear probe's `--write-default-rest` and regenerates the shadow cache. Keep the asset tests passing with whatever the owner bakes.
- Run the full suite, the PCK build and the export-template run, and report exact result lines. Check that the probes parse; native capture is the design owner's.
