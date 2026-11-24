# txt-35 implementation proof

1. Known Moves filters blank parts, attaches condition bonuses and Summon names, and keeps other labeled riders together. The inventory covers all catalog enemies, including those without Grimoire pages. It checks that every line is nonempty and that no line has consecutive separators, a separator at either end, or a separator after a colon or Summon.
2. Nine intent records carry the approved summary verbatim. Last Eclipse and Razor Dive retain generated copy for the resolver reasons below. The generic Summon join still applies to Last Eclipse.
3. The shared Splits trait template uses “On death” and retains its data-driven count, unit and distance. The headless Grimoire probe verifies the exact sentence on Cinder Ooze.
4. Crowncoal Heart preserves the first sentence and uses the approved second sentence. The hover probe opens the owned relic’s production pointer stack and reads “Destroy the target, then deal X damage on that tile and each adjacent tile.” The old wording put the Fire threshold directly after the Burst markup, where the glossary looks for a term’s printed amount. The new wording puts “destroys” between the Burst markup and the threshold and the amount resolves to null. The current fixtures pin the full description. [Glossary amount binding](../../scripts/glossary.gd#L106)

## Authored truth checks

Values below are the raw intent values used for the authored summaries. Move and Retreat show their movement allowances. Melee and Ranged use the existing geometry and damage-chip vocabulary. The live resolver continues to apply its ordinary targeting, terrain, caps and battle modifiers.

| Intent | Reviewed claim | Resolver evidence | Verdict |
| --- | --- | --- | --- |
| Meteorfall | 7 Cinder Marks, Ranged 4 on Fire marks, then a separate Ranged 4 at Range 4 | The first action declares up to 7 tiles using the band selector. The resolver spends that footprint on a 4-damage attack and places Fire. The next action is the separate 4-damage Range 4 shot. [Band selector](../../scripts/dragon_pressure_fields.gd#L14), [Cinder Marks resolver](../../scripts/combat_engine.gd#L7067) | PASS |
| Cinder Maw | Move 2, Melee 8, then 7 Cinder Marks at Ranged 3 on Fire | The intent executes a two-tile approach and the 8-damage melee action before the 7-tile Cinder Marks action. The latter uses the same resolver with damage 3 and Fire. [Action dispatch](../../scripts/combat_engine.gd#L2895), [Cinder Marks resolver](../../scripts/combat_engine.gd#L7067) | PASS |
| Crownfire | Burst 8 at each Cinder Mark, then Move 2 and Melee 6 | Resolves a Burst with 8 damage from the remaining committed Cinder fuel. The approach with allowance 2 and the 6-damage melee action follow in intent order. [Cinder fuel](../../scripts/boss_area_rules.gd#L182), [Cinder detonation](../../scripts/combat_engine.gd#L7091) | PASS |
| Skybreak | 9 Lightning Strikes at Ranged 5, leaving Electrified | The dragon declares up to the specified 9 scatter tiles. The strike resolver attacks the committed tiles using the 5-damage action and its Electrified ground rider. [Declaration](../../scripts/dragon_combat_rules.gd#L83), [Strike resolver](../../scripts/combat_engine.gd#L6886) | PASS |
| Faultline | Burst 8 at each Worldspine, then Ranged 4 at Range 4 | The declaration records the owned Worldspines and their Burst footprint. The resolver uses those centers for Burst 8, destroys the surviving fuel and proceeds to the separate 4-damage Range 4 shot. [Committed sources](../../scripts/boss_area_rules.gd#L139), [Terrain Burst resolver](../../scripts/combat_engine.gd#L6984) | PASS |
| Last Eclipse | Marked Ranged 8, then Eclipse 2 and Summon Veilbound Acolyte | Target selection uses the Marked footprint. The action writes the 2-activation Eclipse into combat state before applying the 8 damage to those targets. The next action can summon one Veilbound Acolyte subject to its cap of 2. [Eclipse resolver](../../scripts/combat_engine.gd#L7188), [Summon resolver](../../scripts/combat_engine.gd#L6892) | FAIL · TODO_DESIGN_last_eclipse |
| Night Coil | Ranged 6, Range 3, Pull 1, area, puts out the nearest brazier | The range-3 line resolves the 6-damage attack with Pull 1. Declaration selects the brazier nearest the player and resolution puts out the brazier with that recorded ID. The glossary has no entry for the object. The Noctyrax Grimoire article already uses lowercase “brazier.” [Declaration](../../scripts/dragon_combat_rules.gd#L93), [Resolution](../../scripts/guardian_combat_rules.gd#L393), [Grimoire copy](../../data/grimoire.json#L771) | PASS |
| Shatterstorm | Move 1, Melee 7, ring with base Range 1, +1 per Crystal Mantle, removes all layers | A one-tile approach precedes the 7-damage ring. Range at declaration is 1 plus the current layers, capped at 4 with the normal limit of 3 layers. The announced ring is held and the resolver clears all layers remaining at resolution. [Status-dependent range](../../scripts/guardian_combat_rules.gd#L547), [Status consumption](../../scripts/guardian_combat_rules.gd#L407) | PASS |
| Hollow Gale | Melee 6, Range 2, Push 1, ring from 1 to 2 | The radial shape starts at its default minimum of 1 and ends at action range 2. The committed 6-damage attack carries Push 1. [Radial shape](../../scripts/committed_pattern_shapes.gd#L75), [Committed attack](../../scripts/guardian_combat_rules.gd#L393) | PASS |
| Eye of the Storm | Retreat 3, Melee 8 at Range 5 with ring from 2 to 5, then Melee 4 | The retreat allowance is 3. The radial resolver uses minimum 2 and maximum 5 for the 8-damage action. A separate ordinary 4-damage melee action follows. [Radial shape](../../scripts/committed_pattern_shapes.gd#L75), [Action dispatch](../../scripts/combat_engine.gd#L2895) | PASS |
| Razor Dive | Move 3, Melee 7 along the path | The nominal 3-move, 7-damage attack builds a footprint along the announced path. If movement is interrupted, resolution translates that footprint to the actual endpoint and can hit outside the path taken. [Swept shape](../../scripts/committed_pattern_shapes.gd#L90), [Held stamp](../../scripts/boss_area_rules.gd#L69), [Interrupted Dive fixture](../../tests/dragon_committed_patterns_test.gd#L210) | FAIL · TODO_DESIGN_razor_dive |

## Proof results

Godot checks used `python3 tools/godot_task_runner.py --task-id txt-35 --stream -- godot --headless --path . --script <script>`.

| Check | Observed result |
| --- | --- |
| Catalog dump comparison | `TXT35 MOVE LINES: PASS (44 enemies, 137 moves, 28 changed)` |
| Rules text lint | `PASS: Rules text lint (16 existing hits)`, `Ran 3 tests in 0.053s`, `OK` |
| Text budget | `Ran 6 tests in 0.096s`, `OK` |
| Short tooltip Python fixtures, including pla02 and txt20 | `Ran 5 tests in 0.010s`, `OK` |
| UI identity lint | `Ran 25 tests in 4.808s`, `OK` |
| `tools/txt34/fixture_suites.gd` | `TXT34 FIXTURES relic_u1_suite.gd: 4510 checks, 0 failures`, `TXT34 FIXTURES inline_icon_description_suite.gd: 2832 checks, 0 failures` |
| `tests/short_card_tooltips_test.gd` | `SHORT CARD TOOLTIPS TEST RESULT: PASS (707 checks, 0 failures)` |
| `tests/card_panel_text_test.gd` | `CARD PANEL TEXT TEST RESULT: PASS (2210 definitions, 7758 panels, 15745 checks, 0 failures)` |
| `tests/mrk01_marked_test.gd` | `MRK01 MARKED TEST: PASS (69 checks, 0 failures)` |
| `tests/pre_battle_semantics_test.gd` | `INT06 LOB INSPECTION: one/two crosses; raw known moves; scaled and held values checked`, `PRE-BATTLE SEMANTICS TEST: PASS`, `TEST RESULT: PASS` |
| `tests/grimoire_focus_return_probe.gd` | `GRIMOIRE SEARCH PROBE RESULT: PASS` |
| `tests/dragon_rewards_test.gd` | `Dragon rewards, gifts, wallet recovery and relic hooks passed.` |
| `tests/worldspine_rules_test.gd` | `grimoire_search_suite.gd: 33 checks, 0 failures`, `dragon_feedback1_suite.gd: 84 checks, 0 failures`, `TRN-01 RULES RESULT: FAIL (2254 checks, 4 failures)` |
| Python default, `--shards 4 --changed-since HEAD` | `INPUT GROUP default: always run`, `SELECTED MODULES: 23 of 59`, `Ran 196 tests in 33.822s`, `OK` |
| `bash tools/txt35/native.sh --dry-run` | `TXT35 UI PROOF: PASS (headless, 12 capture states)` |
| Planned PNG names against the native contract | `TXT35 CAPTURE PLAN: PASS (12 planned PNGs match the contract)` |
| Separate headless `--controller-check` | `TXT35 CONTROLLER OPEN: search focused=true, hint visible=true, overlaps title=true`, `TXT35 UI PROOF: PASS (headless, 0 capture states)` |
| Cel look status | `CEL_STATUS current` |

Worldspine’s four failures match the existing [txt-34 baseline record](../txt34/result.md). FB1.1 fails both the live Tick Burst and the Pass forecast assertions. FB1.2 fails Mountain Stoneskin ordering in both cast orders.

The dragon rewards pass logged its injected persistence failures while exercising recovery. Python’s learned timing cache write hit the read-only Git metadata boundary after the suite completed. Logs for both are under `/private/tmp/labyrinth_codex/txt-35/`.

The windowed command is below. It prints the unique output folder. The 12 PNGs go under its `after/` directory and the manifest is `after-captures.json`. The headless dry-run log is `/private/tmp/labyrinth_codex/txt-35/proof.P16bSa/after.log`. It lists the planned paths. PNG captures and native visual inspection are pending.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/txt-35 && bash tools/txt35/native.sh
```

The capture uses pointer modality and sends no joypad events. The separate controller observation used the normal Grimoire button path with Xbox controller modality, without synthesizing a joypad event.

## Chosen defaults

Proof only. The probe reuses the first accessible combat room from the pre-battle fixture and places Vyraketh in that inspection. It shows Crowncoal Heart as the sole owned relic on the starting run, uses reduced motion for static frames and waits four layout frames at page transitions. Geometry checks allow one pixel of layout tolerance. The pixel contract reuses txt-34’s 920×420 center-region bounds at (500, 320), minimum luma range 25 and minimum luma standard deviation 3.

## Complete Known Move inventory

Both dumps use the Grimoire’s base-value inputs for every catalog entry. The before dump loaded the original formatter from `3067f8cf2`. Intent mechanics and base values are identical in both dumps. The original formatter does not read the optional summary fields. A separate probe checks the authored text on the live Vyraketh pre-battle inspection.

| Enemy / intent | Before | After | Changed |
| --- | --- | --- | --- |
| acolyte / Dust Bolt (`dust_bolt`) | `Ranged 5 · Range 3` | `Ranged 5 · Range 3` |  |
| acolyte / Ward Chant (`ward_chant`) | `Move 1 · Block 4` | `Move 1 · Block 4` |  |
| acolyte / Siphon (`siphon`) | `Move 1 · Ranged 4 · Range 2 · Heal 2` | `Move 1 · Ranged 4 · Range 2 · Heal 2` |  |
| acolyte / Dust Advance (`dust_advance`) | `Move 3 · Melee 2` | `Move 3 · Melee 2` |  |
| arc_thrall / Arc Bolt (`arc_bolt`) | `Move 2 · Ranged 3 · Range 3 · Electrified` | `Move 2 · Ranged 3 · Range 3 · Electrified` |  |
| arc_thrall / Arc Jab (`arc_jab`) | `Move 2 · Melee 3 · Shock 1` | `Move 2 · Melee 3 · Shock 1` |  |
| ash_hound / Bite (`bite`) | `Move 3 · Melee 3` | `Move 3 · Melee 3` |  |
| ash_hound / Flanking Bite (`circle`) | `Move 3 · Melee 2 · Push 1` | `Move 3 · Melee 2 · Push 1` |  |
| ashen_reaver / Raking Flame (`raking_flame`) | `Move 1 · Ranged · Fire · Range 4 · Area` | `Move 1 · Ranged · Fire · Range 4 · Area` |  |
| ashen_reaver / Hooked Sweep (`hooked_sweep`) | `Move 2 · Melee 6 · Range 2 · Push 1 · Fire · Area` | `Move 2 · Melee 6 · Range 2 · Push 1 · Fire · Area` |  |
| ashen_reaver / Executioner's Fall (`executioners_fall`) | `Move 1 · Ranged 8 · Range 4 · Fire · Area · Self: · Expose 3` | `Move 1 · Ranged 8 · Range 4 · Fire · Area · Self: Expose 3` | Yes |
| bell_tender / Join the Choir (`connector`) | `Move 2 · Ranged · Electrified · Range 4 · 2 linked tiles` | `Move 2 · Ranged · Electrified · Range 4 · 2 linked tiles` |  |
| bell_tender / Staff Bolt (`staff_bolt`) | `Move 2 · Ranged 3 · Range 3` | `Move 2 · Ranged 3 · Range 3` |  |
| bile_bloomer / Shale Burst (`bile_burst`) | `Move 1 · Melee 3 · Area · Rubble` | `Move 1 · Melee 3 · Area · Rubble` |  |
| bile_bloomer / Shard Mark (`spore_mark`) | `Ranged 3 · Range 3 · Expose 2 · Rubble` | `Ranged 3 · Range 3 · Expose 2 · Rubble` |  |
| bile_bloomer / Shale Shell (`pustule_shell`) | `Stoneskin 2` | `Stoneskin 2` |  |
| bile_bloomer / Shale Advance (`shale_advance`) | `Move 2` | `Move 2` |  |
| briar_weaver / Thornwall (`thornwall`) | `Marked · Upheaval 3` | `Marked · Upheaval 3` |  |
| briar_weaver / Lash of Thorns (`lash_of_thorns`) | `Ranged 4 · Range 3` | `Ranged 4 · Range 3` |  |
| briar_weaver / Root Mend (`root_mend`) | `Heal 4` | `Heal 4` |  |
| burrow_grub / Burrow (`burrow`) | `Burrow` | `Burrow` |  |
| burrow_grub / Erupt (`erupt`) | `Erupt 6 · Push 1 · Rubble · Expose 2 · Self: · Expose 2` | `Erupt 6 · Push 1 · Rubble · Expose 2 · Self: Expose 2` | Yes |
| burrow_grub / Gnaw (`gnaw`) | `Move 2 · Melee 3` | `Move 2 · Melee 3` |  |
| chainbound_gaoler / Chain Reel (`chain_reel`) | `Melee 4 · Range 3 · Pull 2` | `Melee 4 · Range 3 · Pull 2` |  |
| chainbound_gaoler / Manacle Pin (`manacle_pin`) | `Ranged 1 · Range 3 · Immobilize` | `Ranged 1 · Range 3 · Immobilize` |  |
| chainbound_gaoler / Cudgel Press (`cudgel_press`) | `Move 1 · Melee 6` | `Move 1 · Melee 6` |  |
| chainbound_gaoler / Iron Guard (`iron_guard`) | `Move 2 · Block 5` | `Move 2 · Block 5` |  |
| cinder_droplet / Spatter (`spatter`) | `Move 2 · Melee 3 · Fire` | `Move 2 · Melee 3 · Fire` |  |
| cinder_droplet / Hiss Back (`hiss_back`) | `Retreat 1 · Block 2` | `Retreat 1 · Block 2` |  |
| cinder_ooze / Smolder Slide (`smolder_slide`) | `Move 1 · Melee 5 · Fire` | `Move 1 · Melee 5 · Fire` |  |
| cinder_ooze / Cinder Bloom (`cinder_bloom`) | `Melee 4 · Area · Fire` | `Melee 4 · Area · Fire` |  |
| cinder_ooze / Slag Shell (`slag_shell`) | `Block 3` | `Block 3` |  |
| cinder_ooze / Ooze Advance (`ooze_advance`) | `Move 2` | `Move 2` |  |
| craghide / Crag Heave (`upheaval`) | `Move 2` | `Move 2` |  |
| craghide / Groundsplit (`groundsplit`) | `Marked · Melee 7 · Each Outcrop · within 2` | `Marked · Melee 7 · Each Outcrop · within 2` |  |
| craghide / Crushing Rush (`crushing_rush`) | `Move 3 · Melee 8` | `Move 3 · Melee 8` |  |
| crawler / Skitter Strike (`skitter_strike`) | `Move 2 · Melee 5` | `Move 2 · Melee 5` |  |
| crawler / Coil (`coil`) | `Move 2 · Block 4` | `Move 2 · Block 4` |  |
| crawler / Lunge (`lunge`) | `Move 3 · Melee 3` | `Move 3 · Melee 3` |  |
| ember_hoarder / Kindle (`kindle`) | `Burst +2` | `Burst +2` |  |
| ember_hoarder / Scurry (`scurry`) | `Retreat 2` | `Retreat 2` |  |
| ember_tick / Scuttle (`scuttle`) | `Move 3 · Melee 2` | `Move 3 · Melee 2` |  |
| ember_tick / Kindle (`kindle`) | `Burst +2` | `Burst +2` |  |
| frostglass_lancer / Glass Lunge (`glass_lunge`) | `Move 1 · Melee 6 · Area · Ice · Target on Ice: · Stagger 6` | `Move 1 · Melee 6 · Area · Ice · On Ice: also Stagger 6` | Yes |
| frostglass_lancer / Spear Cast (`spear_cast`) | `Ranged 4 · Range 3` | `Ranged 4 · Range 3` |  |
| frostglass_lancer / Refract Guard (`refract_guard`) | `Retreat 1 · Block 4 · Expend` | `Retreat 1 · Block 4 · Expend` |  |
| frostglass_lancer / Frost Pin (`frost_pin`) | `Ranged 5 · Range 3 · Target on Ice: · Stagger 6` | `Ranged 5 · Range 3 · On Ice: also Stagger 6` | Yes |
| frostglass_lancer / Spear Advance (`spear_advance`) | `Move 3 · Melee 2` | `Move 3 · Melee 2` |  |
| gale_herald / Call the Wind (`call_the_wind`) | `Gust 2 · Push 1` | `Gust 2 · Push 1` |  |
| gale_herald / Gust Bolt (`gust_bolt`) | `Ranged 3 · Range 4 · Push 1` | `Ranged 3 · Range 4 · Push 1` |  |
| gale_herald / Still Air (`still_air`) | `Block 5` | `Block 5` |  |
| gallows_roc / Hookwind (`hookwind`) | `Move 1 · Ranged 3 · Range 4 · Pull 2 · Area` | `Move 1 · Ranged 3 · Range 4 · Pull 2 · Area` |  |
| gallows_roc / Razor Pinion (`razor_pinion`) | `Move 2 · Melee 6 · Range 2 · Push 2 · Area` | `Move 2 · Melee 6 · Range 2 · Push 2 · Area` |  |
| gallows_roc / Grave Dive (`grave_dive`) | `Move 3 · Melee 9` | `Move 3 · Melee 9` |  |
| glacial_mirror / Refraction (`refraction`) | `Melee 4 · Area · Pierce · Target on Ice: · Stagger 6` | `Melee 4 · Area · Pierce · On Ice: also Stagger 6` | Yes |
| glacial_mirror / Crystal Guard (`crystal_guard`) | `Block 6` | `Block 6` |  |
| glacial_mirror / Grind Forward (`advance`) | `Move 2` | `Move 2` |  |
| gloam_stalker / Fade (`fade`) | `Blink 4` | `Blink 4` |  |
| gloam_stalker / Ambush (`ambush`) | `Melee 7` | `Melee 7` |  |
| gloam_stalker / Slash (`slash`) | `Move 2 · Melee 4` | `Move 2 · Melee 4` |  |
| grave_surgeon / Triage Suture (`triage_suture`) | `Move 1 · Heal 2` | `Move 1 · Heal 2` |  |
| grave_surgeon / Saw Jab (`saw_jab`) | `Move 2 · Melee 3` | `Move 2 · Melee 3` |  |
| grave_surgeon / Field Brace (`field_brace`) | `Move 1 · Block 3 · Expend` | `Move 1 · Block 3 · Expend` |  |
| gust_shrike / Dive (`dive`) | `Move 4 · Melee 4 · Push 1 · Along approach +1` | `Move 4 · Melee 4 · Push 1 · Along approach +1` |  |
| gust_shrike / Talon Rake (`talon_rake`) | `Move 2 · Melee 4` | `Move 2 · Melee 4` |  |
| gust_shrike / Hover (`hover`) | `Retreat 2 · Block 3` | `Retreat 2 · Block 3` |  |
| harrier / Pelt (`pelt`) | `Pierce 5 · Range 3` | `Pierce 5 · Range 3` |  |
| harrier / Retreat Step (`retreat_step`) | `Retreat 2 · Block 3` | `Retreat 2 · Block 3` |  |
| harrier / Rush (`rush`) | `Move 3 · Melee 3` | `Move 3 · Melee 3` |  |
| harrier / Darting Pelt (`darting_pelt`) | `Move 1 · Ranged 4 · Range 2` | `Move 1 · Ranged 4 · Range 2` |  |
| hoarfrost_seer / Icefall (`icefall`) | `@pattern(icefall:hero) · Icefall 5 · Range 5` | `@pattern(icefall:hero) · Icefall 5 · Range 5` |  |
| hoarfrost_seer / Icefall (`icefall_land`) | `Icefall 5 · Ice · Target on Ice: · Stagger 6` | `Icefall 5 · Ice · On Ice: also Stagger 6` | Yes |
| hoarfrost_seer / Rime Bolt (`rime_bolt`) | `Ranged 3 · Range 4 · Target on Ice: · Stagger 6` | `Ranged 3 · Range 4 · On Ice: also Stagger 6` | Yes |
| hoarfrost_seer / Withdraw (`withdraw`) | `Retreat 2 · Block 4` | `Retreat 2 · Block 4` |  |
| hollow_mimic / Echo (`echo`) | `Ranged 3 · Range 4 · Retaliate 3` | `Ranged 3 · Range 4 · Retaliate 3` |  |
| hollow_mimic / Shade Bolt (`shade_bolt`) | `Ranged 4 · Range 4` | `Ranged 4 · Range 4` |  |
| hollow_mimic / Recede (`recede`) | `Retreat 2` | `Retreat 2` |  |
| iskaldra / Crystal Mantle (`crystal_mantle`) | `Crystal Mantle 2 · Ranged 4 · Range 4 · Target on Ice: · Stagger 6` | `Crystal Mantle 2 · Ranged 4 · Range 4 · On Ice: also Stagger 6` | Yes |
| iskaldra / Shatterstorm (`shatterstorm`) | `Move 1 · Melee 7 · Range 1 · @pattern(ring_1:1) · · Mantle fuels range` | `Move 1 · Melee 7 · @pattern(ring_1:1) · Range 1, +1 per Crystal Mantle · removes all Crystal Mantle` | Yes |
| iskaldra / Whiteout Lance (`whiteout_lance`) | `Melee 6 · Range 3 · Ice · @pattern(body_cross:3) · Target on Ice: · Stagger 6` | `Melee 6 · Range 3 · Ice · @pattern(body_cross:3) · On Ice: also Stagger 6` | Yes |
| iskaldra / Rime Talon (`rime_talon`) | `Move 3 · Melee 10 · Target on Ice: · Stagger 6` | `Move 3 · Melee 10 · On Ice: also Stagger 6` | Yes |
| last_lamplighter / Snuff (`snuff`) | `Summon · Wick Shade · Snuff refuge` | `Summon Wick Shade · Snuff refuge` | Yes |
| last_lamplighter / Mourning Hook (`mourning_hook`) | `Move 2 · Ranged 3 · Range 4 · Pull 1 · Area` | `Move 2 · Ranged 3 · Range 4 · Pull 1 · Area` |  |
| last_lamplighter / Last Procession (`last_procession`) | `Move 3 · Melee 6` | `Move 3 · Melee 6` |  |
| lightning_wisp / Spark Dart (`spark_dart`) | `Move 3 · Melee 2` | `Move 3 · Melee 2` |  |
| lightning_wisp / Static Lash (`static_lash`) | `Move 1 · Ranged 3 · Range 2 · Electrified` | `Move 1 · Ranged 3 · Range 2 · Electrified` |  |
| lightning_wisp / Capacitor Arc (`blinding_arc`) | `Retreat 1 · Ranged 4 · Range 2 · if Electrified used: · Shock +1` | `Retreat 1 · Ranged 4 · Range 2 · On Electrified: also Shock +1` | Yes |
| noctyrax / Night Coil (`night_coil`) | `Ranged 6 · Range 3 · Pull 1 · Area · · Snuff refuge` | `Ranged 6 · Range 3 · Pull 1 · Area · puts out the nearest brazier` | Yes |
| noctyrax / Last Eclipse (`last_eclipse`) | `Marked · Ranged 8 · Eclipse 2 · Summon · Veilbound Acolyte` | `Marked · Ranged 8 · Eclipse 2 · Summon Veilbound Acolyte` | Yes |
| noctyrax / Void Claw (`void_claw`) | `Move 2 · Melee 10 · Expose 1` | `Move 2 · Melee 10 · Expose 1` |  |
| noctyrax / Starless Breath (`starless_breath`) | `Ranged 8 · Range 4 · Pierce · Area` | `Ranged 8 · Range 4 · Pierce · Area` |  |
| rime_spitter / Rime Needle (`needle`) | `Move 2 · Ranged 2 · Range 3 · Area · Ice · At lane end` | `Move 2 · Ranged 2 · Range 3 · Area · Ice · At lane end` |  |
| rime_spitter / Frost Spit (`recover`) | `Move 2 · Ranged 2 · Range 3 · Target on Ice: · Stagger 6` | `Move 2 · Ranged 2 · Range 3 · On Ice: also Stagger 6` | Yes |
| rime_whelp / Bite (`bite`) | `Move 3 · Melee 3` | `Move 3 · Melee 3` |  |
| rime_whelp / Rime Snap (`circle`) | `Move 2 · Melee 2 · Target on Ice: · Stagger 6` | `Move 2 · Melee 2 · On Ice: also Stagger 6` | Yes |
| rimejaw / Rime Trail (`rime_trail`) | `Move 2 · Ice · Trail · Melee 3` | `Move 2 · Ice · Trail · Melee 3` |  |
| rimejaw / Harrowing Pounce (`harrowing_pounce`) | `Move 3 · Melee 6 · Ice · Target on Ice: · Stagger 6` | `Move 3 · Melee 6 · Ice · On Ice: also Stagger 6` | Yes |
| rimejaw / Rime Bite (`frostbite`) | `Move 2 · Melee 6 · Target on Ice: · Stagger 6` | `Move 2 · Melee 6 · On Ice: also Stagger 6` | Yes |
| roc_fledgling / Darting Peck (`circle`) | `Move 3 · Melee 2` | `Move 3 · Melee 2` |  |
| roc_fledgling / Hooked Peck (`peck`) | `Move 2 · Melee 3` | `Move 2 · Melee 3` |  |
| slag_mortar / Lob Slag (`lob_slag`) | `@pattern(cross:hero) This enemy Marks tiles on your tile. On this enemy's next turn, this enemy will deal 5 damage on the central tile and 3 damage on each adjacent tile, then leave Fire.` | `@pattern(cross:hero) This enemy Marks tiles on your tile. On this enemy's next turn, this enemy will deal 5 damage on the central tile and 3 damage on each adjacent tile, then leave Fire.` |  |
| slag_mortar / Lob Slag (`slag_lands`) | `@pattern(cross) Deal 5 damage on the central tile and 3 damage on each adjacent tile, then leave Fire.` | `@pattern(cross) Deal 5 damage on the central tile and 3 damage on each adjacent tile, then leave Fire.` |  |
| slag_mortar / Brace (`brace`) | `Block 6` | `Block 6` |  |
| slag_mortar / Scatter Shot (`scatter_shot`) | `Ranged 3 · Range 2 · Push 1` | `Ranged 3 · Range 2 · Push 1` |  |
| stoneback_mite / Claw (`bite`) | `Move 2 · Melee 3` | `Move 2 · Melee 3` |  |
| stoneback_mite / Driving Claw (`brace`) | `Move 2 · Block 1 · Melee 2 · Push 1` | `Move 2 · Block 1 · Melee 2 · Push 1` |  |
| storm_cantor / Lay the Choir (`lay_the_choir`) | `Move 2 · Ranged · Electrified · Range 5 · 6 linked tiles` | `Move 2 · Ranged · Electrified · Range 5 · 6 linked tiles` |  |
| storm_cantor / Peal (`peal`) | `Move 1` | `Move 1` |  |
| storm_cantor / Broken Rhythm (`broken_rhythm`) | `Move 2 · Melee 11 · Range 2` | `Move 2 · Melee 11 · Range 2` |  |
| storm_cantor / Call the Spark (`call_the_spark`) | `Summon · Lightning Wisp` | `Summon Lightning Wisp` | Yes |
| storm_capacitor / Charge (`charge`) | `Charge +1` | `Charge +1` |  |
| storm_capacitor / Arc Lash (`discharge`) | `Arc 6, Range 4, 3 extra hits` | `Arc 6, Range 4, 3 extra hits` |  |
| tharokh / Stonewake (`stonewake`) | `Ranged 6 · Range 4 · Area` | `Ranged 6 · Range 4 · Area` |  |
| tharokh / Worldspine Claw (`worldspine_claw`) | `Move 2 · Melee 15 · Range 1 · Area` | `Move 2 · Melee 15 · Range 1 · Area` |  |
| tharokh / Bedrock Breath (`bedrock_breath`) | `Ranged 10 · Range 4 · Rubble · Area` | `Ranged 10 · Range 4 · Rubble · Area` |  |
| tharokh / Faultline (`faultline`) | `Marked · Burst 8 · each Worldspine · Ranged 4 · Range 4` | `Each Worldspine: Burst 8, then Ranged 4 · Range 4` | Yes |
| vaeloryx / Skyhook (`skyhook`) | `Move 2 · Ranged 4 · Range 4 · Pull 2` | `Move 2 · Ranged 4 · Range 4 · Pull 2` |  |
| vaeloryx / Razor Dive (`razor_dive`) | `Move 3 · Melee 7 · Range 1 · Along approach +1` | `Move 3 · Melee 7 · Range 1 · Along approach +1` |  |
| vaeloryx / Hollow Gale (`hollow_gale`) | `Melee · Hollow Gale 6 · Range 2 · Push 1 · @pattern(ring_1:2)` | `Melee 6 · Range 2 · Push 1 · @pattern(ring_1:2)` | Yes |
| vaeloryx / Eye of the Storm (`eye_of_storm`) | `Retreat 3 · Melee 8 · Range 5 · @pattern(ring_2:5) · Melee 4` | `Retreat 3 · Melee 8 · Range 5 · @pattern(ring_2:5), then Melee 4` | Yes |
| veilbound_acolyte / Veil Needle (`veil_needle`) | `Ranged 1 · Range 2` | `Ranged 1 · Range 2` |  |
| veilbound_acolyte / Shroudstep (`shroudstep`) | `Retreat 2` | `Retreat 2` |  |
| veilbound_acolyte / Closing Shade (`closing_shade`) | `Move 2 · Melee 1` | `Move 2 · Melee 1` |  |
| vyraketh / Meteorfall (`kindle_ground`) | `Marked · Cinder Marks 7 · Ranged 4 · Fire · Ranged 4 · Range 4` | `Cinder Marks 7: Ranged 4 · Fire, then Ranged 4 · Range 4` | Yes |
| vyraketh / Cinder Breath (`cinderfall`) | `Ranged 6 · Range 3 · Area` | `Ranged 6 · Range 3 · Area` |  |
| vyraketh / Crownfire (`crownfire`) | `Marked · Crownfire 8 · Move 2 · Melee 6` | `Each Cinder Mark: Burst 8, then Move 2 · Melee 6` | Yes |
| vyraketh / Cinder Maw (`cinder_maw`) | `Move 2 · Melee 8 · Marked · Cinder Marks 7 · Ranged 3 · Fire` | `Move 2 · Melee 8, then Cinder Marks 7: Ranged 3 · Fire` | Yes |
| warden / Marching Blow (`marching_blow`) | `Move 1 · Melee 9` | `Move 1 · Melee 9` |  |
| warden / Bulwark (`bulwark`) | `Block 6` | `Block 6` |  |
| warden / Crushing Step (`crushing_step`) | `Move 2 · Melee 6 · Area` | `Move 2 · Melee 6 · Area` |  |
| wick_shade / Grasp (`grasp`) | `Move 3 · Melee 2` | `Move 3 · Melee 2` |  |
| wick_shade / Hooking Grasp (`drift`) | `Move 2 · Melee 2 · Pull 1` | `Move 2 · Melee 2 · Pull 1` |  |
| wick_shade / Snuff (`snuff`) | `Move 2 · Snuff refuge` | `Move 2 · Snuff refuge` |  |
| zekarion / Skybreak (`skybreak`) | `Marked · Ranged 5 · Lightning Strikes 9 · Electrified` | `Lightning Strikes 9: Ranged 5 · Electrified` | Yes |
| zekarion / Storm Lash (`storm_claw`) | `Move 1 · Ranged 4 · Range 3 · Electrified` | `Move 1 · Ranged 4 · Range 3 · Electrified` |  |
| zekarion / Overload (`tempest_breath`) | `Ranged 3 · Range 4` | `Ranged 3 · Range 4` |  |
| zekarion / Call Wisps (`call_wisps`) | `Ranged 4 · Range 4 · Summon · Lightning Wisp` | `Ranged 4 · Range 4 · Summon Lightning Wisp` | Yes |
