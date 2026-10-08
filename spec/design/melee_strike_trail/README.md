# Melee strike trail

## Goal

The old melee effect is one painted crescent (`assets/art/effects/melee_slash_sheet.png`, six frames). It is placed between the attacker's and target's tile centres and only flips left or right, so it never follows the actual swing: not a dagger stab, a spear thrust, an overhead maul slam or a whip. The owner asked for an effect that "looks good, has some pizzazz, fits with our visual identity" and looks right "no matter what different attack we're doing".

## Owner decisions (2026-10-07)

1. **Treatment A, "warm ember light"** (`review/01_trail_styles_board_scale.png`, top row).
   - An additive warm light that glows over the board instead of muddying it.
   - Animated references: `review/02`–`06`.
2. **Elemental melee tints the trail.** Owner: "Hell yes".
3. **Enemies move onto the same system** in this pass.
4. **Spear haft depth.** While attacking, the spear haft must draw behind the torso, since the spear is held at the hero's side (`review/07_spear_haft_depth.png`).

## The design

**The path.** Every melee strike draws a trail along the attacker's real strike path. That path is the weapon tip (or claw, chain end or spear point), sampled from the attacker's own attack clip at the same effect progress the board is rendering. `review/00_real_tip_paths.png` shows the hero's real tip paths; red is wind-up, yellow the strike, blue the follow-through.

**Trail kinds:**

| Kind | Used by | Drawing |
| --- | --- | --- |
| `sweep` | sword, heavy, bow/repeater bash, whip, and blade or club wielders | A crescent smear between the tip path and a point part-way down the weapon. Its reach narrows toward the tail, so it hugs the tip path. |
| `streak` | dagger stab, spear thrust, and enemy spears | A speed streak behind the tip along the weapon axis, with two thinner side lines. |
| `rake` | claws (crawler, dragons, clawed guardians) | Three bold, tapered contact claw marks revealed over .36–.44. Dragon per-tile area rakes retain their approved sweep profile. |
| `arc` | attackers with no strike point (Lightning Wisp, sprite-lunge enemies, illusion echoes) | A synthetic crescent at the target, oriented by the attack direction. |

**Timing:**
- The trail appears with the strike and is brightest at contact (progress 0.42, unchanged).
- Its tail covers the last 0.10 of effect progress behind the tip. It fades out within about 0.06 of progress after the strike window ends.
- One impact accent at contact: a four-point glint at the strike point, about 0.10 of progress long.
- Contact, damage-once and sounds are unchanged. Reduced motion draws no hero or ordinary enemy strike trail; dragon physical areas retain static, fully revealed claw marks per target tile. Bespoke effects keep their existing reduced presentation.

**Look:**
- **Additive light.** A soft wide glow pass under a sharp core pass.
- **Leading edge:** warm white. **Body:** amber. **Tail:** ember-red, fading out.
- **Sparks:** a few small ember sparks shed from the tip and drift with age. They are deterministic, a pure function of progress and an effect seed.
- **Scale:** every size is in attacker source pixels times the board's unit scale, so trails scale with zoom and art scale.

**Palettes**, as edge / core / rim:

| Element | Edge | Core | Rim |
| --- | --- | --- | --- |
| none | (255,244,220) | (255,178,92) | (150,60,20) |
| fire | (255,236,200) | (255,128,48) | (170,40,10) |
| ice | (236,250,255) | (140,210,255) | (40,90,150) |
| lightning | (248,240,255) | (186,150,255) | (80,50,170) |
| air | (240,255,246) | (150,230,200) | (40,110,90) |
| earth | (255,240,214) | (214,160,96) | (110,70,30) |

**Kept as they are:** the enemy effects that already follow their own attack.
- Grave Surgeon saw jab
- Veilbound Acolyte shadow fingers
- Cinder Droplet fire impact
- Cinder Ooze molten contact
- Vyraketh bite

**Retired:** the old slash sheet and `MeleeThrustFx`. No runtime user remains; the sheet is removed from loading and the asset inventory.

The prototype that produced the review sheets is in `prototype/`. It is reference only; the production version is procedural GDScript.

## Units

| Unit | Brief | Owns |
| --- | --- | --- |
| 1 | `unit_1_trail_core_and_hero.md` | Trail module, hero and illusion integration, element palettes, spear haft depth, tests and proof probes |
| 2 | `unit_2_enemy_trails.md` | Per-enemy strike points and kinds, enemy dispatch, dragon physical areas, tests |

Unit 2 starts after unit 1 is reviewed, because both touch the melee dispatch in `scripts/combat_board_view.gd`.
