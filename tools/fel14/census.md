# Board label overlap census

12 fixtures · 140 sampled frames · 1198 label instances · 142 counted collisions.

See [the label inventory and measurement notes](result.md). Each matrix cell is **rest / hover / enemy turn**. A dot means zero in all three phases. The matrix is symmetric.

| ID | Label kind | Instances |
|---:|---|---:|
| 1 | unit_health | 200 |
| 2 | terrain_health | 6 |
| 3 | status_chip | 80 |
| 4 | defense_chip | 64 |
| 5 | charge_pip | 0 |
| 6 | intent_badge | 75 |
| 7 | intent_tab | 5 |
| 8 | expanded_intent | 35 |
| 9 | tile_damage_badge | 0 |
| 10 | intent_compass | 0 |
| 11 | leader_crest | 0 |
| 12 | mark_medallion | 246 |
| 13 | collision_badge | 0 |
| 14 | lethal_icon | 0 |
| 15 | damage_popup | 49 |
| 16 | heal_popup | 2 |
| 17 | block_popup | 8 |
| 18 | stoneskin_popup | 0 |
| 19 | draw_popup | 0 |
| 20 | card_play_popup | 0 |
| 21 | effect_popup | 0 |
| 22 | intent_result | 0 |
| 23 | action_caption | 116 |
| 24 | objective_threshold | 3 |
| 25 | objective_leader | 12 |
| 26 | door_medallion | 3 |
| 27 | door_focus_chevron | 0 |
| 28 | summon_marker | 0 |
| 29 | brazier_callout | 0 |
| 30 | seals_pill | 0 |
| 31 | friendly_damage_chip | 0 |
| 32 | movement_risk_chip | 0 |
| 33 | loot_icon | 137 |
| 34 | trap_icon | 133 |
| 35 | npc_name | 0 |
| 36 | board_status | 0 |
| 37 | boss_name | 12 |
| 38 | boss_health | 12 |
| 39 | boss_status | 0 |
| 40 | turn_banner | 0 |

## Collision matrix

| Kind | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18 | 19 | 20 | 21 | 22 | 23 | 24 | 25 | 26 | 27 | 28 | 29 | 30 | 31 | 32 | 33 | 34 | 35 | 36 | 37 | 38 | 39 | 40 |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | · | 0 / 0 / 1 | 0 / 0 / 5 | · | · | · | · | · | · | · | · | · | · | · | 0 / 0 / 4 | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | 0 / 1 / 23 | · | · | · | · | · | · | · |
| 2 | 0 / 0 / 1 | · | · | · | · | · | · | · | · | · | · | · | · | · | 0 / 0 / 2 | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · |
| 3 | 0 / 0 / 5 | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | 0 / 0 / 4 | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · |
| 4 | · | · | · | · | · | 1 / 1 / 0 | · | · | · | · | · | · | · | · | · | · | 0 / 0 / 1 | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · |
| 5 | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · |
| 6 | · | · | · | 1 / 1 / 0 | · | · | 0 / 3 / 2 | · | · | · | · | 3 / 3 / 3 | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | 2 / 2 / 2 | 0 / 1 / 0 | · | · | · | · | · | · |
| 7 | · | · | · | · | · | 0 / 3 / 2 | · | 0 / 1 / 0 | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | 0 / 1 / 0 | · | · | · | · | · | · |
| 8 | · | · | · | · | · | · | 0 / 1 / 0 | · | · | · | · | 0 / 8 / 0 | · | · | 0 / 0 / 1 | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · |
| 9 | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · |
| 10 | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · |
| 11 | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · |
| 12 | · | · | · | · | · | 3 / 3 / 3 | · | 0 / 8 / 0 | · | · | · | · | · | · | 0 / 0 / 15 | · | · | · | · | · | · | · | · | · | 1 / 1 / 5 | · | · | · | · | · | · | · | · | 2 / 2 / 23 | · | · | · | · | · | · |
| 13 | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · |
| 14 | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · |
| 15 | 0 / 0 / 4 | 0 / 0 / 2 | · | · | · | · | · | 0 / 0 / 1 | · | · | · | 0 / 0 / 15 | · | · | · | · | · | · | · | · | · | · | · | · | 0 / 0 / 1 | · | · | · | · | · | · | · | 0 / 0 / 1 | 0 / 0 / 2 | · | · | · | · | · | · |
| 16 | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · |
| 17 | · | · | · | 0 / 0 / 1 | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | 0 / 0 / 1 | · | · | · | · | · | · | · | · | · | · | 0 / 0 / 1 | · | · | · | · | · | · |
| 18 | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · |
| 19 | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · |
| 20 | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · |
| 21 | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · |
| 22 | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · |
| 23 | · | · | 0 / 0 / 4 | · | · | · | · | · | · | · | · | · | · | · | · | · | 0 / 0 / 1 | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · |
| 24 | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · |
| 25 | · | · | · | · | · | · | · | · | · | · | · | 1 / 1 / 5 | · | · | 0 / 0 / 1 | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · |
| 26 | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · |
| 27 | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · |
| 28 | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · |
| 29 | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · |
| 30 | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · |
| 31 | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · |
| 32 | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · |
| 33 | 0 / 1 / 23 | · | · | · | · | 2 / 2 / 2 | · | · | · | · | · | · | · | · | 0 / 0 / 1 | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · |
| 34 | · | · | · | · | · | 0 / 1 / 0 | 0 / 1 / 0 | · | · | · | · | 2 / 2 / 23 | · | · | 0 / 0 / 2 | · | 0 / 0 / 1 | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · |
| 35 | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · |
| 36 | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · |
| 37 | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | 2 / 2 / 8 | · | · |
| 38 | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | 2 / 2 / 8 | · | · | · |
| 39 | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · |
| 40 | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · |

## Worst 15

Ranked by lower-label text loss, then smaller-label overlap and overlap area. Below-threshold overlaps fill any remaining ranks.

| Rank | Fixture | Frame | State | Lower | Upper | Overlap px² | Smaller | Text loss | Counts |
|---:|---|---:|---|---|---|---:|---:|---:|---|
| 1 | 07-s4-seed1-4-19_-19-t4 | 83 | enemy_turn 3 melee peak | mark_medallion [2, 5] 7 | damage_popup [2, 5] −8 | 2258.6 | 96.8% | 100.0% | yes |
| 2 | 04-s0-seed8-0--3_2-t5 | 460 | enemy_turn 20 block first, peak | defense_chip enemy_1 6 | block_popup [6, 4] +6 | 712.9 | 64.6% | 100.0% | yes |
| 3 | 12-s1-seed1-1-7_-3-t3 | 384 | enemy_turn 20 status_damage first, peak | unit_health enemy_1 11/16 | damage_popup [2, 6] −3 | 2712.0 | 57.8% | 78.3% | yes |
| 4 | 12-s1-seed1-1-7_-3-t3 | 35 | enemy_turn 2 status_damage first, peak | unit_health enemy_1 12/16 | damage_popup [2, 6] −3 | 2712.0 | 57.8% | 76.6% | yes |
| 5 | 01-s0-seed1-0-4_0-t9 | 27 | hover | mark_medallion [5, 4] Area mark | expanded_intent enemy_1 Faultline, 8, each Worldspine, 4 | 1552.0 | 100.0% | 73.8% | yes |
| 6 | 01-s0-seed1-0-4_0-t9 | 27 | hover | mark_medallion [7, 5] Area mark | expanded_intent enemy_1 Faultline, 8, each Worldspine, 4 | 1255.0 | 80.9% | 62.8% | yes |
| 7 | 11-s4-seed12-4-19_-14-t4 | 7 | rest | loot_icon loot_item_0_2_7 | intent_badge enemy_5 ×2 | 1220.4 | 95.4% | 34.4% | yes |
| 8 | 01-s0-seed1-0-4_0-t9 | 93 | enemy_turn 3 aoe peak | mark_medallion [2, 4] Area mark | damage_popup [2, 5] −4 | 490.1 | 31.6% | 31.3% | yes |
| 9 | 01-s0-seed1-0-4_0-t9 | 93 | enemy_turn 3 aoe peak | mark_medallion [3, 3] Area mark | damage_popup [4, 4] −8 | 783.1 | 50.5% | 28.1% | yes |
| 10 | 09-s3-seed12-3-16_0-t15 | 35 | enemy_turn 2 status_damage first, peak | loot_icon loot_item_0_5_5 | damage_popup [6, 5] −3 | 1552.7 | 98.9% | 25.9% | yes |
| 11 | 07-s4-seed1-4-19_-19-t4 | 28 | hover | loot_icon loot_item_0_5_5 | intent_badge enemy_1 lob | 1024.0 | 100.0% | 24.4% | yes |
| 12 | 07-s4-seed1-4-19_-19-t4 | 35 | enemy_turn 2 intent first | loot_icon loot_item_0_5_5 | intent_badge enemy_1 lob | 1024.0 | 100.0% | 24.4% | yes |
| 13 | 01-s0-seed1-0-4_0-t9 | 27 | hover | mark_medallion [7, 4] Area mark | expanded_intent enemy_1 Faultline, 8, each Worldspine, 4 | 1552.0 | 100.0% | 24.4% | yes |
| 14 | 07-s4-seed1-4-19_-19-t4 | 7 | rest | loot_icon loot_item_0_5_5 | intent_badge enemy_1 lob | 1015.6 | 99.2% | 24.0% | yes |
| 15 | 01-s0-seed1-0-4_0-t9 | 93 | enemy_turn 3 aoe peak | terrain_health terrain_outcrop_8 | damage_popup [2, 4] −4 | 1001.5 | 77.5% | 22.1% | yes |

## Pairs with zero counted collisions

795 unordered kind pairs had zero counts. Each line lists its peers in the matrix’s upper triangle. Kinds with zero instances had no opportunity to collide.

- **unit_health** — unit_health, defense_chip, charge_pip, intent_badge, intent_tab, expanded_intent, tile_damage_badge, intent_compass, leader_crest, mark_medallion, collision_badge, lethal_icon, heal_popup, block_popup, stoneskin_popup, draw_popup, card_play_popup, effect_popup, intent_result, action_caption, objective_threshold, objective_leader, door_medallion, door_focus_chevron, summon_marker, brazier_callout, seals_pill, friendly_damage_chip, movement_risk_chip, trap_icon, npc_name, board_status, boss_name, boss_health, boss_status, turn_banner
- **terrain_health** — terrain_health, status_chip, defense_chip, charge_pip, intent_badge, intent_tab, expanded_intent, tile_damage_badge, intent_compass, leader_crest, mark_medallion, collision_badge, lethal_icon, heal_popup, block_popup, stoneskin_popup, draw_popup, card_play_popup, effect_popup, intent_result, action_caption, objective_threshold, objective_leader, door_medallion, door_focus_chevron, summon_marker, brazier_callout, seals_pill, friendly_damage_chip, movement_risk_chip, loot_icon, trap_icon, npc_name, board_status, boss_name, boss_health, boss_status, turn_banner
- **status_chip** — status_chip, defense_chip, charge_pip, intent_badge, intent_tab, expanded_intent, tile_damage_badge, intent_compass, leader_crest, mark_medallion, collision_badge, lethal_icon, damage_popup, heal_popup, block_popup, stoneskin_popup, draw_popup, card_play_popup, effect_popup, intent_result, objective_threshold, objective_leader, door_medallion, door_focus_chevron, summon_marker, brazier_callout, seals_pill, friendly_damage_chip, movement_risk_chip, loot_icon, trap_icon, npc_name, board_status, boss_name, boss_health, boss_status, turn_banner
- **defense_chip** — defense_chip, charge_pip, intent_tab, expanded_intent, tile_damage_badge, intent_compass, leader_crest, mark_medallion, collision_badge, lethal_icon, damage_popup, heal_popup, stoneskin_popup, draw_popup, card_play_popup, effect_popup, intent_result, action_caption, objective_threshold, objective_leader, door_medallion, door_focus_chevron, summon_marker, brazier_callout, seals_pill, friendly_damage_chip, movement_risk_chip, loot_icon, trap_icon, npc_name, board_status, boss_name, boss_health, boss_status, turn_banner
- **charge_pip** — charge_pip, intent_badge, intent_tab, expanded_intent, tile_damage_badge, intent_compass, leader_crest, mark_medallion, collision_badge, lethal_icon, damage_popup, heal_popup, block_popup, stoneskin_popup, draw_popup, card_play_popup, effect_popup, intent_result, action_caption, objective_threshold, objective_leader, door_medallion, door_focus_chevron, summon_marker, brazier_callout, seals_pill, friendly_damage_chip, movement_risk_chip, loot_icon, trap_icon, npc_name, board_status, boss_name, boss_health, boss_status, turn_banner
- **intent_badge** — intent_badge, expanded_intent, tile_damage_badge, intent_compass, leader_crest, collision_badge, lethal_icon, damage_popup, heal_popup, block_popup, stoneskin_popup, draw_popup, card_play_popup, effect_popup, intent_result, action_caption, objective_threshold, objective_leader, door_medallion, door_focus_chevron, summon_marker, brazier_callout, seals_pill, friendly_damage_chip, movement_risk_chip, npc_name, board_status, boss_name, boss_health, boss_status, turn_banner
- **intent_tab** — intent_tab, tile_damage_badge, intent_compass, leader_crest, mark_medallion, collision_badge, lethal_icon, damage_popup, heal_popup, block_popup, stoneskin_popup, draw_popup, card_play_popup, effect_popup, intent_result, action_caption, objective_threshold, objective_leader, door_medallion, door_focus_chevron, summon_marker, brazier_callout, seals_pill, friendly_damage_chip, movement_risk_chip, loot_icon, npc_name, board_status, boss_name, boss_health, boss_status, turn_banner
- **expanded_intent** — expanded_intent, tile_damage_badge, intent_compass, leader_crest, collision_badge, lethal_icon, heal_popup, block_popup, stoneskin_popup, draw_popup, card_play_popup, effect_popup, intent_result, action_caption, objective_threshold, objective_leader, door_medallion, door_focus_chevron, summon_marker, brazier_callout, seals_pill, friendly_damage_chip, movement_risk_chip, loot_icon, trap_icon, npc_name, board_status, boss_name, boss_health, boss_status, turn_banner
- **tile_damage_badge** — tile_damage_badge, intent_compass, leader_crest, mark_medallion, collision_badge, lethal_icon, damage_popup, heal_popup, block_popup, stoneskin_popup, draw_popup, card_play_popup, effect_popup, intent_result, action_caption, objective_threshold, objective_leader, door_medallion, door_focus_chevron, summon_marker, brazier_callout, seals_pill, friendly_damage_chip, movement_risk_chip, loot_icon, trap_icon, npc_name, board_status, boss_name, boss_health, boss_status, turn_banner
- **intent_compass** — intent_compass, leader_crest, mark_medallion, collision_badge, lethal_icon, damage_popup, heal_popup, block_popup, stoneskin_popup, draw_popup, card_play_popup, effect_popup, intent_result, action_caption, objective_threshold, objective_leader, door_medallion, door_focus_chevron, summon_marker, brazier_callout, seals_pill, friendly_damage_chip, movement_risk_chip, loot_icon, trap_icon, npc_name, board_status, boss_name, boss_health, boss_status, turn_banner
- **leader_crest** — leader_crest, mark_medallion, collision_badge, lethal_icon, damage_popup, heal_popup, block_popup, stoneskin_popup, draw_popup, card_play_popup, effect_popup, intent_result, action_caption, objective_threshold, objective_leader, door_medallion, door_focus_chevron, summon_marker, brazier_callout, seals_pill, friendly_damage_chip, movement_risk_chip, loot_icon, trap_icon, npc_name, board_status, boss_name, boss_health, boss_status, turn_banner
- **mark_medallion** — mark_medallion, collision_badge, lethal_icon, heal_popup, block_popup, stoneskin_popup, draw_popup, card_play_popup, effect_popup, intent_result, action_caption, objective_threshold, door_medallion, door_focus_chevron, summon_marker, brazier_callout, seals_pill, friendly_damage_chip, movement_risk_chip, loot_icon, npc_name, board_status, boss_name, boss_health, boss_status, turn_banner
- **collision_badge** — collision_badge, lethal_icon, damage_popup, heal_popup, block_popup, stoneskin_popup, draw_popup, card_play_popup, effect_popup, intent_result, action_caption, objective_threshold, objective_leader, door_medallion, door_focus_chevron, summon_marker, brazier_callout, seals_pill, friendly_damage_chip, movement_risk_chip, loot_icon, trap_icon, npc_name, board_status, boss_name, boss_health, boss_status, turn_banner
- **lethal_icon** — lethal_icon, damage_popup, heal_popup, block_popup, stoneskin_popup, draw_popup, card_play_popup, effect_popup, intent_result, action_caption, objective_threshold, objective_leader, door_medallion, door_focus_chevron, summon_marker, brazier_callout, seals_pill, friendly_damage_chip, movement_risk_chip, loot_icon, trap_icon, npc_name, board_status, boss_name, boss_health, boss_status, turn_banner
- **damage_popup** — damage_popup, heal_popup, block_popup, stoneskin_popup, draw_popup, card_play_popup, effect_popup, intent_result, action_caption, objective_threshold, door_medallion, door_focus_chevron, summon_marker, brazier_callout, seals_pill, friendly_damage_chip, movement_risk_chip, npc_name, board_status, boss_name, boss_health, boss_status, turn_banner
- **heal_popup** — heal_popup, block_popup, stoneskin_popup, draw_popup, card_play_popup, effect_popup, intent_result, action_caption, objective_threshold, objective_leader, door_medallion, door_focus_chevron, summon_marker, brazier_callout, seals_pill, friendly_damage_chip, movement_risk_chip, loot_icon, trap_icon, npc_name, board_status, boss_name, boss_health, boss_status, turn_banner
- **block_popup** — block_popup, stoneskin_popup, draw_popup, card_play_popup, effect_popup, intent_result, objective_threshold, objective_leader, door_medallion, door_focus_chevron, summon_marker, brazier_callout, seals_pill, friendly_damage_chip, movement_risk_chip, loot_icon, npc_name, board_status, boss_name, boss_health, boss_status, turn_banner
- **stoneskin_popup** — stoneskin_popup, draw_popup, card_play_popup, effect_popup, intent_result, action_caption, objective_threshold, objective_leader, door_medallion, door_focus_chevron, summon_marker, brazier_callout, seals_pill, friendly_damage_chip, movement_risk_chip, loot_icon, trap_icon, npc_name, board_status, boss_name, boss_health, boss_status, turn_banner
- **draw_popup** — draw_popup, card_play_popup, effect_popup, intent_result, action_caption, objective_threshold, objective_leader, door_medallion, door_focus_chevron, summon_marker, brazier_callout, seals_pill, friendly_damage_chip, movement_risk_chip, loot_icon, trap_icon, npc_name, board_status, boss_name, boss_health, boss_status, turn_banner
- **card_play_popup** — card_play_popup, effect_popup, intent_result, action_caption, objective_threshold, objective_leader, door_medallion, door_focus_chevron, summon_marker, brazier_callout, seals_pill, friendly_damage_chip, movement_risk_chip, loot_icon, trap_icon, npc_name, board_status, boss_name, boss_health, boss_status, turn_banner
- **effect_popup** — effect_popup, intent_result, action_caption, objective_threshold, objective_leader, door_medallion, door_focus_chevron, summon_marker, brazier_callout, seals_pill, friendly_damage_chip, movement_risk_chip, loot_icon, trap_icon, npc_name, board_status, boss_name, boss_health, boss_status, turn_banner
- **intent_result** — intent_result, action_caption, objective_threshold, objective_leader, door_medallion, door_focus_chevron, summon_marker, brazier_callout, seals_pill, friendly_damage_chip, movement_risk_chip, loot_icon, trap_icon, npc_name, board_status, boss_name, boss_health, boss_status, turn_banner
- **action_caption** — action_caption, objective_threshold, objective_leader, door_medallion, door_focus_chevron, summon_marker, brazier_callout, seals_pill, friendly_damage_chip, movement_risk_chip, loot_icon, trap_icon, npc_name, board_status, boss_name, boss_health, boss_status, turn_banner
- **objective_threshold** — objective_threshold, objective_leader, door_medallion, door_focus_chevron, summon_marker, brazier_callout, seals_pill, friendly_damage_chip, movement_risk_chip, loot_icon, trap_icon, npc_name, board_status, boss_name, boss_health, boss_status, turn_banner
- **objective_leader** — objective_leader, door_medallion, door_focus_chevron, summon_marker, brazier_callout, seals_pill, friendly_damage_chip, movement_risk_chip, loot_icon, trap_icon, npc_name, board_status, boss_name, boss_health, boss_status, turn_banner
- **door_medallion** — door_medallion, door_focus_chevron, summon_marker, brazier_callout, seals_pill, friendly_damage_chip, movement_risk_chip, loot_icon, trap_icon, npc_name, board_status, boss_name, boss_health, boss_status, turn_banner
- **door_focus_chevron** — door_focus_chevron, summon_marker, brazier_callout, seals_pill, friendly_damage_chip, movement_risk_chip, loot_icon, trap_icon, npc_name, board_status, boss_name, boss_health, boss_status, turn_banner
- **summon_marker** — summon_marker, brazier_callout, seals_pill, friendly_damage_chip, movement_risk_chip, loot_icon, trap_icon, npc_name, board_status, boss_name, boss_health, boss_status, turn_banner
- **brazier_callout** — brazier_callout, seals_pill, friendly_damage_chip, movement_risk_chip, loot_icon, trap_icon, npc_name, board_status, boss_name, boss_health, boss_status, turn_banner
- **seals_pill** — seals_pill, friendly_damage_chip, movement_risk_chip, loot_icon, trap_icon, npc_name, board_status, boss_name, boss_health, boss_status, turn_banner
- **friendly_damage_chip** — friendly_damage_chip, movement_risk_chip, loot_icon, trap_icon, npc_name, board_status, boss_name, boss_health, boss_status, turn_banner
- **movement_risk_chip** — movement_risk_chip, loot_icon, trap_icon, npc_name, board_status, boss_name, boss_health, boss_status, turn_banner
- **loot_icon** — loot_icon, trap_icon, npc_name, board_status, boss_name, boss_health, boss_status, turn_banner
- **trap_icon** — trap_icon, npc_name, board_status, boss_name, boss_health, boss_status, turn_banner
- **npc_name** — npc_name, board_status, boss_name, boss_health, boss_status, turn_banner
- **board_status** — board_status, boss_name, boss_health, boss_status, turn_banner
- **boss_name** — boss_name, boss_status, turn_banner
- **boss_health** — boss_health, boss_status, turn_banner
- **boss_status** — boss_status, turn_banner
- **turn_banner** — turn_banner

## Text and upper-body silhouette overlap

| Fixture | Rest ≥15% | Hover ≥15% | Enemy turn ≥15% | Any positive overlap |
|---|---:|---:|---:|---:|
| 01-s0-seed1-0-4_0-t9 | 5 | 5 | 27 | 45 |
| 02-s0-seed12-0-1_3-t7 | 0 | 0 | 1 | 12 |
| 03-s2-seed8-2-11_-9-t64 | 0 | 0 | 0 | 0 |
| 04-s0-seed8-0--3_2-t5 | 1 | 1 | 2 | 19 |
| 05-s2-seed1-2-9_-7-t2 | 0 | 0 | 2 | 2 |
| 06-s2-seed1-2-11_-10-t5 | 2 | 3 | 40 | 50 |
| 07-s4-seed1-4-19_-19-t4 | 1 | 3 | 11 | 17 |
| 08-s1-seed8-1-5_-4-t5 | 0 | 0 | 0 | 0 |
| 09-s3-seed12-3-16_0-t15 | 1 | 1 | 5 | 7 |
| 10-s3-seed12-3-13_-2-t4 | 0 | 0 | 0 | 0 |
| 11-s4-seed12-4-19_-14-t4 | 1 | 1 | 2 | 30 |
| 12-s1-seed1-1-7_-3-t3 | 0 | 2 | 27 | 31 |
