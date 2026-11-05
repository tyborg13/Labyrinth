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

**The path.** Every melee strike draws a trail along the attacker's real strike path. That path is the weapon tip (or claw, chain end or spear point), sampled from the attacker's own attack clip at the same attack progress and facing the body is rendering. Hero `protagonist_melee` effects include ordinary melee, Whirlwind Slash and Spear Thrust area deliveries. Self-centred swings use the body's held facing and mirror, rather than inferring facing from their zero-length target vector. The source cache is keyed by that displayed facing, gear revision and motion. Area attack cadence already remaps effect progress to attack progress in `RunScene`; the trail consumes that same presented phase. It does not change the existing area result boundary or sounds. `review/00_real_tip_paths.png` shows the hero's real tip paths; red is wind-up, yellow the strike, blue the follow-through.

**Trail kinds:**

| Kind | Used by | Drawing |
| --- | --- | --- |
| `sweep` | sword, heavy, bow/repeater bash, whip, and blade or club wielders | A crescent smear between the tip path and a point part-way down the weapon. Its reach narrows toward the tail, so it hugs the tip path. |
| `streak` | dagger stab, spear thrust, and enemy spears | A speed streak behind the tip along the weapon axis, with two thinner side lines. |
| `rake` | claws (crawler, dragons, clawed guardians) | Three bold, tapered contact claw marks revealed over .36–.44. Dragon per-tile area rakes retain their approved sweep profile. |
| `arc` | attackers with no strike point (Lightning Wisp, sprite-lunge enemies, illusion echoes) | A synthetic crescent at the target, oriented by the attack direction. |

**Timing:**
- The trail appears with the strike and is brightest at contact (progress 0.42, unchanged).
- Its tail covers the last 0.14 of attack progress behind the tip. It fades out within 0.08 of progress after the strike window ends.
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

## fx-06 owner-directed pass (2026-11-04)

- Gust Shrike Dive uses the same target arc as Talon Rake. Vaeloryx Razor Dive uses the same sampled claw point and contact claw marks as its direct strike in Eye of the Storm. These are data opt-ins (`area_strike_intents`) in the attackers' strike-point settings, read generically; other dragon target-tile rakes and the bespoke effects above keep their existing dispatch.
- One hero strike submits one trail and one contact glint, independent of the number of hit tiles. Reduced motion suppresses these area trails as it does ordinary melee.
- Contact stays at attack progress **0.42**. The existing area effect/body phase remapping and damage timing are unchanged.
- **Coarse frame exposure (round 1):** self-centred melee areas keep their existing six-frame body playback, duration and damage/sound cadence. Their .333 → .500 effect step crosses attack progress .42, skipping the lit contact pose. The effect carries its actual frame count; a trail crossing contact by more than its rolling tail retains the path since the prior rendered body pose, exposes it at the existing peak and carries its single contact glint to that first visible contact frame. The crossed path is sampled at equal distances with the same triangle construction so a held follow-through cannot consume the alpha taper. Its leading tip still ends on the currently drawn weapon. Ordinary fine-step melee and the approved brightness values remain unchanged.


Approved brightness data lives at the top of `scripts/strike_trail_fx.gd`:

| Constant | Value |
| --- | --- |
| `TAIL` | 0.14 |
| `FADE` | 0.08 |
| `SWEEP_CORE_ALPHA` | 1.0 |
| `SWEEP_GLOW_ALPHA` | 0.26 |
| `SWEEP_TAIL_RIM_BLEND` | 0.45 |
| `TIP_RIBBON_WIDTH` | 2.4 |
| `RIBBON_GLOW_ALPHA` | 0.28 |
| `CONTACT_GLINT_RADIUS` | 14.0 |
| `CONTACT_GLINT_GLOW_ALPHA` | 0.26 |

The axial streaks, rake ribbons, claw marks, spark emission/drift/lifetime (0.10), and all element palettes retain their existing treatment. The shared tail/fade window and glint use the approved data above. Triangles remain combined into one glow submission and one core submission.

### Verification and director proof

Focused headless board/geometry registration checks cover all 17 weapons in all four held facings, ordinary and self-centred area swings, the remapped body phase, reduced motion, the two enemy dives and unchanged bespoke/per-tile routing:

```sh
python3 tools/godot_task_runner.py --task-id fx-06 --stream -- godot --headless --path . --script /private/tmp/labyrinth_codex/fx-06/tools/strike_trail_test.gd
```

The existing `tests/strike_trail_probe.gd` also captures self-centred area swings and the new fade endpoint. Native before/after tooling and the preserved original trail sources are in `/private/tmp/labyrinth_codex/fx-06/`. It stages baseline/current source overlays in that evidence directory, uses the same real Continue/RunScene fixture as fx-05, keeps the source worktree unchanged, and invokes `tools/visual_probe_runner.py` for both native takes at 1920x1080 / 100% UI scale, cel look on, true speed. The paired reel puts before left and after right, preserving each fx-05 crop at its original clip size. It rejects differing frame counts, crop rectangles or strip-frame offsets. The final side-by-side media is 3840x1080; each native proof frame is 1920x1080.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fx-06 && python3 -B /private/tmp/labyrinth_codex/fx-06/tools/strike_reel.py --before-after --output /private/tmp/labyrinth_codex/fx-06/native-pair-round1
```

`--check-playback` runs the same selected 54 strikes headlessly and emits `observations.json` with measured batch counts, explicitly labelled as headless evidence. Native clips and strips require the design owner's window server. No visual verdict is inferred from headless batches.

**Retired:** the old slash sheet and `MeleeThrustFx`. No runtime user remains; the sheet is removed from loading and the asset inventory.

The prototype that produced the review sheets is in `prototype/`. It is reference only; the production version is procedural GDScript.

## Units

| Unit | Brief | Owns |
| --- | --- | --- |
| 1 | `unit_1_trail_core_and_hero.md` | Trail module, hero and illusion integration, element palettes, spear haft depth, tests and proof probes |
| 2 | `unit_2_enemy_trails.md` | Per-enemy strike points and kinds, enemy dispatch, dragon physical areas, tests |

Unit 2 starts after unit 1 is reviewed, because both touch the melee dispatch in `scripts/combat_board_view.gd`.

Round-1 diagnostics live in `/private/tmp/labyrinth_codex/fx-06/tools/trail_diagnostics.gd`, called per frame for the two reported Whirlwind cases by the real fight capture. They record raw/effective envelope, screen-space tip bounds/length, canvas ancestry/modulation, floor order, and submission/draw revisions. Headless evidence explicitly does not confirm renderer draws. Native capture emits `capture/trail-frames.jsonl`.

Each native take also emits `hero_strips/<id>.png` for all Quick Stab / Whirlwind Slash cases: eight distinct source frames from effect progress .30–.60, 560x480 per cell, 4480x480 per sheet, with no scaling. `hero_strips/index.json` records native movie frame, effect progress and exact crop per cell. New takes measure the live hero center; old accepted takes use the unchanged fixture's measured center (960,395). Repeated held poses remain distinct movie frames. The focused trail test is temporary tooling, with no permanent repository test module.
