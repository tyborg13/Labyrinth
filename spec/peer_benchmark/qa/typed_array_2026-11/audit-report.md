# qa-19 audit details

No confirmed untyped runtime transfer was found in this snapshot. Fixed 594 project-rule literal violations. Windows itself was not run.

## Totals

| Pattern | Before | After | Fixed |
|---|---:|---:|---:|
| literal | 607 | 13 | 594 |
| conditional | 2 | 2 | 0 |
| untyped-source | 0 | 0 | 0 |
| map | 0 | 0 | 0 |
| untyped-transform | 4 | 4 | 0 |
| dictionary-get | 13 | 13 | 0 |
| unresolved-source | 82 | 82 | 0 |
| **Total** | **708** | **114** | **594** |

After: 101 false positives (100 owned, one excluded), plus 13 excluded literal violations. Before-literal contexts: {'var': 505, 'parameter-default': 17, 'const': 37, 'return': 44, 'argument': 4}.

## Files changed

New: `tools/typed_array_audit.py`. No new test module or default-group entry. Other changes are these 55 scripts; counts refer to original candidate sites.

| File | Fixed sites |
|---|---:|
| `scripts/action_icon_library.gd` | 1 |
| `scripts/analytics_store.gd` | 4 |
| `scripts/asset_loader.gd` | 4 |
| `scripts/attack_sfx_library.gd` | 1 |
| `scripts/battlefield_item_rules.gd` | 2 |
| `scripts/battlefield_rules/dispatcher.gd` | 2 |
| `scripts/board_attack_rules.gd` | 1 |
| `scripts/card_drag_targeting_arrow.gd` | 1 |
| `scripts/card_widget.gd` | 3 |
| `scripts/chronicle_panel.gd` | 1 |
| `scripts/combat_board_view.gd` | 100 |
| `scripts/combat_engine.gd` | 90 |
| `scripts/combat_objective_rules.gd` | 5 |
| `scripts/committed_pattern_shapes.gd` | 2 |
| `scripts/controller_prompt_bar.gd` | 1 |
| `scripts/cursor_feedback.gd` | 1 |
| `scripts/dragon_boss_library.gd` | 2 |
| `scripts/dragon_combat_rules.gd` | 2 |
| `scripts/elemental_spell_fx.gd` | 1 |
| `scripts/enemy_mechanics/burrow.gd` | 1 |
| `scripts/enemy_mechanics/death_burst_view.gd` | 1 |
| `scripts/enemy_mechanics/marked_strike.gd` | 1 |
| `scripts/floating_combat_text.gd` | 4 |
| `scripts/game_data.gd` | 7 |
| `scripts/grimoire_library.gd` | 12 |
| `scripts/grimoire_search.gd` | 9 |
| `scripts/guardian_library.gd` | 4 |
| `scripts/guardian_relic_rules.gd` | 3 |
| `scripts/guided_combat_scenario.gd` | 2 |
| `scripts/hand_fan_container.gd` | 1 |
| `scripts/hero_facing_combat.gd` | 1 |
| `scripts/input_glyph.gd` | 2 |
| `scripts/labyrinth_map_view.gd` | 18 |
| `scripts/maneuver_rules.gd` | 9 |
| `scripts/path_utils.gd` | 10 |
| `scripts/performance_phase_partitioner.gd` | 9 |
| `scripts/performance_telemetry.gd` | 12 |
| `scripts/progression_store.gd` | 11 |
| `scripts/protagonist_cutout/rig.gd` | 1 |
| `scripts/retaliate_rules.gd` | 4 |
| `scripts/rite_rules.gd` | 5 |
| `scripts/room_generator.gd` | 36 |
| `scripts/room_icon_library.gd` | 1 |
| `scripts/run_end_recap_overlay.gd` | 1 |
| `scripts/run_engine.gd` | 22 |
| `scripts/run_scene.gd` | 129 |
| `scripts/run_sfx_library.gd` | 1 |
| `scripts/scavenger_shop_view.gd` | 2 |
| `scripts/section_map_graph.gd` | 37 |
| `scripts/sfx_bank.gd` | 2 |
| `scripts/sfx_cue_router.gd` | 2 |
| `scripts/skill_tree_view.gd` | 2 |
| `scripts/steam_service.gd` | 4 |
| `scripts/tempo_rules.gd` | 3 |
| `scripts/turn_order_ink.gd` | 1 |

Empty typed declarations retain Godot’s typed empty default. Nonempty locals use .assign(); returns/arguments use existing typed helpers or explicit typed temporaries. Constants, parameter defaults and the nonempty member use the built-in four-argument Array constructor with explicit element metadata. Literal contents, ordering, const read-only behavior and existing aliases are preserved.

## Every false positive

Locations show before → after line numbers. Each row is one candidate, including the excluded runtime candidate.

| Location | Pattern/context | Reason |
|---|---|---|
| `scripts/asset_loader.gd:641 → 641` | dictionary-get/return | has(cache_key) dominates the return; all cache writers store polygons: Array[PackedVector2Array], so the untyped default is unreachable. |
| `scripts/battlefield_rules/bot_policy.gd:22 → 22` | unresolved-source/var | The production receiver uses scripts/combat_engine.gd:1137 valid_targets_for_player_action() -> Array[Vector2i]; its return is already typed (dynamic receiver exceeds the scan). |
| `scripts/battlefield_rules/bot_policy.gd:110 → 110` | unresolved-source/argument | The production receiver uses scripts/combat_engine.gd:8715 _vector2i_values() -> Array[Vector2i]; its return is already typed (dynamic receiver exceeds the scan). |
| `scripts/battlefield_rules/upheaval.gd:83 → 83` | unresolved-source/argument | The production receiver uses scripts/combat_engine.gd:8715 _vector2i_values() -> Array[Vector2i]; its return is already typed (dynamic receiver exceeds the scan). |
| `scripts/board_attack_rules.gd:38 → 38` | unresolved-source/assignment | The production receiver uses scripts/combat_engine.gd:8507 _best_aoe_tiles_for_target() -> Array[Vector2i]; its return is already typed (dynamic receiver exceeds the scan). |
| `scripts/board_attack_rules.gd:214 → 214` | unresolved-source/var | The production receiver uses scripts/combat_engine.gd:8218 _terrain_indices_in_tiles() -> Array[int]; its return is already typed (dynamic receiver exceeds the scan). |
| `scripts/board_attack_rules.gd:224 → 224` | unresolved-source/var | The production receiver uses scripts/combat_engine.gd:8218 _terrain_indices_in_tiles() -> Array[int]; its return is already typed (dynamic receiver exceeds the scan). |
| `scripts/board_attack_rules.gd:229 → 229` | unresolved-source/argument | The production receiver uses scripts/combat_engine.gd:7560 _trap_tiles_in_tiles() -> Array[Vector2i]; its return is already typed (dynamic receiver exceeds the scan). |
| `scripts/board_intent_clearance.gd:38 → 38` | unresolved-source/var | The production receiver uses scripts/combat_board_view.gd:10431 _offset_rects() -> Array[Rect2]; its return is already typed (dynamic receiver exceeds the scan). |
| `scripts/board_status_layout_cache.gd:262 → 262` | unresolved-source/var | The production receiver uses scripts/combat_board_view.gd:17294 _unit_status_presentation_badges() -> Array[Dictionary]; its return is already typed (dynamic receiver exceeds the scan). |
| `scripts/board_status_layout_cache.gd:265 → 265` | unresolved-source/var | The production receiver uses scripts/combat_board_view.gd:10243 _unit_hud_pip_rects() -> Array[Rect2]; its return is already typed (dynamic receiver exceeds the scan). |
| `scripts/board_status_layout_cache.gd:277 → 277` | unresolved-source/argument | raw[pieces] is written from pieces: Array[Rect2] in resolve(). |
| `scripts/board_status_layout_cache.gd:290 → 290` | unresolved-source/argument | raw[compact_pieces] is written from compact_pieces: Array[Rect2] in resolve(). |
| `scripts/board_status_layout_cache.gd:309 → 309` | unresolved-source/argument | raw[pips] is written from pips: Array[Rect2] in resolve(). |
| `scripts/board_status_layout_cache.gd:361 → 361` | unresolved-source/argument | All four iterated fields store typed Groups.translate_rects()/Plates.rects() results; the dictionary copy retains their array metadata. |
| `scripts/board_tile_tooltip.gd:13 → 13` | unresolved-source/return | The production receiver uses scripts/board_tile_tooltip_cache.gd:24 entries_for_tile() -> Array[Dictionary]; its return is already typed (dynamic receiver exceeds the scan). |
| `scripts/board_tile_tooltip_cache.gd:27 → 27` | unresolved-source/return | The sole cache writer stores result: Array[Dictionary], guarded by has(tile). |
| `scripts/character_inventory_rows.gd:185 → 185` | unresolved-source/argument | The production receiver uses scripts/run_scene.gd:30489 _current_character_row_keys() -> Array[String]; its return is already typed (dynamic receiver exceeds the scan). |
| `scripts/character_inventory_rows.gd:188 → 188` | unresolved-source/var | The production receiver uses scripts/run_scene.gd:30467 _character_row_preparation_jobs() -> Array[Callable]; its return is already typed (dynamic receiver exceeds the scan). |
| `scripts/character_inventory_rows.gd:209 → 209` | unresolved-source/var | The production receiver uses scripts/run_scene.gd:30412 _begin_hidden_character_view() -> Array[Callable]; its return is already typed (dynamic receiver exceeds the scan). |
| `scripts/character_inventory_rows.gd:253 → 253` | unresolved-source/var | The production receiver uses scripts/run_scene.gd:30467 _character_row_preparation_jobs() -> Array[Callable]; its return is already typed (dynamic receiver exceeds the scan). |
| `scripts/character_inventory_rows.gd:266 → 266` | unresolved-source/var | The production receiver uses scripts/run_scene.gd:30412 _begin_hidden_character_view() -> Array[Callable]; its return is already typed (dynamic receiver exceeds the scan). |
| `scripts/combat_board_view.gd:10258 → 10260` | untyped-transform/return | resolve() stores defenses: Array[Dictionary]; duplicate(true) retains its element type. |
| `scripts/combat_board_view.gd:10261 → 10263` | untyped-transform/return | resolve() stores statuses: Array[Dictionary]; duplicate(true) retains its element type. |
| `scripts/combat_board_view.gd:10264 → 10266` | untyped-transform/return | resolve() stores Plates.rects(statuses): Array[Rect2]; duplicate() retains its element type. |
| `scripts/combat_board_view.gd:10267 → 10269` | untyped-transform/return | resolve() stores Plates.rects(defenses): Array[Rect2]; duplicate() retains its element type. |
| `scripts/combat_board_view.gd:11232 → 11235` | conditional/var | Both HeroStrikeTrail.prepare() and EnemyStrikeTrail.prepare() declare Array[Dictionary]; both branches are typed. |
| `scripts/combat_board_view.gd:15598 → 15605` | unresolved-source/return | The guarded cache stores idle_frames: Array[Texture2D] from _load_unit_texture_with_idle(). |
| `scripts/combat_board_view.gd:15604 → 15612` | unresolved-source/return | The guarded cache stores death_frames: Array[Texture2D] from _load_unit_texture_with_idle(). |
| `scripts/combat_engine.gd:1182 → 1182` | unresolved-source/return | The return belongs to stop_after_reaching, a nested lambda explicitly returning bool; the conservative scan attributes it to the outer function. |
| `scripts/combat_engine.gd:10049 → 10049` | unresolved-source/var | Every heap entry stores start_path or next_route: Array[Vector2i]; dictionary/heap transfers preserve type. |
| `scripts/combat_engine.gd:12398 → 12398` | unresolved-source/argument | components[at] is written immediately above from component: Array[Vector2i]. |
| `scripts/committed_pattern_shapes.gd:46 → 46` | unresolved-source/var | The production receiver uses scripts/combat_engine.gd:6657 _dragon_spires() -> Array[Dictionary]; its return is already typed (dynamic receiver exceeds the scan). |
| `scripts/committed_pattern_shapes.gd:65 → 65` | unresolved-source/var | The production receiver uses scripts/run_scene.gd:33840 _enemy_footprint_tiles() -> Array[Vector2i]; its return is already typed (dynamic receiver exceeds the scan). |
| `scripts/dragon_combat_rules.gd:97 → 97` | unresolved-source/var | The production receiver uses scripts/run_scene.gd:33840 _enemy_footprint_tiles() -> Array[Vector2i]; its return is already typed (dynamic receiver exceeds the scan). |
| `scripts/dragon_combat_rules.gd:134 → 134` | unresolved-source/var | The production receiver uses scripts/combat_engine.gd:6646 _all_passable_tiles() -> Array[Vector2i]; its return is already typed (dynamic receiver exceeds the scan). |
| `scripts/encounter_asset_preparation.gd:48 → 48` | unresolved-source/argument | The production receiver uses scripts/combat_objective_hud.gd:440 opening_glyph_preparation_jobs() -> Array[Dictionary]; its return is already typed (dynamic receiver exceeds the scan). |
| `scripts/encounter_asset_preparation.gd:88 → 88` | unresolved-source/var | The production receiver uses scripts/combat_board_view.gd:14986 begin_unit_renderer_preparation() -> Array[Dictionary]; its return is already typed (dynamic receiver exceeds the scan). |
| `scripts/encounter_asset_preparation.gd:159 → 159` | unresolved-source/var | The production receiver uses scripts/run_scene.gd:5323 _begin_hidden_pre_battle_view() -> Array[Callable]; its return is already typed (dynamic receiver exceeds the scan). |
| `scripts/enemy_mechanics/bramble.gd:18 → 18` | unresolved-source/return | The production receiver uses scripts/combat_engine.gd:8715 _vector2i_values() -> Array[Vector2i]; its return is already typed (dynamic receiver exceeds the scan). |
| `scripts/enemy_mechanics/bramble.gd:21 → 21` | unresolved-source/return | The production receiver uses scripts/combat_engine.gd:8715 _vector2i_values() -> Array[Vector2i]; its return is already typed (dynamic receiver exceeds the scan). |
| `scripts/enemy_mechanics/burrow.gd:51 → 51` | unresolved-source/var | The production receiver uses scripts/combat_engine.gd:11626 _surface_actor_records() -> Array[Dictionary]; its return is already typed (dynamic receiver exceeds the scan). |
| `scripts/enemy_mechanics/burst_playback.gd:167 → 167` | unresolved-source/var | The production receiver uses scripts/combat_engine.gd:3974 _actor_target_losses() -> Array[Dictionary]; its return is already typed (dynamic receiver exceeds the scan). |
| `scripts/enemy_mechanics/capacitor.gd:93 → 93` | unresolved-source/var | The production receiver uses scripts/combat_engine.gd:3974 _actor_target_losses() -> Array[Dictionary]; its return is already typed (dynamic receiver exceeds the scan). |
| `scripts/enemy_mechanics/capacitor.gd:112 → 112` | unresolved-source/var | The production receiver uses scripts/combat_engine.gd:8715 _vector2i_values() -> Array[Vector2i]; its return is already typed (dynamic receiver exceeds the scan). |
| `scripts/enemy_mechanics/capacitor.gd:131 → 131` | unresolved-source/var | The production receiver uses scripts/combat_engine.gd:3974 _actor_target_losses() -> Array[Dictionary]; its return is already typed (dynamic receiver exceeds the scan). |
| `scripts/enemy_mechanics/deferred_death_view.gd:25 → 25` | dictionary-get/var | The production receiver uses scripts/run_scene.gd:24912 _visible_umbra_action_tiles() -> Array[Vector2i]; its return is already typed (dynamic receiver exceeds the scan). |
| `scripts/enemy_mechanics/flying.gd:11 → 11` | unresolved-source/var | The production receiver uses scripts/combat_engine.gd:8715 _vector2i_values() -> Array[Vector2i]; its return is already typed (dynamic receiver exceeds the scan). |
| `scripts/enemy_mechanics/flying.gd:15 → 15` | unresolved-source/var | The production receiver uses scripts/combat_engine.gd:8715 _vector2i_values() -> Array[Vector2i]; its return is already typed (dynamic receiver exceeds the scan). |
| `scripts/enemy_mechanics/marked_strike.gd:33 → 33` | dictionary-get/return | The production receiver uses scripts/combat_engine.gd:8715 _vector2i_values() -> Array[Vector2i]; its return is already typed (dynamic receiver exceeds the scan). |
| `scripts/enemy_mechanics/marked_strike.gd:104 → 104` | unresolved-source/var | The production receiver uses scripts/combat_engine.gd:8715 _vector2i_values() -> Array[Vector2i]; its return is already typed (dynamic receiver exceeds the scan). |
| `scripts/enemy_mechanics/marked_strike.gd:129 → 129` | dictionary-get/var | The production receiver uses scripts/combat_engine.gd:8715 _vector2i_values() -> Array[Vector2i]; its return is already typed (dynamic receiver exceeds the scan). |
| `scripts/enemy_mechanics/marked_strike.gd:271 → 271` | dictionary-get/var | The production receiver uses scripts/combat_engine.gd:8715 _vector2i_values() -> Array[Vector2i]; its return is already typed (dynamic receiver exceeds the scan). |
| `scripts/enemy_mechanics/marked_strike.gd:273 → 273` | dictionary-get/assignment | The production receiver uses scripts/combat_engine.gd:8715 _vector2i_values() -> Array[Vector2i]; its return is already typed (dynamic receiver exceeds the scan). |
| `scripts/enemy_mechanics/reaction_loss_ownership.gd:167 → 167` | dictionary-get/var | The production receiver uses scripts/run_scene.gd:26340 _floating_texts_for_target_losses() -> Array[Dictionary]; its return is already typed (dynamic receiver exceeds the scan). |
| `scripts/enemy_mechanics/reflect.gd:74 → 74` | conditional/var | Both CombatEngine._vector2i_values() and local line() return Array[Vector2i]; both branches are typed. |
| `scripts/enemy_mechanics/reflect.gd:93 → 93` | unresolved-source/var | The production receiver uses scripts/combat_engine.gd:3974 _actor_target_losses() -> Array[Dictionary]; its return is already typed (dynamic receiver exceeds the scan). |
| `scripts/enemy_mechanics/reflect_view.gd:98 → 98` | unresolved-source/var | The production receiver uses scripts/combat_engine.gd:3974 _actor_target_losses() -> Array[Dictionary]; its return is already typed (dynamic receiver exceeds the scan). |
| `scripts/enemy_mechanics/snuff.gd:118 → 118` | unresolved-source/var | The production receiver uses scripts/combat_engine.gd:8715 _vector2i_values() -> Array[Vector2i]; its return is already typed (dynamic receiver exceeds the scan). |
| `scripts/enemy_mechanics/snuff.gd:120 → 120` | unresolved-source/assignment | The production receiver uses scripts/combat_engine.gd:4721 _planned_enemy_movement_path() -> Array[Vector2i]; its return is already typed (dynamic receiver exceeds the scan). |
| `scripts/enemy_mechanics/snuff.gd:134 → 134` | unresolved-source/var | The production receiver uses scripts/combat_engine.gd:4721 _planned_enemy_movement_path() -> Array[Vector2i]; its return is already typed (dynamic receiver exceeds the scan). |
| `scripts/enemy_mechanics/stalker.gd:46 → 46` | unresolved-source/var | The production receiver uses scripts/combat_engine.gd:8715 _vector2i_values() -> Array[Vector2i]; its return is already typed (dynamic receiver exceeds the scan). |
| `scripts/enemy_mechanics/wind_view.gd:457 → 457` | unresolved-source/var | The actual receiver is CombatEngine.ManeuverRules; scripts/maneuver_rules.gd:124 declares player_badges() -> Array[Dictionary]. |
| `scripts/enemy_mechanics/wind_view.gd:465 → 465` | unresolved-source/var | The production receiver uses scripts/run_scene.gd:26172 _floating_texts_for_step() -> Array[Dictionary]; its return is already typed (dynamic receiver exceeds the scan). |
| `scripts/enemy_no_action_reason.gd:5 → 5` | unresolved-source/var | The production receiver uses scripts/combat_engine.gd:4158 _actor_targets() -> Array[Dictionary]; its return is already typed (dynamic receiver exceeds the scan). |
| `scripts/enemy_strike_points.gd:104 → 104` | unresolved-source/return | All three shipped enemy strike_samples implementations under assets/units declare Array[Dictionary]; has_method() guards the call. |
| `scripts/enemy_strike_trail.gd:89 → 89` | unresolved-source/assignment | EnemyStrikeCache.project() always writes samples: Array[Dictionary] into resolved[samples]. |
| `scripts/event_rules.gd:410 → 410` | unresolved-source/var | Both pool_by_rarity writers store pool: Array[String] from _magic_pool(); sharing this array intentionally shares remove_at(). |
| `scripts/grimoire_search_rows.gd:24 → 24` | unresolved-source/argument | _grimoire_row_preparation_key() stores _grimoire_known_row_ids(): Array[String]; duplicate(true) preserves it. |
| `scripts/hero_strike_trail.gd:54 → 54` | unresolved-source/return | The sole cache writer stores samples: Array[Dictionary], guarded by has(key). |
| `scripts/hero_strike_trail.gd:55 → 55` | unresolved-source/var | The actual protagonist_cutout/renderer.gd:152 strike_samples implementation returns Array[Dictionary]. |
| `scripts/illusion_card_rules.gd:421 → 421` | unresolved-source/var | The production receiver uses scripts/combat_engine.gd:8155 _live_illusions() -> Array[Dictionary]; its return is already typed (dynamic receiver exceeds the scan). |
| `scripts/illusion_relic_rules.gd:199 → 199` | unresolved-source/var | The production receiver uses scripts/combat_engine.gd:8155 _live_illusions() -> Array[Dictionary]; its return is already typed (dynamic receiver exceeds the scan). |
| `scripts/illusion_relic_rules.gd:210 → 210` | unresolved-source/var | The production receiver uses scripts/combat_engine.gd:1137 valid_targets_for_player_action() -> Array[Vector2i]; its return is already typed (dynamic receiver exceeds the scan). |
| `scripts/illusion_relic_rules.gd:225 → 225` | unresolved-source/argument | Every impacts entry is echo_impact(), explicitly returning Array[Vector2i]. |
| `scripts/illusion_relic_rules.gd:239 → 239` | unresolved-source/return | The production receiver uses scripts/combat_engine.gd:8507 _best_aoe_tiles_for_target() -> Array[Vector2i]; its return is already typed (dynamic receiver exceeds the scan). |
| `scripts/illusion_relic_rules.gd:242 → 242` | unresolved-source/var | The production receiver uses scripts/combat_engine.gd:11585 _surface_action_tiles() -> Array[Vector2i]; its return is already typed (dynamic receiver exceeds the scan). |
| `scripts/live_actor_presentation.gd:39 → 39` | unresolved-source/return | The sole cache writer calls Board._load_idle_frames_for_art_path() -> Array[Texture2D]; call() retains the runtime type. |
| `scripts/maquette_cutout_runtime/board_depth.gd:46 → 46` | unresolved-source/var | The production receiver uses scripts/combat_board_view.gd:15986 _rendered_tiles_in_draw_order() -> Array[Vector2i]; its return is already typed (dynamic receiver exceeds the scan). |
| `scripts/move_attack_approach.gd:28 → 28` | unresolved-source/var | The production receiver uses scripts/run_scene.gd:33840 _enemy_footprint_tiles() -> Array[Vector2i]; its return is already typed (dynamic receiver exceeds the scan). |
| `scripts/move_attack_approach.gd:64 → 64` | unresolved-source/assignment | The production receiver uses scripts/combat_engine.gd:1517 path_from_player_movement_plan() -> Array[Vector2i]; its return is already typed (dynamic receiver exceeds the scan). |
| `scripts/move_attack_approach.gd:68 → 68` | unresolved-source/assignment | The production receiver uses scripts/run_scene.gd:19947 _shortcut_move_route() -> Array[Vector2i]; its return is already typed (dynamic receiver exceeds the scan). |
| `scripts/pre_battle_view.gd:392 → 392` | unresolved-source/var | The production receiver uses scripts/run_engine.gd:1151 pre_battle_start_tiles() -> Array[Vector2i]; its return is already typed (dynamic receiver exceeds the scan). |
| `scripts/room_generator.gd:192 → 192` | unresolved-source/assignment | The nonempty formation assertion dominates this alias; SnareRooms.formation() stores positions: Array[Vector2i]. |
| `scripts/run_initial_preparation.gd:20 → 20` | unresolved-source/var | The production receiver uses scripts/run_scene.gd:1954 _initial_ui_jobs() -> Array[Callable]; its return is already typed (dynamic receiver exceeds the scan). |
| `scripts/scavenger_shop_view.gd:182 → 182` | unresolved-source/var | The production receiver uses scripts/scavenger_shop_view.gd:720 _inventory_shelf_jobs() -> Array[Callable]; its return is already typed (dynamic receiver exceeds the scan). |
| `scripts/skill_tree_library.gd:369 → 369` | unresolved-source/argument | The sole cache writer stores _copy_string_array(result) -> Array[String]; the typed parameter retains the owned copy. |
| `scripts/surface_card_rules.gd:109 → 109` | unresolved-source/return | The production receiver uses scripts/combat_engine.gd:11525 _sorted_tiles_from_lookup() -> Array[Vector2i]; its return is already typed (dynamic receiver exceeds the scan). |
| `scripts/surface_card_rules.gd:254 → 254` | dictionary-get/argument | The production receiver uses scripts/combat_engine.gd:8715 _vector2i_values() -> Array[Vector2i]; its return is already typed (dynamic receiver exceeds the scan). |
| `scripts/surface_card_rules.gd:265 → 265` | unresolved-source/var | The production receiver uses scripts/combat_engine.gd:11525 _sorted_tiles_from_lookup() -> Array[Vector2i]; its return is already typed (dynamic receiver exceeds the scan). |
| `scripts/surface_card_rules.gd:359 → 359` | unresolved-source/return | The production receiver uses scripts/combat_engine.gd:11525 _sorted_tiles_from_lookup() -> Array[Vector2i]; its return is already typed (dynamic receiver exceeds the scan). |
| `scripts/surface_card_rules.gd:393 → 393` | dictionary-get/var | The production receiver uses scripts/combat_engine.gd:8715 _vector2i_values() -> Array[Vector2i]; its return is already typed (dynamic receiver exceeds the scan). |
| `scripts/surface_card_rules.gd:396 → 396` | dictionary-get/var | The production receiver uses scripts/combat_engine.gd:8715 _vector2i_values() -> Array[Vector2i]; its return is already typed (dynamic receiver exceeds the scan). |
| `scripts/surface_card_rules.gd:496 → 496` | unresolved-source/return | The production receiver uses scripts/combat_engine.gd:11525 _sorted_tiles_from_lookup() -> Array[Vector2i]; its return is already typed (dynamic receiver exceeds the scan). |
| `scripts/surface_card_rules.gd:499 → 499` | unresolved-source/var | The production receiver uses scripts/combat_engine.gd:3232 aoe_tiles_for_player_action() -> Array[Vector2i]; its return is already typed (dynamic receiver exceeds the scan). |
| `scripts/surface_card_rules.gd:533 → 533` | dictionary-get/var | The production receiver uses scripts/combat_engine.gd:8715 _vector2i_values() -> Array[Vector2i]; its return is already typed (dynamic receiver exceeds the scan). |
| `scripts/surface_card_rules.gd:565 → 565` | unresolved-source/argument | The production receiver uses scripts/combat_engine.gd:8218 _terrain_indices_in_tiles() -> Array[int]; its return is already typed (dynamic receiver exceeds the scan). |
| `scripts/surface_card_rules.gd:566 → 566` | unresolved-source/var | The production receiver uses scripts/combat_engine.gd:4051 _enemy_target_losses() -> Array[Dictionary]; its return is already typed (dynamic receiver exceeds the scan). |
| `scripts/surface_card_rules.gd:593 → 593` | dictionary-get/var | The production receiver uses scripts/combat_engine.gd:8715 _vector2i_values() -> Array[Vector2i]; its return is already typed (dynamic receiver exceeds the scan). |
| `scripts/surface_variety_relic_rules.gd:223 → 223` | unresolved-source/var | The production receiver uses scripts/combat_engine.gd:6637 _all_actor_passable_tiles() -> Array[Vector2i]; its return is already typed (dynamic receiver exceeds the scan). |
| `scripts/warband_combat_rules.gd:98 → 98` | dictionary-get/return | The production receiver uses scripts/combat_engine.gd:8715 _vector2i_values() -> Array[Vector2i]; its return is already typed (dynamic receiver exceeds the scan). |

## Findings for other owners

Unchanged guardian literal initializers (project-rule findings, locally accepted):

- `scripts/guardian_combat_rules.gd:20` — result: `[]`.
- `scripts/guardian_combat_rules.gd:25` — result: `[]`.
- `scripts/guardian_combat_rules.gd:32` — result: `[]`.
- `scripts/guardian_combat_rules.gd:86` — result: `[]`.
- `scripts/guardian_combat_rules.gd:109` — all_tiles: `[]`.
- `scripts/guardian_combat_rules.gd:114` — affected: `[]`.
- `scripts/guardian_combat_rules.gd:140` — conductors: `[]`.
- `scripts/guardian_combat_rules.gd:384` — valid: `[]`.
- `scripts/guardian_combat_rules.gd:396` — result: `[]`.
- `scripts/guardian_combat_rules.gd:519` — result: `[]`.
- `scripts/guardian_combat_rules.gd:586` — seeds: `[]`.
- `scripts/guardian_combat_rules.gd:590` — best: `[]`.
- `scripts/guardian_combat_rules.gd:598` — new_tiles: `[]`.

`scripts/maquette_cutout_runtime/board_depth.gd:46` is an excluded false positive: board._rendered_tiles_in_draw_order() returns Array[Vector2i]. No candidates in run_scene.gd hover handlers or combat_engine.gd committed_plan branches. `assets/units/storm_cantor_cutout/` does not exist in this checkout. Excluded code and assets are unchanged.

## Runtime table

Godot 4.6.1.stable.official.14d19694e on macOS, headless via the mandatory task runner. The original 30 cases and five constructor/default controls ran independently.

| Case | Observed |
|---|---|
| argument_conditional | ERROR: SCRIPT ERROR: Invalid type in function 'accept' in base 'SceneTree (argument_conditional.gd)'. The array of argument 1 (Array) does not have the same element type as the expected typed array argument. |
| argument_literal | PASS |
| argument_plain | ERROR: SCRIPT ERROR: Invalid type in function 'accept' in base 'SceneTree (argument_plain.gd)'. The array of argument 1 (Array) does not have the same element type as the expected typed array argument. |
| assign_control | PASS |
| conditional_literal | ERROR: SCRIPT ERROR: Trying to assign an array of type "Array" to a variable of type "Array[int]". |
| conditional_typed | PASS |
| conditional_unselected | PASS |
| constructor | ERROR: SCRIPT ERROR: Parse Error: Cannot call on an expression. Use ".call()" if it's a Callable. |
| dictionary_get | ERROR: SCRIPT ERROR: Trying to assign an array of type "Array" to a variable of type "Array[int]". |
| dictionary_typed | PASS |
| duplicate_typed | PASS |
| filter_typed | PASS |
| filter_untyped | ERROR: SCRIPT ERROR: Trying to assign an array of type "Array" to a variable of type "Array[int]". |
| literal_const | PASS |
| literal_empty | PASS |
| literal_local | PASS |
| literal_member | PASS |
| literal_reassign | PASS |
| map_typed | ERROR: SCRIPT ERROR: Trying to assign an array of type "Array" to a variable of type "Array[int]". |
| parameter_constructor | PASS |
| parameter_default | PASS |
| plain_call | ERROR: SCRIPT ERROR: Trying to assign an array of type "Array" to a variable of type "Array[int]". |
| plain_duplicate | ERROR: SCRIPT ERROR: Trying to assign an array of type "Array" to a variable of type "Array[int]". |
| plain_source | ERROR: SCRIPT ERROR: Trying to assign an array of type "Array" to a variable of type "Array[int]". |
| return_conditional | ERROR: SCRIPT ERROR: Trying to return an array of type "Array" where expected return type is "Array[int]". |
| return_literal | PASS |
| return_plain | ERROR: SCRIPT ERROR: Trying to return an array of type "Array" where expected return type is "Array[int]". |
| slice_typed | PASS |
| slice_untyped | ERROR: SCRIPT ERROR: Trying to assign an array of type "Array" to a variable of type "Array[int]". |
| typed_constructor | PASS |
| const_constructor | PASS |
| const_string_name | PASS |
| parameter_dictionary | PASS |
| parameter_texture | PASS |
| parameter_vector | PASS |

True hazards: plain Array transfers into typed targets, typed returns and typed parameters; selected untyped conditional branches; map() even on a typed receiver; duplicate/filter/slice on an untyped receiver; missing dictionary keys falling back to []. A selected typed branch succeeds. Typed dictionary payloads and typed duplicate/filter/slice succeed. Direct literals/defaults/returns/arguments/constants pass here but remain forbidden by project rule. `Array[int](...)` is a deliberate parser-negative control; the built-in metadata constructor and .assign() controls pass.

## Proof and artifacts

All commands run in the qa-19 worktree with `LABYRINTH_CEL_LOOK=off`. No full suite, windowed launch, editor parser scan, reviewer, commit, push or branch mutation.

```sh
python3 tools/typed_array_audit.py --self-test
python3 tools/typed_array_audit.py --runtime-probes /private/tmp/labyrinth_codex/qa-19/repro --task-id qa-19
python3 tools/typed_array_audit.py --runtime-probes /private/tmp/labyrinth_codex/qa-19/constructor-repro --runtime-case const_constructor --runtime-case const_string_name --runtime-case parameter_dictionary --runtime-case parameter_texture --runtime-case parameter_vector
python3 tools/typed_array_audit.py --json /private/tmp/labyrinth_codex/qa-19/after.json
python3 tools/godot_task_runner.py --task-id qa-19 --timeout 500 --stream -- godot --headless --path . --import
python3 tools/godot_task_runner.py --task-id qa-19 --stream -- godot --headless --path . --script /private/tmp/labyrinth_codex/qa-19/parse_changed.gd
python3 tools/godot_task_runner.py --task-id qa-19 --stream -- godot --headless --path . --script /private/tmp/labyrinth_codex/qa-19/focused_suites.gd
python3 tools/run_python_suite.py --shards 4 --changed-since HEAD --output-dir /private/tmp/labyrinth_codex/qa-19/python-default
```

Standalone programs use `python3 tools/godot_task_runner.py --task-id qa-19 --stream -- godot --headless --path . --script tests/<name>.gd`: performance_telemetry_test, surface_analytics_batch_test, save_resume_boundary_test, sfx_sync_bank_test, guided_combat_tutorial_integration_test. Exact result lines/return codes: `focused-programs.json`; complete per-program `.log` files are beside it.

`focused_suites.gd` names all 25 selected suites; `focused-suites.log` has cumulative counts per suite. `parser.log` proves the successful 55-script project load. The initial parser attempt caught two mechanical inline-if expansions in grimoire_search.gd; corrected before final checks. Cold import completed with exit 0; engine log: `/private/tmp/labyrinth-godot-home/qa-19-1793589284577827000-71552/godot.log`.

`before.json/.txt` runs the final scanner on pre-edit per-file snapshots under `originals/`; `after.json/.txt` is final CLI output. `fixes.json` records 594 original locations. `review.json` records every false-positive reason. `repro/` and `constructor-repro/` retain each runtime source/error log/result. No captures: visual proof is not applicable or requested.

Known non-failing output: macOS certificate-store error during headless startup; card-drag source-image loading warnings; ObjectDB leak warning at exit. Python passed; optional timing-cache update was denied by read-only Git metadata:

```text
Cannot update untracked timing cache /Users/borgerding/workspace/Labyrinth/.git/labyrinth-test-timings/python-suite.json: [Errno 1] Operation not permitted: '/Users/borgerding/workspace/Labyrinth/.git/labyrinth-test-timings/tmpfxvhdd2m'
```

## Chosen defaults / remaining work

Debug-only defaults: `PROBE_TIMEOUT_SECONDS = 20`; integer sample 1 and macOS feature branch selection in named `PROBE_CASES`; four Python shards; scratch proof scripts and isolated user:// names. No player-facing defaults or TODO_DESIGN placeholders. The director owns excluded fixes, commit, review and publication. Static analysis remains conservative for arbitrary dynamic dispatch/dictionary dataflow; future hits need review.
