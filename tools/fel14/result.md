| Label kind | Production painter | Anchor | Paint layer | Hover or focus behavior |
|---|---|---|---|---|
| Unit health plate | `scripts/combat_board_view.gd` · `_draw_health_bar_entry`, `_draw_health_bar`, `_draw_health_bar_text` | Unit, by actor key | Board HUD, unit and terrain entries in body depth order. Preview ink has a retained pass | Contextual mode reveals on inspection, aim, Details or a value change. Always keeps the plate shown |
| Terrain health plate | `scripts/combat_board_view.gd` · `_draw_terrain_health_bar` | Destructible object | Board HUD, depth-sorted with unit plates | Contextual mode reveals on inspection or HP change. Always uses the painter’s eligibility rules |
| Status chip and defense chip | `scripts/board_status_plates.gd` · `draw_entry`, via `_draw_unit_statuses` or `scripts/board_plate_visibility.gd` · `draw_terrain_statuses` | Unit or terrain object | Board HUD details or terrain’s health entry | Existing status and defense entries remain available for inspection. Forecast tint, status changes and target visibility govern paint |
| Charge pip | `scripts/board_plate_visibility.gd` · `draw_pips` | Storm Capacitor, above health frame | Board HUD details | Persists while its actor is eligible |
| Unit intent badge | `scripts/combat_board_view.gd` · `_draw_slice_intent_chip`, `scripts/intent_badges.gd` · `_draw_disc` and `scripts/board_layer_slices.gd` · `draw_intent_chip` | Enemy | Board HUD and retained intent children. Raised or dimmed by the aim pass | Badge stays or is dimmed according to threat visibility and isolation. Contextual tab opens on inspection |
| Intent badge tab | `scripts/intent_badges.gd` · `TabInk._draw`, `_draw_tab` | Enemy badge | Clipped child behind its contextual disc. Part of the main chip in Always mode | Opens on inspection, isolation or Details. Closes after leaving those states |
| Expanded intent title and rows | `scripts/combat_board_view.gd` · `_draw_enemy_intent_layout`, `_draw_enemy_intent_title`, `_draw_token_row` | Enemy or boss | Board HUD details and aim-lifted HUD canvases | Appears with hover, focus or Details |
| Intent compass | `scripts/combat_board_view.gd` · `_draw_enemy_intent_compass` | Unit footprint | Scene floor, under its body | Details enables it. Ordinary hover and focus leave it hidden |
| Leader crest | `scripts/combat_board_view.gd` · `_draw_leader_marker` | Leader’s health frame | Board HUD details | Follows actor eligibility. No direct hover hide |
| Threat or tile damage numeral | `scripts/enemy_mechanics/capacitor_view.gd` · `draw_telegraphs` | Chain discharge destination tile | Retained effect telegraphs | Appears with the relevant threat preview |
| Mark medallion, with optional tile damage numeral | `scripts/combat_board_view.gd` · `_draw_meteor_mark_badges`, `scripts/enemy_mechanics/{burrow,icefall,lob}_view.gd` · `draw_badges` and `lob_view.gd` · `draw_mark_badge`, `scripts/boss_area_marks.gd` · `draw_badges` | Marked tile | Effects above bodies, including isolated threat canvases. Number paints after medallion | Persists for an eligible mark. Threat isolation can replace the roster, including showing boss area marks |
| Collision badge and numeral | `scripts/combat_board_view.gd` · `_draw_collision_markers`, also via `_draw_isolated_collision` | Tile or shared edge with blocker | Board effects or isolated threat canvas | Visible with a collision forecast. Forecast can change with focus |
| Lethal preview icon | `scripts/combat_board_view.gd` · `_draw_lethal_preview_icons`, `_draw_lethal_preview_icon` | Unit, object or trap | Board effects after collision and mark badges | Appears while the associated lethal preview is active |
| Damage, Heal, Block, Stoneskin, Draw and Card Play numbers | `scripts/combat_board_view.gd` · `_draw_floating_text_popup`, `scripts/floating_combat_text.gd` · `paint_icon` | Unit if an anchor key is supplied, otherwise tile | Board effects. Numeric ink paints after mark badges and before the normal board HUD. The resource icon uses an effects child RID | Timed feedback. No direct hover hide |
| Other floating combat text | Same floating-text painter | Unit or tile | Board effects | Timed feedback. No direct hover hide |
| Intent result callout | `scripts/intent_callouts.gd` · `draw` | Enemy | End of board HUD, above intent, health and status paint | Timed for the result. No direct hover hide |
| Enemy action caption | `scripts/run_scene.gd` · `_set_action_banner`, `_layout_action_banner`, `scripts/action_caption_scrim.gd` · `_draw` | Acting unit or battlefield event | Stage UI CanvasLayer above the board. Scrim behind label | Follows the current playback caption. No direct hover hide |
| Turn banner | `scripts/run_scene.gd` · `_show_turn_banner`, `scripts/turn_banner.gd` · `show_banner`, `_draw` | Combat handoff | Stage UI CanvasLayer | Times out or yields to the action caption |
| Objective threshold icon | `scripts/combat_board_view.gd` · `_draw_objective_exit_icon`, scheduled by `scripts/board_layer_slices.gd` · `objective_operations` | Threshold tile | Ground overlay, before depth contents | Visible on the objective target tile. No direct hover hide |
| Objective leader icon | `scripts/combat_board_view.gd` · `_draw_objective_leader_beacon` | Leader’s tile | Ground overlay or scoped threat paint | Follows the objective target and isolation |
| Summon marker | `scripts/combat_board_view.gd` · `_draw_tile_overlays` retained texture operation | Summon destination tile | Ground overlay | Visible with a summon forecast |
| Door destination medallion | `scripts/combat_board_view.gd` · `_draw_tile_stone_props`, `_draw_door_icon`, `scripts/section_map_skin.gd` · `draw_medallion`, `draw_unknown_room` | Door object | Depth-sorted tile prop, before that tile’s bodies | Suppressed on a sealed door or while an opening sprite replaces it. No direct hover hide |
| Door focus chevron | `scripts/combat_board_view.gd` · `_draw_controller_door_chevron` | Focused door tile | Ground focus overlay, which can be lifted | Appears for controller door focus |
| Noctyrax brazier callout | `scripts/combat_board_view.gd` · `_draw_noctyrax_brazier_markers` | Brazier object and tile | Board HUD base, before health and intent | Follows a living Noctyrax and brazier state. No direct hover hide |
| Seals · N pill | `scripts/combat_board_view.gd` · `_refresh_snare_chips`, `scripts/snare_seal_chip.gd` · `_init` | Door object, keyed by sealbinder | Board Control child above door art | Visible for an active sealing exit. Hidden once sealed or kept open |
| Friendly damage and movement risk pills | `scripts/combat_board_view.gd` · `_draw_friendly_damage_chips`, `_draw_movement_risk_chips`, `_draw_movement_risk_chip` | Unit’s health plate or risk tile | Friendly forecast in board HUD. Movement forecast in effects | Follow the applicable aim, path or risk preview |
| Loot icon | `scripts/combat_board_view.gd` · `_draw_ground_items_below_path`, `_draw_equipment_pickup`, `_draw_world_texture` | Pickup object | Ground before paths for flat loot. Depth-sorted prop for floating loot | Unclaimed and visible. No direct hover hide |
| Trap icon | `scripts/combat_board_view.gd` · `_draw_trap_marker`, `_draw_elemental_trap_floor_overlay` | Trap object | Ground before paths. Active elemental sprite uses effects paint | Follows visibility and trap state. No direct hover hide |
| NPC nameplate | `scripts/combat_board_view.gd` · `_draw_npc_nameplate` | NPC | Board HUD details | Follows NPC visibility |
| Board status title and hint | `scripts/combat_board_view.gd` · `_draw_status_text` | Board | Effects before floating text | Follows room state and its own fade |
| Boss name, health and status | `scripts/run_scene.gd` · `_setup_boss_health_overlay`, `_refresh_boss_health_overlay`, `scripts/segmented_health_bar.gd` · `_draw` | Boss | Stage UI CanvasLayer above the board, above action caption in vertical layout | Visible while boss HUD is active. No direct hover hide |

## Outputs

- [Census summary](census.md) has the split matrix, top 15, zero-count pairs and silhouette counts.
- [Frame and pair data](census.json) holds label and text or glyph bounds as `[x, y, width, height]`, labels’ owner keys and tiles, paint order, and a row for every unordered pair. The higher order index is on top.

## Measurement

The probe stages each checkpoint in its isolated runtime directory and verifies the resumed boundary, units, positions, surfaces, intents and hand using fel-01’s witness. It takes the first input-ready rest sample, checks that the viewport-only pointer hit the listed Hover tile and that reveal settled, then invokes the production Pass handler. Playback steps contribute only after a board or caption submission and a frame boundary. Commit-only and hidden bookkeeping steps are excluded. Sampling ends before the next hero input. A beat with numbers contributes the earliest frame maximizing the sum of squared rendered number font sizes weighted by opacity. Numbers carried over from a preceding beat are excluded from the peak score. A frame that serves as both the first and peak is counted once.

Board receipts come from the production paint functions. The probe instruments cached scripts in memory and forwards their original draw calls. It follows retained CanvasItem order, CanvasLayer, z-index, transforms, opacity and clipping. Solid shapes use analytic geometry, textures use source alpha and bilinear sampling, and text uses shaped glyph atlas bitmaps. Artwork glows and ordinary surfaces, path washes and other undecorated tile fills are outside the label census. The floating resource icon’s child RID uses the popup painter’s actual source texture and rect. The same popup’s icon and numbers are one label.

Text loss uses pixel centres inside the lower label’s text rect, or its glyph rect for an icon-only label. A pixel counts as opaque when the upper label’s composite alpha rounds to 255. Rectangular overlap uses the smaller screen rect as denominator. The pair counts at 10% rectangle overlap or 15% text loss. Upper-body overlap uses fel-01’s 25%-resolution rest-pose masks, restricted to the top 45% of each unit’s occupied height. Positive hits and the 15% threshold flag are recorded individually.

Native Control glyphs, the action caption scrim, boss HUD, battlefield caption icon and `Seals · N` are reconstructed from the controls’ arranged positions, fonts, theme and painter inputs. The headless mask models geometry and source alpha. Edge antialiasing, texture filtering, HUD batch feathering, shader output and native-only frame scheduling can vary from that model. The normal health fill and batched disc backings use their production command geometry as the mask. The silhouette sample uses rest-pose coverage at the current registration, including facing where supplied by fel-01.

## Proof commands

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-14 && LABYRINTH_CEL_LOOK=all python3 tools/godot_task_runner.py --task-id fel-14 --stream -- godot --headless --fixed-fps 60 --path . --script tools/fel14/census.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-14 && tools/fel14/native.sh --dry-run
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-14 && tools/fel14/native.sh
```

The reviewed round-zero stills and contact sheet are in `tools/fel14/captures/native.BPjd9Q/`. The windowed command above now runs the Round 1 proof below.

## Round 1

The before census replays the reviewed baseline at `7cd924f52`. It has 140 frames and 142 collisions. The after census has 140 frames and 142 collisions. The two runs share 140 fixture and sample keys.

The board now paints plates and chips, intent badges and tabs, tile numerals, expanded intents, intent result callouts, and floating feedback in that order. Mark discs and icons stay with board effects. Boss area marks use the shared painter and keep their existing icon-only presentation.

A mark disc and its numeral keep a single footprint for the collision matrix. Text loss tests only ink above the lower label’s readable part. The top-kind column counts after collisions.

| Pair | Collisions before | Collisions after | ≥15% loss before | ≥15% loss after | After top kind |
|---|---:|---:|---:|---:|---|
| action_caption × block_popup | 1 | 1 | 0 | 0 | action_caption (1) |
| action_caption × status_chip | 4 | 4 | 0 | 0 | action_caption (4) |
| block_popup × defense_chip | 1 | 1 | 0 | 1 | block_popup (1) |
| block_popup × trap_icon | 1 | 1 | 0 | 0 | block_popup (1) |
| boss_health × boss_name | 12 | 12 | 0 | 0 | boss_health (12) |
| damage_popup × expanded_intent | 1 | 1 | 0 | 0 | damage_popup (1) |
| damage_popup × loot_icon | 1 | 1 | 1 | 1 | damage_popup (1) |
| damage_popup × mark_medallion | 15 | 15 | 5 | 5 | damage_popup (15) |
| damage_popup × objective_leader | 1 | 1 | 0 | 0 | damage_popup (1) |
| damage_popup × terrain_health | 2 | 2 | 0 | 1 | damage_popup (2) |
| damage_popup × trap_icon | 2 | 2 | 2 | 2 | damage_popup (2) |
| damage_popup × unit_health | 4 | 4 | 1 | 2 | damage_popup (4) |
| defense_chip × intent_badge | 2 | 2 | 2 | 0 | intent_badge (2) |
| expanded_intent × intent_tab | 1 | 1 | 0 | 0 | expanded_intent (1) |
| expanded_intent × mark_medallion | 8 | 8 | 4 | 4 | expanded_intent (8) |
| intent_badge × intent_tab | 5 | 5 | 0 | 0 | intent_badge (5) |
| intent_badge × loot_icon | 6 | 6 | 4 | 4 | intent_badge (6) |
| intent_badge × mark_medallion | 9 | 9 | 3 | 3 | mark_medallion (9) |
| intent_badge × trap_icon | 1 | 1 | 0 | 0 | intent_badge (1) |
| intent_tab × trap_icon | 1 | 1 | 0 | 0 | intent_tab (1) |
| loot_icon × unit_health | 24 | 24 | 0 | 0 | unit_health (24) |
| mark_medallion × objective_leader | 7 | 7 | 0 | 0 | mark_medallion (7) |
| mark_medallion × trap_icon | 27 | 27 | 0 | 0 | mark_medallion (27) |
| status_chip × unit_health | 5 | 5 | 0 | 0 | status_chip (5) |
| terrain_health × unit_health | 1 | 1 | 0 | 0 | unit_health (1) |

### Named cases

| Before rank | Fixture | After frame | Important label | Before loss | After loss |
|---:|---|---:|---|---:|---:|
| 2 | 07-s4-seed1-4-19_-19-t4 | 7 | mark_medallion (3, 5) 5 | 100.0% | 0.0% |
| 3 | 07-s4-seed1-4-19_-19-t4 | 28 | mark_medallion (3, 5) 5 | 100.0% | 0.0% |
| 4 | 07-s4-seed1-4-19_-19-t4 | 35 | mark_medallion (3, 5) 5 | 100.0% | 0.0% |
| 7 | 12-s1-seed1-1-7_-3-t3 | 384 | damage_popup (2, 6) −3 | 49.6% | 0.0% |
| 8 | 04-s0-seed8-0--3_2-t5 | 7 | intent_badge enemy_4 guard_ally | 39.2% | 0.0% |
| 9 | 04-s0-seed8-0--3_2-t5 | 28 | intent_badge enemy_4 guard_ally | 39.2% | 0.0% |

### New ≥15% losses

Every pair type gained at most two instances.

| Fixture | After frame | Phase | Lower label | Upper label | Before loss | After loss |
|---|---:|---|---|---|---:|---:|
| 01-s0-seed1-0-4_0-t9 | 93 | enemy_turn | terrain_health terrain_outcrop_8 | damage_popup (2, 4) −4 | 0.0% | 22.1% |
| 02-s0-seed12-0-1_3-t7 | 7 | rest | intent_badge enemy_4 melee | mark_medallion (2, 3) 5 | 0.0% | 20.3% |
| 02-s0-seed12-0-1_3-t7 | 28 | hover | intent_badge enemy_4 melee | mark_medallion (2, 3) 5 | 0.0% | 20.3% |
| 02-s0-seed12-0-1_3-t7 | 35 | enemy_turn | intent_badge enemy_4 melee | mark_medallion (2, 3) 5 | 0.0% | 20.3% |
| 04-s0-seed8-0--3_2-t5 | 460 | enemy_turn | defense_chip enemy_1 6 | block_popup (6, 4) +6 | 0.0% | 100.0% |
| 12-s1-seed1-1-7_-3-t3 | 35 | enemy_turn | unit_health enemy_1 12/16 | damage_popup (2, 6) −3 | 0.0% | 76.6% |
| 12-s1-seed1-1-7_-3-t3 | 384 | enemy_turn | unit_health enemy_1 11/16 | damage_popup (2, 6) −3 | 0.0% | 78.3% |

### New worst 15

| Rank | Fixture | Frame | Phase | Lower label | Upper label | Text loss |
|---:|---|---:|---|---|---|---:|
| 1 | 07-s4-seed1-4-19_-19-t4 | 83 | enemy_turn | mark_medallion (2, 5) 7 | damage_popup (2, 5) −8 | 100.0% |
| 2 | 04-s0-seed8-0--3_2-t5 | 460 | enemy_turn | defense_chip enemy_1 6 | block_popup (6, 4) +6 | 100.0% |
| 3 | 12-s1-seed1-1-7_-3-t3 | 384 | enemy_turn | unit_health enemy_1 11/16 | damage_popup (2, 6) −3 | 78.3% |
| 4 | 12-s1-seed1-1-7_-3-t3 | 35 | enemy_turn | unit_health enemy_1 12/16 | damage_popup (2, 6) −3 | 76.6% |
| 5 | 01-s0-seed1-0-4_0-t9 | 27 | hover | mark_medallion (5, 4) Area mark | expanded_intent enemy_1 Faultline, 8, each Worldspine, 4 | 73.8% |
| 6 | 01-s0-seed1-0-4_0-t9 | 27 | hover | mark_medallion (7, 5) Area mark | expanded_intent enemy_1 Faultline, 8, each Worldspine, 4 | 62.8% |
| 7 | 11-s4-seed12-4-19_-14-t4 | 7 | rest | loot_icon loot_item_0_2_7 | intent_badge enemy_5 ×2 | 34.4% |
| 8 | 01-s0-seed1-0-4_0-t9 | 93 | enemy_turn | mark_medallion (2, 4) Area mark | damage_popup (2, 5) −4 | 31.3% |
| 9 | 01-s0-seed1-0-4_0-t9 | 93 | enemy_turn | mark_medallion (3, 3) Area mark | damage_popup (4, 4) −8 | 28.1% |
| 10 | 09-s3-seed12-3-16_0-t15 | 35 | enemy_turn | loot_icon loot_item_0_5_5 | damage_popup (6, 5) −3 | 25.9% |
| 11 | 07-s4-seed1-4-19_-19-t4 | 28 | hover | loot_icon loot_item_0_5_5 | intent_badge enemy_1 lob | 24.4% |
| 12 | 07-s4-seed1-4-19_-19-t4 | 35 | enemy_turn | loot_icon loot_item_0_5_5 | intent_badge enemy_1 lob | 24.4% |
| 13 | 01-s0-seed1-0-4_0-t9 | 27 | hover | mark_medallion (7, 4) Area mark | expanded_intent enemy_1 Faultline, 8, each Worldspine, 4 | 24.4% |
| 14 | 07-s4-seed1-4-19_-19-t4 | 7 | rest | loot_icon loot_item_0_5_5 | intent_badge enemy_1 lob | 24.0% |
| 15 | 01-s0-seed1-0-4_0-t9 | 93 | enemy_turn | terrain_health terrain_outcrop_8 | damage_popup (2, 4) −4 | 22.1% |

### Renderer controls

The selected control is overlap-free wherever the sampled cohort supplies one. The following fixtures only supply controls with fixed stage HUD, unchanged objective and mark icons, or out-of-scope ground overlap and no change in paint order across those overlaps.

- 01-s0-seed1-0-4_0-t9
- 09-s3-seed12-3-16_0-t15

Run `tools/fel14/native.sh` from this worktree to capture both sides. The release-side project is an isolated copy at the reviewed round-zero ref. The script writes the 2× paired crops, raw control frames, a pixel-difference report, and `rank-07-enemy-turn.mp4` under `tools/fel14/captures/round1-native.*/`. Each control is checked against the 0.1% pixel-difference limit.
