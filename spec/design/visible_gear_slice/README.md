# Visible gear on the protagonist — vertical slice

Owner request (2026-10-05): equipment the player equips must appear on the
protagonist cutout everywhere he is drawn. Build a slice with the default plus
two meaningfully different alternates in every equipment slot, judge it in game,
then decide whether to do all 72 items.

Design owner: Claude. Implementation: Codex units below. Art: Codex image runs,
approved by Claude, provenance in `spec/assets/visible_gear_slice/`.

## Owner decisions

> **Superseded in part by round 2 (see the end of this file).** All weapons are now one-handed with the offhand always on; the crossbow is main-hand; front shields draw at z 72 and rear offhands at z 6. Round-1 statements below about two-handed weapons hiding the offhand and rear offhands at z 73 are historical.

- **The cloak, mantle and face scarf are the hero's identity** and stay on for every
  armor. Armor replaces only the torso, both sleeves and the belt/hip piece.
  Hands, trousers, knees and head are never replaced by armor.
- **Every weapon type gets its own attack**: a chunky two-handed swing for heavy
  weapons, a quick stab for daggers, the existing cut for swords.
- **The offhand stays on during cast, shoot and block.** A two-handed weapon
  hides the offhand entirely (both hands are on the weapon).

## Slice items

| Slot | Default (starter) | Alternate 1 | Alternate 2 |
| --- | --- | --- | --- |
| Weapon | Training Sword (existing sword art, `sword` cut) | War Maul (`heavy`, two-handed) | Sawtooth Knife (`stab`, one-handed) |
| Offhand | Splintered Shield (new art) | Ward-Kite (kite shield) | Parrying Dagger (held in the fist) |
| Armor | Patched Cloak (existing leather art) | Undertaker Plate (dark steel) | Cinderweave Mail (black mail, ember glow) |
| Boots | Skirmisher Boots (existing) | Ironshod Sabatons (steel) | Emberstriders (red, ember glow) |
| Trinket | Cracked Lantern (new art, right hip) | Crown of Thorns (head) | War Dancer's Sash (waist) |

The starting hero now visibly carries the Splintered Shield and the Cracked
Lantern, because those are equipped from the start. Items outside the slice show
their slot default's visual until the full pass. An empty offhand or trinket slot
draws nothing.

## Data and layering contract

`assets/units/protagonist_cutout/gear_visuals.json` (authored by the design owner)
is the source of truth: per item, per facing, `replace` entries (swap a named
rig part's texture, optionally with a new source offset for rigid parts) and
`attach` entries (an extra rigid sprite on a named bone with a source offset and
a global `z_index`). All coordinates are global 255-px source-canvas pixels,
the same space as `front.json`/`rear.json`.

Ownership is disjoint, so items combine without per-combination art:

| Slot | Owns |
| --- | --- |
| Weapon | `weapon_r` (replace) |
| Offhand | one attachment: shields on `forearm_l`, held items on `hand_l` |
| Armor | `torso`, `arm_r`, `arm_l`, `hips` (replace) |
| Boots | `foot_r`, `foot_l` (replace) |
| Trinket | one attachment on `hips` or `head` |

Skinned parts (`arm_r`, `arm_l` in both facings) keep their mesh: a replacement
texture must have exactly the original crop size, because every protagonist mesh
spans its full crop rectangle.

Rear offhands draw above the cloak (`z_index` 73). The far arm is hidden under
the cloak in the rear view, and the owner must still see the shield when walking
north.

## Units

| Unit | Brief | Owns | Depends on |
| --- | --- | --- | --- |
| U0 | [Gear visual runtime](unit_0_gear_runtime.md) | rig/renderer gear layer, board/illusion/character-screen wiring, rest bake, fixture, probes | registry + stand-in art (done) |
| U1 | [Weapon and shield motion study](unit_1_weapon_motion_case.md) | `experiments/cutouts/protagonist_gear/` cases only | stand-in art (done) |
| U2 | [Weapon and shield motion in combat](unit_2_motion_integration.md) | `motion.gd` clips, renderer clip choice, melee timing, thrust trail | U0, U1 |
| U3 | [Round 2: one-handed weapons, main-hand crossbow, full boots](unit_3_round2_motion.md) | `motion.gd`, rig/renderer ranged socket, layouts' crossbow bone, gear slots | owner review 2026-10-06 |
| Art | Final paint replaces stand-ins at the same paths | `assets/units/protagonist_cutout/gear/**` | image review |

U0 and U1 run in parallel: U1 touches only its experiment cases.

## Mockups

- `mockups/standin_loadouts.png`: the target composite for four loadouts, front and rear, using stand-in art (flat placeholder shapes and recolored parts). Final art replaces the stand-ins at the same paths and sizes.
- `mockups/placement_front.png`, `mockups/placement_rear.png`: placement studies.
- `mockups/front_joints.png`, `mockups/rear_joints.png`: joint positions on the rest pose (4x, 10-px grid).
- `baseline/`: current master captures of the combat board and the Character screen.

## Round 2 (owner review 2026-10-06)

Kept: Undertaker Plate, Cinderweave Mail and the accessories ("slots in perfectly"), the War Maul art and slam.

Fixed:
- **Shields:** flat and face-on, too small and blurry. They are re-painted strapped side-on to the forearm, about 30% larger, with crisper reduction.
- **Parrying dagger:** looked like a hidden blade. It is re-painted with the grip through the fist, the pommel above it and the guard below.
- **Maul and knife grips:** the haft ended inside the fist. They slide 9 px and 4 px along their axes so the pommel shows above the fist, as the sword's does.
- **Boots:** only the feet were replaced, which made half-boots. The boots slot now also owns the shins.
- **Weapons:** all are one-handed for now and the offhand is always visible.
- **Crossbow:** moves to the main hand for shots.

Round 2 follow-ups (owner, 2026-10-06):
- **Shield size:** 1.5× the round-2 size. Round shield 50×75 front, kite 46×96 front.
- **Front shields:** drawn over the cloak and mantle (z 72), under the scarf and head.
- **Rear offhands:** behind the whole body (z 6, below the far arm's z 7), so only the rim shows past the silhouette.
- **One-handed maul apex:** goes over the weapon-side shoulder. The rear apex sits lower so the head stays under the HP bar.
- **Pixel density:** every gear texture passes through `consolidate` in `tools/process_gear_visual_assets.py` (posterise to 24 colours, 3×3 mode filter, orphan cleanup), so it clusters like the hero's own paint. The owner compared Kuwahara and mode-filter variants on the hero and chose this one for consistency with the original sprite, accepting the loss of Cinderweave Mail's fine ring texture.

## Full pass (owner request 2026-10-06: all 72 items before done)

Every item in `data/equipment.json` now draws its own art. New weapon motions (unit 4): `thrust` (spear, lance, halberd), `lash` (galewhip), `bow`, and `repeater` (the weapon is the crossbow). Unit 5 and its follow-up:
- **Rear weapons:** draw behind the whole body (z 5); a bow or repeater shot draws in front (z 66) while aiming.
- **Long weapons:** poles and the bow use the owner's steep outward carry, through the fist with the head up past the near shoulder and the butt by the foot, never crossing the body; the fist turns to hold them.
- **Bow shot:** a one-arm aim like the crossbow, because the hero's arms are too short for a two-hand draw.
- **Parrying dagger:** the fist is cut out of the texture so it reads as gripped.
- **Robe-style armor:** hips pieces keep their natural mid-thigh length.

Redone after design-owner review: Galewhip, Parrying Dagger, Basalt Pavise, Grapple Hook, Trapdoor Spurs, Cloudstep Sandals, and the four long weapons (the lance redesigned as grim, per the owner). Review sheets: `review/full_*.png`.
