extends SceneTree

const GameData = preload("res://scripts/game_data.gd")
const AnalyticsStore = preload("res://scripts/analytics_store.gd")
const ActionIcons = preload("res://scripts/action_icon_library.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RoomGenerator = preload("res://scripts/room_generator.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")
const CombatBoardView = preload("res://scripts/combat_board_view.gd")
const SegmentedHealthBar = preload("res://scripts/segmented_health_bar.gd")
const LabyrinthMapView = preload("res://scripts/labyrinth_map_view.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const DialogueEngine = preload("res://scripts/dialogue_engine.gd")
const ElementData = preload("res://scripts/element_data.gd")
const HandFanContainer = preload("res://scripts/hand_fan_container.gd")
const MusicLibrary = preload("res://scripts/music_library.gd")
const PathUtils = preload("res://scripts/path_utils.gd")
const RoomIcons = preload("res://scripts/room_icon_library.gd")
const UiSkin = preload("res://scripts/ui_skin.gd")
const UiTooltipPanel = preload("res://scripts/ui_tooltip_panel.gd")
const CardWidget = preload("res://scripts/card_widget.gd")
const CardWidgetScript = CardWidget

var _failures: Array[String] = []

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	ProgressionStore.set_storage_path("user://labyrinth_progression_test.json")
	ProgressionStore.set_run_storage_path("user://labyrinth_run_test.save")
	AnalyticsStore.set_storage_dir("user://labyrinth_analytics_test")
	AnalyticsStore.clear_storage()
	var default_progression: Dictionary = ProgressionStore.default_data()
	_assert(GameData.cards().size() >= 20, "Card data should load")
	_assert(GameData.enemies().size() >= 5, "Enemy data should load")
	_assert(GameData.npcs().size() >= 1, "NPC data should load")
	_assert(GameData.relics().size() >= 5, "Relic data should load")
	_assert(GameData.equipment().size() >= 5, "Equipment data should load")
	_assert(GameData.upgrades().size() >= 3, "Upgrade data should load")
	_test_music_library_routes_elemental_combat_tracks()
	_test_relic_data_rarity_and_offer_weights()
	_test_equipment_data_rarity_and_starter_deck()
	_test_room_generation_is_deterministic()
	_test_room_generation_keeps_spawn_reachable()
	_test_room_generation_enemy_spawns_keep_player_halo()
	_test_room_generation_blocks_door_tiles()
	_test_room_generation_uses_perimeter_walls_only()
	_test_room_generation_avoids_adjacent_columns()
	_test_room_generation_uses_stone_floor_with_moss_accents()
	_test_room_generation_populates_elemental_traps()
	_test_room_generation_adds_pickups_and_destructible_terrain()
	_test_special_rooms_use_corner_pillar_layout()
	_test_room_generation_scales_enemy_density()
	_test_boss_room_spawns_zekarion_with_wisps()
	_test_second_sequence_uses_scaled_zekarion_placeholder()
	_test_start_room_spawns_emaciated_man()
	_test_fatigue_draws_cost_health_and_burn_removes_card()
	_test_two_card_turn_draw_flow()
	_test_initiative_order_starts_with_active_player_and_fast_enemies()
	_test_initiative_advances_enemy_turns_until_player_reacts()
	_test_card_time_scale_changes_player_reentry_order()
	_test_agility_reduces_player_base_initiative()
	_test_combat_log_is_bounded()
	_test_card_play_action_grants_bonus_play()
	_test_starting_deck_uses_hamstring_shot_over_bone_dart()
	_test_equipment_run_state_and_reward_cards(default_progression)
	_test_equipment_collection_to_equip_deck_flow(default_progression)
	_test_elemental_intensity_starts_from_room_element()
	_test_elemental_intensity_actions_gate_effects()
	_test_elemental_intensity_icons_surface_card_requirements()
	_test_elemental_intensity_bonus_modifies_single_attack()
	_test_cards_do_not_define_multiple_player_attacks()
	_test_illusion_action_creates_decoy_and_redirects_enemy()
	_test_enemy_target_ties_randomize_between_player_side_actors()
	_test_enemy_death_grants_card_play_and_embers()
	_test_summoned_enemy_death_does_not_grant_card_play()
	_test_hand_draw_caps_at_eight()
	_test_first_attack_bonus_damage_math()
	_test_relic_effect_hooks()
	_test_tailwind_fletching_modifies_existing_forced_movement()
	_test_pierce_ignores_defenses()
	_test_bleed_expose_and_sunder_keywords()
	_test_enemy_pierce_intents_surface_icons()
	_test_pierce_cards_stay_in_allowed_elements()
	_test_immobilize_cards_stay_in_allowed_elements()
	_test_healing_cards_are_burned_and_downweighted()
	_test_low_movement_enemies_advance_without_outpacing_crawlers()
	_test_harrier_has_moving_ranged_attack()
	_test_player_block_absorbs_full_enemy_phase()
	_test_enemy_block_applies_on_actor_turn_only()
	_test_aoe_hits_multiple_targets()
	_test_close_aoe_hits_adjacent_targets()
	_test_rotated_line_aoe_uses_selected_orientation()
	_test_combat_board_orders_line_aoe_preview_tiles()
	_test_forced_movement_uses_selected_straight_line()
	_test_enemy_phase_preserves_preview_cycle()
	_test_elemental_room_rewards_follow_affinity(default_progression)
	_test_chain_hits_clustered_enemies()
	_test_freeze_and_shock_control_turn_flow()
	_test_immobilize_control_turn_flow()
	_test_traps_trigger_and_apply_current_turn_control()
	_test_traps_roll_control_to_next_turn_when_no_plays_remain()
	_test_move_paths_only_cross_required_traps()
	_test_terrain_blocks_movement_without_blocking_line_of_sight()
	_test_attacking_trap_blasts_adjacent_tiles()
	_test_enemy_attacks_profitable_trap_without_self_damage()
	_test_enemy_breaks_blocking_terrain()
	_test_enemy_moves_toward_breakable_chokepoint()
	_test_poison_and_stoneskin_behaviors()
	_test_statuses_tick_on_affected_actor_turn()
	_test_out_of_range_elemental_enemy_attack_skips_step()
	_test_enemy_close_aoe_still_hits_player()
	_test_enemy_threat_tiles_follow_intent()
	_test_enemy_threat_tiles_assume_player_can_vacate_current_tile()
	_test_enemy_threat_tiles_include_enemy_triggered_trap_blasts()
	_test_large_enemy_threat_tiles_use_footprint()
	_test_lightning_strikes_threat_tiles_are_previewed()
	_test_zekarion_tempest_breath_leaves_corner_safety()
	_test_zekarion_summons_wisps_when_alone()
	_test_summoned_wisps_receive_preview_intents()
	_test_zekarion_ignores_shock_status()
	_test_enemy_pathfinding_avoids_traps()
	_test_shallow_elemental_enemy_actions_scale_back()
	_test_status_badges_surface_countdowns()
	_test_player_restriction_badges_show_turn_lock()
	_test_air_trap_tooltip_is_damage_only()
	_test_pickup_tooltips_describe_effects()
	_test_terrain_health_bars_are_contextual()
	_test_health_bar_segments_use_fixed_point_scale()
	_test_run_scene_terrain_damage_previews_use_terrain_keys()
	_test_enemy_intent_name_reserves_header_line()
	_test_enemy_intent_panels_expand_on_hover_or_toggle()
	_test_enemy_hud_layout_stays_centered_when_clear()
	_test_enemy_hud_layout_offsets_away_from_reserved_ui()
	_test_enemy_hud_layout_offsets_down_from_top_edge()
	_test_boss_intent_layout_avoids_boss_health_bar()
	_test_boss_health_bar_overlays_above_board_origin()
	_test_enemy_art_scale_preserves_center()
	_test_enemy_art_offset_shifts_sprite_vertically()
	_test_enemy_intent_popup_expands_for_long_titles()
	_test_unit_shadow_uses_alpha_silhouette()
	_test_player_uses_original_anime_art()
	_test_combat_board_keeps_equipment_data_off_player_sprite()
	_test_combat_board_surfaces_illusion_units()
	_test_combat_board_surfaces_illusion_preview_units()
	_test_trial_enemy_art_uses_matching_idle_sheets()
	_test_zekarion_uses_matching_idle_sheet()
	_test_lightning_wisp_uses_normal_loop_idle_sheet()
	_test_emaciated_man_uses_matching_idle_sheet()
	_test_unit_hud_stacks_above_sprite_art()
	_test_combat_board_zooms_to_rendered_room_bounds()
	_test_foreground_props_fade_when_covering_behind_objects()
	_test_pillar_art_fits_bottom_center_without_stretching()
	_test_pillar_torch_fixtures_mount_on_both_visible_faces()
	_test_column_torch_idle_sheets_load_and_are_clean()
	_test_pillar_moss_overlay_is_anchored_to_pillar_cap()
	_test_wall_and_pillar_assets_stay_distinct()
	_test_boundary_prop_art_uses_single_tile_footprint()
	_test_boundary_wall_segments_use_full_spans_on_straight_edges()
	_test_boundary_wall_corner_tiles_split_into_two_half_segments()
	_test_door_art_uses_source_and_flipped_variant()
	_test_standalone_door_art_stays_within_single_tile_footprint()
	_test_visible_doors_use_dedicated_frame()
	_test_door_frames_slide_toward_each_back_edge()
	_test_door_opening_sheet_loads_as_directional_frames()
	_test_combat_board_hides_outer_walls_without_hiding_visible_doors()
	_test_combat_board_assigns_deterministic_floor_variants()
	_test_combat_board_ambient_particles_follow_room_element()
	_test_combat_board_draw_order_tracks_moving_unit_world_position()
	_test_keyword_icon_library_surfaces_tooltips()
	_test_room_icon_library_covers_door_room_types()
	_test_minimap_uses_door_icons_and_greys_cleared_rooms()
	_test_combat_board_loads_door_icons_for_room_types()
	_test_run_map_room_types()
	_test_run_map_relic_room_spacing_and_density()
	_test_run_map_repeats_depth_sequences()
	_test_run_map_ring_links_and_outward_quarter()
	_test_run_map_seals_departed_rooms()
	_test_run_map_never_moves_back_toward_center()
	_test_run_map_last_loop_room_opens_outward()
	_test_empty_treasure_room_falls_back_to_room_mode()
	_test_run_engine_campfire_linger_heals_and_continues()
	_test_loaded_run_repairs_stranded_room_visibility()
	_test_combat_finish_generates_reward_state()
	_test_intermediate_boss_opens_next_sequence()
	_test_boss_victory_restores_player_health()
	_test_progression_save_and_purchase(default_progression)
	_test_emaciated_man_does_not_unlock_card_upgrade_dialogue()
	_test_recovery_marker_flow()
	_test_recovery_marker_expires_after_next_run()
	_test_run_state_save_and_load()
	_test_hand_fan_layout_lifts_center_cards()
	_test_default_theme_uses_pixel_font()
	await _test_main_scenes_instantiate()
	await _test_run_scene_minimap_click_opens_large_map()
	await _test_run_scene_debug_boss_fixture_boots()
	await _test_run_scene_offers_pass_during_combat()
	await _test_run_scene_offers_pass_when_hand_dead()
	await _test_run_scene_action_selection_buttons_are_large()
	await _test_run_scene_action_selection_keeps_hand_layout_stable()
	await _test_run_scene_idle_hand_refresh_clears_card_fx_ghosts()
	await _test_run_scene_reward_heal_choice_sits_with_cards()
	await _test_run_scene_selection_prompts_clear_after_pick()
	await _test_run_scene_fatigue_damage_visual_event()
	await _test_run_scene_campfire_choices_use_relic_overlay()
	await _test_run_scene_campfire_bonfire_persists_after_leave()
	await _test_run_scene_optional_followup_attack_stays_playable()
	await _test_run_scene_move_attack_shortcut_clicks_enemy()
	await _test_run_scene_aoe_aim_rotates_before_click()
	await _test_run_scene_push_direction_tiles_filter_closer_tiles()
	await _test_run_scene_block_card_skips_dead_move()
	await _test_run_scene_targetless_card_click_commits_play()
	_test_run_scene_fallback_attack_uses_scaled_damage()
	await _test_run_scene_card_play_meter_spends_before_resolution_rewards()
	await _test_run_scene_damage_display_matches_bonus()
	await _test_run_scene_intensity_condition_rows_mark_activity()
	await _test_run_scene_ranged_cards_show_range()
	await _test_run_scene_preview_normalizes_untyped_target_tiles()
	await _test_run_scene_illusion_hover_surfaces_preview_unit()
	await _test_run_scene_move_previews_avoid_traps_when_possible()
	await _test_run_scene_hovered_enemy_shows_threat_overlay()
	await _test_run_scene_animation_lock_preserves_board_animation_presentation()
	await _test_run_scene_discard_pile_is_face_up_without_count()
	await _test_run_scene_displays_owned_relic_icons()
	await _test_run_scene_relic_header_keeps_relics_and_intensity_tight()
	await _test_run_scene_attack_impact_presentation_drops_projectile_effect()
	await _test_run_scene_auto_triggers_starting_npc_dialogue()
	await _test_run_scene_character_stats_overlay_opens()
	await _test_run_scene_logs_local_analytics()
	await _test_main_menu_shows_continue_for_saved_run()

	if _failures.is_empty():
		print("TEST RESULT: PASS")
		quit(0)
		return

	for failure: String in _failures:
		push_error(failure)
	print("TEST RESULT: FAIL (%d failure(s))" % _failures.size())
	quit(1)

func _test_music_library_routes_elemental_combat_tracks() -> void:
	var expected_tracks: Dictionary = {
		ElementData.FIRE: MusicLibrary.FIRE_COMBAT_TRACK_ID,
		ElementData.ICE: MusicLibrary.ICE_COMBAT_TRACK_ID,
		ElementData.LIGHTNING: MusicLibrary.LIGHTNING_COMBAT_TRACK_ID,
		ElementData.AIR: MusicLibrary.AIR_COMBAT_TRACK_ID,
		ElementData.EARTH: MusicLibrary.EARTH_COMBAT_TRACK_ID
	}
	for element_id_var: Variant in expected_tracks.keys():
		var element_id: String = str(element_id_var)
		var entry: Dictionary = MusicLibrary.entry_for_context("combat", {
			"type": "combat",
			"element": element_id
		})
		var expected_track_id: String = str(expected_tracks.get(element_id, ""))
		var path: String = str(entry.get("path", ""))
		_assert(str(entry.get("id", "")) == expected_track_id, "%s combat rooms should use their element music track" % ElementData.name(element_id))
		_assert(FileAccess.file_exists(path), "%s music asset should exist" % expected_track_id)
		_assert(_audio_asset_loads(path), "%s music asset should load as audio" % expected_track_id)
	var room_entry: Dictionary = MusicLibrary.entry_for_context("room", {
		"type": "combat",
		"element": ElementData.FIRE
	})
	_assert(str(room_entry.get("id", "")) == MusicLibrary.FIRE_COMBAT_TRACK_ID, "Uncleared elemental combat rooms should use their element music outside combat mode")
	var cleared_entry: Dictionary = MusicLibrary.entry_for_context("room", {
		"type": "combat",
		"element": ElementData.FIRE,
		"cleared": true
	})
	_assert(str(cleared_entry.get("id", "")) == MusicLibrary.RELIC_ROOM_TRACK_ID, "Cleared combat rooms should still switch to the post-combat room music")
	var generic_entry: Dictionary = MusicLibrary.entry_for_context("combat", {
		"type": "combat",
		"element": ElementData.NONE
	})
	_assert(str(generic_entry.get("id", "")) == MusicLibrary.GENERIC_COMBAT_TRACK_ID, "Neutral combat should keep the generic combat music fallback")
	var boss_entry: Dictionary = MusicLibrary.entry_for_context("combat", {
		"type": "boss",
		"element": ElementData.LIGHTNING,
		"boss_id": "zekarion"
	})
	_assert(str(boss_entry.get("id", "")) == MusicLibrary.ZEKARION_BOSS_TRACK_ID, "Zekarion should keep boss music over elemental music")
	var generic_boss_entry: Dictionary = MusicLibrary.entry_for_context("combat", {
		"type": "boss",
		"element": ElementData.LIGHTNING
	})
	_assert(str(generic_boss_entry.get("id", "")) == MusicLibrary.GENERIC_COMBAT_TRACK_ID, "Boss fallback should not use non-boss elemental combat music")

func _audio_asset_loads(path: String) -> bool:
	if path.get_extension().to_lower() == "wav":
		return AudioStreamWAV.load_from_file(path) != null
	return load(path) is AudioStream

func _test_relic_data_rarity_and_offer_weights() -> void:
	var valid_rarities: Dictionary = {
		"common": true,
		"rare": true,
		"epic": true,
		"legendary": true
	}
	_assert(GameData.relics().size() >= 20, "Relic pool should have enough breadth for build choices")
	for relic_id: String in GameData.relic_ids():
		var relic: Dictionary = GameData.relic_def(relic_id)
		var rarity: String = str(relic.get("rarity", ""))
		_assert(valid_rarities.has(rarity), "%s should use the relic rarity set" % relic_id)
		_assert(str(relic.get("accent", "")) == GameData.relic_rarity_accent(rarity), "%s border accent should match relic rarity" % relic_id)
		_assert(not (relic.get("effects", []) as Array).is_empty(), "%s should define reusable relic effects" % relic_id)
		var description: String = str(relic.get("description", ""))
		_assert(not description.contains("{") and not description.contains("}"), "%s description placeholders should be formatted for display" % relic_id)
		var icon_path: String = str(relic.get("icon_path", ""))
		_assert(FileAccess.file_exists(icon_path), "%s relic icon should exist" % relic_id)
	_assert(str(GameData.relic_def("thornmail_brooch").get("description", "")).contains("10 damage"), "Thornmail Brooch should display fixed-point thorns damage")
	_assert(str(GameData.relic_def("obsidian_heart").get("description", "")).contains("100 stoneskin"), "Obsidian Heart should display fixed-point stoneskin")
	_assert(str(GameData.relic_def("obsidian_heart").get("description", "")).contains("draw 1 fewer"), "Obsidian Heart should format negative draw as a positive fewer amount")
	_assert(str(GameData.relic_def("black_sun_dial").get("description", "")).contains("deal 30"), "Black Sun Dial should display fixed-point all-enemy damage")
	_assert(GameData.relic_offer_weight("iron_lung") > GameData.relic_offer_weight("ember_lens"), "Common relics should be offered more often than rare relics")
	_assert(GameData.relic_offer_weight("ember_lens") > GameData.relic_offer_weight("bloodglass_knife"), "Rare relics should be offered more often than epic relics")
	_assert(GameData.relic_offer_weight("bloodglass_knife") > GameData.relic_offer_weight("storm_crown"), "Epic relics should be offered more often than legendary relics")

func _test_equipment_data_rarity_and_starter_deck() -> void:
	var valid_rarities: Dictionary = {
		"common": true,
		"rare": true,
		"epic": true,
		"legendary": true
	}
	var slot_counts: Dictionary = {}
	for slot: String in GameData.equipment_slots():
		slot_counts[slot] = 0
	var starter_ids: Array = GameData.starter_equipment_ids()
	_assert(starter_ids.size() == GameData.equipment_slots().size(), "Starter equipment should fill every equipment slot")
	_assert(GameData.equipment().size() >= 20, "Equipment pool should have enough breadth for room drops")
	for equipment_id_var: Variant in GameData.equipment_ids():
		var equipment_id: String = str(equipment_id_var)
		var item: Dictionary = GameData.equipment_def(equipment_id)
		var slot: String = str(item.get("slot", ""))
		var rarity: String = str(item.get("rarity", ""))
		_assert(GameData.equipment_slots().has(slot), "%s should use a valid equipment slot" % equipment_id)
		slot_counts[slot] = int(slot_counts.get(slot, 0)) + 1
		_assert(valid_rarities.has(rarity), "%s should use the relic rarity set" % equipment_id)
		_assert(str(item.get("accent", "")) == GameData.equipment_rarity_accent(rarity), "%s border accent should match equipment rarity" % equipment_id)
		var icon_path: String = str(item.get("icon_path", ""))
		_assert(FileAccess.file_exists(icon_path), "%s equipment icon should exist" % equipment_id)
		var icon_image := Image.new()
		var icon_load_error: Error = icon_image.load(icon_path)
		_assert(icon_load_error == OK and icon_image.get_width() == 96 and icon_image.get_height() == 96, "%s equipment icon should be a 96x96 project asset" % equipment_id)
		var card_ids: Array = GameData.equipment_cards(equipment_id)
		_assert(not card_ids.is_empty(), "%s should contribute at least one card" % equipment_id)
		for card_id_var: Variant in card_ids:
			var card_id: String = str(card_id_var)
			_assert(not GameData.card_def(card_id).is_empty(), "%s should reference an existing card" % equipment_id)
		if bool(item.get("starter", false)):
			_assert(starter_ids.has(equipment_id), "%s should be registered as a starter equipment item" % equipment_id)
			_assert(icon_path.begins_with("res://assets/art/equipment/"), "%s starter equipment should use custom equipment art, not reused relic art" % equipment_id)
	for slot: String in GameData.equipment_slots():
		_assert(int(slot_counts.get(slot, 0)) >= 3, "%s slot should have multiple equipment options" % slot.capitalize())
	var equipped: Dictionary = GameData.starting_equipped_equipment()
	for slot: String in GameData.equipment_slots():
		_assert(not str(equipped.get(slot, "")).is_empty(), "Starting equipment should define %s" % slot)
	var starter_equipment_deck: Array = GameData.compile_deck_cards(equipped, [])
	_assert(starter_equipment_deck.size() == 10, "Starter equipment should still compile to ten gear cards")
	for card_id: String in [
		"quick_stab",
		"guarded_step",
		"shadow_step",
		"hamstring_shot",
		"sidestep_slash",
		"whirlwind_slash",
		"patch_up",
		"bloody_lunge",
		"brace",
		"lantern_shot"
	]:
		_assert(starter_equipment_deck.has(card_id), "Starter equipment should preserve %s in the gear deck" % card_id)
	_assert(GameData.magic_loadout_limit() == 6, "Magic loadout should currently cap at six attuned cards")
	var starting_deck: Array = GameData.starting_deck()
	_assert(starting_deck.size() == starter_equipment_deck.size() + GameData.magic_loadout_limit(), "Full starting deck should add six default magic cards to starter equipment")
	for card_id_var: Variant in GameData.starting_magic_cards():
		_assert(starting_deck.has(str(card_id_var)), "Full starting deck should include default magic card %s" % str(card_id_var))

func _test_room_generation_is_deterministic() -> void:
	var generator: RoomGenerator = RoomGenerator.new()
	var room_meta: Dictionary = {
		"coord": Vector2i(1, 0),
		"depth": 1,
		"type": "combat"
	}
	var a: Dictionary = generator.generate_room(17, room_meta, Vector2i(1, 0))
	var b: Dictionary = generator.generate_room(17, room_meta, Vector2i(1, 0))
	_assert(a.get("grid", []) == b.get("grid", []), "Room generation should be deterministic for identical inputs")
	_assert(a.get("player_start", Vector2i(-1, -1)) == b.get("player_start", Vector2i.ZERO), "Player spawn should be deterministic")
	_assert(a.get("enemies", []) == b.get("enemies", []), "Enemy spawn pattern should be deterministic")

func _test_room_generation_keeps_spawn_reachable() -> void:
	var generator: RoomGenerator = RoomGenerator.new()
	var room_meta: Dictionary = {
		"coord": Vector2i(2, 1),
		"depth": 3,
		"type": "combat"
	}
	var room: Dictionary = generator.generate_room(99, room_meta, Vector2i(0, -1))
	var grid: Array = room.get("grid", [])
	var spawn: Vector2i = room.get("player_start", Vector2i.ZERO)
	var reachable: Array[Vector2i] = PathUtils.reachable_tiles(grid, spawn, 20, {})
	_assert(reachable.size() >= 14, "Generated rooms should leave a broad reachable footprint from the entry tile")

func _test_room_generation_enemy_spawns_keep_player_halo() -> void:
	var generator: RoomGenerator = RoomGenerator.new()
	var sampled_close_spawn: bool = false
	for seed: int in range(40, 70):
		var room: Dictionary = generator.generate_room(seed, {
			"coord": Vector2i(seed % 4, seed % 5),
			"depth": 3,
			"type": "combat"
		}, Vector2i(1, 0))
		var player_start: Vector2i = room.get("player_start", Vector2i.ZERO)
		for enemy_var: Variant in room.get("enemies", []):
			if typeof(enemy_var) != TYPE_DICTIONARY:
				continue
			var enemy: Dictionary = enemy_var
			var distance: int = PathUtils.manhattan(enemy.get("pos", Vector2i(-1, -1)), player_start)
			_assert(distance > RoomGenerator.ENEMY_SPAWN_SAFE_RADIUS, "Enemy spawns should keep the player entry halo clear")
			if distance <= RoomGenerator.ENEMY_SPAWN_SAFE_RADIUS + 2:
				sampled_close_spawn = true
	_assert(sampled_close_spawn, "Enemy spawns should sometimes land near the halo instead of always favoring the far side")

func _test_room_generation_blocks_door_tiles() -> void:
	var generator: RoomGenerator = RoomGenerator.new()
	var room_meta: Dictionary = {
		"coord": Vector2i(1, 2),
		"depth": 2,
		"type": "combat",
		"connections": [
			{"door_dir": Vector2i(0, -1), "coord": Vector2i(1, 1)},
			{"door_dir": Vector2i(1, 0), "coord": Vector2i(2, 2)},
			{"door_dir": Vector2i(0, 1), "coord": Vector2i(1, 3)},
			{"door_dir": Vector2i(-1, 0), "coord": Vector2i(0, 2)}
		]
	}
	var room: Dictionary = generator.generate_room(123, room_meta, Vector2i.ZERO)
	var grid: Array = room.get("grid", [])
	var spawn: Vector2i = room.get("player_start", Vector2i.ZERO)
	var reachable: Array[Vector2i] = PathUtils.reachable_tiles(grid, spawn, 20, {})
	var door_tiles: Array[Vector2i] = [
		RoomGenerator.door_tile_for_direction(Vector2i(0, -1)),
		RoomGenerator.door_tile_for_direction(Vector2i(1, 0)),
		RoomGenerator.door_tile_for_direction(Vector2i(0, 1)),
		RoomGenerator.door_tile_for_direction(Vector2i(-1, 0))
	]
	for door_tile: Vector2i in door_tiles:
		_assert(str(grid[door_tile.y][door_tile.x]) == "door", "Connected rooms should stamp door tiles onto the board edge")
		_assert(not PathUtils.is_passable(grid, door_tile), "Door tiles should be impassable terrain")
		_assert(not reachable.has(door_tile), "Door tiles should not appear in reachable movement ranges")
	for enemy_var: Variant in room.get("enemies", []):
		if typeof(enemy_var) != TYPE_DICTIONARY:
			continue
		var enemy: Dictionary = enemy_var
		_assert(not door_tiles.has(enemy.get("pos", Vector2i(-1, -1))), "Enemy spawns should avoid door tiles")

func _test_hand_fan_layout_lifts_center_cards() -> void:
	var card_size := Vector2(210.0, 300.0)
	var left_rect: Rect2 = HandFanContainer.card_rect_for_layout(0, 5, card_size, -28.0, true)
	var center_rect: Rect2 = HandFanContainer.card_rect_for_layout(2, 5, card_size, -28.0, true)
	var right_rect: Rect2 = HandFanContainer.card_rect_for_layout(4, 5, card_size, -28.0, true)
	var content_size: Vector2 = HandFanContainer.content_size_for_layout(5, card_size, -28.0, true)
	_assert(center_rect.position.y < left_rect.position.y, "Hand fan should lift center cards above the edges")
	_assert(is_equal_approx(left_rect.position.y, right_rect.position.y), "Hand fan should mirror edge lift on both sides")
	_assert(HandFanContainer.card_rotation_for_layout(0, 5, true) < 0.0, "Hand fan should tilt left-side cards outward")
	_assert(HandFanContainer.card_rotation_for_layout(4, 5, true) > 0.0, "Hand fan should tilt right-side cards outward")
	_assert(content_size.y < right_rect.end.y, "Hand fan should reserve a little less than the full arch height so the outer cards can sink slightly offscreen")
	_assert(right_rect.end.y - content_size.y <= 8.0, "Hand fan should not let outer cards sink far enough to clip their bottom frames")
	_assert(HandFanContainer.card_z_index_for_layout(0, 5) < HandFanContainer.card_z_index_for_layout(4, 5), "Hand fan should stack cards left-to-right so the rightmost card stays uncovered")

func _test_room_generation_uses_perimeter_walls_only() -> void:
	var generator: RoomGenerator = RoomGenerator.new()
	for seed: int in [7, 19, 43, 71, 97, 131]:
		var room: Dictionary = generator.generate_room(seed, {
			"coord": Vector2i(seed % 5, seed % 3),
			"depth": 2,
			"type": "combat"
		}, Vector2i.ZERO)
		var grid: Array = room.get("grid", [])
		for y: int in range(1, grid.size() - 1):
			var row: Array = grid[y]
			for x: int in range(1, row.size() - 1):
				var tile: Vector2i = Vector2i(x, y)
				if PathUtils.is_passable(grid, tile):
					continue
				_assert(str(row[x]) == "pillar", "Generated room interiors should use pillars as their only blocking terrain while wall art stays reserved for the perimeter")

func _test_room_generation_avoids_adjacent_columns() -> void:
	var generator: RoomGenerator = RoomGenerator.new()
	for seed: int in range(1, 80):
		for room_type: String in ["combat", "boss", "campfire", "treasure"]:
			var room: Dictionary = generator.generate_room(seed, {
				"coord": Vector2i(seed % 6, seed % 5),
				"depth": 2,
				"type": room_type
			}, Vector2i.ZERO)
			var grid: Array = room.get("grid", [])
			for y: int in range(1, grid.size() - 1):
				var row: Array = grid[y]
				for x: int in range(1, row.size() - 1):
					if str(row[x]) != "pillar":
						continue
					if x + 1 < row.size() - 1:
						_assert(str(row[x + 1]) != "pillar", "Generated columns should not be horizontally adjacent")
					if y + 1 < grid.size() - 1:
						_assert(str((grid[y + 1] as Array)[x]) != "pillar", "Generated columns should not be vertically adjacent")

func _test_room_generation_uses_stone_floor_with_moss_accents() -> void:
	var generator: RoomGenerator = RoomGenerator.new()
	var room: Dictionary = generator.generate_room(73, {
		"coord": Vector2i(2, 1),
		"depth": 2,
		"type": "combat"
	}, Vector2i(0, -1))
	var grid: Array = room.get("grid", [])
	var moss: Dictionary = room.get("moss", {})
	var floor_moss: Array = moss.get("floor", [])
	var wall_moss: Array = moss.get("wall", [])
	var pillar_moss: Array = moss.get("pillar", [])
	var ash_count: int = 0
	var legacy_moss_count: int = 0
	var ember_count: int = 0
	for y: int in range(grid.size()):
		var row: Array = grid[y]
		for x: int in range(row.size()):
			match str(row[x]):
				"ash":
					ash_count += 1
				"moss":
					legacy_moss_count += 1
				"ember":
					ember_count += 1
	_assert(str(room.get("theme", "")) == "ash", "Rooms should now advertise the stone floor theme by default")
	_assert(ember_count == 0, "Generated floors should no longer use ember tiles")
	_assert(legacy_moss_count == 0, "Generated floors should keep moss decorative instead of using dedicated moss terrain tiles")
	_assert(floor_moss.size() >= 5, "Generated floors should now carry a denser layer of decorative moss overlays")
	_assert(wall_moss.size() + pillar_moss.size() >= 1, "Decorative moss should also reach at least one stone fixture beyond the floor")
	_assert(ash_count > floor_moss.size(), "Stone floor tiles should still make up the majority of the room floor")

func _test_special_rooms_use_corner_pillar_layout() -> void:
	var generator: RoomGenerator = RoomGenerator.new()
	var campfire_room: Dictionary = generator.generate_room(91, {
		"coord": Vector2i(2, 0),
		"depth": 2,
		"type": "campfire"
	}, Vector2i(1, 0))
	_assert_corner_pillar_room(campfire_room, "Campfire")
	var treasure_room: Dictionary = generator.generate_room(91, {
		"coord": Vector2i(1, 1),
		"depth": 2,
		"type": "treasure"
	}, Vector2i(0, -1))
	_assert_corner_pillar_room(treasure_room, "Treasure")
	var grid: Array = campfire_room.get("grid", [])
	for y: int in range(3, 6):
		for x: int in range(3, 6):
			_assert(str((grid[y] as Array)[x]) == "ash", "The campfire bonfire footprint should remain floor tiles")
	var floor_moss: Array = (campfire_room.get("moss", {}) as Dictionary).get("floor", [])
	for tile: Vector2i in floor_moss:
		_assert(tile.x < 3 or tile.x > 5 or tile.y < 3 or tile.y > 5, "Campfire moss should leave the 3x3 bonfire footprint visually clear")

func _assert_corner_pillar_room(room: Dictionary, label: String) -> void:
	var grid: Array = room.get("grid", [])
	var pillar_tiles: Array[Vector2i] = [Vector2i(2, 2), Vector2i(6, 2), Vector2i(2, 6), Vector2i(6, 6)]
	for pillar_tile: Vector2i in pillar_tiles:
		_assert(str((grid[pillar_tile.y] as Array)[pillar_tile.x]) == "pillar", "%s rooms should place pillars on the second-to-last ring corners" % label)
	for y: int in range(1, grid.size() - 1):
		for x: int in range(1, (grid[y] as Array).size() - 1):
			var tile := Vector2i(x, y)
			if pillar_tiles.has(tile):
				continue
			_assert(str((grid[y] as Array)[x]) == "ash", "%s rooms should keep the rest of the interior clear" % label)

func _open_floor_count_with_blockers(grid: Array, blocked: Dictionary) -> int:
	var count: int = 0
	for y: int in range(grid.size()):
		var row: Array = grid[y]
		for x: int in range(row.size()):
			var tile: Vector2i = Vector2i(x, y)
			if blocked.has(tile):
				continue
			if PathUtils.is_passable(grid, tile):
				count += 1
	return count

func _reachable_floor_count_with_blockers(grid: Array, start: Vector2i, blocked: Dictionary) -> int:
	if blocked.has(start) or not PathUtils.is_passable(grid, start):
		return 0
	var queue: Array[Vector2i] = []
	queue.append(start)
	var visited: Dictionary = {start: true}
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		for direction: Vector2i in PathUtils.DIRS_4:
			var next_tile: Vector2i = current + direction
			if visited.has(next_tile) or blocked.has(next_tile):
				continue
			if not PathUtils.is_passable(grid, next_tile):
				continue
			visited[next_tile] = true
			queue.append(next_tile)
	return visited.size()

func _is_playable_edge_band_tile(tile: Vector2i) -> bool:
	return tile.x == 1 or tile.y == 1 or tile.x == RoomGenerator.ROOM_WIDTH - 2 or tile.y == RoomGenerator.ROOM_HEIGHT - 2

func _is_playable_corner_tile(tile: Vector2i) -> bool:
	return (tile.x == 1 or tile.x == RoomGenerator.ROOM_WIDTH - 2) and (tile.y == 1 or tile.y == RoomGenerator.ROOM_HEIGHT - 2)

func _test_room_generation_populates_elemental_traps() -> void:
	var generator: RoomGenerator = RoomGenerator.new()
	var trap_count_histogram: Dictionary = {}
	var total_traps: int = 0
	var edge_traps: int = 0
	var corner_traps: int = 0
	for seed: int in range(300, 340):
		var room: Dictionary = generator.generate_room(seed, {
			"coord": Vector2i(seed % 5, seed % 4),
			"depth": 1 + seed % 3,
			"type": "combat",
			"element": "fire"
		}, Vector2i(1, 0))
		var traps: Array = room.get("traps", [])
		trap_count_histogram[traps.size()] = int(trap_count_histogram.get(traps.size(), 0)) + 1
		_assert(traps.size() >= 2 and traps.size() <= 3, "Combat rooms should seed two to three traps")
		var occupied: Dictionary = {room.get("player_start", Vector2i.ZERO): true}
		for enemy_var: Variant in room.get("enemies", []):
			if typeof(enemy_var) != TYPE_DICTIONARY:
				continue
			occupied[(enemy_var as Dictionary).get("pos", Vector2i(-1, -1))] = true
		for loot_var: Variant in room.get("loot", []):
			if typeof(loot_var) != TYPE_DICTIONARY:
				continue
			occupied[(loot_var as Dictionary).get("pos", Vector2i(-1, -1))] = true
		for trap_var: Variant in traps:
			if typeof(trap_var) != TYPE_DICTIONARY:
				continue
			var trap: Dictionary = trap_var
			var pos: Vector2i = trap.get("pos", Vector2i(-1, -1))
			_assert(str(trap.get("element", "")) == "fire", "Generated traps should inherit the room element")
			_assert(int(trap.get("damage", 0)) > 0, "Generated traps should always deal damage")
			_assert(PathUtils.is_passable(room.get("grid", []), pos), "Traps should only spawn on passable floor tiles")
			_assert(not occupied.has(pos), "Traps should avoid player, enemy, and loot placements")
			if _is_playable_edge_band_tile(pos):
				edge_traps += 1
			if _is_playable_corner_tile(pos):
				corner_traps += 1
			total_traps += 1
			occupied[pos] = true
	_assert(trap_count_histogram.has(2) and trap_count_histogram.has(3), "Trap counts should vary between two and three across generated rooms")
	_assert(edge_traps > 0, "Trap placement should allow playable edge-band floor tiles")
	_assert(corner_traps > 0, "Trap placement should allow playable corner floor tiles")
	var depth_two_fire_trap: Dictionary = generator.call("_trap_for_tile", Vector2i(4, 4), ElementData.FIRE, 2)
	var deep_fire_trap: Dictionary = generator.call("_trap_for_tile", Vector2i(4, 4), ElementData.FIRE, 3)
	_assert(int(depth_two_fire_trap.get("burn", 0)) == GameData.fixed_point_amount(1), "Depth-two fire traps should keep shallow burn pressure")
	_assert(int(deep_fire_trap.get("burn", 0)) > int(depth_two_fire_trap.get("burn", 0)), "Deep fire traps should still ramp their burn pressure")

func _test_room_generation_adds_pickups_and_destructible_terrain() -> void:
	var generator: RoomGenerator = RoomGenerator.new()
	for room_type: String in ["combat", "boss", "campfire", "treasure"]:
		var room: Dictionary = generator.generate_room(412, {
			"coord": Vector2i(2, 2),
			"depth": 4 if room_type == "boss" else 2,
			"type": room_type,
			"element": ElementData.FIRE
		}, Vector2i(0, -1))
		var loot_by_kind: Dictionary = {}
		for loot_var: Variant in room.get("loot", []):
			if typeof(loot_var) != TYPE_DICTIONARY:
				continue
			var loot: Dictionary = loot_var
			loot_by_kind[str(loot.get("kind", ""))] = loot
			_assert(PathUtils.is_passable(room.get("grid", []), loot.get("pos", Vector2i(-1, -1))), "Generated pickups should sit on passable floor tiles")
		if room_type in ["combat", "boss"]:
			_assert(loot_by_kind.has("healing_vial"), "%s rooms should always place a healing potion" % room_type.capitalize())
			_assert(int((loot_by_kind.get("healing_vial", {}) as Dictionary).get("amount", 0)) == 40, "Healing potions should heal 40")
			_assert(loot_by_kind.has("rusty_shield"), "%s rooms should always place a rusty shield" % room_type.capitalize())
			_assert(int((loot_by_kind.get("rusty_shield", {}) as Dictionary).get("amount", 0)) == 40, "Rusty shields should grant 40 block")
		else:
			_assert(loot_by_kind.is_empty(), "%s rooms should not place battlefield pickups" % room_type.capitalize())
		_assert(not loot_by_kind.has("ember_cache"), "Generated tile loot should no longer spawn random ember caches")
	var equipment_room: Dictionary = generator.generate_room(412, {
		"coord": Vector2i(2, 2),
		"depth": 2,
		"type": "combat",
		"element": ElementData.FIRE,
		"equipment_drop": "iron_cleaver"
	}, Vector2i(0, -1))
	var equipment_loot: Dictionary = {}
	for loot_var: Variant in equipment_room.get("loot", []):
		if typeof(loot_var) != TYPE_DICTIONARY:
			continue
		var loot: Dictionary = loot_var
		if str(loot.get("kind", "")) == "equipment":
			equipment_loot = loot
			break
	_assert(not equipment_loot.is_empty(), "Combat rooms with an equipment drop should place it as tile loot")
	_assert(str(equipment_loot.get("equipment_id", "")) == "iron_cleaver", "Equipment tile loot should preserve the selected equipment id")
	_assert(PathUtils.is_passable(equipment_room.get("grid", []), equipment_loot.get("pos", Vector2i(-1, -1))), "Equipment tile loot should sit on passable floor tiles")
	var combat_room: Dictionary = generator.generate_room(413, {
		"coord": Vector2i(3, 1),
		"depth": 2,
		"type": "combat",
		"element": ElementData.EARTH
	}, Vector2i(1, 0))
	var occupied: Dictionary = {combat_room.get("player_start", Vector2i.ZERO): true}
	for enemy_var: Variant in combat_room.get("enemies", []):
		if typeof(enemy_var) != TYPE_DICTIONARY:
			continue
		occupied[(enemy_var as Dictionary).get("pos", Vector2i(-1, -1))] = true
	for trap_var: Variant in combat_room.get("traps", []):
		if typeof(trap_var) != TYPE_DICTIONARY:
			continue
		occupied[(trap_var as Dictionary).get("pos", Vector2i(-1, -1))] = true
	for loot_var: Variant in combat_room.get("loot", []):
		if typeof(loot_var) != TYPE_DICTIONARY:
			continue
		occupied[(loot_var as Dictionary).get("pos", Vector2i(-1, -1))] = true
	var terrain_entries: Array = combat_room.get("terrain", [])
	_assert(terrain_entries.size() >= 5 and terrain_entries.size() <= 7, "Combat rooms should scatter five to seven destructible terrain pieces")
	var blocked: Dictionary = {}
	for terrain_var: Variant in terrain_entries:
		if typeof(terrain_var) != TYPE_DICTIONARY:
			continue
		var terrain: Dictionary = terrain_var
		var pos: Vector2i = terrain.get("pos", Vector2i(-1, -1))
		_assert(str(terrain.get("kind", "")) in ["wooden_box", "wooden_crate"], "Generated terrain should be boxes or crates")
		_assert(int(terrain.get("hp", 0)) == 30 and int(terrain.get("max_hp", 0)) == 30, "Generated terrain should have low 30 HP")
		_assert(PathUtils.is_passable(combat_room.get("grid", []), pos), "Generated terrain should sit on passable floor tiles")
		_assert(not occupied.has(pos), "Generated terrain should avoid actors, traps, and pickups")
		occupied[pos] = true
		blocked[pos] = true
	var grid: Array = combat_room.get("grid", [])
	var player_start: Vector2i = combat_room.get("player_start", Vector2i.ZERO)
	_assert(
		_reachable_floor_count_with_blockers(grid, player_start, blocked) == _open_floor_count_with_blockers(grid, blocked),
		"Generated terrain should still leave the open floor connected"
	)
	var edge_pickups: int = 0
	var edge_terrain: int = 0
	var corner_terrain: int = 0
	for seed: int in range(420, 480):
		var sample_room: Dictionary = generator.generate_room(seed, {
			"coord": Vector2i(seed % 7, seed % 5),
			"depth": 2,
			"type": "combat",
			"element": ElementData.FIRE
		}, Vector2i(seed % 3 - 1, 0))
		for loot_var: Variant in sample_room.get("loot", []):
			if typeof(loot_var) != TYPE_DICTIONARY:
				continue
			var loot_pos: Vector2i = (loot_var as Dictionary).get("pos", Vector2i(-1, -1))
			if _is_playable_edge_band_tile(loot_pos):
				edge_pickups += 1
		for terrain_var: Variant in sample_room.get("terrain", []):
			if typeof(terrain_var) != TYPE_DICTIONARY:
				continue
			var terrain_pos: Vector2i = (terrain_var as Dictionary).get("pos", Vector2i(-1, -1))
			if _is_playable_edge_band_tile(terrain_pos):
				edge_terrain += 1
			if _is_playable_corner_tile(terrain_pos):
				corner_terrain += 1
	_assert(edge_pickups > 0, "Generated pickups should be eligible for playable edge-band floor tiles")
	_assert(edge_terrain > 0, "Generated destructible terrain should be eligible for playable edge-band floor tiles")
	_assert(corner_terrain > 0, "Generated destructible terrain should be eligible for playable corner floor tiles")

func _test_room_generation_scales_enemy_density() -> void:
	var generator: RoomGenerator = RoomGenerator.new()
	var depth_one_room: Dictionary = generator.generate_room(27, {
		"coord": Vector2i(1, 0),
		"depth": 1,
		"type": "combat"
	}, Vector2i(1, 0))
	var depth_three_room: Dictionary = generator.generate_room(27, {
		"coord": Vector2i(2, 1),
		"depth": 3,
		"type": "combat"
	}, Vector2i(1, 0))
	var second_sequence_opening: Dictionary = generator.generate_room(27, {
		"coord": Vector2i(5, 0),
		"depth": 5,
		"type": "combat"
	}, Vector2i(1, 0))
	var second_sequence_deep: Dictionary = generator.generate_room(27, {
		"coord": Vector2i(6, 1),
		"depth": 7,
		"type": "combat"
	}, Vector2i(1, 0))
	var boss_room: Dictionary = generator.generate_room(27, {
		"coord": Vector2i(4, 0),
		"depth": 4,
		"type": "boss"
	}, Vector2i(1, 0))
	_assert((depth_one_room.get("enemies", []) as Array).size() >= 3, "Opening combat rooms should pack at least three enemies")
	_assert((depth_three_room.get("enemies", []) as Array).size() >= 5, "Outer combat rooms should feel denser than the opening ring")
	_assert((second_sequence_opening.get("enemies", []) as Array).size() == (depth_one_room.get("enemies", []) as Array).size(), "Second sequence opening rooms should reset to opening density")
	_assert((second_sequence_deep.get("enemies", []) as Array).size() >= 5, "Second sequence deep rooms should climb back to five-enemy density")
	var opening_enemy: Dictionary = (depth_one_room.get("enemies", []) as Array)[0] as Dictionary
	var deep_enemy: Dictionary = (depth_three_room.get("enemies", []) as Array)[0] as Dictionary
	var second_opening_enemy: Dictionary = (second_sequence_opening.get("enemies", []) as Array)[0] as Dictionary
	var opening_base_hp: int = int(GameData.enemy_def(str(opening_enemy.get("type", ""))).get("max_hp", 0))
	var deep_base_hp: int = int(GameData.enemy_def(str(deep_enemy.get("type", ""))).get("max_hp", 0))
	_assert(int(opening_enemy.get("max_hp", 0)) < opening_base_hp, "Opening-depth enemies should start below their base HP")
	_assert(int(deep_enemy.get("max_hp", 0)) > deep_base_hp, "Outer standard rooms should push enemy HP above base")
	_assert(int(second_opening_enemy.get("max_hp", 0)) > int(opening_enemy.get("max_hp", 0)), "Second sequence enemies should start from a tougher HP baseline")
	_assert((boss_room.get("enemies", []) as Array).size() >= 3, "Boss rooms should include support enemies")

func _test_boss_room_spawns_zekarion_with_wisps() -> void:
	var generator: RoomGenerator = RoomGenerator.new()
	var room: Dictionary = generator.generate_room(100, {
		"coord": Vector2i(4, 0),
		"depth": 4,
		"type": "boss",
		"element": ElementData.LIGHTNING
	}, Vector2i(1, 0))
	var enemies: Array = room.get("enemies", [])
	_assert(enemies.size() == 3, "Depth-four boss room should spawn Zekarion and two wisps")
	var zekarion: Dictionary = enemies[0]
	_assert(str(zekarion.get("type", "")) == "zekarion", "Boss room primary enemy should be Zekarion")
	_assert(zekarion.get("footprint", Vector2i.ZERO) == Vector2i(2, 2), "Zekarion should occupy a 2x2 footprint")
	var occupied: Dictionary = {}
	for tile: Vector2i in _enemy_footprint_tiles_for_test(zekarion):
		occupied[tile] = true
		_assert(PathUtils.is_passable(room.get("grid", []), tile), "Zekarion footprint should be on passable terrain")
	_assert(occupied.size() == 4, "Zekarion footprint should cover four unique squares")
	_assert(str((enemies[1] as Dictionary).get("type", "")) == "lightning_wisp", "Boss room should include lightning wisps")
	_assert(str((enemies[2] as Dictionary).get("type", "")) == "lightning_wisp", "Boss room should include a second lightning wisp")

func _test_second_sequence_uses_scaled_zekarion_placeholder() -> void:
	var generator: RoomGenerator = RoomGenerator.new()
	var first_boss_room: Dictionary = generator.generate_room(100, {
		"coord": Vector2i(4, 0),
		"depth": 4,
		"type": "boss",
		"element": ElementData.LIGHTNING
	}, Vector2i(1, 0))
	var second_boss_room: Dictionary = generator.generate_room(100, {
		"coord": Vector2i(8, 0),
		"depth": 8,
		"type": "boss",
		"element": ElementData.LIGHTNING
	}, Vector2i(1, 0))
	var first_boss: Dictionary = (first_boss_room.get("enemies", []) as Array)[0]
	var second_boss: Dictionary = (second_boss_room.get("enemies", []) as Array)[0]
	_assert(str(second_boss.get("type", "")) == "zekarion", "Second sequence boss should use Zekarion as the placeholder dragon")
	_assert(int(second_boss.get("max_hp", 0)) > int(first_boss.get("max_hp", 0)), "Placeholder Zekarion should scale up at the end of the second sequence")

func _test_start_room_spawns_emaciated_man() -> void:
	var run_engine: RunEngine = RunEngine.new()
	var run_state: Dictionary = run_engine.create_new_run(41, ProgressionStore.default_data())
	var start_room: Dictionary = run_engine.room_metadata(run_state, Vector2i.ZERO)
	var start_layout: Dictionary = run_state.get("current_room_layout", {})
	var room_npcs: Array = start_room.get("npcs", [])
	var layout_npcs: Array = start_layout.get("npcs", [])
	_assert(room_npcs.size() == 1 and str((room_npcs[0] as Dictionary).get("id", "")) == "emaciated_man", "The starting room should seed the Emaciated Man NPC")
	_assert(layout_npcs.size() == 1 and str((layout_npcs[0] as Dictionary).get("name", "")) == "Emaciated Man", "The starting room layout should surface the Emaciated Man for rendering")
	_assert((start_layout.get("enemies", []) as Array).is_empty(), "Rooms with NPCs should not populate enemies")

func _test_fatigue_draws_cost_health_and_burn_removes_card() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = combat.create_combat(11, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
			"deck_cards": ["patch_up", "quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var deck: Dictionary = state.get("deck", {}).duplicate(true)
	deck["hand"] = ["patch_up"]
	deck["draw"] = []
	deck["discard"] = ["quick_stab"]
	state["deck"] = deck
	var hp_before: int = int((state.get("player", {}) as Dictionary).get("hp", 0))
	state = combat.finish_player_card(state, 0)
	_assert((state.get("deck", {}) as Dictionary).get("burned", []).has("patch_up"), "Burn cards should move to the burned pile")
	state = combat.prepare_next_player_turn(state)
	var hp_after: int = int((state.get("player", {}) as Dictionary).get("hp", 0))
	_assert(hp_after == hp_before - 15, "Cycling the deck should deal fatigue damage")
	_assert((state.get("deck", {}) as Dictionary).get("hand", []).has("quick_stab"), "Discard should reshuffle into the draw and refill hand")

func _test_two_card_turn_draw_flow() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = combat.create_combat(15, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab", "brace", "quick_stab", "quick_stab", "quick_stab", "bone_dart", "patch_up"],
		"relics": [],
		"hand_size": 5,
		"heal_bonus": 0
	})
	var deck: Dictionary = (state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["quick_stab", "brace", "quick_stab", "quick_stab", "quick_stab"]
	deck["draw"] = ["bone_dart", "patch_up"]
	deck["discard"] = []
	state["deck"] = deck
	_assert(int(state.get("cards_per_turn", 0)) == 2, "Combat should allow two cards per turn")
	_assert(int(state.get("draw_per_turn", 0)) == 2, "Combat should draw two cards each turn")
	state = combat.finish_player_card(state, 1)
	_assert(int(state.get("cards_played_this_turn", 0)) == 1, "Playing one card should consume one play")
	state = combat.finish_player_card(state, 0)
	_assert(int(state.get("cards_played_this_turn", 0)) == 2, "Playing a second card should spend the full turn")
	state = combat.prepare_next_player_turn(state)
	_assert(int(state.get("cards_played_this_turn", 0)) == 0, "A new turn should reset the play counter")
	_assert(int(state.get("turn", 0)) == 2, "Advancing the player turn should increment the turn counter")
	_assert(((state.get("deck", {}) as Dictionary).get("hand", []) as Array).size() == 5, "A new turn should draw two replacement cards")

func _test_initiative_order_starts_with_active_player_and_fast_enemies() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var layout: Dictionary = _simple_room_layout()
	layout["enemies"] = [
		{
			"id": 1,
			"type": "warden",
			"pos": Vector2i(5, 2),
			"hp": 20,
			"max_hp": 20,
			"block": 0
		},
		{
			"id": 2,
			"type": "crawler",
			"pos": Vector2i(6, 2),
			"hp": 14,
			"max_hp": 14,
			"block": 0
		}
	]
	var state: Dictionary = combat.create_combat(15130, layout, {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab", "brace"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var order: Array[Dictionary] = combat.current_turn_order(state, 8)
	_assert(order.size() >= 3, "Initiative order should include the active player and queued enemies")
	_assert(bool(order[0].get("active", false)) and str(order[0].get("kind", "")) == "player", "The player should still start combat as the active actor")
	var crawler_index: int = -1
	var warden_index: int = -1
	var crawler_count: int = 0
	var warden_count: int = 0
	var future_player_count: int = 0
	var first_future_player_index: int = -1
	for index: int in range(1, order.size()):
		if str(order[index].get("kind", "")) == "player":
			future_player_count += 1
			if first_future_player_index < 0:
				first_future_player_index = index
		if str(order[index].get("type", "")) == "crawler" and crawler_index < 0:
			crawler_index = index
		if str(order[index].get("type", "")) == "warden" and warden_index < 0:
			warden_index = index
		if str(order[index].get("type", "")) == "crawler":
			crawler_count += 1
		if str(order[index].get("type", "")) == "warden":
			warden_count += 1
	_assert(crawler_index > 0, "Speedy enemies should appear in the visible initiative queue")
	_assert(warden_index > crawler_index, "Slow enemies should appear later than speedy enemies")
	_assert(future_player_count >= 1, "The player should see their projected next slot while their current turn is active")
	_assert(first_future_player_index > 0 and bool(order[first_future_player_index].get("projected", false)), "The player's projected next turn should slot into the visible order by timing")
	_assert(crawler_count >= 2 and warden_count >= 2, "Turn order should show each enemy's next queued turn plus its projected follow-up")

func _test_initiative_advances_enemy_turns_until_player_reacts() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = combat.create_combat(15131, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab", "brace", "patch_up"],
		"relics": [],
		"hand_size": 2,
		"heal_bonus": 0
	})
	var deck: Dictionary = (state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["quick_stab", "brace"]
	deck["draw"] = ["patch_up"]
	deck["discard"] = []
	state["deck"] = deck
	var enemies: Array = state.get("enemies", [])
	var enemy: Dictionary = (enemies[0] as Dictionary).duplicate(true)
	enemy["intent"] = {
		"name": "Guard",
		"time": 2,
		"actions": [{"type": "block", "amount": 10}]
	}
	enemies[0] = enemy
	state["enemies"] = enemies
	state = combat.finish_player_card(state, 0)
	_assert(int(state.get("player_turn_time_spent", 0)) == 2, "Played cards should add their time cost to the current player turn")
	var scheduled_state: Dictionary = combat.finish_player_activation(state)
	var scheduled_order: Array[Dictionary] = combat.current_turn_order(scheduled_state, 3)
	_assert(str(scheduled_order[0].get("kind", "")) == "enemy", "Passing should hand control to the next queued enemy before the player returns")
	_assert(not bool(scheduled_order[0].get("active", false)), "The player should no longer remain highlighted after their activation is scheduled out")
	_assert(str(scheduled_order[1].get("kind", "")) == "player", "The player's next slot should be scheduled from base initiative plus card time")
	_assert(int(scheduled_order[1].get("time", 0)) == 11, "Quick, two-time cards should schedule the next player turn at initiative 11")
	var phase: Dictionary = combat.advance_to_next_player_turn_with_steps(scheduled_state)
	var after_state: Dictionary = phase.get("state", {})
	_assert(combat.is_player_turn(after_state), "Initiative advancement should stop once the next player turn becomes active")
	_assert(int(after_state.get("initiative_clock", 0)) == 11, "The initiative clock should advance to the player's scheduled return")
	_assert((phase.get("steps", []) as Array).size() >= 1, "Enemy turns resolved before the player should still emit animation steps")
	var saw_turn_order_step: bool = false
	for step_var: Variant in phase.get("steps", []):
		if typeof(step_var) == TYPE_DICTIONARY and str((step_var as Dictionary).get("kind", "")) == "turn_order":
			saw_turn_order_step = true
	_assert(saw_turn_order_step, "Initiative advancement should emit turn-order animation snapshots as actors activate and reslot")
	var next_order: Array[Dictionary] = combat.current_turn_order(after_state, 3)
	_assert(str(next_order[0].get("kind", "")) == "player" and bool(next_order[0].get("active", false)), "The refreshed order should mark the player as the active actor")
	_assert(str(next_order[1].get("kind", "")) == "enemy", "Enemies should immediately reslot for their next future turn after acting")

func _test_card_time_scale_changes_player_reentry_order() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var layout: Dictionary = _simple_room_layout()
	layout["enemies"] = [
		{
			"id": 1,
			"type": "warden",
			"pos": Vector2i(5, 2),
			"hp": 20,
			"max_hp": 20,
			"block": 0
		}
	]
	var fast_state: Dictionary = combat.create_combat(15134, layout, {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["brace"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	fast_state = combat.finish_player_card(fast_state, 0)
	var fast_order: Array[Dictionary] = combat.current_turn_order(combat.finish_player_activation(fast_state), 3)
	_assert(int(GameData.card_def("brace").get("time", 0)) == 1, "Brace should anchor the fast end of the card time scale")
	_assert(str(fast_order[0].get("kind", "")) == "player", "A one-time card should let the player jump ahead of slow enemies")

	var heavy_state: Dictionary = combat.create_combat(15135, layout, {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["bloody_lunge"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	heavy_state = combat.finish_player_card(heavy_state, 0)
	var heavy_order: Array[Dictionary] = combat.current_turn_order(combat.finish_player_activation(heavy_state), 3)
	_assert(int(GameData.card_def("bloody_lunge").get("time", 0)) == 8, "Bloody Lunge should anchor the heavy end of the starter card time scale")
	_assert(str(heavy_order[0].get("kind", "")) == "enemy", "A heavy starter card should let the slow enemy act before the player returns")

	var standard_state: Dictionary = combat.create_combat(15136, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["whirlwind_slash", "lantern_shot"],
		"relics": [],
		"hand_size": 2,
		"heal_bonus": 0
	})
	var standard_deck: Dictionary = (standard_state.get("deck", {}) as Dictionary).duplicate(true)
	standard_deck["hand"] = ["whirlwind_slash", "lantern_shot"]
	standard_deck["draw"] = []
	standard_deck["discard"] = []
	standard_state["deck"] = standard_deck
	var standard_enemies: Array = standard_state.get("enemies", [])
	var standard_enemy: Dictionary = (standard_enemies[0] as Dictionary).duplicate(true)
	standard_enemy["intent"] = {"name": "Measured Claw", "time": 4, "actions": [{"type": "melee", "damage": 3, "range": 1}]}
	standard_enemies[0] = standard_enemy
	standard_state["enemies"] = standard_enemies
	standard_state = combat.finish_player_card(standard_state, 0)
	standard_state = combat.finish_player_card(standard_state, 0)
	var standard_order: Array[Dictionary] = combat.current_turn_order(combat.finish_player_activation(standard_state), 4)
	_assert(int(standard_state.get("player_turn_time_spent", 0)) == 9, "A normal two-card starter turn should spend about nine time")
	_assert(str(standard_order[0].get("kind", "")) == "enemy", "A fast early enemy should still act once before a normal player return")
	_assert(str(standard_order[1].get("kind", "")) == "player", "A normal two-card starter turn should return before the same fast enemy laps the player")
	_assert(str(standard_order[2].get("kind", "")) == "enemy" and bool(standard_order[2].get("projected", false)), "The fast enemy's projected follow-up should remain visible after the player's standard return")

	var slow_state: Dictionary = combat.create_combat(15137, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["bloody_lunge", "whirlwind_slash"],
		"relics": [],
		"hand_size": 2,
		"heal_bonus": 0
	})
	var slow_deck: Dictionary = (slow_state.get("deck", {}) as Dictionary).duplicate(true)
	slow_deck["hand"] = ["bloody_lunge", "whirlwind_slash"]
	slow_deck["draw"] = []
	slow_deck["discard"] = []
	slow_state["deck"] = slow_deck
	var slow_enemies: Array = slow_state.get("enemies", [])
	var slow_enemy: Dictionary = (slow_enemies[0] as Dictionary).duplicate(true)
	slow_enemy["intent"] = {"name": "Measured Claw", "time": 4, "actions": [{"type": "melee", "damage": 3, "range": 1}]}
	slow_enemies[0] = slow_enemy
	slow_state["enemies"] = slow_enemies
	slow_state = combat.finish_player_card(slow_state, 0)
	slow_state = combat.finish_player_card(slow_state, 0)
	var slow_order: Array[Dictionary] = combat.current_turn_order(combat.finish_player_activation(slow_state), 4)
	_assert(int(slow_state.get("player_turn_time_spent", 0)) == 13, "Stacking a heavy card with a normal card should create a slow turn")
	_assert(str(slow_order[0].get("kind", "")) == "enemy", "The fast enemy should act before a slow player return")
	_assert(str(slow_order[1].get("kind", "")) == "enemy" and bool(slow_order[1].get("projected", false)), "Slow starter turns should let fast enemies threaten a double-up")
	_assert(str(slow_order[2].get("kind", "")) == "player", "The player should return after the fast enemy's projected follow-up on slow turns")

func _test_agility_reduces_player_base_initiative() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var agile_state: Dictionary = combat.create_combat(15132, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0,
		"stats": {"agility": 3}
	})
	_assert(combat.player_base_initiative(agile_state) == 6, "Each agility point should reduce the player's base initiative by one")
	var capped_state: Dictionary = combat.create_combat(15133, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0,
		"stats": {"agility": 99}
	})
	_assert(combat.player_base_initiative(capped_state) == 5, "Player base initiative should not drop below the minimum delay")

func _test_combat_log_is_bounded() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = combat.create_combat(1510, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab", "brace"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	for index: int in range(24):
		combat.call("_log", state, "Line %d" % index)
	var lines: Array = state.get("log", [])
	_assert(lines.size() == CombatEngine.MAX_LOG_LINES, "Combat logs should stay bounded so state copies do not grow over long fights")
	_assert(str(lines[0]) == "Line 12", "Bounded combat logs should keep the most recent entries")
	_assert(str(lines[lines.size() - 1]) == "Line 23", "Bounded combat logs should retain the newest entry")

func _test_card_play_action_grants_bonus_play() -> void:
	var starter_has_draw: bool = false
	var starter_has_card_play: bool = false
	var starter_has_illusion: bool = false
	for card_id: String in GameData.starting_deck():
		var starter_card: Dictionary = GameData.card_def(card_id)
		for action_var: Variant in starter_card.get("actions", []):
			if typeof(action_var) != TYPE_DICTIONARY:
				continue
			var action: Dictionary = action_var as Dictionary
			starter_has_draw = starter_has_draw or str(action.get("type", "")) == "draw"
			starter_has_card_play = starter_has_card_play or str(action.get("type", "")) == "card_play"
			starter_has_illusion = starter_has_illusion or str(action.get("type", "")) == "illusion"
	_assert(starter_has_draw, "The starting deck should include at least one draw card")
	_assert(starter_has_card_play, "The starting deck should include at least one card-play card")
	_assert(starter_has_illusion, "The starting deck should include at least one illusion card")
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = combat.create_combat(1511, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["guarded_step", "quick_stab", "brace"],
		"relics": [],
		"hand_size": 3,
		"heal_bonus": 0
	})
	var deck: Dictionary = (state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["guarded_step", "quick_stab", "brace"]
	deck["draw"] = []
	deck["discard"] = []
	state["deck"] = deck
	_assert(combat.cards_remaining_this_turn(state) == 2, "Combat should start with its base card plays available")
	state = combat.apply_player_action(state, {"type": "card_play", "amount": 1})
	_assert(int(state.get("card_play_bonus_this_turn", 0)) == 1, "Card-play actions should track their temporary bonus separately from death rewards")
	_assert(combat.cards_remaining_this_turn(state) == 3, "Card-play actions should increase current turn capacity before the played card is finished")
	state = combat.finish_player_card(state, 0)
	_assert(combat.cards_remaining_this_turn(state) == 2, "Finishing the card should spend one play while preserving the action bonus")
	state = combat.prepare_next_player_turn(state)
	_assert(int(state.get("card_play_bonus_this_turn", 0)) == 0, "Card-play action bonuses should reset on a new player turn")

func _test_starting_deck_uses_hamstring_shot_over_bone_dart() -> void:
	var starting_deck: Array = GameData.starting_deck()
	_assert(starting_deck.has("hamstring_shot"), "Hamstring Shot should replace the plain ranged starter in the starting deck")
	_assert(not starting_deck.has("bone_dart"), "Bone Dart should stay out of the starting deck while retired")
	_assert(bool(GameData.card_def("hamstring_shot").get("starter", false)), "Hamstring Shot should be marked as a starter card")
	_assert(not bool(GameData.card_def("bone_dart").get("starter", false)), "Bone Dart should not be marked as an active starter card")
	var reward_pool: Dictionary = GameData.reward_card_pool_by_rarity()
	for rarity: String in ["common", "uncommon", "rare"]:
		var cards: Array = reward_pool.get(rarity, [])
		_assert(not cards.has("bone_dart"), "Bone Dart should stay out of reward offers while retired")
		_assert(not cards.has("hamstring_shot"), "Starter Hamstring Shot should stay out of reward offers")
		for magic_card_id: String in ["pale_spark", "dull_bolt", "waning_pulse"]:
			_assert(not cards.has(magic_card_id), "Default attuned magic should stay out of combat reward offers")

func _test_equipment_run_state_and_reward_cards(default_progression: Dictionary) -> void:
	var engine: RunEngine = RunEngine.new()
	var run_state: Dictionary = engine.create_new_run(45, default_progression)
	_assert((run_state.get("deck_cards", []) as Array) == GameData.starting_deck(), "Fresh runs should compile their deck from starter equipment plus attuned magic")
	_assert((run_state.get("reward_cards", []) as Array).is_empty(), "Fresh runs should track collected reward magic separately from equipment")
	_assert((run_state.get("attuned_magic_cards", []) as Array) == GameData.starting_magic_cards(), "Fresh runs should start with six bland attuned magic cards")
	_assert((run_state.get("magic_inventory", []) as Array).is_empty(), "Fresh runs should start with no reserve magic")
	_assert((run_state.get("equipment_inventory", []) as Array).is_empty(), "Fresh runs should not duplicate equipped starter gear into inventory")
	_assert(int(run_state.get("equipment_drop_misses", -1)) == 0, "Fresh runs should start equipment pity from zero misses")
	var equipped: Dictionary = run_state.get("equipped_equipment", {}) as Dictionary
	for slot: String in GameData.equipment_slots():
		_assert(not str(equipped.get(slot, "")).is_empty(), "Fresh runs should equip a starter %s" % slot)
	for starter_id_var: Variant in GameData.starter_equipment_ids():
		_assert((run_state.get("collected_equipment", []) as Array).has(str(starter_id_var)), "Fresh runs should mark starter equipment as collected")

	var reward_state: Dictionary = engine.claim_card_reward(run_state, "spark_dart")
	_assert((reward_state.get("reward_cards", []) as Array) == ["spark_dart"], "Claimed card rewards should still append to reward_cards for collection history")
	_assert((reward_state.get("magic_inventory", []) as Array) == ["spark_dart"], "Claimed card rewards should enter reserve magic")
	_assert(not (reward_state.get("deck_cards", []) as Array).has("spark_dart"), "Claimed rewards should stay inactive until attuned")
	_assert((reward_state.get("deck_cards", []) as Array).size() == GameData.starting_deck().size(), "Claimed reserve magic should not grow the active deck")
	var attuned_state: Dictionary = engine.swap_magic_card(reward_state, 0, 0)
	_assert(str((attuned_state.get("attuned_magic_cards", []) as Array)[0]) == "spark_dart", "Swapping reserve magic should update the attuned slot")
	_assert((attuned_state.get("magic_inventory", []) as Array).has("pale_spark"), "Swapping magic should move the replaced default card to reserve")
	_assert((attuned_state.get("deck_cards", []) as Array).has("spark_dart"), "Attuned reward magic should enter the active deck")
	_assert((attuned_state.get("deck_cards", []) as Array).size() == GameData.starting_deck().size(), "Attuning magic should keep the active deck capped")
	var blocked_magic_state: Dictionary = reward_state.duplicate(true)
	blocked_magic_state["mode"] = "combat"
	var blocked_magic_swap: Dictionary = engine.swap_magic_card(blocked_magic_state, 0, 0)
	_assert(not (blocked_magic_swap.get("deck_cards", []) as Array).has("spark_dart"), "Magic swaps should be locked during combat")

	var migrated_claim_state: Dictionary = run_state.duplicate(true)
	migrated_claim_state["reward_cards"] = ["spark_dart", "frostbolt", "firebrand_volley", "chain_bolt"]
	migrated_claim_state.erase("attuned_magic_cards")
	migrated_claim_state.erase("magic_inventory")
	migrated_claim_state["pending_reward"] = {"cards": ["static_lash"]}
	migrated_claim_state["mode"] = "reward"
	var migrated_claimed_state: Dictionary = engine.claim_card_reward(migrated_claim_state, "static_lash")
	var migrated_claimed_attuned: Array = migrated_claimed_state.get("attuned_magic_cards", []) as Array
	_assert(str(migrated_claimed_attuned[4]) == "pale_spark", "Claiming magic in older in-progress runs should repair default attuned slots before adding the new reserve card")
	_assert((migrated_claimed_state.get("magic_inventory", []) as Array) == ["static_lash"], "Claiming magic in older in-progress runs should leave the new card in reserve")
	var late_default_swap_state: Dictionary = engine.swap_magic_card(migrated_claimed_state, 0, 4)
	var late_default_attuned: Array = late_default_swap_state.get("attuned_magic_cards", []) as Array
	_assert(str(late_default_attuned[4]) == "static_lash", "Reserve magic should be swappable into late default magic slots")
	_assert((late_default_swap_state.get("magic_inventory", []) as Array).has("pale_spark"), "Swapping into a late default slot should return that default magic to reserve")

	var legacy_state: Dictionary = run_state.duplicate(true)
	legacy_state.erase("reward_cards")
	legacy_state.erase("attuned_magic_cards")
	legacy_state.erase("magic_inventory")
	legacy_state.erase("equipment_inventory")
	legacy_state.erase("equipped_equipment")
	legacy_state.erase("collected_equipment")
	legacy_state.erase("equipment_drop_misses")
	var legacy_deck: Array = GameData.compile_deck_cards(GameData.starting_equipped_equipment(), [])
	legacy_deck.append("spark_dart")
	legacy_deck.append("frostbolt")
	legacy_state["deck_cards"] = legacy_deck
	var repaired_state: Dictionary = engine.repair_loaded_run_state(legacy_state)
	_assert((repaired_state.get("reward_cards", []) as Array) == ["spark_dart", "frostbolt"], "Legacy decks should migrate non-equipment cards into reward_cards")
	_assert(str((repaired_state.get("attuned_magic_cards", []) as Array)[0]) == "spark_dart", "Legacy reward migration should preserve the first collected cards as attuned magic")
	_assert(str((repaired_state.get("attuned_magic_cards", []) as Array)[1]) == "frostbolt", "Legacy reward migration should preserve collected reward order")
	_assert((repaired_state.get("attuned_magic_cards", []) as Array).size() == GameData.magic_loadout_limit(), "Legacy reward migration should fill remaining attuned slots with default magic")
	_assert((repaired_state.get("deck_cards", []) as Array).has("spark_dart"), "Legacy reward migration should preserve capped collected cards in the active deck")
	_assert(int(repaired_state.get("equipment_drop_misses", -1)) == RunEngine.EQUIPMENT_DROP_PITY_MISSES, "Loaded runs without equipment pity state should guarantee the next eligible equipment drop")

	var dry_room: Dictionary = {
		"coord": Vector2i(1, 0),
		"depth": 1,
		"type": "combat",
		"element": ElementData.FIRE,
		"cleared": false
	}
	var no_pity_state: Dictionary = run_state.duplicate(true)
	no_pity_state["equipment_drop_misses"] = 0
	_assert(str(engine.call("_equipment_drop_for_room", no_pity_state, dry_room)).is_empty(), "Dry equipment rolls should still miss before pity")
	var pity_state: Dictionary = run_state.duplicate(true)
	pity_state["equipment_drop_misses"] = RunEngine.EQUIPMENT_DROP_PITY_MISSES
	_assert(not str(engine.call("_equipment_drop_for_room", pity_state, dry_room)).is_empty(), "Equipment pity should force a drop after consecutive misses")
	var reset_pity_state: Dictionary = engine.call("_record_equipment_drop_attempt", pity_state, {
		"loot": [{"kind": "equipment", "equipment_id": "iron_cleaver", "pos": Vector2i(3, 3)}]
	})
	_assert(int(reset_pity_state.get("equipment_drop_misses", -1)) == 0, "Placed equipment drops should reset equipment pity")
	var missed_pity_state: Dictionary = engine.call("_record_equipment_drop_attempt", no_pity_state, {"loot": []})
	_assert(int(missed_pity_state.get("equipment_drop_misses", -1)) == 1, "Eligible rooms without equipment should advance equipment pity")

	var collected: Array = (run_state.get("collected_equipment", []) as Array).duplicate()
	collected.append("iron_cleaver")
	run_state["equipment_inventory"] = ["iron_cleaver"]
	run_state["collected_equipment"] = collected
	var swapped_state: Dictionary = engine.equip_equipment(run_state, "iron_cleaver")
	var swapped_equipped: Dictionary = swapped_state.get("equipped_equipment", {}) as Dictionary
	var swapped_inventory: Array = swapped_state.get("equipment_inventory", []) as Array
	var swapped_deck: Array = swapped_state.get("deck_cards", []) as Array
	_assert(str(swapped_equipped.get("weapon", "")) == "iron_cleaver", "Equipping a weapon should update the active slot")
	_assert(swapped_inventory.has("training_sword"), "The replaced equipment should move back into inventory")
	_assert(not swapped_inventory.has("iron_cleaver"), "The newly equipped item should leave inventory")
	_assert(swapped_deck.has("cleaver_hook") and swapped_deck.has("needle_flurry") and swapped_deck.has("butcher_chop"), "Equipping an item should add its cards to the active deck")
	_assert(not swapped_deck.has("whirlwind_slash") and not swapped_deck.has("bloody_lunge"), "Equipping an item should remove the previous slot's unique cards")

	var combat_state: Dictionary = swapped_state.duplicate(true)
	combat_state["mode"] = "combat"
	var combat_inventory: Array = swapped_inventory.duplicate()
	combat_inventory.append("ward_kite")
	combat_state["equipment_inventory"] = combat_inventory
	var combat_collected: Array = (combat_state.get("collected_equipment", []) as Array).duplicate()
	combat_collected.append("ward_kite")
	combat_state["collected_equipment"] = combat_collected
	var blocked_state: Dictionary = engine.equip_equipment(combat_state, "ward_kite")
	_assert(str((blocked_state.get("equipped_equipment", {}) as Dictionary).get("offhand", "")) == str(swapped_equipped.get("offhand", "")), "Equipment should not change during combat")
	_assert((blocked_state.get("equipment_inventory", []) as Array).has("ward_kite"), "Blocked equipment changes should leave inventory intact")

	var available_before: Array = engine.call("_available_equipment_drop_ids", run_state)
	_assert(available_before.has("ward_kite"), "Uncollected equipment should be eligible for future drops")
	var collected_state: Dictionary = run_state.duplicate(true)
	collected_state["collected_equipment"] = GameData.starter_equipment_ids() + ["ward_kite"]
	var available_after: Array = engine.call("_available_equipment_drop_ids", collected_state)
	_assert(not available_after.has("ward_kite"), "Collected equipment should not appear in future drop pools")

func _test_equipment_collection_to_equip_deck_flow(default_progression: Dictionary) -> void:
	var run_engine: RunEngine = RunEngine.new()
	var combat_engine: CombatEngine = CombatEngine.new()
	var run_state: Dictionary = run_engine.create_new_run(74, default_progression)
	var layout: Dictionary = _simple_room_layout()
	var equipment_tile := Vector2i(3, 4)
	layout["loot"] = [{
		"kind": "equipment",
		"equipment_id": "ward_kite",
		"pos": equipment_tile
	}]
	var combat_state: Dictionary = combat_engine.create_combat(74, layout, {
		"hp": int(run_state.get("player_hp", 1)),
		"max_hp": int(run_state.get("player_max_hp", 1)),
		"deck_cards": (run_state.get("deck_cards", []) as Array).duplicate(),
		"relics": [],
		"hand_size": int(run_state.get("hand_size", 5)),
		"heal_bonus": int(run_state.get("heal_bonus", 0)),
		"cards_per_turn": 2,
		"draw_per_turn": 2,
		"card_upgrades": {},
		"card_mods": {}
	})
	run_state["mode"] = "combat"
	run_state["combat_state"] = combat_state
	combat_state = combat_engine.apply_player_action(combat_state, {"type": "blink", "range": 99}, equipment_tile)
	_assert((combat_state.get("collected_equipment", []) as Array).has("ward_kite"), "Walking onto equipment loot should record the picked-up equipment in combat state")
	var claimed_loot: Dictionary = _first_loot_of_kind(combat_state, "equipment")
	_assert(bool(claimed_loot.get("claimed", false)), "Equipment loot should be marked claimed after pickup")
	run_state = run_engine.set_combat_state(run_state, combat_state)
	_assert((run_state.get("equipment_inventory", []) as Array).has("ward_kite"), "Collected combat equipment should merge into run inventory")
	_assert((run_state.get("collected_equipment", []) as Array).has("ward_kite"), "Collected combat equipment should be remembered for duplicate-drop exclusion")
	var pre_equip_deck: Array = run_state.get("deck_cards", []) as Array
	_assert(pre_equip_deck.has("brace") and pre_equip_deck.has("guarded_step"), "Picking up equipment should not rebuild the deck until it is equipped")
	_assert(not pre_equip_deck.has("kite_bash"), "Picked-up equipment cards should stay inactive while the item is only in inventory")
	run_state["mode"] = "room"
	run_state = run_engine.equip_equipment(run_state, "ward_kite")
	var equipped: Dictionary = run_state.get("equipped_equipment", {}) as Dictionary
	var post_equip_deck: Array = run_state.get("deck_cards", []) as Array
	_assert(str(equipped.get("offhand", "")) == "ward_kite", "Equipping collected equipment should update the matching slot")
	_assert((run_state.get("equipment_inventory", []) as Array).has("splintered_shield"), "Equipping collected gear should move the replaced starter item into inventory")
	_assert(post_equip_deck.has("kite_bash") and post_equip_deck.has("warded_advance"), "Equipping collected gear should add its cards to the active deck")
	_assert(not post_equip_deck.has("brace") and not post_equip_deck.has("guarded_step"), "Equipping collected gear should remove the previous slot's cards from the active deck")

func _test_elemental_intensity_starts_from_room_element() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var layout: Dictionary = _simple_room_layout()
	layout["element"] = ElementData.FIRE
	var state: Dictionary = combat.create_combat(15121, layout, {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["firebrand_volley"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	_assert(combat.elemental_intensity(state, ElementData.FIRE) == 1, "Combat should seed the room element with baseline intensity")
	_assert(combat.elemental_intensity(state, ElementData.ICE) == 0, "Combat should not seed off-element intensity")

func _test_elemental_intensity_actions_gate_effects() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var layout: Dictionary = _simple_room_layout()
	layout["element"] = ElementData.FIRE
	var state: Dictionary = combat.create_combat(15122, layout, {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["firebrand_volley"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	state["player"] = {
		"pos": Vector2i(2, 4),
		"hp": 24,
		"max_hp": 24,
		"block": 0,
		"stoneskin": 0
	}
	state["enemies"] = [{
		"id": 1,
		"type": "crawler",
		"pos": Vector2i(3, 4),
		"hp": 14,
		"max_hp": 14,
		"block": 0,
		"stoneskin": 0
	}]
	var gated_action: Dictionary = {
		"type": "melee",
		"damage": 5,
		"range": 1,
		"requires_intensity": {"element": ElementData.FIRE, "amount": 2}
	}
	_assert(not combat.player_action_can_resolve(state, gated_action), "Intensity-gated effects should not resolve below their threshold")
	var unchanged: Dictionary = combat.apply_player_action(state, gated_action, Vector2i(3, 4))
	_assert(int(((unchanged.get("enemies", []) as Array)[0] as Dictionary).get("hp", 0)) == 14, "Applying an unmet intensity-gated attack should leave state unchanged")
	state = combat.apply_player_action(state, {"type": "intensity", "element": ElementData.FIRE, "amount": 1})
	_assert(combat.elemental_intensity(state, ElementData.FIRE) == 2, "Intensity actions should raise the matching room counter")
	_assert(combat.player_action_can_resolve(state, gated_action), "Intensity-gated effects should resolve after the threshold is met")
	state = combat.apply_player_action(state, gated_action, Vector2i(3, 4))
	_assert(int(((state.get("enemies", []) as Array)[0] as Dictionary).get("hp", 0)) == 9, "Met intensity-gated attacks should deal damage normally")

func _test_elemental_intensity_icons_surface_card_requirements() -> void:
	var intensity_tokens: Array = ActionIcons.tokens_for_action({"type": "intensity", "element": ElementData.FIRE, "amount": 2})
	_assert(not intensity_tokens.is_empty() and str((intensity_tokens[0] as Dictionary).get("kind", "")) == "elemental_intensity", "Intensity actions should render as elemental intensity tokens")
	_assert(ActionIcons.token_value_text(intensity_tokens[0] as Dictionary) == "+2", "Intensity tokens should show the gained amount")
	_assert(str((intensity_tokens[0] as Dictionary).get("tone", "")) == "neutral", "Intensity gain numbers should use the normal number tone")
	var gated_tokens: Array = ActionIcons.tokens_for_action({
		"type": "ranged",
		"damage": 4,
		"range": 5,
		"requires_intensity": {"element": ElementData.FIRE, "amount": 3}
	})
	_assert(not gated_tokens.is_empty() and str((gated_tokens[0] as Dictionary).get("kind", "")) == "intensity_requirement", "Gated actions should lead with an elemental requirement token")
	_assert(ActionIcons.token_value_text(gated_tokens[0] as Dictionary) == "3+:", "Intensity requirements should visually separate the gate with a colon")
	_assert(ActionIcons.plain_text_for_tokens(gated_tokens).begins_with("Fire 3+:"), "Plain card text should expose the elemental intensity threshold")
	var bonus_tokens: Array = ActionIcons.tokens_for_intensity_bonus({
		"type": "ranged",
		"damage": 4,
		"range": 5,
		"intensity_bonus": {"element": ElementData.FIRE, "threshold": 3, "damage": 2, "burn": 1}
	})
	_assert(not bonus_tokens.is_empty() and str((bonus_tokens[0] as Dictionary).get("kind", "")) == "intensity_requirement", "Intensity bonus rows should lead with an elemental requirement token")
	_assert(ActionIcons.plain_text_for_tokens(bonus_tokens).begins_with("Fire 3+:"), "Plain bonus text should expose the elemental intensity threshold")
	_assert(bonus_tokens.size() > 1 and str((bonus_tokens[1] as Dictionary).get("tone", "")) == "neutral", "Intensity bonus effect numbers should use the normal number tone")

func _test_elemental_intensity_bonus_modifies_single_attack() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var layout: Dictionary = _simple_room_layout()
	layout["element"] = ElementData.FIRE
	var state: Dictionary = combat.create_combat(15123, layout, {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["firebrand_volley"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	state["player"] = {
		"pos": Vector2i(2, 4),
		"hp": 24,
		"max_hp": 24,
		"block": 0,
		"stoneskin": 0
	}
	state["enemies"] = [{
		"id": 1,
		"type": "crawler",
		"pos": Vector2i(3, 4),
		"hp": 20,
		"max_hp": 20,
		"block": 0,
		"stoneskin": 0
	}]
	var action: Dictionary = {
		"type": "melee",
		"damage": 5,
		"range": 1,
		"intensity_bonus": {"element": ElementData.FIRE, "threshold": 2, "damage": 4, "burn": 2}
	}
	_assert(not combat.action_intensity_bonus_requirement_met(state, action), "Intensity bonuses should stay inactive below their threshold")
	_assert(combat.final_damage_for_player_action(state, action) == 5, "Inactive intensity bonuses should not inflate damage previews")
	var boosted_state: Dictionary = combat.apply_player_action(state, {"type": "intensity", "element": ElementData.FIRE, "amount": 1})
	_assert(combat.action_intensity_bonus_requirement_met(boosted_state, action), "Intensity bonuses should activate once the threshold is met")
	_assert(combat.final_damage_for_player_action(boosted_state, action) == 9, "Active intensity bonuses should increase damage previews")
	boosted_state = combat.apply_player_action(boosted_state, action, Vector2i(3, 4))
	var enemy: Dictionary = ((boosted_state.get("enemies", []) as Array)[0] as Dictionary)
	_assert(int(enemy.get("hp", 0)) == 11, "Active intensity bonuses should add damage to the same attack")
	_assert(int(enemy.get("burn", 0)) == 2, "Active intensity bonuses should add gated statuses to the same attack")

	var earth_layout: Dictionary = _simple_room_layout()
	earth_layout["element"] = ElementData.EARTH
	var venom_state: Dictionary = combat.create_combat(15124, earth_layout, {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["venom_claw"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	venom_state["player"] = {
		"pos": Vector2i(2, 4),
		"hp": 24,
		"max_hp": 24,
		"block": 0,
		"stoneskin": 0
	}
	venom_state["enemies"] = [{
		"id": 1,
		"type": "crawler",
		"pos": Vector2i(3, 4),
		"hp": 200,
		"max_hp": 200,
		"block": 0,
		"stoneskin": 0
	}]
	var venom_card: Dictionary = GameData.card_def("venom_claw")
	var venom_actions: Array = venom_card.get("actions", [])
	venom_state = combat.apply_player_action(venom_state, venom_actions[0] as Dictionary)
	_assert(combat.elemental_intensity(venom_state, ElementData.EARTH) == 2, "Venom Claw should self-enable its Earth 2+ rider in an Earth room")
	_assert(combat.final_damage_for_player_action(venom_state, venom_actions[1] as Dictionary) == 100, "Venom Claw's active Earth rider should increase same-attack damage")
	venom_state = combat.apply_player_action(venom_state, venom_actions[1] as Dictionary, Vector2i(3, 4))
	var venom_enemy: Dictionary = ((venom_state.get("enemies", []) as Array)[0] as Dictionary)
	_assert(int(venom_enemy.get("hp", 0)) == 100, "Venom Claw should apply its conditional damage to the target")
	var venom_poison: Dictionary = venom_enemy.get("poison", {}) as Dictionary
	_assert(int(venom_poison.get("damage", 0)) == 40, "Venom Claw should apply its conditional poison to the target")

func _test_cards_do_not_define_multiple_player_attacks() -> void:
	var attack_types: Array = ["melee", "ranged", "aoe", "push", "pull"]
	for card_id_var: Variant in GameData.cards().keys():
		var card_id: String = str(card_id_var)
		var card: Dictionary = GameData.card_def(card_id)
		var attack_count: int = 0
		for action_var: Variant in card.get("actions", []):
			if typeof(action_var) != TYPE_DICTIONARY:
				continue
			var action: Dictionary = action_var
			if str(action.get("type", "")) in attack_types:
				attack_count += 1
		_assert(attack_count <= 1, "%s should not define multiple player attacks" % card_id)

func _test_illusion_action_creates_decoy_and_redirects_enemy() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = combat.create_combat(1512, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["shadow_step", "quick_stab", "brace"],
		"relics": [],
		"hand_size": 3,
		"heal_bonus": 0
	})
	state["player"] = {
		"pos": Vector2i(2, 4),
		"hp": 24,
		"max_hp": 24,
		"block": 0,
		"stoneskin": 0
	}
	state["enemies"] = [
		{
			"id": 1,
			"type": "crawler",
			"pos": Vector2i(5, 4),
			"hp": 14,
			"max_hp": 14,
			"block": 0,
			"intent": {"name": "Claw", "actions": [{"type": "melee", "damage": 3, "range": 1}]}
		}
	]
	var action := {"type": "illusion", "health": 4, "range": 3}
	_assert(combat.valid_targets_for_player_action(state, action).has(Vector2i(4, 4)), "Illusion actions should target open tiles within placement range")
	state = combat.apply_player_action(state, action, Vector2i(4, 4))
	var illusions: Array = state.get("illusions", [])
	_assert(illusions.size() == 1, "Illusion actions should add a combat actor")
	_assert(int((illusions[0] as Dictionary).get("hp", 0)) == 4, "Created illusions should use the action health")
	_assert(not combat.valid_targets_for_player_action(state, {"type": "move", "range": 3}).has(Vector2i(4, 4)), "Player movement should treat illusions as occupied")
	var hp_before: int = int((state.get("player", {}) as Dictionary).get("hp", 0))
	var phase: Dictionary = combat.resolve_enemy_phase_with_steps(state)
	var after_state: Dictionary = phase.get("state", {})
	_assert(int((after_state.get("player", {}) as Dictionary).get("hp", 0)) == hp_before, "Enemies should attack a closer illusion instead of the player")
	var after_illusion: Dictionary = (after_state.get("illusions", []) as Array)[0]
	_assert(int(after_illusion.get("hp", 0)) == 1, "Enemy damage should reduce illusion health")
	var saw_illusion_loss_step: bool = false
	for step_var: Variant in phase.get("steps", []):
		if typeof(step_var) != TYPE_DICTIONARY:
			continue
		var step: Dictionary = step_var
		for loss_var: Variant in step.get("target_losses", []):
			if typeof(loss_var) != TYPE_DICTIONARY:
				continue
			var loss: Dictionary = loss_var
			if str(loss.get("key", "")) == "illusion_1" and int(loss.get("hp_loss", 0)) == 3:
				saw_illusion_loss_step = true
	_assert(saw_illusion_loss_step, "Enemy animation steps should report illusion damage as target loss")

func _test_enemy_target_ties_randomize_between_player_side_actors() -> void:
	var saw_player_hit: bool = false
	var saw_illusion_hit: bool = false
	for seed: int in range(400, 432):
		var combat: CombatEngine = CombatEngine.new()
		var state: Dictionary = combat.create_combat(seed, _simple_room_layout(), {
			"hp": 24,
			"max_hp": 24,
			"deck_cards": ["shadow_step"],
			"relics": [],
			"hand_size": 1,
			"heal_bonus": 0
		})
		state["player"] = {
			"pos": Vector2i(3, 4),
			"hp": 24,
			"max_hp": 24,
			"block": 0,
			"stoneskin": 0
		}
		state["enemies"] = [
			{
				"id": 1,
				"type": "crawler",
				"pos": Vector2i(4, 4),
				"hp": 14,
				"max_hp": 14,
				"block": 0,
				"intent": {"name": "Tie Claw", "actions": [{"type": "melee", "damage": 3, "range": 1}]}
			}
		]
		state["illusions"] = [{"id": 1, "pos": Vector2i(5, 4), "hp": 4, "max_hp": 4}]
		state["rng_state"] = seed
		var after_state: Dictionary = combat.resolve_enemy_phase(state)
		if int((after_state.get("player", {}) as Dictionary).get("hp", 0)) < 24:
			saw_player_hit = true
		var illusions: Array = after_state.get("illusions", [])
		if not illusions.is_empty() and int((illusions[0] as Dictionary).get("hp", 0)) < 4:
			saw_illusion_hit = true
		if saw_player_hit and saw_illusion_hit:
			break
	_assert(saw_player_hit and saw_illusion_hit, "Equal-distance player-side targets should be selected by deterministic random tie-breaks instead of always preferring the player")

func _test_enemy_death_grants_card_play_and_embers() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = combat.create_combat(16, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab", "quick_stab"],
		"relics": [],
		"hand_size": 2,
		"heal_bonus": 0
	})
	var player: Dictionary = (state.get("player", {}) as Dictionary).duplicate(true)
	player["pos"] = Vector2i(2, 4)
	state["player"] = player
	var enemies: Array = state.get("enemies", [])
	var enemy: Dictionary = (enemies[0] as Dictionary).duplicate(true)
	enemy["pos"] = Vector2i(3, 4)
	enemy["hp"] = 9
	enemy["block"] = 0
	enemies[0] = enemy
	enemies.append({
		"id": 2,
		"type": "harrier",
		"pos": Vector2i(5, 5),
		"hp": 10,
		"max_hp": 10,
		"block": 0
	})
	state["enemies"] = enemies
	state = combat.apply_player_action(state, {"type": "melee", "damage": 9, "range": 1}, Vector2i(3, 4))
	_assert(int(state.get("death_bonus_card_plays_this_turn", 0)) == 1, "Killing a non-summoned enemy should add one bonus card play this turn")
	_assert(combat.cards_remaining_this_turn(state) == 3, "The new play should increase this turn's play capacity before the killing card is finished")
	_assert(int(state.get("room_embers", 0)) == 8, "Enemy death should still add its ember reward immediately")
	var rewards: Array = state.get("death_rewards", [])
	_assert(rewards.size() == 1 and int((rewards[0] as Dictionary).get("embers", 0)) == 8, "Death rewards should record ember amount for UI collection animation")
	state = combat.finish_player_card(state, 0)
	_assert(combat.cards_remaining_this_turn(state) == 2, "Finishing the killing card should spend one play but keep the death bonus")
	state = combat.prepare_next_player_turn(state)
	_assert(int(state.get("death_bonus_card_plays_this_turn", 0)) == 0, "A new player turn should clear death bonus plays")

func _test_summoned_enemy_death_does_not_grant_card_play() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = combat.create_combat(17, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var player: Dictionary = (state.get("player", {}) as Dictionary).duplicate(true)
	player["pos"] = Vector2i(2, 4)
	state["player"] = player
	state["enemies"] = [{
		"id": 8,
		"type": "lightning_wisp",
		"summoned": true,
		"pos": Vector2i(3, 4),
		"hp": 6,
		"max_hp": 6,
		"block": 0
	}]
	state = combat.apply_player_action(state, {"type": "melee", "damage": 9, "range": 1}, Vector2i(3, 4))
	_assert(int(state.get("death_bonus_card_plays_this_turn", 0)) == 0, "Killing a summoned enemy should not add a bonus card play")
	_assert(combat.cards_remaining_this_turn(state) == 2, "Summoned deaths should leave base plays unchanged before the killing card is finished")
	var rewards: Array = state.get("death_rewards", [])
	_assert(rewards.size() == 1 and bool((rewards[0] as Dictionary).get("summoned", false)), "Summoned death rewards should still be marked for animation filtering")

func _test_hand_draw_caps_at_eight() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = combat.create_combat(151, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab", "quick_stab", "quick_stab", "quick_stab", "quick_stab", "quick_stab", "quick_stab", "quick_stab", "quick_stab", "quick_stab"],
		"relics": [],
		"hand_size": 5,
		"heal_bonus": 0
	})
	var deck: Dictionary = (state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["quick_stab", "quick_stab", "quick_stab", "quick_stab", "quick_stab", "quick_stab", "quick_stab"]
	deck["draw"] = ["quick_stab", "quick_stab", "quick_stab"]
	deck["discard"] = []
	deck["burned"] = []
	state["deck"] = deck
	state["draw_per_turn"] = 3
	state = combat.prepare_next_player_turn(state)
	_assert(((state.get("deck", {}) as Dictionary).get("hand", []) as Array).size() == 8, "Drawing for a new turn should stop once the hand reaches eight cards")

func _test_first_attack_bonus_damage_math() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = combat.create_combat(16, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab"],
		"relics": ["ember_lens"],
		"hand_size": 1,
		"heal_bonus": 0
	})
	state["enemies"] = [
		{
			"id": 1,
			"type": "crawler",
			"pos": Vector2i(3, 4),
			"hp": 140,
			"max_hp": 140,
			"block": 40
		}
	]
	var action: Dictionary = {"type": "melee", "damage": 60, "range": 1}
	_assert(combat.final_damage_for_player_action(state, action) == 80, "Displayed attack damage should include the first-attack bonus before the card resolves")
	state = combat.apply_player_action(state, action, Vector2i(3, 4))
	var enemy: Dictionary = (state.get("enemies", []) as Array)[0]
	_assert(int(enemy.get("block", 0)) == 0, "Damage should remove enemy block before health")
	_assert(int(enemy.get("hp", 0)) == 100, "A 60-damage strike with Ember Lens into 40 block should deal 40 health damage")
	_assert(combat.attack_bonus_for_current_turn(state) == 0, "The first-attack bonus should be consumed after the hit resolves")

func _test_relic_effect_hooks() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var shield_state: Dictionary = combat.create_combat(1601, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab"],
		"relics": ["reinforced_shield"],
		"hand_size": 1,
		"heal_bonus": 0
	})
	_assert(int((shield_state.get("player", {}) as Dictionary).get("stoneskin", 0)) == 40, "Start-combat relic effects should apply before the first turn")
	var thorn_state: Dictionary = combat.create_combat(1611, _simple_room_layout(), {
		"hp": 240,
		"max_hp": 240,
		"deck_cards": ["stone_plate"],
		"relics": ["thornmail_brooch"],
		"hand_size": 1,
		"heal_bonus": 0
	})
	thorn_state["player"] = {"pos": Vector2i(2, 4), "hp": 240, "max_hp": 240, "block": 0, "stoneskin": 0}
	thorn_state["enemies"] = [{
		"id": 1,
		"type": "crawler",
		"pos": Vector2i(3, 4),
		"hp": 140,
		"max_hp": 140,
		"block": 0,
		"stoneskin": 0
	}]
	thorn_state = combat.apply_player_action(thorn_state, {"type": "stoneskin", "amount": 40})
	_assert(int(((thorn_state.get("enemies", []) as Array)[0] as Dictionary).get("hp", 0)) == 130, "Thornmail Brooch should use fixed-point thorns damage")
	var fire_card: Dictionary = combat.card_def("hearth_rush", {"relics": ["flint_edge"]})
	var fire_base_melee: Dictionary = {}
	for action_var: Variant in fire_card.get("actions", []):
		if typeof(action_var) != TYPE_DICTIONARY:
			continue
		var action: Dictionary = action_var
		if str(action.get("type", "")) != "melee":
			continue
		fire_base_melee = action
	_assert(int(fire_base_melee.get("burn", 0)) == 10, "Elemental relic action mods should augment matching base card actions")
	_assert(int((fire_base_melee.get("intensity_bonus", {}) as Dictionary).get("burn", 0)) == 20, "Elemental relic action mods should preserve matching intensity-gated bonus actions")
	var storm_card: Dictionary = combat.card_def("spark_dart", {"relics": ["storm_crown"]})
	var storm_actions: Array = storm_card.get("actions", [])
	_assert(str((storm_actions[storm_actions.size() - 1] as Dictionary).get("type", "")) == "card_play", "Append-action relic effects should add reusable card actions")
	var frost_state: Dictionary = combat.create_combat(1602, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab"],
		"relics": ["frost_prism"],
		"hand_size": 1,
		"heal_bonus": 0
	})
	frost_state["player"] = {"pos": Vector2i(2, 4), "hp": 240, "max_hp": 240, "block": 0, "stoneskin": 0}
	frost_state["enemies"] = [{
		"id": 1,
		"type": "crawler",
		"pos": Vector2i(3, 4),
		"hp": 140,
		"max_hp": 140,
		"block": 0,
		"stoneskin": 0,
		"freeze": 1
	}]
	frost_state = combat.apply_player_action(frost_state, {"type": "melee", "damage": 40, "range": 1}, Vector2i(3, 4))
	_assert(int(((frost_state.get("enemies", []) as Array)[0] as Dictionary).get("hp", 0)) == 20, "Target-status relic effects should add damage before existing freeze vulnerability")
	var phoenix_state: Dictionary = combat.create_combat(1603, _simple_room_layout(), {
		"hp": 30,
		"max_hp": 240,
		"deck_cards": ["quick_stab"],
		"relics": ["phoenix_ember"],
		"hand_size": 1,
		"heal_bonus": 0
	})
	phoenix_state["enemies"] = [{
		"id": 1,
		"type": "crawler",
		"pos": Vector2i(3, 4),
		"hp": 140,
		"max_hp": 140,
		"block": 0,
		"stoneskin": 0
	}]
	phoenix_state = combat.call("_damage_player", phoenix_state, 90, true)
	_assert(int((phoenix_state.get("player", {}) as Dictionary).get("hp", 0)) == 10, "Prevent-lethal relic effects should rescue the player once")
	_assert(int(((phoenix_state.get("enemies", []) as Array)[0] as Dictionary).get("burn", 0)) == 30, "Prevent-lethal relic effects should be able to apply follow-up status")
	var cinder_state: Dictionary = combat.create_combat(1604, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab"],
		"relics": ["cinderbrand_tongs", "coalheart_crucible"],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var cinder_intensity: Dictionary = combat.elemental_intensities(cinder_state)
	cinder_intensity[ElementData.FIRE] = 3
	cinder_state["elemental_intensity"] = cinder_intensity
	cinder_state["player"] = {"pos": Vector2i(4, 2), "hp": 24, "max_hp": 24, "block": 0, "stoneskin": 0}
	cinder_state = combat.apply_player_action(cinder_state, {"type": "melee", "damage": 10, "range": 1, "burn": 10}, Vector2i(5, 2))
	_assert(combat.elemental_intensity(cinder_state, ElementData.FIRE) == 2, "Fire threshold relics should be able to consume intensity after crossing")
	_assert(int(cinder_state.get("card_play_bonus_this_turn", 0)) == 1, "Intensity threshold rewards should be able to grant card plays")
	_assert(int(((cinder_state.get("enemies", []) as Array)[0] as Dictionary).get("burn", 0)) == 30, "Intensity threshold rewards should apply all-enemy statuses")
	var cinder_spent: Dictionary = combat.elemental_intensity_counter(cinder_state, "elemental_intensity_spent_total")
	_assert(int(cinder_spent.get(ElementData.FIRE, 0)) == 2, "Combat state should track gross intensity spent by relic payoffs")
	var overflow_state: Dictionary = combat.create_combat(1610, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab"],
		"relics": ["overflow_censer"],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var overflow_intensity: Dictionary = combat.elemental_intensities(overflow_state)
	overflow_intensity[ElementData.ICE] = 2
	overflow_state["elemental_intensity"] = overflow_intensity
	overflow_state = combat.apply_player_action(overflow_state, {"type": "intensity", "element": ElementData.ICE, "amount": 1})
	_assert(int((overflow_state.get("player", {}) as Dictionary).get("block", 0)) == 50, "Any-element threshold rewards should trigger from matching crossings")
	var voltaic_state: Dictionary = combat.create_combat(1605, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab"],
		"relics": ["voltaic_tuning_fork"],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var voltaic_intensity: Dictionary = combat.elemental_intensities(voltaic_state)
	voltaic_intensity[ElementData.LIGHTNING] = 2
	voltaic_state["elemental_intensity"] = voltaic_intensity
	var voltaic_deck: Dictionary = (voltaic_state.get("deck", {}) as Dictionary).duplicate(true)
	voltaic_deck["draw"] = ["quick_stab"]
	voltaic_deck["hand"] = []
	voltaic_deck["discard"] = []
	voltaic_deck["burned"] = []
	voltaic_state["deck"] = voltaic_deck
	voltaic_state = combat.apply_player_action(voltaic_state, {"type": "intensity", "element": ElementData.LIGHTNING, "amount": 1})
	_assert(combat.elemental_intensity(voltaic_state, ElementData.LIGHTNING) == 3, "Non-consuming threshold rewards should leave intensity in place")
	_assert(((voltaic_state.get("deck", {}) as Dictionary).get("hand", []) as Array).size() == 1, "Intensity threshold rewards should be able to draw cards")
	var basalt_room: Dictionary = _simple_room_layout()
	basalt_room["element"] = ElementData.NONE
	var basalt_state: Dictionary = combat.create_combat(1606, basalt_room, {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["venom_claw", "stone_plate", "quarry_step", "thorn_skewer"],
		"relics": ["basalt_calendar"],
		"hand_size": 1,
		"heal_bonus": 0
	})
	_assert(combat.elemental_intensity(basalt_state, ElementData.EARTH) == 1, "Deck-conditioned relics should be able to seed elemental intensity at combat start")
	var updraft_state: Dictionary = combat.create_combat(1607, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab"],
		"relics": ["updraft_bottle"],
		"hand_size": 1,
		"heal_bonus": 0
	})
	updraft_state = combat.apply_player_action(updraft_state, {"type": "blink", "range": 2}, Vector2i(3, 4))
	updraft_state = combat.apply_player_action(updraft_state, {"type": "blink", "range": 2}, Vector2i(2, 4))
	_assert(combat.elemental_intensity(updraft_state, ElementData.AIR) == 1, "Blink intensity relics should trigger only once per turn")
	var tectonic_state: Dictionary = combat.create_combat(1608, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab"],
		"relics": ["tectonic_abacus"],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var tectonic_intensity: Dictionary = combat.elemental_intensities(tectonic_state)
	tectonic_intensity[ElementData.EARTH] = 3
	tectonic_state["elemental_intensity"] = tectonic_intensity
	tectonic_state = combat.apply_player_action(tectonic_state, {"type": "intensity", "element": ElementData.EARTH, "amount": 1})
	_assert(combat.elemental_intensity(tectonic_state, ElementData.EARTH) == 2, "Earth threshold relics should consume their configured intensity")
	_assert(int((tectonic_state.get("player", {}) as Dictionary).get("stoneskin", 0)) == 80, "Earth threshold relics should be able to grant stoneskin")
	var black_sun_state: Dictionary = combat.create_combat(1609, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab"],
		"relics": ["black_sun_dial"],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var black_sun_intensity: Dictionary = combat.elemental_intensities(black_sun_state)
	black_sun_intensity[ElementData.FIRE] = 4
	black_sun_state["elemental_intensity"] = black_sun_intensity
	var black_sun_deck: Dictionary = (black_sun_state.get("deck", {}) as Dictionary).duplicate(true)
	black_sun_deck["draw"] = ["quick_stab"]
	black_sun_deck["hand"] = []
	black_sun_deck["discard"] = []
	black_sun_deck["burned"] = []
	black_sun_state["deck"] = black_sun_deck
	black_sun_state["enemies"] = [{
		"id": 1,
		"type": "crawler",
		"pos": Vector2i(5, 2),
		"hp": 140,
		"max_hp": 140,
		"block": 0,
		"stoneskin": 0
	}]
	black_sun_state = combat.apply_player_action(black_sun_state, {"type": "intensity", "element": ElementData.FIRE, "amount": 1})
	_assert(combat.elemental_intensity(black_sun_state, ElementData.FIRE) == 2, "Any-element consuming relics should spend the triggering element")
	_assert(int(((black_sun_state.get("enemies", []) as Array)[0] as Dictionary).get("hp", 0)) == 110, "Any-element threshold rewards should be able to damage all enemies")
	_assert(((black_sun_state.get("deck", {}) as Dictionary).get("hand", []) as Array).size() == 1, "Any-element threshold rewards should be able to draw")

func _test_tailwind_fletching_modifies_existing_forced_movement() -> void:
	var tailwind_skybreak: Dictionary = GameData.card_def_for_progression("skybreak_current", {"relics": ["tailwind_fletching"]})
	var skybreak_attack: Dictionary = (tailwind_skybreak.get("actions", []) as Array)[1]
	_assert(int(skybreak_attack.get("range", 0)) == 7, "Tailwind should keep its ranged Air range bonus")
	_assert(int(skybreak_attack.get("push", 0)) == 3, "Tailwind should increase existing push on Air ranged attacks")
	_assert(ActionIcons.token_tooltip(ActionIcons.tokens_for_action(skybreak_attack)[2] as Dictionary).contains("Tailwind Fletching"), "Relic-modified push tokens should name Tailwind in their tooltip")
	var tailwind_squall: Dictionary = GameData.card_def_for_progression("squall_shot", {"relics": ["tailwind_fletching"]})
	var squall_action: Dictionary = (tailwind_squall.get("actions", []) as Array)[1]
	_assert(int(squall_action.get("push", 0)) == 2, "Tailwind should increase existing push on Air AOE attacks")
	var tailwind_vacuum: Dictionary = GameData.card_def_for_progression("vacuum_line", {"relics": ["tailwind_fletching"]})
	var vacuum_action: Dictionary = (tailwind_vacuum.get("actions", []) as Array)[0]
	_assert(int(vacuum_action.get("amount", 0)) == 3, "Tailwind should increase existing Air pull action distance")
	var stacked_updraft: Dictionary = GameData.card_def_for_progression("updraft", {"relics": ["tailwind_fletching", "anchor_chain"]})
	var stacked_action: Dictionary = (stacked_updraft.get("actions", []) as Array)[1]
	_assert(int(stacked_action.get("amount", 0)) == 4, "Multiple relics should stack on the same forced-movement number")
	var stacked_tokens: Array = ActionIcons.tokens_for_action(stacked_action)
	var stacked_push_token: Dictionary = (stacked_tokens[stacked_tokens.size() - 1] as Dictionary)
	_assert(str(stacked_push_token.get("icon", "")) == "push", "Forced movement cards should render push after the hit")
	var stacked_tooltip: String = ActionIcons.token_tooltip(stacked_push_token)
	_assert(ActionIcons.token_is_modified(stacked_push_token), "Relic-modified forced movement should carry a dynamic token marker")
	_assert(stacked_tooltip.contains("Tailwind Fletching") and stacked_tooltip.contains("Anchor Chain"), "A token modified by multiple relics should list every source")

func _test_pierce_ignores_defenses() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var melee_state: Dictionary = combat.create_combat(1701, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	melee_state["player"] = {"pos": Vector2i(2, 4), "hp": 24, "max_hp": 24, "block": 0, "stoneskin": 0}
	melee_state["enemies"] = [{
		"id": 1,
		"type": "crawler",
		"pos": Vector2i(3, 4),
		"hp": 14,
		"max_hp": 14,
		"block": 4,
		"stoneskin": 3
	}]
	melee_state = combat.apply_player_action(melee_state, {"type": "melee", "damage": 5, "range": 1, "pierce": true}, Vector2i(3, 4))
	var pierced_enemy: Dictionary = (melee_state.get("enemies", []) as Array)[0]
	_assert(int(pierced_enemy.get("hp", 0)) == 9, "Pierce melee should damage HP through enemy defenses")
	_assert(int(pierced_enemy.get("block", 0)) == 4, "Pierce melee should not remove enemy block")
	_assert(int(pierced_enemy.get("stoneskin", 0)) == 3, "Pierce melee should not remove enemy stoneskin")

	var aoe_state: Dictionary = combat.create_combat(1702, _aoe_test_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["whirlwind_slash"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	aoe_state["player"] = {"pos": Vector2i(4, 4), "hp": 24, "max_hp": 24, "block": 0, "stoneskin": 0}
	aoe_state["enemies"] = [
		{"id": 1, "type": "crawler", "pos": Vector2i(4, 3), "hp": 14, "max_hp": 14, "block": 2, "stoneskin": 2},
		{"id": 2, "type": "harrier", "pos": Vector2i(5, 4), "hp": 10, "max_hp": 10, "block": 3, "stoneskin": 1}
	]
	var aoe_action: Dictionary = {"type": "aoe", "damage": 4, "range": 0, "pattern": [[0, -1], [1, 0]], "rotate": false, "pierce": true}
	aoe_state = combat.apply_player_action(aoe_state, aoe_action)
	var aoe_enemies: Array = aoe_state.get("enemies", [])
	_assert(int((aoe_enemies[0] as Dictionary).get("hp", 0)) == 10, "Pierce AOE should damage the first target through defenses")
	_assert(int((aoe_enemies[0] as Dictionary).get("block", 0)) == 2, "Pierce AOE should leave first target block intact")
	_assert(int((aoe_enemies[1] as Dictionary).get("hp", 0)) == 6, "Pierce AOE should damage the second target through defenses")
	_assert(int((aoe_enemies[1] as Dictionary).get("stoneskin", 0)) == 1, "Pierce AOE should leave second target stoneskin intact")

	var enemy_state: Dictionary = combat.create_combat(1703, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["brace"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	enemy_state["player"] = {"pos": Vector2i(2, 4), "hp": 24, "max_hp": 24, "block": 6, "stoneskin": 4}
	enemy_state["enemies"] = [{
		"id": 1,
		"type": "crawler",
		"pos": Vector2i(3, 4),
		"hp": 14,
		"max_hp": 14,
		"block": 0,
		"stoneskin": 0,
		"intent": {"name": "Needle", "actions": [{"type": "melee", "damage": 5, "range": 1, "pierce": true}]}
	}]
	enemy_state = combat.resolve_enemy_phase(enemy_state)
	var pierced_player: Dictionary = enemy_state.get("player", {})
	_assert(int(pierced_player.get("hp", 0)) == 19, "Enemy pierce attacks should damage player HP through defenses")
	_assert(int(pierced_player.get("block", 0)) == 6, "Enemy pierce attacks should leave player block intact")
	_assert(int(pierced_player.get("stoneskin", 0)) == 4, "Enemy pierce attacks should leave player stoneskin intact")

func _test_bleed_expose_and_sunder_keywords() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = combat.create_combat(1711, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	state["player"] = {"pos": Vector2i(2, 4), "hp": 24, "max_hp": 24, "block": 0, "stoneskin": 0}
	state["enemies"] = [{
		"id": 1,
		"type": "crawler",
		"pos": Vector2i(3, 4),
		"hp": 20,
		"max_hp": 20,
		"block": 4,
		"stoneskin": 3,
		"intent": {}
	}]
	state = combat.apply_player_action(state, {"type": "melee", "damage": 0, "range": 1, "bleed": 3, "expose": 4}, Vector2i(3, 4))
	var marked_enemy: Dictionary = (state.get("enemies", []) as Array)[0]
	_assert(int(marked_enemy.get("bleed", 0)) == 3, "Bleed attacks should store a physical damage-over-time stack")
	_assert(int(marked_enemy.get("expose", 0)) == 4, "Expose attacks should store a next-hit damage bonus")
	state = combat.apply_player_action(state, {"type": "melee", "damage": 5, "range": 1, "sunder": 6}, Vector2i(3, 4))
	var sundered_enemy: Dictionary = (state.get("enemies", []) as Array)[0]
	_assert(int(sundered_enemy.get("block", 0)) == 0, "Sunder should remove block before damage")
	_assert(int(sundered_enemy.get("stoneskin", 0)) == 0, "Sunder plus follow-up damage should clear the remaining stoneskin")
	_assert(int(sundered_enemy.get("hp", 0)) == 12, "Expose should add to the next hit before clearing")
	_assert(int(sundered_enemy.get("expose", 0)) == 0, "Expose should clear after it boosts a hit")
	var turn_result: Dictionary = combat.resolve_enemy_turn_with_steps(state, 0)
	var bleed_state: Dictionary = turn_result.get("state", state)
	var bleeding_enemy: Dictionary = (bleed_state.get("enemies", []) as Array)[0]
	_assert(int(bleeding_enemy.get("hp", 0)) == 9, "Bleed should deal its stack at enemy start of turn")
	_assert(int(bleeding_enemy.get("bleed", 0)) == 2, "Bleed should decay by one after ticking")
	var saw_bleed_step: bool = false
	for step_var: Variant in turn_result.get("steps", []):
		if typeof(step_var) == TYPE_DICTIONARY and str((step_var as Dictionary).get("label", "")) == "Bleed":
			saw_bleed_step = true
	_assert(saw_bleed_step, "Bleed ticks should surface status-damage steps")

func _test_enemy_pierce_intents_surface_icons() -> void:
	var board := CombatBoardView.new()
	for enemy_type: String in ["harrier"]:
		var pierce_intents: Array = []
		var non_pierce_attack_count: int = 0
		var enemy_def: Dictionary = GameData.enemy_def(enemy_type)
		for intent_var: Variant in enemy_def.get("intents", []):
			if typeof(intent_var) != TYPE_DICTIONARY:
				continue
			var intent: Dictionary = intent_var
			var has_attack: bool = false
			var has_pierce: bool = false
			for action_var: Variant in intent.get("actions", []):
				if typeof(action_var) != TYPE_DICTIONARY:
					continue
				var action: Dictionary = action_var
				var action_type: String = str(action.get("type", ""))
				if action_type in ["melee", "ranged", "aoe", "push", "pull"]:
					has_attack = true
					if bool(action.get("pierce", false)):
						has_pierce = true
			if has_pierce:
				pierce_intents.append(intent)
			elif has_attack:
				non_pierce_attack_count += 1
		_assert(pierce_intents.size() == 1, "%s should have exactly one pierce attack intent" % str(enemy_def.get("name", enemy_type)))
		_assert(non_pierce_attack_count >= 1, "%s should keep at least one non-pierce attack intent" % str(enemy_def.get("name", enemy_type)))
		if pierce_intents.is_empty():
			continue
		var found_pierce_icon: bool = false
		for row_var: Variant in board.call("_intent_rows", pierce_intents[0]):
			if typeof(row_var) != TYPE_ARRAY:
				continue
			for token_var: Variant in row_var as Array:
				if typeof(token_var) != TYPE_DICTIONARY:
					continue
				if str((token_var as Dictionary).get("icon", "")) == "pierce":
					found_pierce_icon = true
		_assert(found_pierce_icon, "%s pierce intent should render with the pierce icon" % str(enemy_def.get("name", enemy_type)))
	board.free()

func _test_pierce_cards_stay_in_allowed_elements() -> void:
	var allowed_elements: Dictionary = {
		"none": true,
		"ice": true,
		"earth": true
	}
	for card_id: String in GameData.cards().keys():
		var card: Dictionary = GameData.card_def(card_id)
		var has_pierce: bool = false
		for action_var: Variant in card.get("actions", []):
			if typeof(action_var) != TYPE_DICTIONARY:
				continue
			if bool((action_var as Dictionary).get("pierce", false)):
				has_pierce = true
				break
		if not has_pierce:
			continue
		var card_element: String = GameData.card_element_from_def(card)
		_assert(bool(allowed_elements.get(card_element, false)), "Pierce cards should currently stay neutral, ice, or earth: %s" % card_id)

func _test_immobilize_cards_stay_in_allowed_elements() -> void:
	var allowed_elements: Dictionary = {
		"none": true,
		"ice": true,
		"earth": true
	}
	for card_id: String in GameData.cards().keys():
		var card: Dictionary = GameData.card_def(card_id)
		var has_immobilize: bool = false
		for action_var: Variant in card.get("actions", []):
			if typeof(action_var) != TYPE_DICTIONARY:
				continue
			var action: Dictionary = action_var as Dictionary
			if bool(action.get("immobilize", false)) or bool((action.get("intensity_bonus", {}) as Dictionary).get("immobilize", false)):
				has_immobilize = true
				break
		if not has_immobilize:
			continue
		var card_element: String = GameData.card_element_from_def(card)
		_assert(bool(allowed_elements.get(card_element, false)), "Immobilize cards should currently stay neutral, ice, or earth: %s" % card_id)

func _test_healing_cards_are_burned_and_downweighted() -> void:
	var patch_up: Dictionary = GameData.card_def("patch_up")
	_assert(bool(patch_up.get("burn", false)), "Starter recovery should burn so recovery is a shorter-term tactical choice")
	_assert(int((patch_up.get("actions", [])[0] as Dictionary).get("amount", 0)) <= 30, "Patch Up should heal less than the original starter version")
	var cinch_straps: Dictionary = GameData.card_def("rallying_breath")
	_assert(str(cinch_straps.get("name", "")) == "Cinch Straps", "Boiled Leather should own a defensive strap-tightening card instead of generic healing")
	_assert(not bool(cinch_straps.get("reward_pool", true)), "Equipment-owned neutral utility should stay out of normal reward offers")
	_assert(str(((cinch_straps.get("actions", []) as Array)[0] as Dictionary).get("type", "")) == "block", "Cinch Straps should be armor defense, not a healing reward")
	var glass_mending: Dictionary = GameData.card_def("last_light")
	_assert(str(glass_mending.get("name", "")) == "Glass Mending", "Glassbone Cuirass should own a thematic mending card")
	_assert(not bool(glass_mending.get("reward_pool", true)), "Equipment-owned mending should stay out of normal reward offers")
	_assert(int(((glass_mending.get("actions", []) as Array)[0] as Dictionary).get("amount", 0)) <= 30, "Glass Mending should be modest equipment recovery")

func _test_low_movement_enemies_advance_without_outpacing_crawlers() -> void:
	var crawler_weighted_average: float = _weighted_average_enemy_toward_move("crawler")
	var acolyte_weighted_average: float = _weighted_average_enemy_toward_move("acolyte")
	var warden_weighted_average: float = _weighted_average_enemy_toward_move("warden")
	var crawler_average: float = _average_enemy_toward_move("crawler")
	var acolyte_average: float = _average_enemy_toward_move("acolyte")
	var warden_average: float = _average_enemy_toward_move("warden")
	_assert(_enemy_distinct_toward_move_count("crawler") > 1, "Crawlers should vary their movement budget across intents instead of repeating the same step")
	_assert(_enemy_distinct_toward_move_count("acolyte") > 1, "Acolytes should vary their step sizes instead of always taking the same drift action")
	_assert(_enemy_distinct_toward_move_count("warden") > 1, "Wardens should mix planted turns with heavier steps")
	_assert(is_equal_approx(crawler_average, 3.0), "Crawlers should average three tiles of forward movement across their intents")
	_assert(is_equal_approx(acolyte_average, 2.0), "Acolytes should average two tiles of forward movement across their intents")
	_assert(is_equal_approx(warden_average, 1.0), "Wardens should average one tile of forward movement across their intents")
	_assert(crawler_weighted_average > acolyte_weighted_average, "Crawlers should move more aggressively than acolytes in actual intent frequency")
	_assert(warden_weighted_average < crawler_weighted_average, "Wardens should stay slower than crawlers in actual intent frequency")

func _test_harrier_has_moving_ranged_attack() -> void:
	var found: bool = false
	for intent_var: Variant in GameData.enemy_def("harrier").get("intents", []):
		if typeof(intent_var) != TYPE_DICTIONARY:
			continue
		var has_move_toward: bool = false
		var has_ranged_attack: bool = false
		for action_var: Variant in (intent_var as Dictionary).get("actions", []):
			if typeof(action_var) != TYPE_DICTIONARY:
				continue
			var action: Dictionary = action_var as Dictionary
			if str(action.get("type", "")) == "move_toward" and int(action.get("range", 0)) > 0:
				has_move_toward = true
			if str(action.get("type", "")) == "ranged" and int(action.get("damage", 0)) > 0:
				has_ranged_attack = true
		if has_move_toward and has_ranged_attack:
			found = true
			break
	_assert(found, "Harriers should have at least one ranged attack that advances before firing")

func _max_elemental_enemy_move_attack_reach(combat: CombatEngine, element_id: String, room_depth: int) -> int:
	var max_reach: int = 0
	for enemy_type: String in ["crawler", "acolyte", "harrier", "warden"]:
		for intent_var: Variant in GameData.enemy_def(enemy_type).get("intents", []):
			if typeof(intent_var) != TYPE_DICTIONARY:
				continue
			var intent: Dictionary = combat.call("_elementalize_enemy_intent", intent_var as Dictionary, element_id, room_depth)
			max_reach = maxi(max_reach, _move_attack_reach_for_intent(intent))
	return max_reach

func _move_attack_reach_for_intent(intent: Dictionary) -> int:
	var move_range: int = 0
	var attack_range: int = 0
	for action_var: Variant in intent.get("actions", []):
		if typeof(action_var) != TYPE_DICTIONARY:
			continue
		var action: Dictionary = action_var as Dictionary
		var action_type: String = str(action.get("type", ""))
		if action_type == "move_toward" or action_type == "move_away":
			move_range += int(action.get("range", 0))
		elif action_type in ["melee", "ranged", "aoe", "push", "pull"]:
			var fallback_range: int = 1 if action_type == "melee" else 0
			attack_range = maxi(attack_range, int(action.get("range", fallback_range)))
	return move_range + attack_range

func _average_enemy_toward_move(enemy_type: String) -> float:
	var enemy_def: Dictionary = GameData.enemy_def(enemy_type)
	var intent_count: int = 0
	var total_move: int = 0
	for intent_var: Variant in enemy_def.get("intents", []):
		if typeof(intent_var) != TYPE_DICTIONARY:
			continue
		var intent: Dictionary = intent_var as Dictionary
		intent_count += 1
		total_move += _intent_toward_move(intent)
	if intent_count <= 0:
		return 0.0
	return float(total_move) / float(intent_count)

func _weighted_average_enemy_toward_move(enemy_type: String) -> float:
	var enemy_def: Dictionary = GameData.enemy_def(enemy_type)
	var total_weight: int = 0
	var weighted_move: int = 0
	for intent_var: Variant in enemy_def.get("intents", []):
		if typeof(intent_var) != TYPE_DICTIONARY:
			continue
		var intent: Dictionary = intent_var as Dictionary
		var weight: int = maxi(1, int(intent.get("weight", 1)))
		total_weight += weight
		weighted_move += weight * _intent_toward_move(intent)
	if total_weight <= 0:
		return 0.0
	return float(weighted_move) / float(total_weight)

func _enemy_distinct_toward_move_count(enemy_type: String) -> int:
	var distinct: Dictionary = {}
	for intent_var: Variant in GameData.enemy_def(enemy_type).get("intents", []):
		if typeof(intent_var) != TYPE_DICTIONARY:
			continue
		distinct[_intent_toward_move(intent_var as Dictionary)] = true
	return distinct.size()

func _intent_toward_move(intent: Dictionary) -> int:
	var total_move: int = 0
	for action_var: Variant in intent.get("actions", []):
		if typeof(action_var) != TYPE_DICTIONARY:
			continue
		var action: Dictionary = action_var as Dictionary
		if str(action.get("type", "")) == "move_toward":
			total_move += int(action.get("range", 0))
	return total_move

func _test_player_block_absorbs_full_enemy_phase() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = combat.create_combat(18, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["brace"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	state = combat.apply_player_action(state, {"type": "block", "amount": 8})
	state["enemies"] = [
		{
			"id": 1,
			"type": "crawler",
			"pos": Vector2i(3, 4),
			"hp": 14,
			"max_hp": 14,
			"block": 0,
			"intent": {"name": "Claw", "actions": [{"type": "melee", "damage": 5, "range": 1}]}
		},
		{
			"id": 2,
			"type": "harrier",
			"pos": Vector2i(2, 2),
			"hp": 10,
			"max_hp": 10,
			"block": 0,
			"intent": {"name": "Pelt", "actions": [{"type": "ranged", "damage": 4, "range": 4}]}
		}
	]
	var hp_before: int = int((state.get("player", {}) as Dictionary).get("hp", 0))
	state = combat.resolve_enemy_phase(state)
	var player: Dictionary = state.get("player", {})
	_assert(int(player.get("hp", 0)) == hp_before - 1, "Player block should absorb damage across the whole enemy phase before health is lost")
	_assert(int(player.get("block", 0)) == 0, "Enemy attacks should consume player block before health")

func _test_enemy_block_applies_on_actor_turn_only() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = combat.create_combat(19, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	state["enemies"] = [
		{
			"id": 1,
			"type": "crawler",
			"pos": Vector2i(3, 4),
			"hp": 14,
			"max_hp": 14,
			"block": 0,
			"intent": {"name": "Coil", "actions": [{"type": "block", "amount": 4}]}
		}
	]
	state = combat._apply_revealed_intent_blocks(state)
	var blocked_enemy: Dictionary = (state.get("enemies", []) as Array)[0]
	_assert(int(blocked_enemy.get("block", 0)) == 0, "Enemy block intents should not become real block before that enemy acts")
	state = combat.apply_player_action(state, {"type": "melee", "damage": 6, "range": 1}, Vector2i(3, 4))
	blocked_enemy = (state.get("enemies", []) as Array)[0]
	_assert(int(blocked_enemy.get("hp", 0)) == 8, "Future enemy block should not mitigate the current player turn")
	_assert(int(blocked_enemy.get("block", 0)) == 0, "Unresolved enemy block intent should remain non-mitigating")
	state["enemies"] = [
		{
			"id": 1,
			"type": "crawler",
			"pos": Vector2i(3, 4),
			"hp": 14,
			"max_hp": 14,
			"block": 0,
			"intent": {"name": "Coil", "time": 2, "actions": [{"type": "block", "amount": 4}]}
		}
	]
	var block_turn: Dictionary = combat.resolve_enemy_turn_with_steps(state, 0)
	state = block_turn.get("state", {})
	blocked_enemy = (state.get("enemies", []) as Array)[0]
	_assert(int(blocked_enemy.get("block", 0)) == 4, "Enemy block should apply when that enemy resolves its own block action")
	var enemies: Array = state.get("enemies", [])
	blocked_enemy = (enemies[0] as Dictionary).duplicate(true)
	blocked_enemy["intent"] = {"name": "Claw", "time": 2, "actions": [{"type": "melee", "damage": 1, "range": 1}]}
	enemies[0] = blocked_enemy
	state["enemies"] = enemies
	var next_turn: Dictionary = combat.resolve_enemy_turn_with_steps(state, 0)
	blocked_enemy = ((next_turn.get("state", {}) as Dictionary).get("enemies", []) as Array)[0]
	_assert(int(blocked_enemy.get("block", 0)) == 0, "Enemy block should expire when that enemy's next turn starts")

func _test_aoe_hits_multiple_targets() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = combat.create_combat(4, _aoe_test_room_layout(), {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["cyclone_seal"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var action: Dictionary = GameData.card_def("cyclone_seal").get("actions", [])[0]
	state = combat.apply_player_action(state, action, Vector2i(4, 3))
	var enemies: Array = state.get("enemies", [])
	_assert(int((enemies[0] as Dictionary).get("hp", 0)) < int((enemies[0] as Dictionary).get("max_hp", 0)), "AOE should damage the first target")
	_assert(int((enemies[1] as Dictionary).get("hp", 0)) < int((enemies[1] as Dictionary).get("max_hp", 0)), "AOE should damage the second target in the pattern")

func _test_close_aoe_hits_adjacent_targets() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = combat.create_combat(41, _aoe_test_room_layout(), {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["whirlwind_slash"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	state["player"] = {"pos": Vector2i(4, 4), "hp": 200, "max_hp": 200, "block": 0, "stoneskin": 0}
	state["enemies"] = [
		{"id": 1, "type": "crawler", "pos": Vector2i(4, 3), "hp": 140, "max_hp": 140, "block": 0},
		{"id": 2, "type": "harrier", "pos": Vector2i(5, 4), "hp": 100, "max_hp": 100, "block": 0},
		{"id": 3, "type": "acolyte", "pos": Vector2i(5, 5), "hp": 120, "max_hp": 120, "block": 0}
	]
	var action: Dictionary = GameData.card_def("whirlwind_slash").get("actions", [])[0]
	state = combat.apply_player_action(state, action)
	var enemies: Array = state.get("enemies", [])
	_assert(int((enemies[0] as Dictionary).get("hp", 0)) == 60, "Close AOE should hit the northern adjacent tile")
	_assert(int((enemies[1] as Dictionary).get("hp", 0)) == 20, "Close AOE should hit the eastern adjacent tile")
	_assert(int((enemies[2] as Dictionary).get("hp", 0)) == 120, "Close AOE should not hit diagonal tiles")

func _test_rotated_line_aoe_uses_selected_orientation() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = combat.create_combat(4101, _simple_room_layout(), {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["thunderline"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	state["player"] = {"pos": Vector2i(2, 4), "hp": 20, "max_hp": 20, "block": 0, "stoneskin": 0}
	state["enemies"] = [
		{"id": 1, "type": "crawler", "pos": Vector2i(4, 4), "hp": 20, "max_hp": 20, "block": 0},
		{"id": 2, "type": "harrier", "pos": Vector2i(4, 2), "hp": 20, "max_hp": 20, "block": 0},
		{"id": 3, "type": "acolyte", "pos": Vector2i(6, 4), "hp": 20, "max_hp": 20, "block": 0}
	]
	var action: Dictionary = {"type": "aoe", "damage": 5, "range": 6, "pattern": [[0, 0], [1, 0], [2, 0]], "rotate": true}
	_assert(combat.player_action_needs_orientation(action), "Asymmetric ranged line AOE should ask the player for an orientation")
	var north_action: Dictionary = action.duplicate(true)
	north_action["orientation"] = Vector2i(0, -1)
	var north_tiles: Array[Vector2i] = combat.aoe_tiles_for_player_action(state, north_action, Vector2i(4, 3))
	_assert(north_tiles.has(Vector2i(4, 2)) and north_tiles.has(Vector2i(4, 4)) and not north_tiles.has(Vector2i(6, 4)), "Line AOE preview should rotate around the selected center tile")
	var north_state: Dictionary = combat.apply_player_action(state, north_action, Vector2i(4, 3))
	var north_enemies: Array = north_state.get("enemies", [])
	_assert(int((north_enemies[1] as Dictionary).get("hp", 0)) == 15, "North-oriented line should hit the northern enemy")
	_assert(int((north_enemies[2] as Dictionary).get("hp", 0)) == 20, "North-oriented line should not hit the eastern enemy")
	var east_action: Dictionary = action.duplicate(true)
	east_action["orientation"] = Vector2i(1, 0)
	var east_tiles: Array[Vector2i] = combat.aoe_tiles_for_player_action(state, east_action, Vector2i(5, 4))
	_assert(east_tiles.has(Vector2i(4, 4)) and east_tiles.has(Vector2i(6, 4)) and not east_tiles.has(Vector2i(4, 2)), "East-oriented line should center on the hovered middle tile")
	var east_state: Dictionary = combat.apply_player_action(state, east_action, Vector2i(5, 4))
	var east_enemies: Array = east_state.get("enemies", [])
	_assert(int((east_enemies[1] as Dictionary).get("hp", 0)) == 20, "East-oriented line should not hit the northern enemy")
	_assert(int((east_enemies[2] as Dictionary).get("hp", 0)) == 15, "East-oriented line should hit the eastern enemy")

func _test_combat_board_orders_line_aoe_preview_tiles() -> void:
	var board := CombatBoardView.new()
	var east_tiles: Array = board.call("_ordered_aoe_line_tiles_for_effect", {
		"tiles": [Vector2i(5, 4), Vector2i(4, 4), Vector2i(6, 4)]
	})
	_assert(east_tiles == [Vector2i(4, 4), Vector2i(5, 4), Vector2i(6, 4)], "Combat board should order horizontal AOE line tiles for the late-drawn guide")
	var north_tiles: Array = board.call("_ordered_aoe_line_tiles_for_effect", {
		"tiles": [Vector2i(4, 3), Vector2i(4, 2), Vector2i(4, 4)]
	})
	_assert(north_tiles == [Vector2i(4, 2), Vector2i(4, 3), Vector2i(4, 4)], "Combat board should order vertical AOE line tiles for the late-drawn guide")
	var corner_tiles: Array = board.call("_ordered_aoe_line_tiles_for_effect", {
		"tiles": [Vector2i(4, 4), Vector2i(5, 4), Vector2i(4, 5)]
	})
	_assert(corner_tiles.is_empty(), "Combat board should not connect non-line AOE patterns with a line guide")
	board.free()

func _test_forced_movement_uses_selected_straight_line() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = combat.create_combat(4102, _simple_room_layout(), {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["updraft"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	state["player"] = {"pos": Vector2i(2, 4), "hp": 20, "max_hp": 20, "block": 0, "stoneskin": 0}
	state["enemies"] = [
		{"id": 1, "type": "crawler", "pos": Vector2i(4, 4), "hp": 20, "max_hp": 20, "block": 0}
	]
	var push_action: Dictionary = {"type": "push", "amount": 2, "range": 5, "damage": 0, "force_direction": Vector2i(0, -1)}
	_assert(combat.player_action_needs_orientation(push_action), "Push actions should ask the player for a movement direction")
	var push_directions: Array[Vector2i] = combat.force_directions_for_player_action(state, push_action, Vector2i(4, 4))
	_assert(push_directions.has(Vector2i(0, -1)) and push_directions.has(Vector2i(1, 0)) and not push_directions.has(Vector2i(-1, 0)), "Push should only offer directions that move farther from the player")
	var push_preview: Array[Vector2i] = combat.forced_movement_tiles_for_player_action(state, push_action, Vector2i(4, 4))
	_assert(push_preview.size() == 2 and push_preview[0] == Vector2i(4, 3) and push_preview[1] == Vector2i(4, 2), "Push preview should follow a chosen straight line that increases distance")
	var pushed_state: Dictionary = combat.apply_player_action(state, push_action, Vector2i(4, 4))
	var pushed_enemy: Dictionary = (pushed_state.get("enemies", []) as Array)[0]
	_assert(pushed_enemy.get("pos", Vector2i.ZERO) == Vector2i(4, 2), "Push should move the target along the selected away direction")
	var invalid_push_action: Dictionary = {"type": "push", "amount": 1, "range": 5, "damage": 0, "force_direction": Vector2i(-1, 0)}
	_assert(not combat.valid_targets_for_player_action(state, invalid_push_action).has(Vector2i(4, 4)), "Push should reject directions that move the target closer to the player")
	var pull_action: Dictionary = {"type": "pull", "amount": 1, "range": 5, "damage": 0, "force_direction": Vector2i(-1, 0)}
	var pull_directions: Array[Vector2i] = combat.force_directions_for_player_action(state, pull_action, Vector2i(4, 4))
	_assert(pull_directions.size() == 1 and pull_directions.has(Vector2i(-1, 0)), "Pull should only offer directions that move closer to the player")
	var pulled_state: Dictionary = combat.apply_player_action(state, pull_action, Vector2i(4, 4))
	var pulled_enemy: Dictionary = (pulled_state.get("enemies", []) as Array)[0]
	_assert(pulled_enemy.get("pos", Vector2i.ZERO) == Vector2i(3, 4), "Pull should move the target along the selected closer direction")

func _test_enemy_phase_preserves_preview_cycle() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = combat.create_combat(21, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var before_intent: Dictionary = ((state.get("enemies", []) as Array)[0] as Dictionary).get("intent", {})
	var before_rng_state: int = int(state.get("rng_state", 0))
	state = combat.resolve_enemy_phase(state)
	var after_intent: Dictionary = ((state.get("enemies", []) as Array)[0] as Dictionary).get("intent", {})
	_assert(not before_intent.is_empty(), "Enemies should begin combat with a preview intent")
	_assert(not after_intent.is_empty(), "Enemies should roll another preview intent after acting")
	_assert(int(state.get("rng_state", 0)) != before_rng_state, "Enemy phase should advance deterministic RNG state")

func _test_elemental_room_rewards_follow_affinity(default_progression: Dictionary) -> void:
	var engine: RunEngine = RunEngine.new()
	var run_state: Dictionary = engine.create_new_run(44, default_progression)
	var destination: Vector2i = Vector2i.ZERO
	for coord: Vector2i in engine.available_moves(run_state):
		var room: Dictionary = engine.room_metadata(run_state, coord)
		if str(room.get("type", "")) == "combat":
			destination = coord
			break
	_assert(destination != Vector2i.ZERO, "A fresh run should expose at least one combat room from the waypoint")
	run_state = engine.move_to_room(run_state, destination)
	var room_meta: Dictionary = engine.room_metadata(run_state, destination)
	var room_element: String = str(room_meta.get("element", "none"))
	_assert(room_element != "none", "Standard combat rooms should carry an elemental affinity")
	var combat_state: Dictionary = (run_state.get("combat_state", {}) as Dictionary).duplicate(true)
	combat_state["enemies"] = []
	var reward_state: Dictionary = engine.finish_combat(run_state, combat_state)
	var reward_cards: Array = ((reward_state.get("pending_reward", {}) as Dictionary).get("cards", []) as Array).duplicate()
	_assert(reward_cards.size() == 3, "Combat rewards should still offer three card choices")
	var elemental_count: int = 0
	var neutral_count: int = 0
	for card_id_var: Variant in reward_cards:
		var card_element: String = GameData.card_element(str(card_id_var))
		if card_element == room_element:
			elemental_count += 1
		if card_element == "none":
			neutral_count += 1
		_assert(ElementData.is_elemental(card_element), "Combat card rewards should stay elemental while equipment owns neutral utility")
	_assert(elemental_count >= 2, "Elemental combat rewards should favor at least two cards from the room's element")
	_assert(neutral_count == 0, "Elemental combat rewards should not offer neutral cards")

func _test_chain_hits_clustered_enemies() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var layout: Dictionary = _aoe_test_room_layout()
	layout["enemies"] = [
		{"id": 1, "type": "crawler", "pos": Vector2i(4, 3), "hp": 14, "max_hp": 14, "block": 0},
		{"id": 2, "type": "harrier", "pos": Vector2i(5, 3), "hp": 10, "max_hp": 10, "block": 0},
		{"id": 3, "type": "acolyte", "pos": Vector2i(6, 3), "hp": 12, "max_hp": 12, "block": 0}
	]
	var state: Dictionary = combat.create_combat(141, layout, {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["chain_bolt"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	for enemy_index: int in range((state.get("enemies", []) as Array).size()):
		var enemy: Dictionary = ((state.get("enemies", []) as Array)[enemy_index] as Dictionary).duplicate(true)
		enemy["block"] = 0
		enemy["intent"] = {}
		(state.get("enemies", []) as Array)[enemy_index] = enemy
	state = combat.apply_player_action(state, {"type": "ranged", "damage": 4, "range": 6, "chain": 2}, Vector2i(4, 3))
	var enemies: Array = state.get("enemies", [])
	_assert(int((enemies[0] as Dictionary).get("hp", 0)) == 10, "Chain attacks should hit the initial target")
	_assert(int((enemies[1] as Dictionary).get("hp", 0)) == 6, "Chain attacks should jump to a nearby second enemy")
	_assert(int((enemies[2] as Dictionary).get("hp", 0)) == 8, "Chain attacks should continue while valid nearby targets remain")

func _test_freeze_and_shock_control_turn_flow() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = combat.create_combat(155, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["frostbolt"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	state["enemies"] = [
		{
			"id": 1,
			"type": "crawler",
			"pos": Vector2i(4, 4),
			"hp": 14,
			"max_hp": 14,
			"block": 0,
			"intent": {"name": "Claw", "actions": [{"type": "melee", "damage": 5, "range": 2}]}
		}
	]
	state = combat.apply_player_action(state, {"type": "ranged", "damage": 4, "range": 6, "freeze": 1}, Vector2i(4, 4))
	state = combat.apply_player_action(state, {"type": "ranged", "damage": 3, "range": 6}, Vector2i(4, 4))
	var enemy: Dictionary = (state.get("enemies", []) as Array)[0]
	_assert(int(enemy.get("hp", 0)) == 4, "Frozen enemies should take double damage from follow-up hits")
	var hp_before_enemy_turn: int = int((state.get("player", {}) as Dictionary).get("hp", 0))
	var phase_result: Dictionary = combat.resolve_enemy_phase_with_steps(state)
	var after_enemy_phase: Dictionary = phase_result.get("state", {})
	_assert(int((after_enemy_phase.get("player", {}) as Dictionary).get("hp", 0)) == hp_before_enemy_turn, "Frozen enemies should skip their next turn")
	var player_state: Dictionary = combat.create_combat(156, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["guarded_step"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var player: Dictionary = (player_state.get("player", {}) as Dictionary).duplicate(true)
	player["shock"] = 1
	player_state["player"] = player
	player_state = combat.prepare_next_player_turn(player_state)
	_assert(combat.player_action_can_resolve(player_state, {"type": "move", "range": 2}), "Shock should still allow movement actions")
	_assert(not combat.player_action_can_resolve(player_state, {"type": "block", "amount": 4}), "Shock should block non-movement player actions for the turn")

func _test_immobilize_control_turn_flow() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = combat.create_combat(157, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["root_snare"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	state["enemies"] = [
		{
			"id": 1,
			"type": "crawler",
			"pos": Vector2i(4, 4),
			"hp": 14,
			"max_hp": 14,
			"block": 0,
			"intent": {"name": "Lunge", "actions": [{"type": "move_toward", "range": 2}, {"type": "melee", "damage": 5, "range": 1}]}
		}
	]
	state = combat.apply_player_action(state, {"type": "ranged", "damage": 0, "range": 6, "immobilize": true}, Vector2i(4, 4))
	var phase_result: Dictionary = combat.resolve_enemy_phase_with_steps(state)
	var after_phase: Dictionary = phase_result.get("state", {})
	var rooted_enemy: Dictionary = (after_phase.get("enemies", []) as Array)[0]
	_assert(rooted_enemy.get("pos", Vector2i.ZERO) == Vector2i(4, 4), "Immobilized enemies should skip movement actions for their activation")
	_assert(int((after_phase.get("player", {}) as Dictionary).get("hp", 0)) == 24, "Immobilize should deny attacks that needed movement to reach")

	var adjacent_state: Dictionary = combat.create_combat(158, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["root_snare"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	adjacent_state["enemies"] = [
		{
			"id": 1,
			"type": "crawler",
			"pos": Vector2i(3, 4),
			"hp": 14,
			"max_hp": 14,
			"block": 0,
			"intent": {"name": "Claw", "actions": [{"type": "move_toward", "range": 2}, {"type": "melee", "damage": 5, "range": 1}]}
		}
	]
	adjacent_state = combat.apply_player_action(adjacent_state, {"type": "ranged", "damage": 0, "range": 6, "immobilize": true}, Vector2i(3, 4))
	adjacent_state = combat.resolve_enemy_phase(adjacent_state)
	_assert(int((adjacent_state.get("player", {}) as Dictionary).get("hp", 0)) == 19, "Immobilized enemies should still attack if already in range")

	var player_state: Dictionary = combat.create_combat(159, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["guarded_step"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var player: Dictionary = (player_state.get("player", {}) as Dictionary).duplicate(true)
	player["immobilize"] = true
	player_state["player"] = player
	player_state = combat.prepare_next_player_turn(player_state)
	_assert(not combat.player_action_can_resolve(player_state, {"type": "move", "range": 2}), "Immobilize should block player movement actions for the turn")
	_assert(not combat.player_action_can_resolve(player_state, {"type": "blink", "range": 3}), "Immobilize should block player blink actions for the turn")
	_assert(combat.player_action_can_resolve(player_state, {"type": "block", "amount": 4}), "Immobilize should still allow non-movement player actions")

func _test_traps_trigger_and_apply_current_turn_control() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var layout: Dictionary = _simple_room_layout()
	layout["traps"] = [{
		"id": "trap_3_4",
		"pos": Vector2i(3, 4),
		"element": "lightning",
		"damage": 2,
		"shock": 1
	}]
	var state: Dictionary = combat.create_combat(161, layout, {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var deck: Dictionary = (state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["quick_stab"]
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	state["deck"] = deck
	state = combat.apply_player_action(state, {"type": "move", "range": 3}, Vector2i(5, 4))
	_assert((state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO) == Vector2i(5, 4), "Triggered traps should not halt movement mid-path")
	_assert((state.get("traps", []) as Array).is_empty(), "Triggered traps should be consumed immediately")
	_assert(str(state.get("pending_player_trap_restriction", "")) == "shock", "Trap control should wait until the current card finishes before applying this turn")
	state = combat.finish_player_card(state, 0)
	_assert(bool((state.get("player_turn_restrictions", {}) as Dictionary).get("shocked", false)), "Trap shock should apply to the current turn when a play remains after the card")
	_assert(combat.player_action_can_resolve(state, {"type": "move", "range": 2}), "Trap shock should still leave movement lines playable this turn")
	_assert(not combat.player_action_can_resolve(state, {"type": "block", "amount": 4}), "Trap shock should block non-movement follow-up plays this turn")

func _test_traps_roll_control_to_next_turn_when_no_plays_remain() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var layout: Dictionary = _simple_room_layout()
	layout["traps"] = [{
		"id": "trap_3_4",
		"pos": Vector2i(3, 4),
		"element": "lightning",
		"damage": 2,
		"shock": 1
	}]
	var state: Dictionary = combat.create_combat(162, layout, {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	state["cards_played_this_turn"] = 1
	var deck: Dictionary = (state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["quick_stab"]
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	state["deck"] = deck
	state = combat.apply_player_action(state, {"type": "move", "range": 3}, Vector2i(5, 4))
	_assert(int((state.get("player", {}) as Dictionary).get("shock", 0)) == 1, "Last-play trap shock should stay on the player for next turn setup")
	state = combat.finish_player_card(state, 0)
	_assert(not bool((state.get("player_turn_restrictions", {}) as Dictionary).get("shocked", false)), "Last-play trap shock should not retroactively lock the finished turn")
	state = combat.prepare_next_player_turn(state)
	_assert(bool((state.get("player_turn_restrictions", {}) as Dictionary).get("shocked", false)), "Last-play trap shock should carry into the next turn")

func _test_move_paths_only_cross_required_traps() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var layout: Dictionary = _simple_room_layout()
	layout["traps"] = [
		{
			"id": "trap_3_4",
			"pos": Vector2i(3, 4),
			"element": "fire",
			"damage": 2,
			"burn": 1
		},
		{
			"id": "trap_5_4",
			"pos": Vector2i(5, 4),
			"element": "fire",
			"damage": 2,
			"burn": 1
		}
	]
	var state: Dictionary = combat.create_combat(163, layout, {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var move_action: Dictionary = {"type": "move", "range": 5}
	var goal: Vector2i = Vector2i(5, 4)
	var path: Array[Vector2i] = combat.path_for_player_action(state, move_action, goal)
	_assert(path.back() == goal, "Move previews should still reach trap destinations when the chosen square is the trap")
	_assert(not path.has(Vector2i(3, 4)), "Move paths should avoid extra traps when only the destination trap is required")
	state = combat.apply_player_action(state, move_action, goal)
	_assert((state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO) == goal, "Trap-aware move resolution should still land on the chosen tile")
	var remaining_traps: Array = state.get("traps", [])
	_assert(remaining_traps.size() == 1 and ((remaining_traps[0] as Dictionary).get("pos", Vector2i.ZERO) == Vector2i(3, 4)), "Only the required destination trap should be consumed")
	_assert(int((state.get("player", {}) as Dictionary).get("hp", 0)) == 22, "Avoiding extra traps should only apply the destination trap's damage")

func _test_terrain_blocks_movement_without_blocking_line_of_sight() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var layout: Dictionary = _simple_room_layout()
	layout["enemies"] = [{
		"id": 1,
		"type": "crawler",
		"pos": Vector2i(5, 4),
		"hp": 14,
		"max_hp": 14,
		"block": 0
	}]
	layout["terrain"] = [{
		"id": "terrain_3_4",
		"kind": "wooden_box",
		"pos": Vector2i(3, 4),
		"hp": 3,
		"max_hp": 3
	}]
	var state: Dictionary = combat.create_combat(164, layout, {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var move_targets: Array[Vector2i] = combat.valid_targets_for_player_action(state, {"type": "move", "range": 2})
	_assert(not move_targets.has(Vector2i(3, 4)), "Destructible terrain should block movement target tiles")
	var ranged_targets: Array[Vector2i] = combat.valid_targets_for_player_action(state, {"type": "ranged", "damage": 1, "range": 5})
	_assert(ranged_targets.has(Vector2i(5, 4)), "Destructible terrain should not block line of sight")
	state = combat.apply_player_action(state, {"type": "melee", "damage": 3, "range": 1}, Vector2i(3, 4))
	var terrain: Dictionary = (state.get("terrain", []) as Array)[0]
	_assert(int(terrain.get("hp", 0)) == 0, "Player attacks should be able to destroy low-HP terrain")

func _test_attacking_trap_blasts_adjacent_tiles() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var layout: Dictionary = _simple_room_layout()
	layout["enemies"] = [{
		"id": 1,
		"type": "crawler",
		"pos": Vector2i(4, 4),
		"hp": 10,
		"max_hp": 10,
		"block": 0
	}]
	layout["traps"] = [{
		"id": "trap_3_4",
		"pos": Vector2i(3, 4),
		"element": ElementData.FIRE,
		"damage": 3,
		"burn": 1
	}]
	var state: Dictionary = combat.create_combat(165, layout, {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["spark_dart"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	state = combat.apply_player_action(state, {"type": "ranged", "damage": 0, "range": 2}, Vector2i(3, 4))
	_assert((state.get("traps", []) as Array).is_empty(), "Attacking a trap should consume and trigger it even for zero attack damage")
	_assert(int((state.get("player", {}) as Dictionary).get("hp", 0)) == 17, "Trap blasts should damage the player on adjacent tiles")
	var enemy: Dictionary = (state.get("enemies", []) as Array)[0]
	_assert(int(enemy.get("hp", 0)) == 7, "Trap blasts should damage enemies on adjacent tiles")

func _test_enemy_attacks_profitable_trap_without_self_damage() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var layout: Dictionary = _simple_room_layout()
	layout["player_start"] = Vector2i(5, 4)
	layout["enemies"] = [{
		"id": 1,
		"type": "crawler",
		"pos": Vector2i(1, 4),
		"hp": 12,
		"max_hp": 12,
		"block": 0,
		"intent": {"name": "Snipe", "actions": [{"type": "ranged", "damage": 1, "range": 5}]}
	}]
	layout["traps"] = [{
		"id": "trap_4_4",
		"pos": Vector2i(4, 4),
		"element": ElementData.FIRE,
		"damage": 4,
		"burn": 1
	}]
	var state: Dictionary = combat.create_combat(166, layout, {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	_set_enemy_intent(state, 0, {"name": "Snipe", "actions": [{"type": "ranged", "damage": 1, "range": 5}]})
	var phase: Dictionary = combat.resolve_enemy_phase_with_steps(state)
	var after_state: Dictionary = phase.get("state", {})
	_assert((after_state.get("traps", []) as Array).is_empty(), "Enemies should attack a trap when its blast beats their direct attack")
	_assert(int((after_state.get("player", {}) as Dictionary).get("hp", 0)) == 16, "Enemy-triggered traps should apply their blast damage to the player")
	var steps: Array = phase.get("steps", [])
	_assert(not steps.is_empty() and not ((steps.back() as Dictionary).get("triggered_traps", []) as Array).is_empty(), "Enemy attack animation steps should report triggered traps")

	layout["enemies"] = [{
		"id": 1,
		"type": "crawler",
		"pos": Vector2i(3, 4),
		"hp": 12,
		"max_hp": 12,
		"block": 0,
		"intent": {"name": "Snipe", "actions": [{"type": "ranged", "damage": 1, "range": 5}]}
	}]
	var self_risk_state: Dictionary = combat.create_combat(167, layout, {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	_set_enemy_intent(self_risk_state, 0, {"name": "Snipe", "actions": [{"type": "ranged", "damage": 1, "range": 5}]})
	var self_risk_after: Dictionary = combat.resolve_enemy_phase(self_risk_state)
	_assert((self_risk_after.get("traps", []) as Array).size() == 1, "Enemies should not attack a trap if its blast would hit themselves")
	_assert(int((self_risk_after.get("player", {}) as Dictionary).get("hp", 0)) == 19, "Enemies should fall back to a direct attack when the trap would be self-damaging")

func _test_enemy_breaks_blocking_terrain() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var layout: Dictionary = _simple_room_layout()
	layout["player_start"] = Vector2i(5, 4)
	layout["enemies"] = [{
		"id": 1,
		"type": "crawler",
		"pos": Vector2i(2, 4),
		"hp": 12,
		"max_hp": 12,
		"block": 0,
		"intent": {"name": "Break Through", "actions": [{"type": "melee", "damage": 3, "range": 1}]}
	}]
	layout["terrain"] = [{
		"id": "terrain_3_4",
		"kind": "wooden_crate",
		"pos": Vector2i(3, 4),
		"hp": 3,
		"max_hp": 3
	}]
	var state: Dictionary = combat.create_combat(168, layout, {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	_set_enemy_intent(state, 0, {"name": "Break Through", "actions": [{"type": "melee", "damage": 3, "range": 1}]})
	var phase: Dictionary = combat.resolve_enemy_phase_with_steps(state)
	var after_state: Dictionary = phase.get("state", {})
	var terrain: Dictionary = (after_state.get("terrain", []) as Array)[0]
	_assert(int(terrain.get("hp", 0)) == 0, "Enemies should break destructible terrain blocking their most direct attack path")
	_assert(int((after_state.get("player", {}) as Dictionary).get("hp", 0)) == 20, "Enemy terrain-breaking attacks should not also damage the player")
	var steps: Array = phase.get("steps", [])
	_assert(not steps.is_empty() and not ((steps.back() as Dictionary).get("terrain_losses", []) as Array).is_empty(), "Enemy terrain-breaking steps should report terrain damage")

func _test_enemy_moves_toward_breakable_chokepoint() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var layout: Dictionary = {
		"name": "Crate Chokepoint",
		"coord": Vector2i(1, 0),
		"type": "combat",
		"grid": [
			["wall", "wall", "wall", "wall", "wall", "wall", "wall"],
			["wall", "wall", "wall", "wall", "wall", "wall", "wall"],
			["wall", "wall", "wall", "wall", "wall", "wall", "wall"],
			["wall", "ash", "ash", "ash", "ash", "ash", "wall"],
			["wall", "wall", "wall", "wall", "wall", "wall", "wall"],
			["wall", "wall", "wall", "wall", "wall", "wall", "wall"],
			["wall", "wall", "wall", "wall", "wall", "wall", "wall"]
		],
		"player_start": Vector2i(1, 3),
		"enemies": [{
			"id": 1,
			"type": "crawler",
			"pos": Vector2i(5, 3),
			"hp": 12,
			"max_hp": 12,
			"block": 0
		}],
		"terrain": [{
			"id": "terrain_3_3",
			"kind": "wooden_crate",
			"pos": Vector2i(3, 3),
			"hp": 3,
			"max_hp": 3
		}],
		"loot": []
	}
	var state: Dictionary = combat.create_combat(169, layout, {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	_set_enemy_intent(state, 0, {
		"name": "Force Passage",
		"actions": [
			{"type": "move_toward", "range": 2},
			{"type": "melee", "damage": 3, "range": 1}
		]
	})
	var phase: Dictionary = combat.resolve_enemy_phase_with_steps(state)
	var after_state: Dictionary = phase.get("state", {})
	var enemy: Dictionary = (after_state.get("enemies", []) as Array)[0]
	var terrain: Dictionary = (after_state.get("terrain", []) as Array)[0]
	_assert(enemy.get("pos", Vector2i.ZERO) == Vector2i(4, 3), "Enemies should move up to destructible terrain when it is the only path forward")
	_assert(int(terrain.get("hp", 0)) == 0, "Enemies should break terrain after closing to a blocked chokepoint")
	_assert(int((after_state.get("player", {}) as Dictionary).get("hp", 0)) == 20, "Breaking a path through terrain should not also hit the player")

func _test_poison_and_stoneskin_behaviors() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = combat.create_combat(177, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["stone_plate"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	state = combat.apply_player_action(state, {"type": "stoneskin", "amount": 6})
	state = combat.prepare_next_player_turn(state)
	_assert(int((state.get("player", {}) as Dictionary).get("stoneskin", 0)) == 6, "Stoneskin should persist across turn resets")
	var poison_state: Dictionary = combat.create_combat(178, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["venom_claw"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	poison_state["enemies"] = [
		{
			"id": 1,
			"type": "crawler",
			"pos": Vector2i(3, 4),
			"hp": 14,
			"max_hp": 14,
			"block": 0,
			"intent": {"name": "Wait", "actions": []}
		}
	]
	poison_state = combat.apply_player_action(poison_state, {"type": "melee", "damage": 0, "range": 1, "poison": 4}, Vector2i(3, 4))
	var first_phase: Dictionary = combat.resolve_enemy_phase(poison_state)
	var first_enemy: Dictionary = (first_phase.get("enemies", []) as Array)[0]
	_assert(int(first_enemy.get("hp", 0)) == 14, "Poison should not trigger on the very next turn")
	var second_phase: Dictionary = combat.resolve_enemy_phase(combat.prepare_next_player_turn(first_phase))
	var second_enemy: Dictionary = (second_phase.get("enemies", []) as Array)[0]
	_assert(int(second_enemy.get("hp", 0)) == 10, "Poison should land after waiting two turns")

func _test_statuses_tick_on_affected_actor_turn() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = combat.create_combat(179, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["venom_claw"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	state["enemies"] = [
		{
			"id": 1,
			"type": "crawler",
			"pos": Vector2i(3, 4),
			"hp": 14,
			"max_hp": 14,
			"block": 0,
			"intent": {"name": "Wait", "time": 1, "actions": []}
		},
		{
			"id": 2,
			"type": "harrier",
			"pos": Vector2i(5, 4),
			"hp": 10,
			"max_hp": 10,
			"block": 0,
			"burn": 3,
			"intent": {"name": "Wait", "time": 1, "actions": []}
		}
	]
	state = combat.apply_player_action(state, {"type": "melee", "damage": 0, "range": 1, "poison": 4}, Vector2i(3, 4))
	var other_turn: Dictionary = combat.resolve_enemy_turn_with_steps(state, 1)
	state = other_turn.get("state", {})
	var enemies: Array = state.get("enemies", [])
	var poisoned_enemy: Dictionary = enemies[0]
	var burned_enemy: Dictionary = enemies[1]
	var poison: Dictionary = poisoned_enemy.get("poison", {}) as Dictionary
	_assert(int(poison.get("delay", 0)) == 2, "Poison should not tick when a different enemy takes a turn")
	_assert(int(poisoned_enemy.get("hp", 0)) == 14, "Poison should only damage the actor that owns it on that actor's turn")
	_assert(int(burned_enemy.get("hp", 0)) == 7, "Burn should tick when the burned enemy's own turn starts")
	_assert(int(burned_enemy.get("burn", 0)) < 3, "Burn countdown should decrement on the burned enemy's own turn")
	var burn_after_own_turn: int = int(burned_enemy.get("burn", 0))
	var poison_turn: Dictionary = combat.resolve_enemy_turn_with_steps(state, 0)
	state = poison_turn.get("state", {})
	enemies = state.get("enemies", [])
	poisoned_enemy = enemies[0]
	burned_enemy = enemies[1]
	poison = poisoned_enemy.get("poison", {}) as Dictionary
	_assert(int(poison.get("delay", 0)) == 1, "Poison should advance at the start of the poisoned enemy's own turn")
	_assert(int(poisoned_enemy.get("hp", 0)) == 14, "Poison should wait through its delay before dealing damage")
	_assert(int(burned_enemy.get("burn", 0)) == burn_after_own_turn, "Burn should not tick again when a different enemy takes a turn")

func _test_enemy_pathfinding_avoids_traps() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = combat.create_combat(163, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	state["enemies"] = [
		{
			"id": 1,
			"type": "crawler",
			"pos": Vector2i(5, 4),
			"hp": 14,
			"max_hp": 14,
			"block": 0,
			"intent": {"name": "Advance", "actions": [{"type": "move_toward", "range": 2}]}
		}
	]
	state["traps"] = [{
		"id": "trap_4_4",
		"pos": Vector2i(4, 4),
		"element": "fire",
		"damage": 2,
		"burn": 2
	}]
	var destination: Vector2i = combat.call("_best_move_toward", state, 0, Vector2i(2, 4), 2)
	_assert(destination != Vector2i(4, 4), "Enemies should path around traps instead of walking onto them willingly")
	var threat: Dictionary = combat.enemy_threat_tiles(state, 0)
	_assert(not (threat.get("move", []) as Array).has(Vector2i(4, 4)), "Enemy threat previews should omit trap tiles they refuse to path through")

func _test_out_of_range_elemental_enemy_attack_skips_step() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = combat.create_combat(1781, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	state["player"] = {
		"pos": Vector2i(1, 6),
		"hp": 24,
		"max_hp": 24,
		"block": 0,
		"stoneskin": 0
	}
	state["enemies"] = [
		{
			"id": 1,
			"type": "harrier",
			"pos": Vector2i(6, 1),
			"hp": 10,
			"max_hp": 10,
			"block": 0,
			"intent": {
				"name": "Cold Snap",
				"actions": [{"type": "ranged", "damage": 3, "range": 2, "freeze": 1}]
			}
		}
	]
	var phase: Dictionary = combat.resolve_enemy_phase_with_steps(state)
	var attack_step_found: bool = false
	for step_var: Variant in phase.get("steps", []):
		var step: Dictionary = step_var
		if str(step.get("kind", "")) in ["melee", "ranged", "aoe", "push", "pull"]:
			attack_step_found = true
			break
	_assert(not attack_step_found, "Enemy attack animations should only enqueue when the attack actually connects")

func _test_enemy_close_aoe_still_hits_player() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var layout: Dictionary = _simple_room_layout()
	layout["player_start"] = Vector2i(4, 4)
	layout["enemies"] = [{
		"id": 1,
		"type": "crawler",
		"pos": Vector2i(4, 5),
		"hp": 14,
		"max_hp": 14,
		"block": 0
	}]
	var state: Dictionary = combat.create_combat(1782, layout, {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	_set_enemy_intent(state, 0, {
		"name": "Ground Slam",
		"actions": [{"type": "aoe", "damage": 3, "range": 0, "pattern": [[0, -1]], "rotate": false}]
	})
	var phase: Dictionary = combat.resolve_enemy_phase_with_steps(state)
	var after_state: Dictionary = phase.get("state", {})
	_assert(int((after_state.get("player", {}) as Dictionary).get("hp", 0)) == 21, "Close enemy AOE attacks should still hit the player")
	var steps: Array = phase.get("steps", [])
	_assert(not steps.is_empty() and str((steps.back() as Dictionary).get("kind", "")) == "aoe", "Close enemy AOE hits should still enqueue an impact step")

func _test_shallow_elemental_enemy_actions_scale_back() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var shallow_ice_intent: Dictionary = combat.call("_elementalize_enemy_intent", {"weight": 2, "actions": [{"type": "ranged", "damage": 4, "range": 5}]}, "ice", 1)
	var common_ice_intent: Dictionary = combat.call("_elementalize_enemy_intent", {"weight": 4, "actions": [{"type": "ranged", "damage": 4, "range": 5}]}, "ice", 3)
	var rare_ice_intent: Dictionary = combat.call("_elementalize_enemy_intent", {"weight": 2, "actions": [{"type": "ranged", "damage": 4, "range": 5}]}, "ice", 3)
	var shallow_ice_action: Dictionary = (shallow_ice_intent.get("actions", [])[0] as Dictionary)
	var common_ice_action: Dictionary = (common_ice_intent.get("actions", [])[0] as Dictionary)
	var rare_ice_action: Dictionary = (rare_ice_intent.get("actions", [])[0] as Dictionary)
	_assert(int(shallow_ice_action.get("freeze", 0)) == 0, "Early-depth ice rooms should not hand enemies full freeze crowd control")
	_assert(int(common_ice_action.get("freeze", 0)) == 0, "Common ice intents should not freeze on every shot")
	_assert(int(rare_ice_action.get("freeze", 0)) == 1, "Rarer ice intents should keep their freeze identity")
	_assert(int(rare_ice_action.get("range", 0)) == 4, "Freeze-bearing ice attacks should use a shorter range than the longest elemental shots")
	var shallow_lightning_intent: Dictionary = combat.call("_elementalize_enemy_intent", {"weight": 2, "actions": [{"type": "ranged", "damage": 4, "range": 5}]}, "lightning", 1)
	var common_lightning_intent: Dictionary = combat.call("_elementalize_enemy_intent", {"weight": 4, "actions": [{"type": "ranged", "damage": 4, "range": 5}]}, "lightning", 3)
	var rare_lightning_intent: Dictionary = combat.call("_elementalize_enemy_intent", {"weight": 2, "actions": [{"type": "ranged", "damage": 4, "range": 5}]}, "lightning", 3)
	var shallow_lightning_action: Dictionary = (shallow_lightning_intent.get("actions", [])[0] as Dictionary)
	var common_lightning_action: Dictionary = (common_lightning_intent.get("actions", [])[0] as Dictionary)
	var rare_lightning_action: Dictionary = (rare_lightning_intent.get("actions", [])[0] as Dictionary)
	_assert(int(shallow_lightning_action.get("shock", 0)) == 0, "Early-depth lightning rooms should not hand enemies full shock crowd control")
	_assert(int(common_lightning_action.get("shock", 0)) == 0, "Common lightning intents should not shock on every shot")
	_assert(int(rare_lightning_action.get("shock", 0)) == 1, "Rarer lightning intents should keep their shock identity")
	_assert(int(rare_lightning_action.get("range", 0)) == 4, "Shock-bearing lightning attacks should use a shorter range than the longest elemental shots")
	var second_sequence_opening: Dictionary = combat.call("_elementalize_enemy_intent", {"weight": 2, "actions": [{"type": "ranged", "damage": 4, "range": 5}]}, "lightning", 5)
	var second_sequence_deep: Dictionary = combat.call("_elementalize_enemy_intent", {"weight": 2, "actions": [{"type": "ranged", "damage": 4, "range": 5}]}, "lightning", 7)
	var second_sequence_opening_action: Dictionary = (second_sequence_opening.get("actions", [])[0] as Dictionary)
	var second_sequence_deep_action: Dictionary = (second_sequence_deep.get("actions", [])[0] as Dictionary)
	_assert(int(second_sequence_opening_action.get("shock", 0)) == 0, "Second sequence opening rooms should repeat the shallow control curve")
	_assert(int(second_sequence_opening_action.get("damage", 0)) > int(shallow_lightning_action.get("damage", 0)), "Second sequence opening rooms should still hit from a higher damage baseline")
	_assert(int(second_sequence_deep_action.get("shock", 0)) == 1, "Second sequence deep rooms should regain full elemental control")
	var air_lunge_intent: Dictionary = combat.call("_elementalize_enemy_intent", {"weight": 2, "actions": [{"type": "move_toward", "range": 4}, {"type": "melee", "damage": 5, "range": 1}]}, "air", 3)
	var air_lunge_actions: Array = air_lunge_intent.get("actions", [])
	var air_lunge_move: Dictionary = air_lunge_actions[0] as Dictionary
	var air_lunge_attack: Dictionary = air_lunge_actions[1] as Dictionary
	_assert(int(air_lunge_move.get("range", 0)) == 5, "Air rooms should keep their high enemy movement identity")
	_assert(int(air_lunge_attack.get("range", 0)) == 3, "Air enemy attacks should give back safety by using shorter follow-up range")
	var lightning_bolt_intent: Dictionary = combat.call("_elementalize_enemy_intent", {"weight": 4, "actions": [{"type": "move_toward", "range": 2}, {"type": "ranged", "damage": 4, "range": 5}]}, "lightning", 3)
	var lightning_bolt_actions: Array = lightning_bolt_intent.get("actions", [])
	var lightning_bolt_move: Dictionary = lightning_bolt_actions[0] as Dictionary
	var lightning_bolt_attack: Dictionary = lightning_bolt_actions[1] as Dictionary
	_assert(int(lightning_bolt_move.get("range", 0)) == 1, "Lightning rooms should pull enemy movement back while keeping pressure")
	_assert(int(lightning_bolt_attack.get("range", 0)) == 5, "Lightning rooms should keep their relatively high attack range")
	_assert(_max_elemental_enemy_move_attack_reach(combat, ElementData.AIR, 3) == 8, "Air room enemies should no longer combine max movement with four-plus range attacks")
	_assert(_max_elemental_enemy_move_attack_reach(combat, ElementData.LIGHTNING, 3) == 6, "Lightning room enemies should leave more movement-based safety than before")
	_assert(_max_elemental_enemy_move_attack_reach(combat, ElementData.FIRE, 3) <= 7, "Fire room enemy reach should stay below the extreme mobility threshold")
	_assert(_max_elemental_enemy_move_attack_reach(combat, ElementData.ICE, 3) <= 7, "Ice room enemy reach should stay below the extreme mobility threshold")
	_assert(_max_elemental_enemy_move_attack_reach(combat, ElementData.EARTH, 3) <= 5, "Earth room enemy reach should stay close and punish through durability/status instead")
	var shallow_fire: Dictionary = combat.call("_elementalize_enemy_action", {"type": "melee", "damage": 4, "range": 1}, "fire", 1)
	var depth_two_fire: Dictionary = combat.call("_elementalize_enemy_action", {"type": "melee", "damage": 4, "range": 1}, "fire", 2)
	var deep_fire: Dictionary = combat.call("_elementalize_enemy_action", {"type": "melee", "damage": 4, "range": 1}, "fire", 3)
	_assert(int(depth_two_fire.get("burn", 0)) == int(shallow_fire.get("burn", 0)), "Depth-two fire rooms should keep shallow burn pressure")
	_assert(int(shallow_fire.get("burn", 0)) < int(deep_fire.get("burn", 0)), "Shallow elemental rooms should use lighter status payloads than deeper rooms")
	var shallow_earth: Dictionary = combat.call("_elementalize_enemy_action", {"type": "melee", "damage": 4, "range": 1}, "earth", 1)
	var depth_two_earth: Dictionary = combat.call("_elementalize_enemy_action", {"type": "melee", "damage": 4, "range": 1}, "earth", 2)
	var deep_earth: Dictionary = combat.call("_elementalize_enemy_action", {"type": "melee", "damage": 4, "range": 1}, "earth", 3)
	_assert(int(depth_two_earth.get("poison", 0)) == int(shallow_earth.get("poison", 0)), "Depth-two earth rooms should keep shallow poison pressure")
	_assert(int(shallow_earth.get("poison", 0)) < int(deep_earth.get("poison", 0)), "Deeper earth rooms should retain a stronger poison identity")

func _test_enemy_threat_tiles_follow_intent() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = combat.create_combat(179, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	state["player"] = {
		"pos": Vector2i(2, 4),
		"hp": 24,
		"max_hp": 24,
		"block": 0,
		"stoneskin": 0
	}
	state["enemies"] = [
		{
			"id": 1,
			"type": "harrier",
			"pos": Vector2i(5, 2),
			"hp": 10,
			"max_hp": 10,
			"block": 0,
			"intent": {
				"name": "Pelt",
				"actions": [
					{"type": "move_toward", "range": 2},
					{"type": "ranged", "damage": 4, "range": 3}
				]
			}
		}
	]
	var threat: Dictionary = combat.enemy_threat_tiles(state, 0)
	var move_tiles: Array = threat.get("move", [])
	var attack_tiles: Array = threat.get("attack", [])
	_assert(move_tiles.has(Vector2i(4, 2)), "Threat previews should include forward movement tiles for advancing enemies")
	_assert(move_tiles.has(Vector2i(4, 3)), "Threat previews should include closer diagonal paths when they are reachable")
	_assert(move_tiles.has(Vector2i(6, 2)), "Threat previews should show the enemy's full movement reach instead of only player-directed tiles")
	_assert(attack_tiles.has(Vector2i(2, 4)), "Threat previews should include the player's tile when the intent can connect after moving")
	_assert(attack_tiles.has(Vector2i(4, 2)), "Threat previews should mark tiles attackable from any reachable movement endpoint")

func _test_enemy_threat_tiles_assume_player_can_vacate_current_tile() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var layout: Dictionary = {
		"name": "Vacated Corridor",
		"coord": Vector2i(1, 0),
		"type": "combat",
		"grid": [
			["wall", "wall", "wall", "wall", "wall", "wall", "wall"],
			["wall", "wall", "wall", "wall", "wall", "wall", "wall"],
			["wall", "wall", "wall", "wall", "wall", "wall", "wall"],
			["wall", "ash", "ash", "ash", "ash", "ash", "wall"],
			["wall", "wall", "wall", "wall", "wall", "wall", "wall"],
			["wall", "wall", "wall", "wall", "wall", "wall", "wall"],
			["wall", "wall", "wall", "wall", "wall", "wall", "wall"]
		],
		"player_start": Vector2i(3, 3),
		"enemies": [{
			"id": 1,
			"type": "crawler",
			"pos": Vector2i(1, 3),
			"hp": 12,
			"max_hp": 12,
			"block": 0
		}],
		"loot": []
	}
	var state: Dictionary = combat.create_combat(184, layout, {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	_set_enemy_intent(state, 0, {
		"name": "Corridor Lunge",
		"actions": [
			{"type": "move_toward", "range": 3},
			{"type": "melee", "damage": 5, "range": 1}
		]
	})
	var threat: Dictionary = combat.enemy_threat_tiles(state, 0)
	_assert(
		(threat.get("attack", []) as Array).has(Vector2i(5, 3)),
		"Threat previews should assume the player can vacate their current tile before enemy movement"
	)
	var moved_state: Dictionary = state.duplicate(true)
	var moved_player: Dictionary = (moved_state.get("player", {}) as Dictionary).duplicate(true)
	moved_player["pos"] = Vector2i(5, 3)
	moved_state["player"] = moved_player
	var after_state: Dictionary = combat.resolve_enemy_phase(moved_state)
	_assert(
		int((after_state.get("player", {}) as Dictionary).get("hp", 0)) < 24,
		"The regression setup should prove the enemy can actually hit that vacated-corridor square"
	)

func _test_enemy_threat_tiles_include_enemy_triggered_trap_blasts() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var layout: Dictionary = _simple_room_layout()
	layout["player_start"] = Vector2i(2, 4)
	layout["enemies"] = [{
		"id": 1,
		"type": "crawler",
		"pos": Vector2i(1, 4),
		"hp": 12,
		"max_hp": 12,
		"block": 0
	}]
	layout["traps"] = [{
		"id": "trap_4_4",
		"pos": Vector2i(4, 4),
		"element": ElementData.FIRE,
		"damage": 4,
		"burn": 1
	}]
	var state: Dictionary = combat.create_combat(185, layout, {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	_set_enemy_intent(state, 0, {
		"name": "Fuse Shot",
		"actions": [{"type": "ranged", "damage": 1, "range": 3}]
	})
	var threat: Dictionary = combat.enemy_threat_tiles(state, 0)
	_assert(
		(threat.get("attack", []) as Array).has(Vector2i(5, 4)),
		"Threat previews should include blast tiles from traps an enemy can safely trigger"
	)
	var moved_state: Dictionary = state.duplicate(true)
	var moved_player: Dictionary = (moved_state.get("player", {}) as Dictionary).duplicate(true)
	moved_player["pos"] = Vector2i(5, 4)
	moved_state["player"] = moved_player
	var after_state: Dictionary = combat.resolve_enemy_phase(moved_state)
	_assert((after_state.get("traps", []) as Array).is_empty(), "The regression setup should prove the enemy triggers the trap")
	_assert(
		int((after_state.get("player", {}) as Dictionary).get("hp", 0)) < 20,
		"The regression setup should prove the trap blast can hit the moved player"
	)

func _test_large_enemy_threat_tiles_use_footprint() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = combat.create_combat(181, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	state["player"] = {
		"pos": Vector2i(6, 4),
		"hp": 24,
		"max_hp": 24,
		"block": 0,
		"stoneskin": 0
	}
	state["enemies"] = [
		{
			"id": 1,
			"type": "zekarion",
			"pos": Vector2i(4, 3),
			"footprint": Vector2i(2, 2),
			"hp": 72,
			"max_hp": 72,
			"block": 0,
			"intent": {
				"name": "Storm Claw",
				"actions": [{"type": "melee", "damage": 12, "range": 1}]
			}
		}
	]
	var threat: Dictionary = combat.enemy_threat_tiles(state, 0)
	var attack_tiles: Array = threat.get("attack", [])
	_assert(attack_tiles.has(Vector2i(6, 4)), "Large-enemy melee previews should include tiles adjacent to any footprint square")
	_assert(attack_tiles.has(Vector2i(5, 5)), "Large-enemy melee previews should include the footprint's lower edge")
	_assert(not attack_tiles.has(Vector2i(6, 5)), "Large-enemy melee previews should still exclude tiles outside attack range")
	var after_state: Dictionary = combat.resolve_enemy_phase(state)
	_assert(int((after_state.get("player", {}) as Dictionary).get("hp", 0)) < 24, "The large-enemy footprint preview should match actual enemy damage reach")

func _test_lightning_strikes_threat_tiles_are_previewed() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = combat.create_combat(182, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var action: Dictionary = {"type": "lightning_strikes", "damage": 7, "count": 6, "shock": 1}
	var enemy: Dictionary = {
		"id": 1,
		"type": "zekarion",
		"pos": Vector2i(4, 3),
		"footprint": Vector2i(2, 2),
		"hp": 72,
		"max_hp": 72,
		"block": 0,
		"intent": {
			"name": "Skybreak",
			"actions": [action]
		}
	}
	state["enemies"] = [enemy]
	var threat: Dictionary = combat.enemy_threat_tiles(state, 0)
	var attack_tiles: Array = threat.get("attack", [])
	var expected_tiles: Array = combat.call("_lightning_strike_tiles", state, enemy, action)
	_assert(attack_tiles.size() == expected_tiles.size(), "Lightning strike previews should show the deterministic strike tiles instead of hiding the attack")
	for tile: Vector2i in expected_tiles:
		_assert(attack_tiles.has(tile), "Lightning strike previews should include every deterministic strike tile")

func _test_zekarion_tempest_breath_leaves_corner_safety() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = combat.create_combat(183, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	state["player"] = {
		"pos": Vector2i(1, 1),
		"hp": 24,
		"max_hp": 24,
		"block": 0,
		"stoneskin": 0
	}
	state["enemies"] = [
		{
			"id": 1,
			"type": "zekarion",
			"pos": Vector2i(4, 3),
			"footprint": Vector2i(2, 2),
			"hp": 72,
			"max_hp": 72,
			"block": 0
		}
	]
	var tempest_breath: Dictionary = _enemy_intent_by_id("zekarion", "tempest_breath")
	_set_enemy_intent(state, 0, tempest_breath)
	var breath_action: Dictionary = ((tempest_breath.get("actions", []) as Array)[1] as Dictionary)
	_assert(int(breath_action.get("range", 0)) == 3, "Zekarion's Tempest Breath should leave more room-scale counterplay")
	var threat: Dictionary = combat.enemy_threat_tiles(state, 0)
	_assert(not (threat.get("attack", []) as Array).has(Vector2i(1, 1)), "Tempest Breath threat preview should leave the opposite corner safe")
	var after_state: Dictionary = combat.resolve_enemy_phase(state)
	_assert(int((after_state.get("player", {}) as Dictionary).get("hp", 0)) == 24, "Tempest Breath should not hit a player outside the previewed threat")

func _test_zekarion_summons_wisps_when_alone() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = combat.create_combat(44, _zekarion_test_room_layout(), {
		"hp": 24,
		"max_hp": 36,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var enemies: Array = state.get("enemies", [])
	for index: int in range(enemies.size()):
		var enemy: Dictionary = enemies[index]
		if str(enemy.get("type", "")) == "zekarion":
			enemy["intent"] = {"id": "debug_wait", "name": "Wait", "actions": []}
			enemies[index] = enemy
		if str(enemy.get("type", "")) == "lightning_wisp":
			enemy["hp"] = 0
			enemies[index] = enemy
	state["enemies"] = enemies
	var phase: Dictionary = combat.resolve_enemy_phase_with_steps(state)
	var next_state: Dictionary = phase.get("state", {})
	var live_wisps: int = 0
	for enemy_var: Variant in next_state.get("enemies", []):
		var enemy: Dictionary = enemy_var
		if str(enemy.get("type", "")) == "lightning_wisp" and int(enemy.get("hp", 0)) > 0:
			live_wisps += 1
	_assert(live_wisps == 0, "Zekarion should finish his current intent before scheduling a wisp summon")
	var scheduled_summon: bool = false
	for enemy_var: Variant in next_state.get("enemies", []):
		var enemy: Dictionary = enemy_var
		if str(enemy.get("type", "")) == "zekarion":
			scheduled_summon = str((enemy.get("intent", {}) as Dictionary).get("id", "")) == "call_wisps"
	_assert(scheduled_summon, "Zekarion should choose Call Wisps as his next intent when no wisps remain")
	var summon_phase: Dictionary = combat.resolve_enemy_phase_with_steps(next_state)
	var summoned_state: Dictionary = summon_phase.get("state", {})
	live_wisps = 0
	for enemy_var: Variant in summoned_state.get("enemies", []):
		var enemy: Dictionary = enemy_var
		if str(enemy.get("type", "")) == "lightning_wisp" and int(enemy.get("hp", 0)) > 0:
			live_wisps += 1
	_assert(live_wisps == 2, "Zekarion should summon two wisps when his scheduled summon turn executes")

func _test_summoned_wisps_receive_preview_intents() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = combat.create_combat(45, _zekarion_test_room_layout(), {
		"hp": 24,
		"max_hp": 36,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var enemies: Array = state.get("enemies", [])
	for index: int in range(enemies.size()):
		var enemy: Dictionary = enemies[index]
		if str(enemy.get("type", "")) == "zekarion":
			enemy["intent"] = {
				"id": "call_wisps",
				"name": "Call Wisps",
				"actions": [{"type": "summon_minions", "minion_type": "lightning_wisp", "count": 2}]
			}
			enemies[index] = enemy
		elif str(enemy.get("type", "")) == "lightning_wisp":
			enemy["hp"] = 0
			enemies[index] = enemy
	state["enemies"] = enemies
	var phase: Dictionary = combat.resolve_enemy_phase_with_steps(state)
	var next_state: Dictionary = phase.get("state", {})
	for enemy_var: Variant in next_state.get("enemies", []):
		var enemy: Dictionary = enemy_var
		if str(enemy.get("type", "")) == "lightning_wisp" and int(enemy.get("hp", 0)) > 0:
			_assert(not (enemy.get("intent", {}) as Dictionary).is_empty(), "Summoned wisps should immediately receive a preview intent")

func _test_zekarion_ignores_shock_status() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = combat.create_combat(46, _zekarion_test_room_layout(), {
		"hp": 24,
		"max_hp": 36,
		"deck_cards": ["static_lash"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var enemies: Array = state.get("enemies", [])
	for index: int in range(enemies.size()):
		var enemy: Dictionary = enemies[index]
		if str(enemy.get("type", "")) != "zekarion":
			continue
		state = combat.call("_apply_action_keywords_to_enemy", state, index, {"type": "ranged", "shock": 1}, Vector2i(2, 2))
		var zekarion: Dictionary = (state.get("enemies", []) as Array)[index]
		_assert(int(zekarion.get("shock", 0)) == 0, "Zekarion should ignore lightning shock status")
		break

func _test_status_badges_surface_countdowns() -> void:
	var board := CombatBoardView.new()
	var badges: Array = board.call("_unit_status_badges", {
		"burn": 5,
		"freeze": 1,
		"shock": 1,
		"immobilize": true,
		"poison": {"damage": 4, "delay": 2}
	})
	_assert(badges.size() == 5, "Status badges should surface each active status independently")
	_assert(str((badges[0] as Dictionary).get("icon", "")) == "burn", "Burn badges should use the shared burn icon")
	_assert(int((badges[0] as Dictionary).get("count", 0)) == 5, "Burn badges should show their remaining countdown")
	_assert(str((badges[3] as Dictionary).get("icon", "")) == "immobilize", "Immobilize badges should use the shared immobilize icon")
	_assert(str((badges[4] as Dictionary).get("icon", "")) == "poison", "Poison badges should use the shared poison icon")
	_assert(int((badges[4] as Dictionary).get("count", 0)) == 2, "Poison badges should show the turns remaining before it lands")

func _test_player_restriction_badges_show_turn_lock() -> void:
	var board := CombatBoardView.new()
	var statuses: Dictionary = board.call("_player_display_statuses", {"burn": 0, "freeze": 0, "shock": 0, "immobilize": false}, {"frozen": true, "shocked": false, "immobilized": false})
	_assert(int(statuses.get("freeze", 0)) == 1, "Frozen turns should still surface a freeze badge even after the restriction consumes the stored counter")
	statuses = board.call("_player_display_statuses", {"burn": 0, "freeze": 0, "shock": 0, "immobilize": false}, {"frozen": false, "shocked": true, "immobilized": false})
	_assert(int(statuses.get("shock", 0)) == 1, "Shocked turns should still surface a shock badge even after the restriction consumes the stored counter")
	statuses = board.call("_player_display_statuses", {"burn": 0, "freeze": 0, "shock": 0, "immobilize": false}, {"frozen": false, "shocked": false, "immobilized": true})
	_assert(bool(statuses.get("immobilize", false)), "Immobilized turns should still surface an immobilize badge after the restriction consumes the stored condition")

func _test_air_trap_tooltip_is_damage_only() -> void:
	var board := CombatBoardView.new()
	var tooltip: String = str(board.call("_trap_tooltip_text", {
		"element": "air",
		"damage": 3
	}))
	_assert(tooltip.contains("Air Trap"), "Trap tooltips should identify their elemental type")
	_assert(tooltip.contains("3 damage to adjacent tiles"), "Trap tooltips should show adjacent blast damage")
	_assert(not tooltip.contains("Burn") and not tooltip.contains("Freeze") and not tooltip.contains("Shock") and not tooltip.contains("Immobilize") and not tooltip.contains("Poison"), "Air trap tooltips should stay damage-only until the air secondary effect is decided")

func _test_pickup_tooltips_describe_effects() -> void:
	var board := CombatBoardView.new()
	board.size = Vector2(960.0, 680.0)
	board.combat_state = {"grid": _simple_grid()}
	_assert(
		str(board.call("_loot_tooltip_text", {"kind": "healing_vial", "amount": 4})) == "Healing potion: Heal 4",
		"Potion tooltips should describe the exact healing effect"
	)
	_assert(
		str(board.call("_loot_tooltip_text", {"kind": "rusty_shield", "amount": 4})) == "Rusty shield: Gain 4 block",
		"Rusty shield tooltips should describe the exact block effect"
	)
	_assert(
		str(board.call("_loot_tooltip_text", {"kind": "dropped_embers", "amount": 23})) == "Dropped embers: Reclaim 23",
		"Dropped ember tooltips should show the exact recoverable amount"
	)
	_assert(
		str(board.call("_loot_tooltip_text", {"kind": "equipment", "equipment_id": "iron_cleaver"})) == "Iron Cleaver: Weapon",
		"Equipment pickup tooltips should identify the item and slot"
	)
	var potion_rect: Rect2 = board.call("_loot_rect_for_tile", Vector2i(3, 3), null, {"kind": "healing_vial"})
	var equipment_rect: Rect2 = board.call("_loot_rect_for_tile", Vector2i(3, 3), null, {"kind": "equipment", "equipment_id": "iron_cleaver"})
	_assert(equipment_rect.size == potion_rect.size, "Equipment pickups should use the same grounded tile footprint as ordinary pickups")
	_assert(is_equal_approx(equipment_rect.end.y, potion_rect.end.y), "Equipment pickups should share the consumable pickup baseline")
	var terrain_tooltip: String = str(board.call("_terrain_tooltip_text", {
		"kind": "wooden_crate",
		"hp": 2,
		"max_hp": 3
	}))
	_assert(terrain_tooltip.contains("Wooden crate"), "Terrain tooltips should identify the object")
	_assert(terrain_tooltip.contains("2/3 HP"), "Terrain tooltips should show HP")
	_assert(not terrain_tooltip.contains("Blocks movement"), "Client terrain tooltips should stay concise")
	_assert(not terrain_tooltip.contains("Line of sight open"), "Client terrain tooltips should not repeat tactical harness guidance")
	_assert(not terrain_tooltip.contains("Attack to break"), "Client terrain tooltips should avoid instructional text")

func _test_terrain_health_bars_are_contextual() -> void:
	var board := CombatBoardView.new()
	var terrain_tile := Vector2i(3, 4)
	var terrain := {
		"id": "box_a",
		"kind": "wooden_box",
		"pos": terrain_tile,
		"hp": 3,
		"max_hp": 3
	}
	_assert(not bool(board.call("_should_show_terrain_health_bar", terrain)), "Undamaged, unhighlighted terrain should hide its health bar")
	var damaged_terrain: Dictionary = terrain.duplicate(true)
	damaged_terrain["hp"] = 2
	_assert(bool(board.call("_should_show_terrain_health_bar", damaged_terrain)), "Damaged terrain should show its health bar")
	var highlighted_tiles: Array[Vector2i] = []
	highlighted_tiles.append(terrain_tile)
	board.set("attack_tiles", highlighted_tiles)
	_assert(bool(board.call("_should_show_terrain_health_bar", terrain)), "Attack-highlighted terrain should show its health bar")
	var empty_tiles: Array[Vector2i] = []
	board.set("attack_tiles", empty_tiles)
	board.set("presentation", {
		"effect": {
			"preview": true,
			"damage_preview": {
				"terrain_box_a": {
					"hp": 1,
					"hp_loss": 2,
					"lethal": false
				}
			}
		}
	})
	var terrain_preview: Dictionary = board.call("_terrain_damage_preview", terrain)
	_assert(bool(board.call("_should_show_terrain_health_bar", terrain)), "Terrain with a pending damage preview should show its health bar")
	_assert(int(terrain_preview.get("hp", -1)) == 1 and int(terrain_preview.get("hp_loss", 0)) == 2, "Terrain health bars should read terrain damage previews by terrain key")

func _test_health_bar_segments_use_fixed_point_scale() -> void:
	var board := CombatBoardView.new()
	_assert(SegmentedHealthBar.segment_count_for_max_hp(140.0) == 7, "Segmented health bars should default to 20 HP per divider after fixed-point scaling")
	_assert(int(board.call("_health_bar_segment_count", 140)) == 7, "Combat board unit health bars should use the shared fixed-point segment size")
	_assert(int(board.call("_health_bar_segment_count", 30)) == 2, "Low-HP terrain should avoid one segment per HP")
	_assert(int(board.call("_health_bar_segment_count", 10)) == 1, "Tiny health bars should keep at least one filled segment")

func _test_run_scene_terrain_damage_previews_use_terrain_keys() -> void:
	var run_scene_script: Script = load("res://scripts/run_scene.gd")
	_assert(run_scene_script != null, "Run scene script should load for terrain preview coverage")
	if run_scene_script == null:
		return
	var instance: Node = run_scene_script.new()
	var combat: CombatEngine = CombatEngine.new()
	var layout: Dictionary = _simple_room_layout()
	layout["player_start"] = Vector2i(2, 4)
	layout["enemies"] = []
	layout["terrain"] = [{
		"id": "box_a",
		"kind": "wooden_box",
		"pos": Vector2i(3, 4),
		"hp": 3,
		"max_hp": 3
	}]
	var state: Dictionary = combat.create_combat(169, layout, {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var preview: Dictionary = instance.call("_preview_damage_for_action", state, {"type": "melee", "damage": 2, "range": 1}, Vector2i(3, 4))
	var terrain_preview: Dictionary = preview.get("terrain_box_a", {}) as Dictionary
	_assert(not terrain_preview.is_empty(), "Run scene attack previews should include terrain damage entries")
	_assert(int(terrain_preview.get("hp", -1)) == 1 and int(terrain_preview.get("hp_loss", 0)) == 2, "Terrain damage previews should project remaining HP and loss")
	var lethal_preview: Dictionary = instance.call("_preview_damage_for_action", state, {"type": "melee", "damage": 4, "range": 1}, Vector2i(3, 4))
	var lethal_terrain_preview: Dictionary = lethal_preview.get("terrain_box_a", {}) as Dictionary
	_assert(bool(lethal_terrain_preview.get("lethal", false)), "Terrain damage previews should mark lethal terrain hits")
	instance.free()

func _test_unit_hud_stacks_above_sprite_art() -> void:
	var board := CombatBoardView.new()
	board.size = Vector2(960.0, 680.0)
	var center := Vector2(320.0, 240.0)
	var unit: Dictionary = {
		"type": "harrier",
		"intent": {
			"name": "Pelt",
			"actions": [
				{"type": "move_toward", "range": 2},
				{"type": "ranged", "damage": 4, "range": 3}
			]
		}
	}
	var health_rect: Rect2 = board.call("_unit_health_bar_rect", unit, center)
	var intent_rect: Rect2 = board.call("_enemy_intent_rect_for_line_count", center, health_rect, board.call("_enemy_intent_line_count", unit.get("intent", {})))
	var art_top_y: float = float(board.call("_unit_art_top_y", unit, center))
	_assert(health_rect.position.y + health_rect.size.y <= art_top_y - 5.5, "Unit health bars should sit clear of the sprite art")
	_assert(is_equal_approx(intent_rect.position.y + intent_rect.size.y, health_rect.position.y), "Enemy intent popups should stack directly above health bars")

func _test_combat_board_zooms_to_rendered_room_bounds() -> void:
	var board := CombatBoardView.new()
	board.size = Vector2(1900.0, 790.0)
	board.set("combat_state", {"grid": _simple_grid()})
	var tile_width: float = board.call("_tile_width")
	var top_inner_tile: Vector2 = board.call("_tile_center", Vector2i(1, 1))
	var bottom_inner_tile: Vector2 = board.call("_tile_center", Vector2i(6, 6))
	_assert(tile_width > 160.0, "Combat board should zoom past the old conservative tile cap on large stage space")
	_assert(top_inner_tile.y < 220.0, "Combat board layout should use hidden-wall-free bounds and sit higher in the stage")
	_assert(bottom_inner_tile.y + tile_width * 0.30 < board.size.y - 24.0, "Combat board should keep the lower room clear of the hand area")

func _test_enemy_intent_name_reserves_header_line() -> void:
	var board := CombatBoardView.new()
	var attack_intent := {
		"name": "Pelt",
		"actions": [{"type": "ranged", "damage": 4, "range": 4}]
	}
	var wait_intent := {
		"name": "Wait",
		"actions": []
	}
	_assert(int(board.call("_enemy_intent_line_count", attack_intent)) == 2, "Named enemy intents should reserve a header line above their action icons")
	_assert(int(board.call("_enemy_intent_line_count", wait_intent)) == 1, "Name-only enemy intents should still render a title line")

func _test_enemy_intent_panels_expand_on_hover_or_toggle() -> void:
	var board := CombatBoardView.new()
	board.size = Vector2(960.0, 680.0)
	var font: Font = load("res://fonts/LabyrinthCrumble-Regular.tres")
	var center := Vector2(320.0, 320.0)
	var enemy := {
		"id": 7,
		"type": "harrier",
		"role": "enemy",
		"pos": Vector2i(3, 3),
		"intent": {
			"name": "Pelt",
			"actions": [{"type": "ranged", "damage": 4, "range": 4}]
		}
	}
	var compact_layout: Dictionary = board.call("_enemy_hud_layout", enemy, center, [], font)
	var compact_rows: Array = compact_layout.get("rows", [])
	var compact_rect: Rect2 = compact_layout.get("intent_rect", Rect2())
	_assert(compact_rows.is_empty(), "Enemy intent panels should only show the action name by default")
	board.set("_hover_tile", Vector2i(3, 3))
	var hovered_layout: Dictionary = board.call("_enemy_hud_layout", enemy, center, [], font)
	var hovered_rows: Array = hovered_layout.get("rows", [])
	var hovered_rect: Rect2 = hovered_layout.get("intent_rect", Rect2())
	_assert(hovered_rows.size() == 1, "Hovered enemy intent panels should expand to show action details")
	_assert(hovered_rect.size.y > compact_rect.size.y, "Hovered enemy intent panels should grow when details become visible")
	board.set("_hover_tile", Vector2i(-1, -1))
	board.presentation = {"expanded_enemy_actor_keys": ["enemy_7"]}
	var portrait_hover_layout: Dictionary = board.call("_enemy_hud_layout", enemy, center, [], font)
	var portrait_hover_rows: Array = portrait_hover_layout.get("rows", [])
	_assert(portrait_hover_rows.size() == 1, "Turn-order portrait hovers should expand the matching enemy intent panel")
	board.presentation = {"show_all_enemy_intents": true}
	var toggled_layout: Dictionary = board.call("_enemy_hud_layout", enemy, center, [], font)
	var toggled_rows: Array = toggled_layout.get("rows", [])
	_assert(toggled_rows.size() == 1, "The show-all enemy intent flag should expand panels without hover")

func _test_enemy_hud_layout_stays_centered_when_clear() -> void:
	var board := CombatBoardView.new()
	board.size = Vector2(960.0, 680.0)
	var font: Font = load("res://fonts/LabyrinthCrumble-Regular.tres")
	var center := Vector2(320.0, 320.0)
	var enemy := {
		"type": "harrier",
		"role": "enemy",
		"intent": {
			"name": "Pelt",
			"actions": [{"type": "ranged", "damage": 4, "range": 4}]
		}
	}
	var layout: Dictionary = board.call("_enemy_hud_layout", enemy, center, [], font)
	var offset: Vector2 = layout.get("offset", Vector2.ONE)
	_assert(offset == Vector2.ZERO, "Enemy HUDs should keep their default stack when nothing important is in the way")

func _test_enemy_hud_layout_offsets_away_from_reserved_ui() -> void:
	var board := CombatBoardView.new()
	board.size = Vector2(960.0, 680.0)
	board.presentation = {"show_all_enemy_intents": true}
	var font: Font = load("res://fonts/LabyrinthCrumble-Regular.tres")
	var center := Vector2(320.0, 240.0)
	var enemy := {
		"type": "harrier",
		"role": "enemy",
		"intent": {
			"name": "Pelt",
			"actions": [
				{"type": "move_toward", "range": 2},
				{"type": "ranged", "damage": 4, "range": 3}
			]
		}
	}
	var health_rect: Rect2 = board.call("_unit_health_bar_rect", enemy, center)
	var line_count: int = int(board.call("_enemy_intent_line_count", enemy.get("intent", {})))
	var intent_rect: Rect2 = board.call("_enemy_intent_rect_for_line_count", center, health_rect, line_count)
	var layout: Dictionary = board.call("_enemy_hud_layout", enemy, center, [health_rect, intent_rect], font)
	var offset: Vector2 = layout.get("offset", Vector2.ZERO)
	_assert(offset != Vector2.ZERO, "Enemy HUDs should nudge away when their default stack would cover reserved HUD space")
	for rect_var: Variant in layout.get("occupied_rects", []):
		if typeof(rect_var) != TYPE_RECT2:
			continue
		var rect: Rect2 = rect_var
		_assert(not rect.intersects(health_rect, false), "Shifted enemy HUD pieces should clear the reserved health bar space")
		_assert(not rect.intersects(intent_rect, false), "Shifted enemy HUD pieces should clear the reserved intent space")

func _test_enemy_hud_layout_offsets_down_from_top_edge() -> void:
	var board := CombatBoardView.new()
	board.size = Vector2(960.0, 680.0)
	var font: Font = load("res://fonts/LabyrinthCrumble-Regular.tres")
	var enemy := {
		"type": "harrier",
		"role": "enemy",
		"intent": {
			"name": "Pelt",
			"actions": [{"type": "ranged", "damage": 4, "range": 4}]
		}
	}
	var layout: Dictionary = board.call("_enemy_hud_layout", enemy, Vector2(480.0, 215.0), [], font)
	var intent_rect: Rect2 = layout.get("intent_rect", Rect2())
	var offset: Vector2 = layout.get("offset", Vector2.ZERO)
	_assert(offset.y > 0.0, "Enemy HUD layout should move downward when a top-edge intent would clip offscreen")
	_assert(intent_rect.position.y >= 6.0, "Top-edge enemy intents should remain inside the board viewport")

func _test_boss_intent_layout_avoids_boss_health_bar() -> void:
	var board := CombatBoardView.new()
	board.size = Vector2(960.0, 680.0)
	var font: Font = load("res://fonts/LabyrinthCrumble-Regular.tres")
	var boss := {
		"type": "zekarion",
		"role": "enemy",
		"pos": Vector2i(4, 4),
		"footprint": Vector2i(2, 2),
		"boss_bar": true,
		"intent": {
			"name": "Tempest Breath",
			"actions": [
				{"type": "move_toward", "range": 1},
				{"type": "ranged", "damage": 8, "range": 3, "shock": 1}
			]
		}
	}
	var center := Vector2(480.0, 145.0)
	var boss_bar: Rect2 = board.call("_boss_health_bar_rect").grow(6.0)
	var compact_layout: Dictionary = board.call("_boss_intent_layout", boss, center, [boss_bar], font)
	var compact_rect: Rect2 = compact_layout.get("intent_rect", Rect2())
	board.presentation = {"show_all_enemy_intents": true}
	var expanded_layout: Dictionary = board.call("_boss_intent_layout", boss, center, [boss_bar], font)
	var expanded_rect: Rect2 = expanded_layout.get("intent_rect", Rect2())
	_assert(not expanded_rect.intersects(boss_bar, false), "Expanded boss intents should avoid the boss health bar")
	_assert(is_equal_approx(compact_rect.end.y, expanded_rect.end.y), "Compact boss intent placement should be anchored to the expanded layout")

func _test_boss_health_bar_overlays_above_board_origin() -> void:
	var board := CombatBoardView.new()
	board.size = Vector2(960.0, 680.0)
	var boss_bar: Rect2 = board.call("_boss_health_bar_rect")
	_assert(boss_bar.position.y < 0.0, "Boss health bar should overlay upward outside the board layout")
	_assert(boss_bar.end.y > 0.0, "Boss health bar should still encroach slightly into the board zone")

func _test_enemy_art_scale_preserves_center() -> void:
	var board := CombatBoardView.new()
	board.size = Vector2(960.0, 680.0)
	board.call("_load_assets")
	var center := Vector2(320.0, 240.0)
	var crawler_unit := {"type": "crawler", "pos": Vector2i(0, 0)}
	var crawler_texture: Texture2D = board.call("_texture_for_unit", crawler_unit)
	var frame_rect: Rect2 = board.call("_unit_frame_rect", center)
	var fitted_rect: Rect2 = board.call("_fitted_unit_rect", crawler_texture, frame_rect)
	var scaled_rect: Rect2 = board.call("_unit_draw_rect_for_center", crawler_unit, center)
	var crawler_scale: float = float(GameData.enemy_def("crawler").get("art_scale", 1.0))
	_assert(is_equal_approx(scaled_rect.size.x, fitted_rect.size.x * crawler_scale), "Crawler art scale should shrink the fitted sprite width")
	_assert(is_equal_approx(scaled_rect.size.y, fitted_rect.size.y * crawler_scale), "Crawler art scale should shrink the fitted sprite height")
	_assert(is_equal_approx(scaled_rect.get_center().x, fitted_rect.get_center().x), "Crawler art scaling should keep the sprite centered horizontally")
	_assert(is_equal_approx(scaled_rect.end.y, fitted_rect.end.y), "Crawler art scaling should keep the sprite feet anchored to the same bottom edge")

func _test_enemy_art_offset_shifts_sprite_vertically() -> void:
	var board := CombatBoardView.new()
	board.size = Vector2(960.0, 680.0)
	board.call("_load_assets")
	var center := Vector2(320.0, 240.0)
	var acolyte_unit := {"type": "acolyte", "pos": Vector2i(0, 0)}
	var acolyte_texture: Texture2D = board.call("_texture_for_unit", acolyte_unit)
	var frame_rect: Rect2 = board.call("_unit_frame_rect", center)
	var fitted_rect: Rect2 = board.call("_fitted_unit_rect", acolyte_texture, frame_rect)
	var scaled_rect: Rect2 = board.call("_scaled_unit_rect", fitted_rect, board.call("_unit_art_scale", acolyte_unit))
	var draw_rect: Rect2 = board.call("_unit_draw_rect_for_center", acolyte_unit, center)
	var art_offset: Vector2 = board.call("_unit_art_offset", acolyte_unit)
	_assert(is_equal_approx(draw_rect.position.x, scaled_rect.position.x + art_offset.x), "Enemy art offset should shift the sprite horizontally after fitting")
	_assert(is_equal_approx(draw_rect.position.y, scaled_rect.position.y + art_offset.y), "Enemy art offset should shift the sprite vertically after fitting")
	_assert(is_equal_approx(draw_rect.end.y, scaled_rect.end.y + art_offset.y), "Enemy art offset should move the sprite feet by the configured amount")

func _test_enemy_intent_popup_expands_for_long_titles() -> void:
	var board := CombatBoardView.new()
	var font: Font = load("res://fonts/LabyrinthCrumble-Regular.tres")
	var width: float = float(board.call("_enemy_intent_popup_width", {
		"name": "Skittering Stonebreaker Strike",
		"actions": [{"type": "melee", "damage": 4, "range": 1}]
	}, [[{"icon": "melee"}, {"icon": "damage", "value": 4}]], font))
	_assert(width > 136.0, "Long enemy intent titles should widen the popup instead of clipping")

func _test_unit_shadow_uses_alpha_silhouette() -> void:
	var board := CombatBoardView.new()
	board.size = Vector2(960.0, 680.0)
	board.call("_load_assets")
	var unit := {"type": "crawler", "pos": Vector2i(0, 0)}
	var texture: Texture2D = board.call("_texture_for_unit", unit)
	var local_polygons: Array = board.call("_unit_shadow_polygons_for_texture", texture)
	_assert(not local_polygons.is_empty(), "Unit shadows should extract alpha silhouette polygons instead of falling back to a generic ellipse")
	if local_polygons.is_empty():
		board.free()
		return
	var draw_rect: Rect2 = board.call("_unit_draw_rect_for_center", unit, Vector2(320.0, 240.0))
	var bounds: Rect2 = board.call("_unit_shadow_bounds_for_texture", texture)
	var shadow_size: Vector2 = board.call("_unit_shadow_draw_size", texture, draw_rect.size, bounds)
	var foot_point: Vector2 = board.call("_unit_shadow_foot_point", texture, draw_rect, bounds, "crawler")
	_assert(foot_point.y < draw_rect.end.y, "Unit shadow anchor should use opaque feet instead of transparent texture padding")
	var stable_ratio: float = float(board.call("_unit_shadow_stable_bottom_ratio", "crawler", texture, bounds))
	var max_idle_ratio: float = 0.0
	for frame_texture: Texture2D in board.call("_unit_idle_frames", unit):
		var frame_bounds: Rect2 = board.call("_unit_shadow_bounds_for_texture", frame_texture)
		max_idle_ratio = maxf(max_idle_ratio, float(board.call("_unit_shadow_bottom_ratio", frame_texture, frame_bounds)))
	_assert(stable_ratio < max_idle_ratio, "Unit shadow anchor should ignore occasional low-contact idle pixels instead of following every claw/limb frame")
	var projected: PackedVector2Array = board.call(
		"_project_unit_shadow_polygon",
		local_polygons[0],
		shadow_size,
		foot_point
	)
	var min_point: Vector2 = projected[0]
	var max_point: Vector2 = projected[0]
	for point: Vector2 in projected:
		min_point.x = minf(min_point.x, point.x)
		min_point.y = minf(min_point.y, point.y)
		max_point.x = maxf(max_point.x, point.x)
		max_point.y = maxf(max_point.y, point.y)
	var projected_size: Vector2 = max_point - min_point
	_assert(projected_size.x > draw_rect.size.x * 0.24, "Projected unit shadow should preserve meaningful sprite silhouette width")
	_assert(projected_size.y > draw_rect.size.y * 0.10, "Projected unit shadow should preserve meaningful sprite silhouette depth")
	_assert(min_point.y <= foot_point.y + 1.0, "Projected unit shadow should begin at the opaque feet without a visible vertical gap")
	board.free()

func _test_player_uses_original_anime_art() -> void:
	var board := CombatBoardView.new()
	board.visible = true
	board.call("_load_assets")
	board.combat_state = {
		"player": {"pos": Vector2i(3, 3), "hp": 20, "max_hp": 20}
	}
	board.presentation = {}
	var player_unit := {"key": "player", "role": "player", "type": "player", "pos": Vector2i(3, 3), "hp": 20}
	var idle_frames: Array = board.call("_unit_idle_frames", player_unit)
	var player_texture: Texture2D = board.call("_texture_for_unit", player_unit)
	_assert(idle_frames.size() == 8, "Original anime player art should still load its matching idle sheet")
	_assert(player_texture != null, "Original anime player art should load for board rendering")
	board.free()

func _test_combat_board_keeps_equipment_data_off_player_sprite() -> void:
	var board := CombatBoardView.new()
	board.visible = true
	board.call("_load_assets")
	board.set_combat_state({
		"grid": _simple_grid(),
		"player": {"pos": Vector2i(3, 3), "hp": 20, "max_hp": 20},
		"enemies": []
	}, [], [], Vector2i(-1, -1), "", "", {}, {}, {
		"equipped_equipment": {
			"weapon": "iron_cleaver",
			"offhand": "ward_kite",
			"armor": "boiled_leather",
			"boots": "dust_tabi",
			"trinket": "ember_pendant"
		}
	})
	var presentation: Dictionary = board.get("presentation")
	_assert(str((presentation.get("equipped_equipment", {}) as Dictionary).get("weapon", "")) == "iron_cleaver", "Combat board presentation may preserve equipment data for future sprite art")
	_assert(not board.has_method("_draw_player_equipment_overlays"), "Combat board should not render equipment icon overlays on the player sprite")
	board.free()

func _test_combat_board_surfaces_illusion_units() -> void:
	var board := CombatBoardView.new()
	board.visible = true
	board.call("_load_assets")
	board.combat_state = {
		"grid": _simple_grid(),
		"player": {"pos": Vector2i(2, 4), "hp": 20, "max_hp": 20},
		"illusions": [{"id": 7, "pos": Vector2i(4, 4), "hp": 3, "max_hp": 3}],
		"enemies": []
	}
	board.presentation = {}
	var illusion_unit: Dictionary = {}
	for unit_var: Variant in board.call("_visible_units"):
		if typeof(unit_var) != TYPE_DICTIONARY:
			continue
		var unit: Dictionary = unit_var
		if str(unit.get("role", "")) == "illusion":
			illusion_unit = unit
			break
	_assert(not illusion_unit.is_empty(), "Combat board should include live illusions in visible units")
	_assert(str(illusion_unit.get("key", "")) == "illusion_7", "Illusion units should use stable actor keys")
	_assert(str(illusion_unit.get("type", "")) == "player", "Illusion units should reuse protagonist art")
	_assert(int(illusion_unit.get("hp", 0)) == 3, "Illusion units should expose their health for HUD rendering")
	_assert(board.call("_texture_for_unit", illusion_unit) != null, "Illusions should resolve the player texture for drawing")
	board.free()

func _test_combat_board_surfaces_illusion_preview_units() -> void:
	var board := CombatBoardView.new()
	board.visible = true
	board.call("_load_assets")
	board.combat_state = {
		"grid": _simple_grid(),
		"player": {"pos": Vector2i(2, 4), "hp": 20, "max_hp": 20},
		"illusions": [],
		"enemies": []
	}
	board.presentation = {
		"preview_units": [{
			"key": "illusion_preview",
			"role": "illusion_preview",
			"type": "player",
			"pos": Vector2i(4, 4),
			"hp": 2,
			"max_hp": 2
		}]
	}
	var preview_unit: Dictionary = {}
	for unit_var: Variant in board.call("_visible_units"):
		if typeof(unit_var) != TYPE_DICTIONARY:
			continue
		var unit: Dictionary = unit_var
		if str(unit.get("role", "")) == "illusion_preview":
			preview_unit = unit
			break
	_assert(not preview_unit.is_empty(), "Combat board should include illusion placement previews in visible units")
	_assert(str(preview_unit.get("key", "")) == "illusion_preview", "Illusion preview units should use a stable presentation key")
	_assert(str(preview_unit.get("type", "")) == "player", "Illusion previews should reuse protagonist art")
	_assert(int(preview_unit.get("hp", 0)) == 2, "Illusion previews should carry action health for presentation metadata")
	_assert(board.call("_texture_for_unit", preview_unit) != null, "Illusion previews should resolve the player texture for drawing")
	board.free()

func _test_trial_enemy_art_uses_matching_idle_sheets() -> void:
	var board := CombatBoardView.new()
	board.visible = true
	board.call("_load_assets")
	board.presentation = {}
	for enemy_type: String in ["crawler", "acolyte", "harrier", "warden"]:
		var enemy_unit := {"key": "enemy_%s" % enemy_type, "type": enemy_type}
		var idle_frames: Array = board.call("_unit_idle_frames", enemy_unit)
		var texture: Texture2D = board.call("_texture_for_unit", enemy_unit)
		var first_frame: AtlasTexture = idle_frames[0] as AtlasTexture
		var seventh_frame: AtlasTexture = idle_frames[6] as AtlasTexture
		var eighth_frame: AtlasTexture = idle_frames[7] as AtlasTexture
		var last_frame: AtlasTexture = idle_frames[idle_frames.size() - 1] as AtlasTexture
		_assert(idle_frames.size() == 12, "%s anime trial art should skip the final source frame and ping-pong without duplicated endpoints" % enemy_type)
		_assert((idle_frames[0] as Texture2D).get_size() == Vector2(1020.0, 1020.0), "%s anime trial idle sheet should use 4x2 frames" % enemy_type)
		_assert(first_frame != null and seventh_frame != null and eighth_frame != null and last_frame != null, "%s anime trial idle frames should be atlas-backed slices" % enemy_type)
		_assert(first_frame.region.position == Vector2.ZERO, "%s anime trial idle loop should keep the source frame at the start of the sheet" % enemy_type)
		_assert(seventh_frame.region != eighth_frame.region, "%s anime trial idle loop should not hold the final frame at the turn-around" % enemy_type)
		_assert(first_frame.region != last_frame.region, "%s anime trial idle loop should not hold the first frame at the loop boundary" % enemy_type)
		_assert(is_equal_approx(float(board.call("_unit_idle_frame_seconds", enemy_unit)), 0.1), "%s anime trial idle loop should use the original frame cadence" % enemy_type)
		_assert(texture != null, "%s anime trial art should load for board rendering" % enemy_type)

func _test_zekarion_uses_matching_idle_sheet() -> void:
	var board := CombatBoardView.new()
	board.visible = true
	board.call("_load_assets")
	board.presentation = {}
	var boss_unit := {"key": "enemy_zekarion", "type": "zekarion"}
	var idle_frames: Array = board.call("_unit_idle_frames", boss_unit)
	var texture: Texture2D = board.call("_texture_for_unit", boss_unit)
	_assert(idle_frames.size() == 12, "Zekarion should load a matching 4x2 ping-pong idle sheet")
	_assert((idle_frames[0] as Texture2D).get_size() == Vector2(1020.0, 1020.0), "Zekarion idle frames should use 1020px 4x2 source cells")
	_assert(is_equal_approx(float(board.call("_unit_idle_frame_seconds", boss_unit)), 0.1), "Zekarion idle loop should use the boss frame cadence")
	_assert(texture != null, "Zekarion idle art should load for board rendering")

func _test_lightning_wisp_uses_normal_loop_idle_sheet() -> void:
	var board := CombatBoardView.new()
	board.visible = true
	board.call("_load_assets")
	board.presentation = {}
	var wisp_unit := {"key": "enemy_wisp", "type": "lightning_wisp"}
	var idle_frames: Array = board.call("_unit_idle_frames", wisp_unit)
	var texture: Texture2D = board.call("_texture_for_unit", wisp_unit)
	var first_frame: AtlasTexture = idle_frames[0] as AtlasTexture
	var last_frame: AtlasTexture = idle_frames[idle_frames.size() - 1] as AtlasTexture
	_assert(idle_frames.size() == 16, "Lightning wisp should load all 16 source frames without ping-ponging")
	_assert((idle_frames[0] as Texture2D).get_size() == Vector2(1020.0, 1020.0), "Lightning wisp idle frames should use 1020px 4x4 source cells")
	_assert(first_frame != null and last_frame != null, "Lightning wisp idle frames should be atlas-backed slices")
	_assert(first_frame.region.position == Vector2.ZERO, "Lightning wisp normal loop should start at the first source frame")
	_assert(last_frame.region.position == Vector2(3060.0, 3060.0), "Lightning wisp normal loop should include the final source frame")
	_assert(is_equal_approx(float(board.call("_unit_idle_frame_seconds", wisp_unit)), 0.15), "Lightning wisp idle loop should match the downloaded GIF cadence")
	_assert(texture != null, "Lightning wisp idle art should load for board rendering")

func _test_emaciated_man_uses_matching_idle_sheet() -> void:
	var board := CombatBoardView.new()
	board.visible = true
	board.call("_load_assets")
	board.combat_state = {
		"npcs": [{"id": "emaciated_man", "name": "Emaciated Man", "pos": Vector2i(3, 3)}]
	}
	board.presentation = {}
	var npc_unit := {"key": "npc_emaciated_man_0", "role": "npc", "type": "emaciated_man", "pos": Vector2i(3, 3)}
	var idle_frames: Array = board.call("_unit_idle_frames", npc_unit)
	var npc_texture: Texture2D = board.call("_texture_for_unit", npc_unit)
	var acolyte_texture: Texture2D = (board.get("_unit_textures") as Dictionary).get("acolyte", null)
	var first_frame: AtlasTexture = idle_frames[0] as AtlasTexture
	var seventh_frame: AtlasTexture = idle_frames[6] as AtlasTexture
	var eighth_frame: AtlasTexture = idle_frames[7] as AtlasTexture
	var last_frame: AtlasTexture = idle_frames[idle_frames.size() - 1] as AtlasTexture
	_assert(idle_frames.size() == 12, "Emaciated Man anime trial art should skip the final source frame and ping-pong without duplicated endpoints")
	_assert((idle_frames[0] as Texture2D).get_size() == Vector2(1020.0, 1020.0), "Emaciated Man anime trial idle sheet should use 4x2 frames")
	_assert(first_frame != null and seventh_frame != null and eighth_frame != null and last_frame != null, "Emaciated Man idle frames should be atlas-backed slices")
	_assert(first_frame.region.position == Vector2.ZERO, "Emaciated Man idle loop should keep the source frame at the start of the sheet")
	_assert(seventh_frame.region != eighth_frame.region, "Emaciated Man idle loop should not hold the final frame at the turn-around")
	_assert(first_frame.region != last_frame.region, "Emaciated Man idle loop should not hold the first frame at the loop boundary")
	_assert(npc_texture != null, "Emaciated Man static art should load for board rendering")
	_assert(npc_texture != acolyte_texture, "Emaciated Man should not reuse the Ash Acolyte texture")

func _test_foreground_props_fade_when_covering_behind_objects() -> void:
	var board := CombatBoardView.new()
	board.size = Vector2(960.0, 680.0)
	board.combat_state = {"grid": _simple_grid()}
	var blocker_tile := Vector2i(3, 3)
	var prop_rect: Rect2 = board.call("_prop_rect_for_tile", blocker_tile)
	var behind_unit := {"key": "behind", "type": "player", "pos": Vector2i(3, 2)}
	var foreground_tint: Color = board.call("_foreground_blocker_tint", "pillar", blocker_tile, prop_rect, [behind_unit])
	_assert(foreground_tint.a < 1.0, "Foreground pillars should become translucent when they overlap a character on a farther-back tile")
	var front_unit := {"key": "front", "type": "player", "pos": Vector2i(3, 4)}
	var clear_tint: Color = board.call("_foreground_blocker_tint", "pillar", blocker_tile, prop_rect, [front_unit])
	_assert(is_equal_approx(clear_tint.a, 1.0), "Pillars should not fade for units that will draw in front of them")
	var behind_pickup := {"tile": Vector2i(3, 2), "rect": board.call("_loot_rect_for_tile", Vector2i(3, 2), null)}
	var door_tint: Color = board.call("_foreground_blocker_tint", "door", blocker_tile, prop_rect, [behind_pickup])
	_assert(door_tint.a < 1.0, "Foreground doors should fade when covering pickups on farther-back tiles")
	var behind_trap := {"tile": Vector2i(3, 2), "rect": board.call("_trap_draw_rect", Vector2i(3, 2))}
	var terrain_tint: Color = board.call("_foreground_blocker_tint", "terrain", blocker_tile, prop_rect, [behind_trap])
	_assert(terrain_tint.a < 1.0, "Foreground destructible terrain should fade when covering traps or other tile contents")
	var sliver_rect := Rect2(prop_rect.position + Vector2(prop_rect.size.x - 3.0, prop_rect.size.y - 3.0), Vector2(20.0, 20.0))
	var sliver_entry := {"tile": Vector2i(3, 2), "rect": sliver_rect}
	var sliver_tint: Color = board.call("_foreground_blocker_tint", "pillar", blocker_tile, prop_rect, [sliver_entry])
	_assert(is_equal_approx(sliver_tint.a, 1.0), "Foreground props should stay opaque when covering less than 25% of a farther-back sprite")
	var covered_rect := Rect2(prop_rect.position + Vector2(12.0, 12.0), Vector2(24.0, 24.0))
	var covered_entry := {"tile": Vector2i(3, 2), "rect": covered_rect}
	var covered_tint: Color = board.call("_foreground_blocker_tint", "pillar", blocker_tile, prop_rect, [covered_entry])
	_assert(covered_tint.a < 1.0, "Foreground props should fade when covering at least 25% of a farther-back sprite")
	board.free()

func _test_pillar_art_fits_bottom_center_without_stretching() -> void:
	var board := CombatBoardView.new()
	board.size = Vector2(960.0, 680.0)
	board.call("_load_assets")
	var pillar_texture: Texture2D = (board.get("_prop_textures") as Dictionary).get("pillar", null)
	var frame_rect: Rect2 = board.call("_prop_rect_for_tile", Vector2i(3, 3))
	var draw_rect: Rect2 = board.call("_prop_draw_rect", pillar_texture, frame_rect)
	_assert(is_equal_approx(draw_rect.get_center().x, frame_rect.get_center().x), "Prop art should stay horizontally centered within its tile frame")
	_assert(is_equal_approx(draw_rect.end.y, frame_rect.end.y), "Prop art should stay bottom-aligned so walls and pillars feel planted on the tile")
	var source_ratio: float = pillar_texture.get_size().x / pillar_texture.get_size().y
	var draw_ratio: float = draw_rect.size.x / draw_rect.size.y
	_assert(is_equal_approx(draw_ratio, source_ratio), "Prop art should preserve its aspect ratio instead of stretching to fill the placeholder frame")
	board.free()

func _test_pillar_torch_fixtures_mount_on_both_visible_faces() -> void:
	var board := CombatBoardView.new()
	board.size = Vector2(960.0, 680.0)
	board.call("_load_assets")
	var textures: Dictionary = board.get("_prop_textures") as Dictionary
	var left_texture: Texture2D = textures.get("column_torch_left", null)
	var right_texture: Texture2D = textures.get("column_torch_right", null)
	_assert(left_texture != null, "Combat board should load the left-facing column torch fixture")
	_assert(right_texture != null, "Combat board should load the right-facing column torch fixture")
	var pillar_texture: Texture2D = textures.get("pillar", null)
	var pillar_rect: Rect2 = board.call("_prop_draw_rect", pillar_texture, board.call("_prop_rect_for_tile", Vector2i(3, 3)))
	var left_rect: Rect2 = board.call("_pillar_torch_rect", pillar_rect, left_texture, -1.0)
	var right_rect: Rect2 = board.call("_pillar_torch_rect", pillar_rect, right_texture, 1.0)
	_assert(left_rect.get_center().x < pillar_rect.get_center().x, "The left torch should mount on the screen-left visible pillar face")
	_assert(right_rect.get_center().x > pillar_rect.get_center().x, "The right torch should mount on the screen-right visible pillar face")
	_assert(left_rect.size.x >= pillar_rect.size.x * 0.28, "Column torches should be large enough to read at board scale")
	_assert(right_rect.size.x >= pillar_rect.size.x * 0.28, "Column torches should be large enough to read at board scale")
	_assert(left_rect.size.x <= pillar_rect.size.x * 0.34, "Column torches should stay compact enough to mount on the pillar shaft")
	_assert(right_rect.size.x <= pillar_rect.size.x * 0.34, "Column torches should stay compact enough to mount on the pillar shaft")
	_assert(left_rect.get_center().distance_to(right_rect.get_center()) >= pillar_rect.size.x * 0.70, "Column torches should be spread onto their respective pillar sides")
	_assert(left_rect.position.y >= pillar_rect.position.y + pillar_rect.size.y * 0.24, "Column torches should sit on the pillar shaft below the cap")
	_assert(right_rect.position.y >= pillar_rect.position.y + pillar_rect.size.y * 0.24, "Column torches should sit on the pillar shaft below the cap")
	board.free()

func _test_column_torch_idle_sheets_load_and_are_clean() -> void:
	var board := CombatBoardView.new()
	board.size = Vector2(960.0, 680.0)
	var grid: Array = _simple_grid()
	grid[3][3] = "pillar"
	board.combat_state = {
		"grid": grid,
		"player": {"pos": Vector2i(2, 2), "hp": 10, "max_hp": 10}
	}
	board.call("_load_assets")
	var idle_frames: Dictionary = board.get("_pillar_torch_idle_frames") as Dictionary
	_assert((idle_frames.get("left", []) as Array).size() == 16, "Left column torch idle sheet should load as a 4x4 animation")
	_assert((idle_frames.get("right", []) as Array).size() == 16, "Right column torch idle sheet should load as a 4x4 animation")
	_assert(bool(board.call("_pillar_torch_idle_animation_active")), "Column torch idle animation should run when a room has pillars")
	board.set("_idle_elapsed", 0.0)
	var first_left: Texture2D = board.call("_pillar_torch_texture", "left")
	board.set("_idle_elapsed", 0.12)
	var second_left: Texture2D = board.call("_pillar_torch_texture", "left")
	_assert(first_left != null and second_left != null and first_left != second_left, "Column torch texture should advance through idle frames")
	board.set("_idle_elapsed", 0.10)
	var before_torch_tick: String = str(board.call("_active_idle_frame_key"))
	board.set("_idle_elapsed", 0.12)
	var after_torch_tick: String = str(board.call("_active_idle_frame_key"))
	_assert(before_torch_tick != after_torch_tick, "Board redraw gating should notice torch frame changes even when unit frame timing does not align")
	_assert_torch_sheet_has_no_chroma_speckles("res://assets/art/tiles/column_torch_left_idle.png")
	_assert_torch_sheet_has_no_chroma_speckles("res://assets/art/tiles/column_torch_right_idle.png")
	board.free()

func _assert_torch_sheet_has_no_chroma_speckles(path: String) -> void:
	var image: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
	_assert(image != null and not image.is_empty(), "%s should expose image data for chroma validation" % path)
	if image == null or image.is_empty():
		return
	var chroma_pixels: int = 0
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			var color: Color = image.get_pixel(x, y)
			if color.a <= 0.0:
				continue
			if color.g > 0.12 and color.g > color.r * 1.12 and color.g > color.b * 1.12:
				chroma_pixels += 1
			elif color.r > 0.28 and color.b > 0.24 and color.r > color.g * 1.18 and color.b > color.g * 1.18:
				chroma_pixels += 1
	_assert(chroma_pixels == 0, "%s should not keep visible green or purple chroma-key speckles" % path)

func _test_pillar_moss_overlay_is_anchored_to_pillar_cap() -> void:
	var board := CombatBoardView.new()
	board.size = Vector2(960.0, 680.0)
	board.call("_load_assets")
	var pillar_texture: Texture2D = (board.get("_prop_textures") as Dictionary).get("pillar", null)
	var frame_rect: Rect2 = board.call("_prop_rect_for_tile", Vector2i(3, 3))
	var draw_rect: Rect2 = board.call("_prop_draw_rect", pillar_texture, frame_rect)
	var moss_rect: Rect2 = board.call("_pillar_moss_rect", draw_rect)
	_assert(moss_rect.position.y >= draw_rect.position.y + draw_rect.size.y * 0.14, "Pillar moss should sit down on the cap instead of floating above it")
	_assert(moss_rect.get_center().x <= draw_rect.get_center().x - draw_rect.size.x * 0.02, "Pillar moss should be nudged left to stay centered on the cap")
	board.free()

func _test_wall_and_pillar_assets_stay_distinct() -> void:
	var board := CombatBoardView.new()
	board.call("_load_assets")
	var textures: Dictionary = board.get("_prop_textures") as Dictionary
	var pillar_texture: Texture2D = textures.get("pillar", null)
	var wall_texture: Texture2D = textures.get("wall_row", null)
	_assert(pillar_texture != null, "Combat board should load dedicated pillar art")
	_assert(wall_texture != null, "Combat board should load dedicated wall art")
	if pillar_texture == null or wall_texture == null:
		board.free()
		return
	var pillar_ratio: float = pillar_texture.get_size().x / maxf(1.0, pillar_texture.get_size().y)
	var wall_ratio: float = wall_texture.get_size().x / maxf(1.0, wall_texture.get_size().y)
	_assert(pillar_texture.get_size().x >= wall_texture.get_size().x * 1.5, "Pillar art should stay materially broader than wall segments so support columns cannot silently reuse wall art")
	_assert(pillar_ratio >= wall_ratio + 0.15, "Pillar art should keep a distinctly squarer silhouette than wall segments so a wall/pillar asset swap is caught early")
	board.free()

func _test_boundary_prop_art_uses_single_tile_footprint() -> void:
	var board := CombatBoardView.new()
	board.size = Vector2(960.0, 680.0)
	board.call("_load_assets")
	var textures: Dictionary = board.get("_prop_textures") as Dictionary
	var frame_rect: Rect2 = board.call("_prop_rect_for_tile", Vector2i(3, 0))
	var door_frame_rect: Rect2 = board.call("_door_rect_for_tile", Vector2i(3, 0))
	var tile_width: float = board.call("_tile_width")
	var wall_draw_rect: Rect2 = board.call("_prop_draw_rect", textures.get("wall_row", null), frame_rect)
	var door_draw_rect: Rect2 = board.call("_prop_draw_rect", textures.get("door", null), door_frame_rect)
	_assert(is_equal_approx(wall_draw_rect.get_center().x, frame_rect.get_center().x), "Boundary walls should stay centered within their tile frame")
	_assert(is_equal_approx(wall_draw_rect.end.y, frame_rect.end.y), "Boundary walls should stay planted on the same base line after fitting")
	_assert(wall_draw_rect.size.x <= tile_width * 0.66, "Boundary wall art should fit a single wall tile span instead of reading like a multi-tile module")
	_assert(door_draw_rect.size.x <= door_frame_rect.size.x, "Standalone door art should fit inside its dedicated door frame instead of spilling beyond it")
	_assert(is_equal_approx(door_draw_rect.end.y, door_frame_rect.end.y), "Standalone door art should stay planted on its dedicated floor line after fitting")
	board.free()

func _test_boundary_wall_segments_use_full_spans_on_straight_edges() -> void:
	var board := CombatBoardView.new()
	board.size = Vector2(960.0, 680.0)
	board.call("_load_assets")
	var grid: Array = _simple_grid()
	var top_wall := Vector2i(3, 0)
	var left_wall := Vector2i(0, 3)
	var textures: Dictionary = board.get("_prop_textures") as Dictionary
	var top_segments: Array = board.call("_boundary_prop_segments", "wall", grid, top_wall)
	var left_segments: Array = board.call("_boundary_prop_segments", "wall", grid, left_wall)
	_assert(top_segments.size() == 1, "Straight top-edge walls should render as a single full-span segment")
	_assert(left_segments.size() == 1, "Straight side-edge walls should render as a single full-span segment")
	var top_segment: Dictionary = _find_boundary_segment(top_segments, "row")
	var left_segment: Dictionary = _find_boundary_segment(left_segments, "col")
	_assert(str(top_segment.get("half", "")) == "full", "Straight top-edge walls should use the full row segment")
	_assert(str(left_segment.get("half", "")) == "full", "Straight side-edge walls should use the full column segment")
	var top_frame: Rect2 = board.call("_prop_rect_for_tile", top_wall)
	var left_frame: Rect2 = board.call("_prop_rect_for_tile", left_wall)
	var full_row_rect: Rect2 = board.call("_prop_draw_rect", textures.get("wall_row", null), top_frame)
	var full_col_rect: Rect2 = board.call("_prop_draw_rect", textures.get("wall_col", null), left_frame)
	var top_draw_rect: Rect2 = top_segment.get("draw_rect", Rect2())
	var left_draw_rect: Rect2 = left_segment.get("draw_rect", Rect2())
	_assert(is_equal_approx(top_draw_rect.position.x, full_row_rect.position.x) and is_equal_approx(top_draw_rect.size.x, full_row_rect.size.x), "Straight top-edge walls should keep the full row-span footprint")
	_assert(is_equal_approx(left_draw_rect.position.x, full_col_rect.position.x) and is_equal_approx(left_draw_rect.size.x, full_col_rect.size.x), "Straight side-edge walls should keep the full column-span footprint")
	board.free()

func _test_boundary_wall_corner_tiles_split_into_two_half_segments() -> void:
	var board := CombatBoardView.new()
	board.size = Vector2(960.0, 680.0)
	board.call("_load_assets")
	var grid: Array = _simple_grid()
	var textures: Dictionary = board.get("_prop_textures") as Dictionary
	var expectations: Array[Dictionary] = [
		{"tile": Vector2i(0, 0), "row_half": "right", "col_half": "left"},
		{"tile": Vector2i(7, 0), "row_half": "left", "col_half": "left"},
		{"tile": Vector2i(0, 7), "row_half": "right", "col_half": "right"},
		{"tile": Vector2i(7, 7), "row_half": "left", "col_half": "right"}
	]
	for entry: Dictionary in expectations:
		var tile: Vector2i = entry.get("tile", Vector2i.ZERO)
		var segments: Array = board.call("_boundary_prop_segments", "wall", grid, tile)
		_assert(segments.size() == 2, "Corner wall tiles should split into two half segments so both perimeter runs meet in the tile center")
		var row_segment: Dictionary = _find_boundary_segment(segments, "row")
		var col_segment: Dictionary = _find_boundary_segment(segments, "col")
		_assert(str(row_segment.get("half", "")) == str(entry.get("row_half", "")), "Corner row segments should use the inward-facing half of the wall span")
		_assert(str(col_segment.get("half", "")) == str(entry.get("col_half", "")), "Corner column segments should use the inward-facing half of the wall span")
		var frame_rect: Rect2 = board.call("_prop_rect_for_tile", tile)
		var full_row_rect: Rect2 = board.call("_prop_draw_rect", textures.get("wall_row", null), frame_rect)
		var full_col_rect: Rect2 = board.call("_prop_draw_rect", textures.get("wall_col", null), frame_rect)
		var row_draw_rect: Rect2 = row_segment.get("draw_rect", Rect2())
		var col_draw_rect: Rect2 = col_segment.get("draw_rect", Rect2())
		_assert(is_equal_approx(row_draw_rect.size.x, full_row_rect.size.x * 0.5), "Corner row segments should be cut to half-width so they terminate at the tile center")
		_assert(is_equal_approx(col_draw_rect.size.x, full_col_rect.size.x * 0.5), "Corner column segments should be cut to half-width so they terminate at the tile center")
	board.free()

func _test_door_art_uses_source_and_flipped_variant() -> void:
	var board := CombatBoardView.new()
	board.size = Vector2(960.0, 680.0)
	board.call("_load_assets")
	var textures: Dictionary = board.get("_prop_textures") as Dictionary
	_assert(textures.get("door", null) != null, "Combat board should load the standalone door art")
	_assert(textures.get("door_row", null) == textures.get("door", null), "Bottom-left/top-right doors should use the supplied source orientation directly")
	_assert(textures.get("door_col", null) != null, "Combat board should build a flipped door texture for the opposite diagonal")
	_assert(textures.get("door_col", null) != textures.get("door", null), "Bottom-right/top-left doors should use a flipped variant instead of the identical source sprite")
	_assert(board.call("_floor_texture_key", "door") == "ash", "Door tiles should render on top of the regular ash floor texture")
	board.free()

func _test_standalone_door_art_stays_within_single_tile_footprint() -> void:
	var board := CombatBoardView.new()
	board.size = Vector2(960.0, 680.0)
	board.call("_load_assets")
	var grid: Array = _simple_grid()
	var textures: Dictionary = board.get("_prop_textures") as Dictionary
	var door_texture: Texture2D = textures.get("door", null)
	var tile := Vector2i(4, 0)
	var door_frame: Rect2 = board.call("_door_rect_for_tile", tile, grid)
	var door_rect: Rect2 = board.call("_prop_draw_rect", door_texture, door_frame)
	var door_offset: Vector2 = board.call("_door_back_edge_offset_for_tile", tile, grid)
	_assert(door_rect.size.x <= door_frame.size.x, "Standalone door art should stay inside its dedicated door frame instead of spilling beyond it")
	_assert(is_equal_approx(door_rect.get_center().x, board.call("_tile_center", tile).x + door_offset.x), "Standalone door art should stay centered on its back-edge door frame")
	board.free()

func _test_visible_doors_use_dedicated_frame() -> void:
	var board := CombatBoardView.new()
	board.size = Vector2(960.0, 680.0)
	var grid: Array = _simple_grid()
	var tile := Vector2i(4, 0)
	var wall_frame: Rect2 = board.call("_prop_rect_for_tile", tile)
	var door_frame: Rect2 = board.call("_door_rect_for_tile", tile, grid)
	var door_offset: Vector2 = board.call("_door_back_edge_offset_for_tile", tile, grid)
	_assert(door_frame.size.x > wall_frame.size.x, "Standalone door art should use its own enlarged frame instead of inheriting wall architecture sizing")
	_assert(door_frame.size.y > wall_frame.size.y, "Standalone door art should use its own enlarged frame instead of inheriting wall architecture sizing")
	_assert(is_equal_approx(door_frame.get_center().x, wall_frame.get_center().x + door_offset.x), "Standalone door art should use the opening tile's mirrored back-edge offset")
	_assert(door_frame.end.y >= wall_frame.end.y - 10.0, "Standalone door art should stay planted near the same floor line as the surrounding architecture")
	board.free()

func _test_door_frames_slide_toward_each_back_edge() -> void:
	var board := CombatBoardView.new()
	board.size = Vector2(960.0, 680.0)
	var grid: Array = _simple_grid()
	var offsets: Dictionary = {
		"top_right": board.call("_door_back_edge_offset_for_tile", Vector2i(4, 0), grid),
		"bottom_right": board.call("_door_back_edge_offset_for_tile", Vector2i(7, 4), grid),
		"bottom_left": board.call("_door_back_edge_offset_for_tile", Vector2i(4, 7), grid),
		"top_left": board.call("_door_back_edge_offset_for_tile", Vector2i(0, 4), grid)
	}
	var top_right: Vector2 = offsets.get("top_right", Vector2.ZERO)
	var bottom_right: Vector2 = offsets.get("bottom_right", Vector2.ZERO)
	var bottom_left: Vector2 = offsets.get("bottom_left", Vector2.ZERO)
	var top_left: Vector2 = offsets.get("top_left", Vector2.ZERO)
	_assert(top_right.x > 0.0 and top_right.y < 0.0, "Top-right doors should slide up-right toward their back edge")
	_assert(bottom_right.x > 0.0 and bottom_right.y > 0.0, "Bottom-right doors should slide down-right toward their back edge")
	_assert(bottom_left.x < 0.0 and bottom_left.y > 0.0, "Bottom-left doors should slide down-left toward their back edge")
	_assert(top_left.x < 0.0 and top_left.y < 0.0, "Top-left doors should slide up-left toward their back edge")
	_assert(is_equal_approx(absf(top_right.x), absf(top_left.x)), "Top door back-edge offsets should share the same horizontal magnitude")
	_assert(is_equal_approx(absf(top_right.y), absf(top_left.y)), "Top door back-edge offsets should share the same vertical magnitude")
	_assert(is_equal_approx(absf(bottom_right.x), absf(bottom_left.x)), "Bottom door back-edge offsets should share the same horizontal magnitude")
	_assert(is_equal_approx(absf(bottom_right.y), absf(bottom_left.y)), "Bottom door back-edge offsets should share the same vertical magnitude")
	_assert(absf(top_right.x) < absf(bottom_right.x), "Top doors should use a slightly smaller back-edge offset than bottom doors")
	_assert(absf(top_right.y) < absf(bottom_right.y), "Top doors should use a slightly smaller back-edge offset than bottom doors")
	board.free()

func _test_door_opening_sheet_loads_as_directional_frames() -> void:
	var board := CombatBoardView.new()
	board.size = Vector2(960.0, 680.0)
	board.call("_load_assets")
	var frames: Array = board.get("_door_opening_frames") as Array
	var flipped_frames: Array = board.get("_door_opening_flipped_frames") as Array
	_assert(frames.size() == 8, "Door opening sheet should load as eight animation frames")
	_assert(flipped_frames.size() == frames.size(), "Door opening animation should build flipped frames for side-edge doors")
	var canvas_size: Vector2i = board.call("_door_opening_frame_canvas_size")
	_assert(canvas_size == Vector2i(256, 383), "Door opening frames should share the max source-frame canvas size")
	var first_frame: Texture2D = frames[0] if not frames.is_empty() else null
	var final_frame: Texture2D = frames[frames.size() - 1] if not frames.is_empty() else null
	_assert(first_frame != null and first_frame.get_size() == Vector2(canvas_size), "Door opening frame textures should all use the shared canvas")
	_assert(final_frame != null and final_frame.get_size() == Vector2(canvas_size), "Final door opening frame should stay on the shared canvas")
	var first_used_rect: Rect2i = board.call("_texture_used_rect", first_frame)
	var final_used_rect: Rect2i = board.call("_texture_used_rect", final_frame)
	_assert(first_used_rect.position == Vector2i(20, 2) and first_used_rect.size == Vector2i(236, 381), "First door opening sprite should keep its real source bounds inside the shared canvas")
	_assert(final_used_rect.position == Vector2i(4, 4) and final_used_rect.size == Vector2i(252, 379), "Final door opening sprite should stay bottom-right anchored inside the shared canvas")
	var grid: Array = _simple_grid()
	var row_tile := Vector2i(4, 0)
	var col_tile := Vector2i(7, 4)
	grid[row_tile.y][row_tile.x] = "door"
	grid[col_tile.y][col_tile.x] = "door"
	board.set_combat_state({"grid": grid}, [], [], Vector2i(-1, -1), "", "", {}, {}, {"door_opening": {"tile": row_tile, "progress": 0.0}})
	var first_source_frame: Texture2D = frames[0] if not frames.is_empty() else null
	_assert(board.call("_door_opening_texture_for_tile", grid, row_tile) == first_source_frame, "Top/bottom door openings should use the source orientation frame")
	board.set_combat_state({"grid": grid}, [], [], Vector2i(-1, -1), "", "", {}, {}, {"door_opening": {"tile": col_tile, "progress": 1.0}})
	var final_flipped_frame: Texture2D = flipped_frames[flipped_frames.size() - 1] if not flipped_frames.is_empty() else null
	_assert(board.call("_door_opening_texture_for_tile", grid, col_tile) == final_flipped_frame, "Side door openings should use the flipped final frame")
	var textures: Dictionary = board.get("_prop_textures") as Dictionary
	var row_static_texture: Texture2D = textures.get("door_row", null)
	var row_static_draw_rect: Rect2 = board.call("_prop_draw_rect", row_static_texture, board.call("_door_rect_for_tile", row_tile, grid))
	var row_static_used_rect: Rect2 = board.call("_texture_used_draw_rect", row_static_texture, row_static_draw_rect)
	var row_opening_draw_rect: Rect2 = board.call("_door_opening_draw_rect", first_source_frame, row_static_texture, row_static_draw_rect, false)
	_assert(is_equal_approx(row_opening_draw_rect.end.x, row_static_used_rect.end.x), "Source door opening frames should keep their stone edge anchored to the static door's right edge")
	_assert(is_equal_approx(row_opening_draw_rect.end.y, row_static_used_rect.end.y), "Door opening frames should stay planted on the static door baseline")
	var row_final_opening_draw_rect: Rect2 = board.call("_door_opening_draw_rect", final_frame, row_static_texture, row_static_draw_rect, false)
	_assert(row_final_opening_draw_rect.is_equal_approx(row_opening_draw_rect), "Source door opening frames should render into one stable draw rect across the animation")
	var row_opening_used_rect: Rect2 = board.call("_texture_used_draw_rect", first_source_frame, row_opening_draw_rect)
	_assert(is_equal_approx(row_opening_used_rect.position.y, row_static_used_rect.position.y), "First opening frame should match the static door visible top edge")
	_assert(is_equal_approx(row_opening_used_rect.end.y, row_static_used_rect.end.y), "First opening frame should match the static door visible bottom edge")
	var col_static_texture: Texture2D = textures.get("door_col", null)
	var col_static_draw_rect: Rect2 = board.call("_prop_draw_rect", col_static_texture, board.call("_door_rect_for_tile", col_tile, grid))
	var col_static_used_rect: Rect2 = board.call("_texture_used_draw_rect", col_static_texture, col_static_draw_rect)
	var col_opening_draw_rect: Rect2 = board.call("_door_opening_draw_rect", final_flipped_frame, col_static_texture, col_static_draw_rect, true)
	_assert(is_equal_approx(col_opening_draw_rect.position.x, col_static_used_rect.position.x), "Flipped door opening frames should keep their stone edge anchored to the static door's left edge")
	_assert(is_equal_approx(col_opening_draw_rect.end.y, col_static_used_rect.end.y), "Flipped door opening frames should stay planted on the static door baseline")
	board.free()

func _test_combat_board_hides_outer_walls_without_hiding_visible_doors() -> void:
	var board := CombatBoardView.new()
	var grid: Array = _simple_grid()
	var wall_tile := Vector2i(0, 3)
	grid[0][4] = "door"
	var door_tile := Vector2i(4, 0)
	board.set_combat_state({"grid": grid}, [], [], Vector2i(-1, -1), "", "", {}, {}, {})
	_assert(board.call("_display_tile_id", "door", door_tile) == "wall", "Inactive perimeter doors should fall back to wall semantics")
	var hidden_tiles: Array = board.call("_tiles_in_draw_order", grid)
	_assert(not hidden_tiles.has(wall_tile), "Boundary wall tiles should drop out of the draw order while outer wall visuals are disabled")
	_assert(not hidden_tiles.has(door_tile), "Inactive perimeter doors should also disappear once they resolve back to boundary walls")
	board.set_combat_state({"grid": grid}, [], [], Vector2i(-1, -1), "", "", {}, {}, {"active_door_tiles": {door_tile: true}})
	_assert(board.call("_display_tile_id", "door", door_tile) == "door", "Active connected doors should render as doors again")
	var active_tiles: Array = board.call("_tiles_in_draw_order", grid)
	_assert(active_tiles.has(door_tile), "Active connected doors should stay in draw order so they remain clickable")
	board.set_combat_state({"grid": grid}, [], [], Vector2i(-1, -1), "", "", {door_tile: "N"}, {}, {})
	_assert(board.call("_display_tile_id", "door", door_tile) == "door", "Usable exits should stay visually present even while the outer wall toggle is off")
	var exit_tiles: Array = board.call("_tiles_in_draw_order", grid)
	_assert(exit_tiles.has(door_tile), "Usable exits should remain in draw order so the player can click them")
	board.set_combat_state({"grid": grid}, [], [], Vector2i(-1, -1), "", "", {door_tile: "N"}, {}, {"pulse_exit_tiles": true})
	_assert(bool(board.call("_presentation_needs_continuous_redraw")), "Pulsing exit doors should keep the board redraw loop active")
	board.set_combat_state({"grid": grid}, [], [], Vector2i(-1, -1), "", "", {}, {}, {"locked_door_tiles": {door_tile: true}})
	_assert(board.call("_display_tile_id", "door", door_tile) == "door", "Locked traversal doors should still render as doors for presentation")
	var locked_tiles: Array = board.call("_tiles_in_draw_order", grid)
	_assert(locked_tiles.has(door_tile), "Locked traversal doors should stay in draw order while visible")
	board.free()

func _test_combat_board_assigns_deterministic_floor_variants() -> void:
	var board := CombatBoardView.new()
	board.call("_load_assets")
	var floor_variants: Dictionary = board.get("_floor_texture_variants")
	var ash_variants: Array = floor_variants.get("ash", [])
	_assert(ash_variants.size() == 7, "Combat board should load all seven extracted stone floor variants")
	var state := {"grid": _simple_grid(), "room_coord": Vector2i(2, 1)}
	board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, {})
	var first_lookup: Dictionary = (board.get("_floor_variant_by_tile") as Dictionary).duplicate(true)
	var distinct: Dictionary = {}
	for y: int in range(1, 7):
		for x: int in range(1, 7):
			distinct[int(first_lookup.get(Vector2i(x, y), -1))] = true
	_assert(distinct.size() >= 4, "Interior ash floors should spread across several stone variants instead of collapsing to one look")
	var center_tile := Vector2i(4, 4)
	_assert(int(first_lookup.get(center_tile, -1)) != int(first_lookup.get(Vector2i(3, 4), -1)), "Variant assignment should avoid immediate left-right repeats on ash floors when possible")
	_assert(int(first_lookup.get(center_tile, -1)) != int(first_lookup.get(Vector2i(4, 3), -1)), "Variant assignment should avoid immediate front-back repeats on ash floors when possible")
	board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, {})
	var repeated_lookup: Dictionary = board.get("_floor_variant_by_tile")
	_assert(repeated_lookup.get(center_tile, -1) == first_lookup.get(center_tile, -2), "Floor variants should stay deterministic for the same room coordinate")
	board.set_combat_state({"grid": _simple_grid(), "room_coord": Vector2i(5, 1)}, [], [], Vector2i(-1, -1), "", "", {}, {}, {})
	var shifted_lookup: Dictionary = board.get("_floor_variant_by_tile")
	_assert(
		shifted_lookup.get(center_tile, -1) != first_lookup.get(center_tile, -1)
		or shifted_lookup.get(Vector2i(5, 4), -1) != first_lookup.get(Vector2i(5, 4), -1),
		"Different room coordinates should reshuffle the deterministic floor-variant mix"
	)
	board.free()

func _test_combat_board_ambient_particles_follow_room_element() -> void:
	var board := CombatBoardView.new()
	board.call("_load_assets")
	var neutral_state := {"grid": _simple_grid(), "room_coord": Vector2i(2, 1), "room_element": "none"}
	board.set_combat_state(neutral_state, [], [], Vector2i(-1, -1), "", "", {}, {}, {})
	_assert(not bool(board.call("_ambient_particles_active")), "Neutral rooms should not render elemental ambient particles")
	_assert(not bool(board.call("_presentation_needs_continuous_redraw")), "Neutral rooms with no active presentation should not request continuous redraw")
	var fire_state := {"grid": _simple_grid(), "room_coord": Vector2i(2, 1), "room_element": "fire"}
	board.set_combat_state(fire_state, [], [], Vector2i(-1, -1), "", "", {}, {}, {})
	_assert(bool(board.call("_ambient_particles_active")), "Elemental rooms should activate ambient particles")
	_assert(bool(board.call("_presentation_needs_continuous_redraw")), "Ambient particles should drive a lightweight redraw loop")
	_assert(board.call("_ambient_particle_texture", "fire", 0) != null, "Elemental ambient particles should use the generated raster atlas")
	_assert(board.call("_ambient_fire_soft_texture", 0) != null, "Fire ambient particles should use a softened mote atlas to avoid flat sprite rendering")
	var air_state := {"grid": _simple_grid(), "room_coord": Vector2i(2, 1), "room_element": "air"}
	board.set_combat_state(air_state, [], [], Vector2i(-1, -1), "", "", {}, {}, {})
	var air_wisp_variant: int = int(board.call("_ambient_air_wisp_variant_index", 1200))
	_assert(air_wisp_variant in [1, 3], "Air wind wisps should use directional full-body variants")
	_assert(board.call("_ambient_air_wisp_texture", air_wisp_variant, 16) != null, "Air ambient particles should use a full-body wisp frame instead of path-reveal frames")
	_assert(board.call("_ambient_air_wisp_soft_texture", air_wisp_variant) != null, "Air wind wisps should have a softened body atlas")
	_assert(board.call("_ambient_air_wisp_glow_texture", air_wisp_variant, 16) != null, "Air wind wisps should have matching glow frames")
	var wind_direction: float = float(board.call("_ambient_air_wind_direction"))
	_assert(is_equal_approx(absf(wind_direction), 1.0), "Air wind wisps should share a deterministic left/right wind direction")
	var first_seed: int = int(board.call("_ambient_room_seed", "fire"))
	board.set_combat_state(fire_state, [], [], Vector2i(-1, -1), "", "", {}, {}, {})
	_assert(int(board.call("_ambient_room_seed", "fire")) == first_seed, "Ambient particle seeds should stay stable for the same room coordinate and element")
	board.set_combat_state({"grid": _simple_grid(), "room_coord": Vector2i(3, 1), "room_element": "fire"}, [], [], Vector2i(-1, -1), "", "", {}, {}, {})
	_assert(int(board.call("_ambient_room_seed", "fire")) != first_seed, "Ambient particle seeds should vary across rooms")
	_assert(int(board.call("_ambient_particle_count", "ice", 72)) > int(board.call("_ambient_particle_count", "earth", 72)), "Snow rooms should carry more particles than heavier earth motes")
	_assert(int(board.call("_ambient_particle_count", "lightning", 72)) < int(board.call("_ambient_particle_count", "fire", 72)), "Lightning rooms should stay sparser than fire after density tuning")
	board.free()

func _test_combat_board_draw_order_tracks_moving_unit_world_position() -> void:
	var board := CombatBoardView.new()
	board.combat_state = {"grid": _simple_grid()}
	var from_tile := Vector2i(2, 2)
	var to_tile := Vector2i(4, 4)
	board.presentation = {
		"unit_world_positions": {
			"enemy_1": board.world_position_for_tile(to_tile)
		},
		"unit_draw_tiles": {
			"enemy_1": to_tile
		}
	}
	var draw_tile: Vector2i = board.call("_effective_unit_tile", {"key": "enemy_1", "pos": from_tile})
	_assert(draw_tile == to_tile, "Moving units should use their presentation draw tile for stable layering during motion")
	var boss_unit := {"key": "enemy_2", "pos": from_tile, "footprint": Vector2i(2, 2)}
	var boss_draw_tile: Vector2i = board.draw_tile_for_unit_origin(boss_unit, to_tile)
	var boss_center: Vector2 = board.world_position_for_unit_origin(boss_unit, to_tile)
	var expected_boss_center: Vector2 = (
		board.world_position_for_tile(to_tile)
		+ board.world_position_for_tile(to_tile + Vector2i(1, 0))
		+ board.world_position_for_tile(to_tile + Vector2i(0, 1))
		+ board.world_position_for_tile(to_tile + Vector2i(1, 1))
	) / 4.0
	_assert(boss_draw_tile == to_tile + Vector2i(1, 1), "Large moving units should draw on the destination footprint's front tile")
	_assert(boss_center.distance_to(expected_boss_center) <= 0.001, "Large moving units should animate from their footprint center, not their anchor tile")
	board.free()

func _test_keyword_icon_library_surfaces_tooltips() -> void:
	var row: Array = ActionIcons.tokens_for_action({"type": "ranged", "damage": 4, "range": 4, "poison": 2})
	_assert(row.size() == 3, "Ranged actions should tokenize into action, range, and status icons")
	_assert(str((row[0] as Dictionary).get("icon", "")) == "ranged", "Ranged action tokens should use the bow icon")
	_assert(str((row[1] as Dictionary).get("icon", "")) == "range", "Ranged action tokens should include the shared range icon")
	_assert(str((row[2] as Dictionary).get("icon", "")) == "poison", "Status keywords should use their shared icon token")
	var immobilize_row: Array = ActionIcons.tokens_for_action({"type": "ranged", "damage": 3, "range": 5, "immobilize": true})
	_assert(str((immobilize_row[2] as Dictionary).get("icon", "")) == "immobilize", "Immobilize should use its shared status icon token")
	_assert(ActionIcons.tooltip("immobilize").contains("movement"), "Immobilize tooltip should explain the movement lock")
	var shove_row: Array = ActionIcons.tokens_for_action({"type": "ranged", "damage": 4, "range": 4, "poison": 2, "push": 1})
	_assert(str((shove_row[shove_row.size() - 1] as Dictionary).get("icon", "")) == "push", "Push riders should render after hit, range, and status tokens")
	var direct_push_row: Array = ActionIcons.tokens_for_action({"type": "push", "damage": 5, "range": 4, "amount": 2})
	_assert(str((direct_push_row[0] as Dictionary).get("icon", "")) == "melee", "Push action rows should show the hit before forced movement")
	_assert(str((direct_push_row[direct_push_row.size() - 1] as Dictionary).get("icon", "")) == "push", "Push action rows should end with forced movement")
	var direct_pull_row: Array = ActionIcons.tokens_for_action({"type": "pull", "damage": 5, "range": 4, "amount": 2})
	_assert(str((direct_pull_row[0] as Dictionary).get("icon", "")) == "melee", "Pull action rows should show the hit before forced movement")
	_assert(str((direct_pull_row[direct_pull_row.size() - 1] as Dictionary).get("icon", "")) == "pull", "Pull action rows should end with forced movement")
	var pierce_row: Array = ActionIcons.tokens_for_action({"type": "ranged", "damage": 6, "range": 5, "pierce": true})
	_assert(pierce_row.size() == 2, "Pierce should replace the ranged damage icon instead of adding another keyword token")
	_assert(str((pierce_row[0] as Dictionary).get("icon", "")) == "pierce", "Pierce attacks should use the pierce damage icon")
	_assert(ActionIcons.tooltip("pierce").contains("block"), "Pierce tooltip should explain defense bypass")
	var blood_row: Array = ActionIcons.tokens_for_action({"type": "melee", "damage": 3, "range": 1, "bleed": 2, "expose": 4, "sunder": 3})
	_assert(str((blood_row[1] as Dictionary).get("icon", "")) == "bleed", "Bleed should render as an attack keyword token")
	_assert(str((blood_row[2] as Dictionary).get("icon", "")) == "expose", "Expose should render as an attack keyword token")
	_assert(str((blood_row[3] as Dictionary).get("icon", "")) == "sunder", "Sunder should render as an attack keyword token")
	_assert(ActionIcons.tooltip("bleed").contains("Physical damage"), "Bleed tooltip should explain the physical tick")
	_assert(ActionIcons.tooltip("expose").contains("next hit"), "Expose tooltip should explain the follow-up damage")
	_assert(ActionIcons.tooltip("sunder").contains("stoneskin"), "Sunder tooltip should explain defense breaking")
	var aoe_row: Array = ActionIcons.tokens_for_action({"type": "aoe", "damage": 5, "range": 0, "pattern": [[0, -1], [1, 0], [0, 1], [-1, 0]]})
	_assert(str((aoe_row[1] as Dictionary).get("kind", "")) == "aoe_pattern", "AOE actions should surface a tile pattern token")
	_assert(bool((aoe_row[1] as Dictionary).get("show_origin", false)), "Close AOE pattern tokens should include the player origin tile")
	_assert(ActionIcons.tooltip("poison").contains("Delayed damage"), "Keyword icon tooltips should include readable descriptions")
	var card_play_row: Array = ActionIcons.tokens_for_action({"type": "card_play", "amount": 1})
	_assert(str((card_play_row[0] as Dictionary).get("icon", "")) == "card_play", "Card-play actions should use the play-meter icon")
	_assert(ActionIcons.tooltip("card_play").contains("card plays"), "Card-play tooltip should explain the temporary play bonus")
	var illusion_row: Array = ActionIcons.tokens_for_action({"type": "illusion", "health": 4, "range": 3})
	_assert(str((illusion_row[0] as Dictionary).get("icon", "")) == "illusion", "Illusion actions should use the illusion icon")
	_assert(str((illusion_row[1] as Dictionary).get("icon", "")) == "range", "Illusion actions should show placement range")
	_assert(ActionIcons.tooltip("illusion").contains("stationary copy"), "Illusion tooltip should explain the decoy")
	var cost_rows: Array = ActionIcons.cost_rows_for_card(GameData.card_def("gate_gambit"))
	_assert(cost_rows.size() == 1, "Card costs should render as one leading action row")
	var cost_row: Array = cost_rows[0] as Array
	_assert(str((cost_row[0] as Dictionary).get("icon", "")) == "exhaust", "Exhausting cards should use the exhaust cost icon")
	_assert(str((cost_row[1] as Dictionary).get("icon", "")) == "health_cost", "Health costs should use the health-cost token")
	_assert(not ActionIcons.tooltip("burn").contains("card"), "Burn status tooltip should not describe card exhaust costs")
	_assert(ActionIcons.tooltip("exhaust").contains("Removes this card"), "Exhaust cost tooltip should describe card removal")
	var tooltip_panel: PanelContainer = UiTooltipPanel.make_text(ActionIcons.tooltip("poison"))
	_assert(tooltip_panel.get_child_count() == 1, "Keyword tooltip text should render as a custom panel instead of the default engine tooltip")
	tooltip_panel.free()

func _test_room_icon_library_covers_door_room_types() -> void:
	var room_cases: Array[Dictionary] = [
		{"room": {"type": "combat", "element": "fire"}, "icon": "fire"},
		{"room": {"type": "combat", "element": "none"}, "icon": "combat"},
		{"room": {"type": "campfire", "element": "none"}, "icon": "campfire"},
		{"room": {"type": "treasure", "element": "none"}, "icon": "treasure"},
		{"room": {"type": "boss", "element": "none"}, "icon": "boss"}
	]
	for room_case: Dictionary in room_cases:
		var icon_id: String = RoomIcons.icon_id_for_room(room_case.get("room", {}))
		_assert(icon_id == str(room_case.get("icon", "")), "Door icon ids should distinguish elemental combat and non-combat room destinations")
		_assert(not RoomIcons.icon_path(icon_id).is_empty(), "Every door icon id should resolve to a texture path")
		_assert(RoomIcons.icon_texture(icon_id) != null, "Every door icon id should load a texture")

func _test_minimap_uses_door_icons_and_greys_cleared_rooms() -> void:
	var map_view := LabyrinthMapView.new()
	var combat_icon: Texture2D = map_view.call("_room_icon_texture_for_room", {"type": "combat", "element": "fire"})
	var campfire_icon: Texture2D = map_view.call("_room_icon_texture_for_room", {"type": "campfire", "element": "none"})
	_assert(combat_icon != null, "Minimap combat rooms should use the same elemental door icon textures")
	_assert(campfire_icon != null, "Minimap non-combat rooms should use the same door icon textures")
	var uncleared: Color = map_view.call("_room_fill_color", {"type": "combat", "element": "fire", "cleared": false})
	var cleared: Color = map_view.call("_room_fill_color", {"type": "combat", "element": "fire", "cleared": true})
	var grey := Color("6f6a63")
	var uncleared_distance: float = absf(uncleared.r - grey.r) + absf(uncleared.g - grey.g) + absf(uncleared.b - grey.b)
	var cleared_distance: float = absf(cleared.r - grey.r) + absf(cleared.g - grey.g) + absf(cleared.b - grey.b)
	_assert(cleared_distance < uncleared_distance, "Cleared minimap rooms should read as muted grey instead of using a large X mark")
	map_view.set("interactive", false)
	map_view.set_run_state({
		"mode": "room",
		"current_room": Vector2i.ZERO,
		"rooms": {
			"0,0": {"coord": Vector2i.ZERO, "type": "start", "revealed": true, "cleared": true}
		}
	})
	map_view.size = Vector2(220.0, 188.0)
	_assert(float(map_view.call("_base_node_size")) >= 14.0, "Compact minimap icons should keep a legible minimum node size")
	map_view.set_run_state({
		"mode": "room",
		"current_room": Vector2i.ZERO,
		"rooms": {
			"0,0": {
				"coord": Vector2i.ZERO,
				"type": "start",
				"revealed": true,
				"cleared": true,
				"connections": [{"coord": Vector2i(1, 0)}]
			},
			"1,0": {
				"coord": Vector2i(1, 0),
				"type": "combat",
				"element": "fire",
				"revealed": true,
				"cleared": false,
				"connections": [{"coord": Vector2i.ZERO}]
			}
		}
	})
	var node_size: float = float(map_view.call("_base_node_size"))
	var left_position: Vector2 = map_view.call("_coord_position", Vector2i.ZERO)
	var right_position: Vector2 = map_view.call("_coord_position", Vector2i(1, 0))
	var compact_spacing: float = float(map_view.call("_grid_spacing"))
	_assert(left_position.x - node_size * 0.5 >= 6.0, "Compact minimap rooms should keep visible horizontal padding inside the frame")
	_assert(right_position.x + node_size * 0.5 <= map_view.size.x - 6.0, "Compact minimap rooms should keep visible horizontal padding inside the frame")
	_assert(is_equal_approx(absf(right_position.x - left_position.x), compact_spacing), "Compact minimap adjacent rooms should use the same spacing that connectors draw across")
	map_view.set("interactive", true)
	map_view.set("show_legend", true)
	map_view.size = Vector2(920.0, 580.0)
	var full_left_position: Vector2 = map_view.call("_coord_position", Vector2i.ZERO)
	var full_right_position: Vector2 = map_view.call("_coord_position", Vector2i(1, 0))
	var full_spacing: float = float(map_view.call("_grid_spacing"))
	_assert(full_spacing <= 132.0 and full_spacing >= compact_spacing * 3.0, "Full map should use a generous fixed grid without stretching sparse rooms to the frame edges")
	_assert(float(map_view.call("_base_node_size")) >= 56.0, "Full map nodes should read as deliberate large-map controls instead of compact minimap icons")
	_assert(is_equal_approx(absf(full_right_position.x - full_left_position.x), full_spacing), "Full map adjacent rooms should stay evenly spaced on the same grid")
	_assert(absf(full_right_position.x - full_left_position.x) < map_view.size.x * 0.25, "Full map should allow dead space instead of stretching early rooms apart")
	var map_rect: Rect2 = map_view.call("_map_rect")
	var legend_rect: Rect2 = map_view.call("_legend_rect")
	_assert(map_rect.end.x + 1.0 <= legend_rect.position.x, "Full map legend should reserve space instead of covering map rooms")
	_assert(legend_rect.size.y < map_view.size.y * 0.70, "Full map legend should only be as tall as its entries need")
	var labels: Dictionary = {}
	for entry_var: Variant in map_view.call("_legend_entries"):
		var entry: Dictionary = entry_var
		labels[str(entry.get("label", ""))] = true
	for expected_label: String in ["Fire", "Ice", "Lightning", "Air", "Earth", "Campfire", "Relic", "Boss"]:
		_assert(labels.has(expected_label), "Full map legend should include %s" % expected_label)
	_assert(not labels.has("Fight"), "Full map legend should not invent a generic Fight room icon")
	var marker_rooms: Dictionary = {
		"0,0": {
			"coord": Vector2i.ZERO,
			"type": "start",
			"revealed": true,
			"cleared": true
		},
		"3,0": {
			"coord": Vector2i(3, 0),
			"type": "combat",
			"element": "fire",
			"revealed": false,
			"cleared": false,
			"recovery_marker": true,
			"recovery_amount": 23
		}
	}
	map_view.set("interactive", false)
	map_view.set_run_state({"mode": "room", "current_room": Vector2i.ZERO, "rooms": marker_rooms})
	_assert(not _map_visible_coords(map_view).has(Vector2i(3, 0)), "Compact minimap should not reveal distant dropped embers")
	map_view.set("interactive", true)
	_assert(_map_visible_coords(map_view).has(Vector2i(3, 0)), "Full map should show the dropped ember room at its exact coordinate")
	map_view.free()

func _test_combat_board_loads_door_icons_for_room_types() -> void:
	var board := CombatBoardView.new()
	board.call("_load_assets")
	var textures: Dictionary = board.get("_door_icon_textures") as Dictionary
	for icon_id: String in ["fire", "combat", "campfire", "treasure", "boss"]:
		_assert(textures.get(icon_id, null) != null, "Combat board should load door icons for elemental and non-combat destinations")
	board.free()

func _map_visible_coords(map_view: LabyrinthMapView) -> Array[Vector2i]:
	var coords: Array[Vector2i] = []
	for room_var: Variant in map_view.call("_visible_rooms"):
		if typeof(room_var) != TYPE_DICTIONARY:
			continue
		coords.append((room_var as Dictionary).get("coord", Vector2i.ZERO))
	return coords

func _test_run_map_room_types() -> void:
	var run_engine: RunEngine = RunEngine.new()
	var progression: Dictionary = ProgressionStore.prepare_for_new_run(ProgressionStore.default_data())
	var run_state: Dictionary = run_engine.create_new_run(13, progression)
	_assert(str(run_engine.room_metadata(run_state, Vector2i.ZERO).get("type", "")) == "start", "Origin should be the start room")
	_assert(str(run_engine.room_metadata(run_state, Vector2i(2, 0)).get("type", "")) == "campfire", "Axis depth-2 rooms should be campfire rooms")
	_assert(str(run_engine.room_metadata(run_state, Vector2i(4, 0)).get("type", "")) == "boss", "Depth-four rooms should punctuate the first sequence with boss territory")
	_assert(str(run_engine.room_metadata(run_state, Vector2i(6, 0)).get("type", "")) == "campfire", "Axis depth-6 rooms should repeat the campfire beat in the second sequence")
	_assert(str(run_engine.room_metadata(run_state, Vector2i(8, 0)).get("type", "")) == "boss", "Depth-eight rooms should be the temporary final boss territory")

func _test_run_map_relic_room_spacing_and_density() -> void:
	var run_engine: RunEngine = RunEngine.new()
	var total_non_boss_rooms: int = 0
	var total_relic_rooms: int = 0
	var first_signature: String = ""
	var found_different_signature: bool = false
	for seed: int in range(1, 41):
		var run_state: Dictionary = run_engine.create_new_run(seed, ProgressionStore.default_data())
		var signature_parts: Array[String] = []
		for exit_coord: Vector2i in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
			_assert(str(run_engine.room_metadata(run_state, exit_coord).get("type", "")) != "treasure", "Relic rooms should never be direct exits from the start")
		for x: int in range(-RunEngine.MAX_DEPTH, RunEngine.MAX_DEPTH + 1):
			for y: int in range(-RunEngine.MAX_DEPTH, RunEngine.MAX_DEPTH + 1):
				var coord := Vector2i(x, y)
				if maxi(absi(coord.x), absi(coord.y)) > RunEngine.MAX_DEPTH:
					continue
				var room: Dictionary = run_engine.room_metadata(run_state, coord)
				var room_type: String = str(room.get("type", "combat"))
				if room_type != "boss":
					total_non_boss_rooms += 1
				if room_type != "treasure":
					continue
				total_relic_rooms += 1
				signature_parts.append("%d,%d" % [coord.x, coord.y])
				for dir: Vector2i in PathUtils.DIRS_4:
					var neighbor: Vector2i = coord + dir
					if maxi(absi(neighbor.x), absi(neighbor.y)) > RunEngine.MAX_DEPTH:
						continue
					_assert(str(run_engine.room_metadata(run_state, neighbor).get("type", "")) != "treasure", "Relic rooms should not be cardinally adjacent")
		signature_parts.sort()
		var signature: String = "|".join(signature_parts)
		if seed == 1:
			first_signature = signature
		elif signature != first_signature:
			found_different_signature = true
	var density: float = float(total_relic_rooms) / float(maxi(1, total_non_boss_rooms))
	_assert(density > 0.20 and density < 0.30, "Relic rooms should average roughly one quarter of non-boss rooms")
	_assert(found_different_signature, "Relic room placement should vary probabilistically by seed")

func _test_run_map_repeats_depth_sequences() -> void:
	var run_engine: RunEngine = RunEngine.new()
	var run_state: Dictionary = run_engine.create_new_run(13, ProgressionStore.default_data())
	var depth_four_room: Dictionary = run_engine.room_metadata(run_state, Vector2i(4, 0))
	var has_depth_five_exit: bool = false
	for connection_var: Variant in depth_four_room.get("connections", []):
		var connection: Dictionary = connection_var
		var target: Vector2i = connection.get("coord", Vector2i.ZERO)
		if int(run_engine.room_metadata(run_state, target).get("depth", 0)) == 5:
			has_depth_five_exit = true
			break
	_assert(has_depth_five_exit, "Intermediate boss rooms should open directly into the next depth sequence")
	_assert(str(run_engine.room_metadata(run_state, Vector2i(5, 0)).get("type", "")) != "boss", "Depth five should restart regular room generation instead of remaining boss territory")

func _test_run_map_ring_links_and_outward_quarter() -> void:
	var run_engine: RunEngine = RunEngine.new()
	var run_state: Dictionary = run_engine.create_new_run(13, ProgressionStore.default_data())
	for depth: int in [1, 2, 3, 5, 6, 7]:
		var outward_rooms: int = 0
		var total_rooms: int = 0
		for x: int in range(-depth, depth + 1):
			for y: int in range(-depth, depth + 1):
				var coord := Vector2i(x, y)
				if maxi(absi(coord.x), absi(coord.y)) != depth:
					continue
				total_rooms += 1
				var room: Dictionary = run_engine.room_metadata(run_state, coord)
				var same_depth_links: int = 0
				var outward_links: int = 0
				for connection_var: Variant in room.get("connections", []):
					var connection: Dictionary = connection_var
					var target: Vector2i = connection.get("coord", Vector2i.ZERO)
					_assert(PathUtils.manhattan(coord, target) == 1, "All map links should use literal cardinal adjacency")
					var target_depth: int = maxi(absi(target.x), absi(target.y))
					if target_depth == depth:
						same_depth_links += 1
					elif target_depth == depth + 1:
						outward_links += 1
				_assert(total_rooms <= depth * 8, "Square-ring depth %d should never exceed 8*d rooms" % depth)
				_assert(same_depth_links == 2, "Depth-%d rooms should always link to one room on either side of the ring" % depth)
				if outward_links > 0:
					outward_rooms += 1
		_assert(total_rooms == depth * 8, "Depth-%d should contain exactly %d rooms in the square ring" % [depth, depth * 8])
		_assert(outward_rooms == int(total_rooms / 4), "Exactly one quarter of depth-%d rooms should open to depth %d" % [depth, depth + 1])

func _test_run_map_seals_departed_rooms() -> void:
	var run_engine: RunEngine = RunEngine.new()
	var run_state: Dictionary = run_engine.create_new_run(13, ProgressionStore.default_data())
	run_state = run_engine.move_to_room(run_state, Vector2i(1, 0))
	if str(run_state.get("mode", "")) == "combat":
		var combat_state: Dictionary = run_state.get("combat_state", {}).duplicate(true)
		for enemy_index: int in range((combat_state.get("enemies", []) as Array).size()):
			var enemy: Dictionary = (combat_state.get("enemies", []) as Array)[enemy_index]
			enemy["hp"] = 0
			(combat_state.get("enemies", []) as Array)[enemy_index] = enemy
		run_state = run_engine.finish_combat(run_state, combat_state)
		run_state = run_engine.skip_reward_for_heal(run_state)
	_assert(bool(run_engine.room_metadata(run_state, Vector2i.ZERO).get("sealed", false)), "Leaving the waypoint should seal it forever")
	_assert(not run_engine.available_moves(run_state).has(Vector2i.ZERO), "Backtracking into a sealed room should be impossible")
	var side_destination := Vector2i(999, 999)
	for coord: Vector2i in run_engine.available_moves(run_state):
		if int(run_engine.room_metadata(run_state, coord).get("depth", 0)) == 1:
			side_destination = coord
			break
	_assert(side_destination.x < 900, "Depth-1 rooms should still expose a side route around the ring")
	run_state = run_engine.move_to_room(run_state, side_destination)
	_assert(bool(run_engine.room_metadata(run_state, Vector2i(1, 0)).get("sealed", false)), "Once you leave a ring room it should stay sealed")
	_assert(not run_engine.available_moves(run_state).has(Vector2i(1, 0)), "The room you just left should never remain traversable")

func _test_run_map_never_moves_back_toward_center() -> void:
	var run_engine: RunEngine = RunEngine.new()
	var run_state: Dictionary = run_engine.create_new_run(13, ProgressionStore.default_data())
	run_state = run_engine.move_to_room(run_state, Vector2i(1, 0))
	run_state = run_engine.move_to_room(run_state, Vector2i(2, 0))
	var current_depth: int = int(run_engine.room_metadata(run_state, run_state.get("current_room", Vector2i.ZERO)).get("depth", 0))
	for coord: Vector2i in run_engine.available_moves(run_state):
		_assert(int(run_engine.room_metadata(run_state, coord).get("depth", 0)) >= current_depth, "Available exits should never move back toward easier central rooms")

func _test_run_map_last_loop_room_opens_outward() -> void:
	var run_engine: RunEngine = RunEngine.new()
	var run_state: Dictionary = run_engine.create_new_run(13, ProgressionStore.default_data())
	var current := Vector2i(2, -1)
	var outward := Vector2i(3, -1)
	var rooms: Dictionary = {}
	var current_room: Dictionary = run_engine.room_metadata(run_state, current).duplicate(true)
	current_room["revealed"] = true
	current_room["visited"] = true
	current_room["cleared"] = true
	current_room["sealed"] = false
	rooms["%d,%d" % [current.x, current.y]] = current_room
	var sealed_coords: Array[Vector2i] = []
	sealed_coords.append(Vector2i(2, -2))
	sealed_coords.append(Vector2i(2, 0))
	for sealed_coord: Vector2i in sealed_coords:
		var sealed_room: Dictionary = run_engine.room_metadata(run_state, sealed_coord).duplicate(true)
		sealed_room["revealed"] = true
		sealed_room["visited"] = true
		sealed_room["cleared"] = true
		sealed_room["sealed"] = true
		rooms["%d,%d" % [sealed_coord.x, sealed_coord.y]] = sealed_room
	run_state["current_room"] = current
	run_state["mode"] = "room"
	run_state["rooms"] = rooms
	run_state["current_room_layout"] = run_engine.call("_display_layout_for_room", int(run_state.get("seed", 0)), current_room, Vector2i.ZERO)
	_assert(run_engine.available_moves(run_state).is_empty(), "Regression fixture should strand the loop-closing room before repair")
	run_state = run_engine.repair_loaded_run_state(run_state)
	_assert(run_engine.available_moves(run_state).has(outward), "A loop-closing room with no remaining progressive exits should open an outward escape")
	var repaired_room: Dictionary = run_engine.room_metadata(run_state, current)
	var found_loop_escape: bool = false
	for connection_var: Variant in repaired_room.get("connections", []):
		if typeof(connection_var) != TYPE_DICTIONARY:
			continue
		var connection: Dictionary = connection_var
		if connection.get("coord", Vector2i.ZERO) == outward and bool(connection.get("loop_escape", false)):
			found_loop_escape = true
			break
	_assert(found_loop_escape, "The emergency outward connection should be persisted on the current room")
	var layout: Dictionary = run_state.get("current_room_layout", {})
	var grid: Array = layout.get("grid", [])
	var door_tile: Vector2i = RoomGenerator.door_tile_for_direction(Vector2i(1, 0))
	_assert(not grid.is_empty() and str((grid[door_tile.y] as Array)[door_tile.x]) == "door", "The loop escape should stamp an outward door into the visible room layout")

func _test_empty_treasure_room_falls_back_to_room_mode() -> void:
	var run_engine: RunEngine = RunEngine.new()
	var base_state: Dictionary = run_engine.create_new_run(13, ProgressionStore.default_data())
	base_state["relics"] = GameData.relic_ids().duplicate()
	var treasure_coord := Vector2i(999, 999)
	var source_coord := Vector2i(999, 999)
	for x: int in range(-3, 4):
		for y: int in range(-3, 4):
			var candidate := Vector2i(x, y)
			if candidate == Vector2i.ZERO:
				continue
			if str(run_engine.room_metadata(base_state, candidate).get("type", "")) != "treasure":
				continue
			for sx: int in range(-3, 4):
				for sy: int in range(-3, 4):
					var source := Vector2i(sx, sy)
					var source_room: Dictionary = run_engine.room_metadata(base_state, source)
					for connection_var: Variant in source_room.get("connections", []):
						var connection: Dictionary = connection_var
						if connection.get("coord", Vector2i(999, 999)) != candidate:
							continue
						if int(source_room.get("depth", 0)) > int(run_engine.room_metadata(base_state, candidate).get("depth", 0)):
							continue
						treasure_coord = candidate
						source_coord = source
						break
					if treasure_coord.x < 900:
						break
				if treasure_coord.x < 900:
					break
			if treasure_coord.x < 900:
				break
		if treasure_coord.x < 900:
			break
	_assert(treasure_coord.x < 900 and source_coord.x < 900, "A deterministic seed should expose a connected treasure room for regression coverage")
	var rooms: Dictionary = {}
	var source_room: Dictionary = run_engine.room_metadata(base_state, source_coord)
	source_room["revealed"] = true
	source_room["visited"] = true
	source_room["sealed"] = false
	rooms["%d,%d" % [source_coord.x, source_coord.y]] = source_room
	var treasure_room: Dictionary = run_engine.room_metadata(base_state, treasure_coord)
	treasure_room["revealed"] = true
	rooms["%d,%d" % [treasure_coord.x, treasure_coord.y]] = treasure_room
	base_state["rooms"] = rooms
	base_state["current_room"] = source_coord
	base_state = run_engine.move_to_room(base_state, treasure_coord)
	_assert(str(base_state.get("mode", "")) == "room", "Treasure rooms with no relic choices should fall back to normal room mode")
	_assert((base_state.get("pending_relics", []) as Array).is_empty(), "Empty treasure rooms should not leave stale relic choices behind")
	_assert(not run_engine.available_moves(base_state).is_empty(), "Entering a treasure room should still reveal at least one onward exit")

func _test_run_engine_campfire_linger_heals_and_continues() -> void:
	var run_engine: RunEngine = RunEngine.new()
	var run_state: Dictionary = run_engine.create_new_run(13, ProgressionStore.default_data())
	run_state["mode"] = "campfire"
	run_state["player_hp"] = 19
	run_state["player_max_hp"] = 24
	var healed_state: Dictionary = run_engine.leave_campfire(run_state, 10)
	_assert(str(healed_state.get("mode", "")) == "room", "Lingering at a fire should continue onward")
	_assert(int(healed_state.get("player_hp", 0)) == 24, "Lingering at a fire should heal without exceeding max HP")
	run_state["player_hp"] = 12
	healed_state = run_engine.leave_campfire(run_state, 10)
	_assert(int(healed_state.get("player_hp", 0)) == 22, "Lingering at a fire should heal the configured amount below max HP")

func _test_loaded_run_repairs_stranded_room_visibility() -> void:
	var run_engine: RunEngine = RunEngine.new()
	var run_state: Dictionary = {
		"seed": 13,
		"mode": "room",
		"current_room": Vector2i(-1, 2),
		"rooms": {
			"-1,2": {
				"coord": Vector2i(-1, 2),
				"depth": 2,
				"type": "treasure",
				"element": "none",
				"connections": [
					{"coord": Vector2i(0, 2), "door_dir": Vector2i(1, 0), "kind": "lateral"},
					{"coord": Vector2i(-2, 2), "door_dir": Vector2i(-1, 0), "kind": "lateral"}
				],
				"revealed": true,
				"visited": true,
				"cleared": true,
				"sealed": false,
				"npcs": []
			},
			"-2,2": {
				"coord": Vector2i(-2, 2),
				"depth": 2,
				"type": "combat",
				"element": "air",
				"connections": [
					{"coord": Vector2i(-1, 2), "door_dir": Vector2i(1, 0), "kind": "lateral"},
					{"coord": Vector2i(-2, 1), "door_dir": Vector2i(0, -1), "kind": "lateral"},
					{"coord": Vector2i(-3, 2), "door_dir": Vector2i(-1, 0), "kind": "outward"}
				],
				"revealed": true,
				"visited": true,
				"cleared": true,
				"sealed": true,
				"npcs": []
			}
		}
	}
	_assert(run_engine.available_moves(run_state).is_empty(), "Regression fixture should reproduce the stranded-room save state")
	run_state = run_engine.repair_loaded_run_state(run_state)
	_assert(run_engine.available_moves(run_state).has(Vector2i(0, 2)), "Loading a stranded room should restore its missing revealed exit")

func _test_combat_finish_generates_reward_state() -> void:
	var run_engine: RunEngine = RunEngine.new()
	var run_state: Dictionary = run_engine.create_new_run(29, ProgressionStore.default_data())
	var combat_destination: Vector2i = Vector2i.ZERO
	for candidate: Vector2i in run_engine.available_moves(run_state):
		if str(run_engine.room_metadata(run_state, candidate).get("type", "")) == "combat":
			combat_destination = candidate
			break
	_assert(combat_destination != Vector2i.ZERO, "The opening ring should include at least one combat room")
	run_state = run_engine.move_to_room(run_state, combat_destination)
	_assert(str(run_state.get("mode", "")) == "combat", "Entering an uncleared combat room should start combat")
	_assert(run_engine.available_moves(run_state).is_empty(), "Uncleared combat rooms should not reveal or expose adjacent exits on the minimap")
	var combat_state: Dictionary = run_state.get("combat_state", {}).duplicate(true)
	for enemy_index: int in range((combat_state.get("enemies", []) as Array).size()):
		var enemy: Dictionary = (combat_state.get("enemies", []) as Array)[enemy_index]
		enemy["hp"] = 0
		(combat_state.get("enemies", []) as Array)[enemy_index] = enemy
	combat_state["room_embers"] = 12
	run_state = run_engine.finish_combat(run_state, combat_state)
	_assert(str(run_state.get("mode", "")) == "reward", "Winning a non-boss combat should transition to the reward state")
	_assert(run_engine.held_embers(run_state) >= 12, "Combat victory should award held embers to the run")
	_assert((run_state.get("pending_reward", {}) as Dictionary).get("cards", []).size() == 3, "Combat rewards should offer three card choices")
	_assert(not run_engine.available_moves(run_state).is_empty(), "Cleared combat rooms should reveal adjacent exits once the fight ends")

func _test_intermediate_boss_opens_next_sequence() -> void:
	var run_engine: RunEngine = RunEngine.new()
	var run_state: Dictionary = run_engine.create_new_run(29, ProgressionStore.default_data())
	var boss_coord := Vector2i(4, 0)
	run_state["current_room"] = boss_coord
	var rooms: Dictionary = run_state.get("rooms", {}).duplicate(true)
	var boss_room: Dictionary = run_engine.room_metadata(run_state, boss_coord)
	boss_room["revealed"] = true
	boss_room["visited"] = true
	boss_room["cleared"] = false
	rooms["4,0"] = boss_room
	run_state["rooms"] = rooms
	run_state["player_hp"] = 9
	run_state["player_max_hp"] = 36
	var combat_state: Dictionary = _defeated_zekarion_combat_state(4, boss_coord)
	run_state = run_engine.finish_combat(run_state, combat_state)
	_assert(str(run_state.get("mode", "")) == "room", "Defeating a non-final sequence boss should return to room mode")
	_assert(not bool(run_state.get("victory", false)), "The first sequence boss should not end the expanded run")
	_assert(int(run_state.get("player_hp", 0)) == int(run_state.get("player_max_hp", 0)), "Defeating an intermediate boss should restore the player to full health")
	var has_next_sequence_move: bool = false
	var exposes_lateral_boss_move: bool = false
	for coord: Vector2i in run_engine.available_moves(run_state):
		var depth: int = int(run_engine.room_metadata(run_state, coord).get("depth", 0))
		if depth == 5:
			has_next_sequence_move = true
		elif depth == 4:
			exposes_lateral_boss_move = true
	_assert(has_next_sequence_move, "Clearing the first boss should reveal a route into depth five")
	_assert(not exposes_lateral_boss_move, "Clearing an intermediate boss should push the route outward instead of farming sideways boss gates")

func _test_boss_victory_restores_player_health() -> void:
	var run_engine: RunEngine = RunEngine.new()
	var run_state: Dictionary = run_engine.create_new_run(29, ProgressionStore.default_data())
	run_state["current_room"] = Vector2i(8, 0)
	var rooms: Dictionary = run_state.get("rooms", {}).duplicate(true)
	var final_boss_room: Dictionary = run_engine.room_metadata(run_state, Vector2i(8, 0))
	final_boss_room["revealed"] = true
	final_boss_room["visited"] = true
	final_boss_room["cleared"] = false
	rooms["8,0"] = final_boss_room
	run_state["rooms"] = rooms
	run_state["player_hp"] = 9
	run_state["player_max_hp"] = 36
	var combat_state: Dictionary = _defeated_zekarion_combat_state(8, Vector2i(8, 0))
	run_state = run_engine.finish_combat(run_state, combat_state)
	_assert(str(run_state.get("mode", "")) == "victory", "Defeating the final placeholder Zekarion should end the run in victory")
	_assert(int(run_state.get("player_hp", 0)) == int(run_state.get("player_max_hp", 0)), "Defeating the final placeholder Zekarion should restore the player to full health")

func _test_progression_save_and_purchase(default_progression: Dictionary) -> void:
	var data: Dictionary = ProgressionStore.add_embers(default_progression, 180)
	_assert(ProgressionStore.save_data(data), "Progression save should succeed")
	var loaded: Dictionary = ProgressionStore.load_data()
	_assert(int(loaded.get("embers", 0)) == 180, "Saved progression embers should reload as held embers")
	_assert(int(loaded.get("level", 0)) == 1, "Progression should start at level one")
	_assert(ProgressionStore.next_level_cost(loaded) == 180, "The first level-up cost should require a meaningful run")
	_assert(not ProgressionStore.can_purchase_level_with_stats(loaded, ["might"]), "Level-up purchases should require two stat picks")
	_assert(not ProgressionStore.can_purchase_level_with_stats(loaded, ["might", "might"]), "Level-up stat picks should be different stats")
	loaded = ProgressionStore.purchase_level_with_stats(loaded, ["might", "dexterity"])
	_assert(int(loaded.get("level", 0)) == 2, "Buying a level should permanently raise character level")
	_assert(int(loaded.get("embers", 0)) == 0, "Buying a level should spend held embers")
	_assert(GameData.stat_value(loaded, "might") == 1, "Buying a level should allocate the first chosen stat point")
	_assert(GameData.stat_value(loaded, "dexterity") == 1, "Buying a level should allocate the second chosen stat point")
	_assert(int(loaded.get("unspent_stat_points", 0)) == 0, "A normal level-up should assign both stat points immediately")
	var upgraded_card: Dictionary = GameData.card_def_for_progression("quick_stab", loaded)
	var upgraded_action: Dictionary = (upgraded_card.get("actions", []) as Array)[0]
	_assert(int(upgraded_action.get("damage", 0)) == 92, "Might should increment melee cards on top of fixed-point base damage")
	loaded = ProgressionStore.set_embers(loaded, 42)
	var combat: CombatEngine = CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(9, _simple_room_layout(), {
		"hp": 120,
		"max_hp": 200,
		"deck_cards": ["quick_stab"],
		"stats": loaded.get("stats", {}),
		"level": loaded.get("level", 1),
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	_assert(int(((combat.card_def("quick_stab", combat_state).get("actions", []) as Array)[0] as Dictionary).get("damage", 0)) == 92, "Combat should resolve progression stats from the combat snapshot")
	var run_engine: RunEngine = RunEngine.new()
	var run_state: Dictionary = run_engine.create_new_run(9, loaded)
	_assert(run_engine.held_embers(run_state) == 42, "New runs should carry the current held ember count")

func _test_emaciated_man_does_not_unlock_card_upgrade_dialogue() -> void:
	var dialogue_engine: DialogueEngine = DialogueEngine.new()
	var room: Dictionary = {
		"coord": Vector2i.ZERO,
		"npcs": [{"id": "emaciated_man"}]
	}
	var progression: Dictionary = ProgressionStore.mark_rested_at_fire(ProgressionStore.default_data())
	var dialogue: Dictionary = dialogue_engine.build_room_dialogue(room, {}, progression)
	var lines: Array = dialogue.get("lines", [])
	_assert(lines.size() == 3, "Resting at a fire should no longer unlock a card-upgrade dialogue branch")
	_assert(not bool(dialogue.get("marks_fire_rest_seen", false)), "Fire rests should not create a one-time card-upgrade dialogue marker")
	var options: Array = (lines[lines.size() - 1] as Dictionary).get("options", [])
	_assert(options.is_empty(), "The Emaciated Man should no longer offer permanent card upgrade options")
	progression = ProgressionStore.mark_fire_rest_dialogue_seen(progression)
	dialogue = dialogue_engine.build_room_dialogue(room, {}, progression)
	lines = dialogue.get("lines", [])
	_assert(lines.size() == 3, "Legacy fire-rest markers should still return to the default Emaciated Man dialogue")
	_assert(str((lines[0] as Dictionary).get("text", "")) == "Hehehe. You're back...so soon.", "Runs should still use the default start-room dialogue text")
	options = (lines[lines.size() - 1] as Dictionary).get("options", [])
	_assert(options.is_empty(), "Legacy unlocked progression should not keep the old touch option alive")

func _test_recovery_marker_flow() -> void:
	var run_engine: RunEngine = RunEngine.new()
	var progression: Dictionary = ProgressionStore.prepare_for_new_run(ProgressionStore.default_data())
	var planning_state: Dictionary = run_engine.create_new_run(51, ProgressionStore.default_data())
	var recovery_coord := Vector2i.ZERO
	for x: int in range(-2, 3):
		for y: int in range(-2, 3):
			var candidate := Vector2i(x, y)
			if candidate == Vector2i.ZERO:
				continue
			if int(run_engine.room_metadata(planning_state, candidate).get("depth", 0)) != 2:
				continue
			if _find_route_to_coord(run_engine, planning_state, candidate).is_empty():
				continue
			recovery_coord = candidate
			break
		if recovery_coord != Vector2i.ZERO:
			break
	_assert(recovery_coord != Vector2i.ZERO, "The map should expose at least one reachable depth-2 room for recovery coverage")
	progression = ProgressionStore.record_lost_embers(progression, 23, recovery_coord, int(progression.get("run_counter", 0)))
	progression = ProgressionStore.prepare_for_new_run(progression)
	var run_state: Dictionary = run_engine.create_new_run(51, progression)
	_assert(int(run_state.get("run_index", 0)) == 2, "Run index should advance when a new run begins")
	var recovery_key: String = "%d,%d" % [recovery_coord.x, recovery_coord.y]
	var staged_room: Dictionary = (run_state.get("rooms", {}) as Dictionary).get(recovery_key, {})
	_assert(bool(staged_room.get("recovery_marker", false)), "The next run should stage the dropped ember room on the map")
	_assert(int(staged_room.get("recovery_amount", 0)) == 23, "The staged dropped ember room should remember the recoverable amount")
	_assert(str(staged_room.get("type", "")) == "combat", "Dropped ember rooms should become combat rooms when they are not boss gates")
	var route: Array = _find_route_to_coord(run_engine, run_state, recovery_coord)
	_assert(not route.is_empty(), "Recovery markers should still be reachable on the next run")
	for route_index: int in range(route.size()):
		var step: Vector2i = route[route_index]
		if route_index == route.size() - 1:
			run_state = run_engine.move_to_room(run_state, step)
		else:
			run_state = _route_state_after_step(run_engine, run_state, step)
	_assert(str(run_state.get("mode", "")) == "combat", "Reaching dropped embers should start the recovery combat")
	_assert(run_engine.held_embers(run_state) == 0, "Entering the recovery room should not auto-restore dropped embers")
	var combat_state: Dictionary = run_state.get("combat_state", {})
	var dropped_loot: Dictionary = _first_loot_of_kind(combat_state, "dropped_embers")
	_assert(not dropped_loot.is_empty(), "Recovery combat should place a dropped ember pile")
	_assert(int(dropped_loot.get("amount", 0)) == 23, "The dropped ember pile should carry the lost amount")
	var combat_engine: CombatEngine = CombatEngine.new()
	combat_state = combat_engine.apply_player_action(combat_state, {"type": "blink", "range": 99}, dropped_loot.get("pos", Vector2i.ZERO))
	run_state = run_engine.set_combat_state(run_state, combat_state)
	_assert(run_engine.held_embers(run_state) == 23, "Reaching the recovery room on the next run should restore lost embers")
	_assert(str(run_state.get("notice", "")).contains("Recovered"), "Recovery should leave a short room notice")
	_assert(ProgressionStore.recovery_marker(run_state.get("progression", {})).is_empty(), "Recovering lost embers should clear the marker")
	_assert(not bool(run_engine.room_metadata(run_state, recovery_coord).get("recovery_marker", false)), "The map marker should clear after pickup")

func _test_recovery_marker_expires_after_next_run() -> void:
	var progression: Dictionary = ProgressionStore.prepare_for_new_run(ProgressionStore.default_data())
	progression = ProgressionStore.record_lost_embers(progression, 14, Vector2i(1, 1), int(progression.get("run_counter", 0)))
	progression = ProgressionStore.prepare_for_new_run(progression)
	_assert(not ProgressionStore.recovery_marker(progression).is_empty(), "The recovery marker should stay active for the immediate next run")
	progression = ProgressionStore.prepare_for_new_run(progression)
	_assert(ProgressionStore.recovery_marker(progression).is_empty(), "Recovery markers should expire after that next run passes")

func _test_run_state_save_and_load() -> void:
	var run_engine: RunEngine = RunEngine.new()
	var progression: Dictionary = ProgressionStore.prepare_for_new_run(ProgressionStore.default_data())
	var run_state: Dictionary = run_engine.create_new_run(41, progression)
	_assert(int(run_state.get("hand_size", 0)) == 5, "New runs should start with a five-card hand")
	_assert(ProgressionStore.save_run_state(run_state), "Run save should succeed")
	var loaded: Dictionary = ProgressionStore.load_saved_run()
	_assert(loaded.get("current_room", Vector2i(99, 99)) == Vector2i.ZERO, "Saved runs should preserve the current room")
	_assert(int(loaded.get("hand_size", 0)) == 5, "Saved runs should preserve the base hand size")
	ProgressionStore.clear_saved_run()
	_assert(not ProgressionStore.has_saved_run(), "Clearing the saved run should remove the save slot")

func _test_default_theme_uses_pixel_font() -> void:
	var theme: Theme = load("res://themes/default_theme.tres")
	_assert(theme != null, "The project should ship a default UI theme")
	if theme == null:
		return
	var probe := Control.new()
	probe.theme = theme
	root.add_child(probe)
	var font: Font = probe.get_theme_default_font()
	_assert(font != null, "The default theme should expose a default font")
	if font != null:
		_assert(font.resource_path.ends_with("LabyrinthCrumble-Regular.tres"), "The default theme should use the custom crumbly pixel font")
	probe.queue_free()

func _test_main_scenes_instantiate() -> void:
	var main_menu_scene: PackedScene = load("res://scenes/main_menu.tscn")
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	_assert(main_menu_scene != null, "Main menu scene should load")
	_assert(run_scene != null, "Run scene should load")
	if main_menu_scene == null or run_scene == null:
		return
	var main_menu_instance: Node = main_menu_scene.instantiate()
	root.add_child(main_menu_instance)
	await process_frame
	main_menu_instance.queue_free()
	await process_frame
	var run_scene_instance: Node = run_scene.instantiate()
	root.add_child(run_scene_instance)
	await process_frame
	run_scene_instance.queue_free()
	await process_frame

func _test_run_scene_minimap_click_opens_large_map() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for minimap click coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var mini_map_overlay: Control = instance.get_node("Backdrop/Margin/MainVBox/StageRoot/MiniMapOverlay") as Control
	var mini_map: Control = instance.get_node("Backdrop/Margin/MainVBox/StageRoot/MiniMapOverlay/MiniMapMargin/MiniMap") as Control
	_assert(mini_map_overlay.mouse_filter == Control.MOUSE_FILTER_STOP, "Minimap overlay should receive clicks")
	_assert(mini_map.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Embedded minimap should not consume clicks before the overlay can open the large map")
	instance.call("_close_dialogue")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	instance.call("_on_mini_map_overlay_gui_input", click)
	await process_frame
	var large_map_scrim: ColorRect = instance.get("_large_map_scrim") as ColorRect
	_assert(large_map_scrim != null and large_map_scrim.visible, "Clicking the minimap should open the large map overlay")
	if large_map_scrim != null:
		_assert(large_map_scrim.color.a >= 0.99, "Large map backdrop should hide underlying room header text")
	var large_map_view: Control = instance.get("_large_map_view") as Control
	_assert(large_map_view != null and not bool(large_map_view.get("draw_background")), "Large map view should let the translucent panel show through behind map rooms")
	var large_map_dialog: PanelContainer = instance.get("_large_map_dialog") as PanelContainer
	var close_button: Button = null
	if large_map_dialog != null:
		close_button = large_map_dialog.find_child("CloseButton", true, false) as Button
	_assert(close_button != null, "Large map should expose a close button")
	if close_button != null:
		_assert(absf(close_button.custom_minimum_size.x - close_button.custom_minimum_size.y) <= 1.0, "Large map close button should be boxy instead of a wide native button")
	instance.queue_free()
	await process_frame

func _test_run_scene_debug_boss_fixture_boots() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for debug boss fixture coverage")
		return
	root.set_meta("labyrinth_debug_boss_run", true)
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var run_state: Dictionary = instance.get("_run_state")
	var combat_state: Dictionary = instance.get("_combat_state")
	_assert(bool(run_state.get("debug_boss_run", false)), "Debug boss fixture should mark its run as independent")
	_assert(str(run_state.get("mode", "")) == "combat", "Debug boss fixture should boot directly into combat")
	_assert(str(combat_state.get("room_type", "")) == "boss", "Debug boss fixture should load the boss room")
	_assert(int(run_state.get("player_max_hp", 0)) >= 40, "Debug boss fixture should grant plausible late-run max health")
	_assert(int(run_state.get("hand_size", 0)) == 5, "Debug boss fixture should keep the normal hand UI footprint")
	_assert((run_state.get("attuned_magic_cards", []) as Array).size() == GameData.magic_loadout_limit(), "Debug boss fixture should obey the attuned magic cap")
	_assert((run_state.get("magic_inventory", []) as Array).size() > 0, "Debug boss fixture should keep extra progressed cards in reserve magic")
	_assert((run_state.get("deck_cards", []) as Array).has("cinderburst"), "Debug boss fixture should still grant progressed attuned magic")
	var found_boss: bool = false
	for enemy_var: Variant in combat_state.get("enemies", []):
		var enemy: Dictionary = enemy_var
		if str(enemy.get("type", "")) == "zekarion":
			found_boss = true
			break
	_assert(found_boss, "Debug boss fixture should spawn Zekarion")
	instance.queue_free()
	if root.has_meta("labyrinth_debug_boss_run"):
		root.remove_meta("labyrinth_debug_boss_run")
	await process_frame

func _test_run_scene_offers_pass_during_combat() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for pass-turn coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var combat: CombatEngine = CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(76, _simple_room_layout(), {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["quick_stab"]
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	combat_state["deck"] = deck
	var run_state: Dictionary = instance.get("_run_state")
	run_state["mode"] = "combat"
	run_state["combat_state"] = combat_state
	instance.set("_run_state", run_state)
	instance.set("_combat_state", combat_state)
	instance.call("_refresh_choice_bar")
	var choice_host: Node = _run_scene_choice_button_host(instance)
	var pass_button: Button = _button_with_text(choice_host, "Pass")
	_assert(pass_button != null, "Combat UI should always offer Pass when the player can end the turn manually")
	if pass_button != null:
		_assert_button_uses_native_ratio(pass_button, UiSkin.BUTTON_HEIGHT_ACTION, "Combat Pass button should use a large native-ratio frame")
	var overlay: Control = instance.get("_choice_button_overlay") as Control
	var piles_bar: HBoxContainer = instance.get_node("Backdrop/Margin/MainVBox/BottomStack/HandRow/LeftActionStack/PilesBar")
	_assert(overlay != null and overlay.visible, "Combat Pass button should render in the stable overlay host")
	if overlay != null and piles_bar != null:
		_assert(overlay.global_position.y >= piles_bar.global_position.y - overlay.size.y - 10.0 and overlay.global_position.y < piles_bar.global_position.y, "Combat Pass overlay should stay directly above the pile widgets instead of jumping near the top of the screen")
	instance.queue_free()
	await process_frame

func _test_run_scene_offers_pass_when_hand_dead() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for pass-turn UI coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var combat: CombatEngine = CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(77, _dead_hand_room_layout(), {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["quick_stab", "quick_stab", "quick_stab", "quick_stab", "quick_stab"],
		"relics": [],
		"hand_size": 5,
		"heal_bonus": 0
	})
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["quick_stab", "quick_stab", "quick_stab", "quick_stab", "quick_stab"]
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	combat_state["deck"] = deck
	var run_state: Dictionary = instance.get("_run_state")
	run_state["mode"] = "combat"
	run_state["combat_state"] = combat_state
	instance.set("_run_state", run_state)
	instance.set("_combat_state", combat_state)
	instance.call("_refresh_choice_bar")
	var choice_host: Node = _run_scene_choice_button_host(instance)
	var pass_button: Button = _button_with_text(choice_host, "Pass")
	_assert(pass_button != null, "Combat UI should offer Pass when the hand has no playable cards")
	if pass_button != null:
		_assert_button_uses_native_ratio(pass_button, UiSkin.BUTTON_HEIGHT_ACTION, "Dead-hand Pass button should use a large native-ratio frame")
	instance.queue_free()
	await process_frame

func _test_run_scene_action_selection_buttons_are_large() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for action-selection button coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var run_state: Dictionary = instance.get("_run_state")
	run_state["mode"] = "combat"
	instance.set("_run_state", run_state)
	instance.set("_selected_card_index", 0)
	instance.set("_pending_actions", [{"type": "ranged"}])
	instance.set("_pending_action_index", 0)
	instance.set("_pending_action_can_skip", true)
	instance.call("_refresh_choice_bar")
	var choice_host: Node = _run_scene_choice_button_host(instance)
	var skip_button: Button = _button_with_text(choice_host, "Skip")
	var cancel_button: Button = _button_with_text(choice_host, "Cancel")
	_assert(skip_button != null, "Action selection should show Skip when the current action can be skipped")
	_assert(cancel_button != null, "Action selection should show Cancel while a card action is selected")
	if skip_button != null:
		_assert_button_uses_native_ratio(skip_button, UiSkin.BUTTON_HEIGHT_ACTION, "Action-selection Skip button should use a large native-ratio frame")
	if cancel_button != null:
		_assert_button_uses_native_ratio(cancel_button, UiSkin.BUTTON_HEIGHT_ACTION, "Action-selection Cancel button should use a large native-ratio frame")
	instance.queue_free()
	await process_frame

func _test_run_scene_action_selection_keeps_hand_layout_stable() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for action-selection layout coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var run_state: Dictionary = instance.get("_run_state")
	run_state["mode"] = "combat"
	instance.set("_run_state", run_state)
	instance.set("_selected_card_index", -1)
	instance.set("_pending_actions", [])
	instance.set("_pending_action_index", 0)
	instance.set("_pending_action_can_skip", false)
	instance.call("_refresh_choice_bar")
	instance.call("_refresh_visibility")
	await process_frame
	var hand_scroll: ScrollContainer = instance.get_node("Backdrop/Margin/MainVBox/BottomStack/HandRow/HandScroll")
	var left_action_stack: VBoxContainer = instance.get_node("Backdrop/Margin/MainVBox/BottomStack/HandRow/LeftActionStack")
	var choice_bar: HBoxContainer = instance.get_node("Backdrop/Margin/MainVBox/BottomStack/HandRow/LeftActionStack/ChoiceBar")
	var piles_bar: HBoxContainer = instance.get_node("Backdrop/Margin/MainVBox/BottomStack/HandRow/LeftActionStack/PilesBar")
	var pass_hand_x: float = hand_scroll.global_position.x
	var pass_action_width: float = left_action_stack.size.x
	var single_action_width: float = UiSkin.new().button_native_size(UiSkin.BUTTON_HEIGHT_ACTION).x
	var expected_action_width: float = maxf(piles_bar.get_combined_minimum_size().x, single_action_width)
	var two_action_width: float = single_action_width * 2.0 + float(choice_bar.get_theme_constant("separation"))
	_assert(absf(pass_action_width - expected_action_width) <= 1.0, "Combat action controls should keep the original pile/pass layout footprint")
	_assert(pass_action_width < two_action_width - 1.0, "Combat action controls should not permanently reserve the wider Skip/Cancel footprint")
	instance.set("_selected_card_index", 0)
	instance.set("_pending_actions", [{"type": "move"}])
	instance.set("_pending_action_index", 0)
	instance.set("_pending_action_can_skip", true)
	instance.call("_refresh_choice_bar")
	instance.call("_refresh_visibility")
	await process_frame
	var targeting_hand_x: float = hand_scroll.global_position.x
	var targeting_action_width: float = left_action_stack.size.x
	_assert(absf(targeting_hand_x - pass_hand_x) <= 1.0, "Move targeting Skip/Cancel controls should not shift the hand area")
	_assert(absf(targeting_action_width - pass_action_width) <= 1.0, "Combat action controls should reserve a stable column width")
	instance.queue_free()
	await process_frame

func _test_run_scene_idle_hand_refresh_clears_card_fx_ghosts() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for card FX ghost cleanup coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var card_fx_layer: Control = instance.get("_card_fx_layer") as Control
	_assert(card_fx_layer != null, "Run scene should build a card FX layer")
	if card_fx_layer != null:
		var active_ghost := Control.new()
		active_ghost.name = "ActiveCardFxGhost"
		active_ghost.top_level = true
		card_fx_layer.add_child(active_ghost)
		instance.set("_animation_lock", true)
		instance.call("_refresh_hand_panel")
		_assert(card_fx_layer.get_child_count() == 1, "Hand refresh should not clear card FX while animations are locked")
		instance.set("_animation_lock", false)
		instance.call("_refresh_hand_panel")
		_assert(card_fx_layer.get_child_count() == 0, "Idle hand refresh should clear leftover card FX proxies before later selections")
	instance.queue_free()
	await process_frame

func _test_run_scene_reward_heal_choice_sits_with_cards() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for reward heal-choice coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var run_state: Dictionary = instance.get("_run_state")
	run_state["mode"] = "reward"
	run_state["pending_reward"] = {
		"cards": ["quick_stab", "bone_dart", "sidestep_slash"],
		"heal_amount": RunEngine.REWARD_HEAL,
		"ember_amount": 0
	}
	instance.set("_run_state", run_state)
	instance.call("_refresh_choice_bar")
	instance.call("_refresh_hand_panel")
	instance.call("_refresh_visibility")
	await process_frame
	var choice_bar: HBoxContainer = instance.get_node("Backdrop/Margin/MainVBox/BottomStack/HandRow/LeftActionStack/ChoiceBar")
	var hand_box: Control = instance.get_node("Backdrop/Margin/MainVBox/BottomStack/HandRow/HandScroll/HandCenter/HandBox")
	_assert(not choice_bar.visible and choice_bar.get_child_count() == 0, "Reward heal choice should not appear in the combat choice bar")
	var heal_slot: Node = hand_box.get_child(3) if hand_box.get_child_count() >= 4 else null
	var heal_choice: PanelContainer = null
	if heal_slot != null:
		heal_choice = heal_slot.find_child("RewardHealChoice", true, false) as PanelContainer
	_assert(heal_choice != null, "Reward heal choice should render as a card-like tile beside the offered cards")
	if heal_choice != null:
		_assert(int(heal_choice.get_meta("reward_heal_amount", 0)) == RunEngine.REWARD_HEAL, "Reward heal tile should keep the offered heal amount")
		_assert(heal_choice.mouse_filter == Control.MOUSE_FILTER_STOP, "Reward heal tile should receive clicks directly")
		_assert(_button_with_text(hand_box, "+%d HP" % RunEngine.REWARD_HEAL) == null, "Reward heal choice should not render as a floating button over the cards")
		_assert(heal_slot != null and heal_slot.get_parent() == hand_box, "Reward heal choice should be parented as a hand choice slot")
		_assert(hand_box.get_child_count() == 4 and hand_box.get_child(3) == heal_slot, "Reward heal choice should sit immediately to the right of the offered cards")
	instance.queue_free()
	await process_frame

func _test_run_scene_selection_prompts_clear_after_pick() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for selection prompt coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame

	var run_state: Dictionary = instance.get("_run_state")
	run_state["mode"] = "reward"
	run_state["pending_reward"] = {
		"cards": ["quick_stab", "bone_dart", "sidestep_slash"],
		"heal_amount": RunEngine.REWARD_HEAL,
		"ember_amount": 0
	}
	instance.set("_run_state", run_state)
	instance.call("_refresh_choice_bar")
	var prompt_overlay: Control = instance.get("_relic_choice_overlay") as Control
	var prompt_title: Label = instance.get("_relic_choice_title") as Label
	_assert(prompt_overlay != null and prompt_overlay.visible, "Card reward selection should show the shared stage prompt overlay")
	_assert(prompt_title != null and prompt_title.visible and prompt_title.text == "GROW YOUR POWER", "Card reward selection should use the Grow your power prompt")
	instance.call("_on_reward_card_pressed", "quick_stab")
	await process_frame
	_assert(prompt_overlay != null and not prompt_overlay.visible, "Card reward prompt should clear after picking a reward")
	_assert(prompt_title != null and not prompt_title.visible, "Card reward title should hide after picking a reward")

	run_state = instance.get("_run_state")
	run_state["mode"] = "treasure"
	run_state["pending_relics"] = ["iron_lung", "ember_lens", "pilgrim_boots"]
	instance.set("_run_state", run_state)
	instance.call("_refresh_choice_bar")
	_assert(prompt_overlay != null and prompt_overlay.visible, "Relic selection should show the shared stage prompt overlay")
	_assert(prompt_title != null and prompt_title.visible and prompt_title.text == "CLAIM YOUR TREASURE", "Relic selection should keep the treasure prompt")
	run_state = instance.get("_run_state")
	var run_engine: RunEngine = instance.get("_run_engine") as RunEngine
	instance.set("_run_state", run_engine.claim_relic(run_state, "iron_lung"))
	instance.call("_refresh_choice_bar")
	await process_frame
	_assert(prompt_overlay != null and not prompt_overlay.visible, "Relic prompt should clear after picking a relic")
	_assert(prompt_title != null and not prompt_title.visible, "Relic title should hide after picking a relic")

	instance.queue_free()
	await process_frame

func _test_run_scene_fatigue_damage_visual_event() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for fatigue visual coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame

	var combat: CombatEngine = CombatEngine.new()
	var before_state: Dictionary = combat.create_combat(118, _simple_room_layout(), {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["quick_stab", "brace"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var deck: Dictionary = (before_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = []
	deck["draw"] = []
	deck["discard"] = ["quick_stab"]
	deck["burned"] = []
	deck["cycles"] = 0
	before_state["deck"] = deck
	var after_state: Dictionary = combat.prepare_next_player_turn(before_state)
	var fatigue_events: Array = instance.call("_fatigue_damage_events_between_states", before_state, after_state)
	_assert(fatigue_events.size() == 1, "Fatigue draw should create one visual event when the deck cycles")
	if not fatigue_events.is_empty():
		var event: Dictionary = fatigue_events[0]
		var player_tile: Vector2i = (after_state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO)
		_assert(int(event.get("amount", 0)) == 15, "First fatigue visual event should carry the first fatigue damage amount")
		_assert(event.get("tile", Vector2i(-1, -1)) == player_tile, "Fatigue visual text should anchor to the player tile")
	var fatigue_texts: Array = instance.call("_fatigue_floating_texts_for_events", after_state, fatigue_events)
	var found_damage_number: bool = false
	var found_fatigue_text: bool = false
	for text_var: Variant in fatigue_texts:
		var text_entry: Dictionary = text_var
		found_damage_number = found_damage_number or str(text_entry.get("text", "")) == "-15"
		found_fatigue_text = found_fatigue_text or str(text_entry.get("text", "")) == "fatigue sets in"
	_assert(found_damage_number, "Fatigue visual should include the normal floating damage number")
	_assert(found_fatigue_text, "Fatigue visual should include the fatigue text callout")
	var fatigue_presentation: Dictionary = instance.call("_fatigue_damage_presentation_for_progress", after_state, fatigue_events, 0.25)
	_assert((fatigue_presentation.get("impact_actor_keys", []) as Array).has("player"), "Fatigue visual should drive the player's damage impact animation")
	_assert(float(fatigue_presentation.get("impact_strength", 0.0)) > 1.0, "Fatigue visual should boost the player damage impact so it reads on the player sprite")
	_assert((fatigue_presentation.get("floating_texts", []) as Array).size() >= 2, "Fatigue damage presentation should show both damage number and fatigue text")
	var overlay: Control = instance.get("_fatigue_edge_overlay") as Control
	_assert(overlay != null, "RunScene should build a full-screen fatigue edge overlay")
	if overlay != null:
		instance.call("_set_fatigue_edge_progress", 0.5)
		await process_frame
		_assert(overlay.visible, "Fatigue edge overlay should appear while the pulse is active")
		instance.call("_set_fatigue_edge_progress", -1.0)
		await process_frame
		_assert(not overlay.visible, "Fatigue edge overlay should hide after the pulse")

	instance.queue_free()
	await process_frame

func _test_run_scene_campfire_choices_use_relic_overlay() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for campfire overlay coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var run_state: Dictionary = instance.get("_run_state")
	run_state["mode"] = "campfire"
	run_state["progression"] = ProgressionStore.default_data()
	run_state["held_embers"] = 0
	run_state["unbanked_embers"] = 0
	instance.set("_run_state", run_state)
	instance.set("_progression", ProgressionStore.default_data())
	instance.call("_refresh_choice_bar")
	var choice_bar: HBoxContainer = instance.get_node("Backdrop/Margin/MainVBox/BottomStack/HandRow/LeftActionStack/ChoiceBar")
	var context_overlay: PanelContainer = instance.get_node("Backdrop/Margin/MainVBox/StageRoot/ContextChoiceOverlay")
	var relic_overlay: Control = instance.get("_relic_choice_overlay") as Control
	var relic_bar: HBoxContainer = instance.get("_relic_choice_bar") as HBoxContainer
	_assert(not choice_bar.visible, "Campfire choices should no longer sit in the bottom choice bar")
	_assert(not context_overlay.visible and _buttons_under(context_overlay).is_empty(), "Campfire choices should no longer use button overlays")
	_assert(relic_overlay != null and relic_overlay.visible, "Campfire choices should use the shared relic-style stage overlay")
	_assert(relic_bar != null and relic_bar.get_child_count() == 3, "Campfire overlay should expose heal, carry, and level-up choice panels")
	_assert(_label_with_text(relic_overlay, "Linger for a moment") != null, "Campfire overlay should label the continue option")
	_assert(_label_with_text(relic_overlay, "Embrace the fire's warmth") != null, "Campfire overlay should label the abandon option")
	_assert(_label_with_text(relic_overlay, "Draw strength from the flame") != null, "Campfire overlay should label the level-up option")
	_assert(_label_with_text(relic_overlay, "Heal 100 and continue onward") != null, "Campfire linger choice should describe the heal")
	_assert(_label_with_text(relic_overlay, "Carry held embers into the next run") != null, "Campfire abandon choice should describe ember carry-forward")
	_assert(_label_with_text(relic_overlay, "Need 180 embers") != null, "Campfire level-up choice should be disabled when held embers are short")
	var loaded_icon_count: int = 0
	for texture_rect: TextureRect in _texture_rects_under(relic_overlay):
		if texture_rect.texture != null:
			loaded_icon_count += 1
	_assert(loaded_icon_count >= 3, "Campfire choice panels should load generated protagonist icons")
	run_state = instance.get("_run_state")
	run_state["held_embers"] = 180
	run_state["unbanked_embers"] = 180
	run_state["progression"] = ProgressionStore.set_embers(ProgressionStore.default_data(), 180)
	instance.set("_run_state", run_state)
	instance.set("_progression", run_state.get("progression", {}))
	instance.call("_refresh_choice_bar")
	relic_overlay = instance.get("_relic_choice_overlay") as Control
	_assert(_label_with_text(relic_overlay, "Spend embers to become permanently stronger (180 embers)") != null, "Campfire level-up choice should reveal its cost when affordable")
	instance.queue_free()
	await process_frame

func _test_run_scene_campfire_bonfire_persists_after_leave() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for campfire prop coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var run_engine: RunEngine = instance.get("_run_engine")
	var run_state: Dictionary = run_engine.create_new_run(123, ProgressionStore.default_data())
	var campfire_coord := Vector2i(0, 2)
	var campfire_room: Dictionary = run_engine.room_metadata(run_state, campfire_coord)
	_assert(str(campfire_room.get("type", "")) == "campfire", "Depth-2 axis fixture should be a campfire room")
	run_state["current_room"] = campfire_coord
	run_state["mode"] = "room"
	run_state["current_room_layout"] = run_engine.call("_display_layout_for_room", int(run_state.get("seed", 0)), campfire_room, Vector2i.ZERO)
	instance.set("_run_state", run_state)
	instance.call("_refresh_stage_view")
	var board_view: Node = instance.get_node("Backdrop/Margin/MainVBox/StageRoot/CombatBoard")
	var scene_props: Array = board_view.get("presentation").get("scene_props", [])
	var found_bonfire: bool = false
	for prop_var: Variant in scene_props:
		if typeof(prop_var) == TYPE_DICTIONARY and str((prop_var as Dictionary).get("kind", "")) == "campfire_bonfire":
			found_bonfire = true
			break
	_assert(found_bonfire, "Campfire bonfire should stay on the board after leaving the campfire choice mode")
	var idle_frames: Array = board_view.call("_scene_prop_idle_frames_for_kind", "campfire_bonfire")
	_assert(idle_frames.size() == 16, "Campfire bonfire should load the full 4x4 idle animation sheet")
	var first_frame: AtlasTexture = null
	var second_frame: AtlasTexture = null
	if idle_frames.size() > 0:
		first_frame = idle_frames[0] as AtlasTexture
	if idle_frames.size() > 1:
		second_frame = idle_frames[1] as AtlasTexture
	_assert(first_frame != null and second_frame != null and first_frame.region != second_frame.region, "Campfire bonfire idle frames should be atlas-backed sprite sheet slices")
	instance.queue_free()
	await process_frame

func _test_run_scene_optional_followup_attack_stays_playable() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for optional follow-up coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var combat: CombatEngine = CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(91, _optional_followup_room_layout(), {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["sidestep_slash"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["sidestep_slash"]
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	combat_state["deck"] = deck
	instance.set("_combat_state", combat_state)
	var preview: Dictionary = instance.call("_card_preview_for_index", 0)
	_assert(bool(preview.get("playable", false)), "Move-attack cards should stay playable even when the follow-up attack has no valid target")
	_assert(not (preview.get("target_tiles", []) as Array).is_empty(), "Optional move-attack cards should still offer movement targets")
	var first_target: Vector2i = (preview.get("target_tiles", []) as Array)[0]
	var next_state: Dictionary = combat.apply_player_action(combat_state, preview.get("action", {}), first_target)
	var next_preview: Dictionary = instance.call(
		"_card_preview_from_state",
		"sidestep_slash",
		next_state,
		GameData.card_def("sidestep_slash").get("actions", []),
		1
	)
	_assert(bool(next_preview.get("complete", false)), "The follow-up attack should auto-skip when it has no valid target")
	instance.queue_free()
	await process_frame

func _test_run_scene_move_attack_shortcut_clicks_enemy() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for move-attack shortcut coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var combat: CombatEngine = CombatEngine.new()
	var layout: Dictionary = _simple_room_layout()
	layout["player_start"] = Vector2i(2, 5)
	layout["enemies"] = [{
		"id": 1,
		"type": "crawler",
		"pos": Vector2i(5, 5),
		"hp": 140,
		"max_hp": 140,
		"block": 0
	}]
	var combat_state: Dictionary = combat.create_combat(92, layout, {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["sidestep_slash"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["sidestep_slash"]
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	combat_state["deck"] = deck
	var run_state: Dictionary = instance.get("_run_state")
	run_state["mode"] = "combat"
	run_state["combat_state"] = combat_state
	instance.set("_run_state", run_state)
	instance.set("_combat_state", combat_state)
	var preview: Dictionary = instance.call("_card_preview_for_index", 0)
	await instance.call("_begin_card_preview", 0, preview)
	var enemy_tile := Vector2i(5, 5)
	instance.call("_on_board_tile_hovered", enemy_tile)
	var board_view: Node = instance.get_node("Backdrop/Margin/MainVBox/StageRoot/CombatBoard")
	var attack_tiles: Array = board_view.get("attack_tiles")
	_assert(attack_tiles.has(enemy_tile), "Move-attack previews should let the player click a reachable enemy directly")
	_assert(bool(board_view.get("presentation").get("pulse_attack_tiles", false)), "Player attack targets should request pulsing attack highlights")
	var focus_tiles: Array = board_view.get("presentation").get("focus_tiles", [])
	var typed_focus_tiles: bool = not focus_tiles.is_empty()
	for tile_var: Variant in focus_tiles:
		if typeof(tile_var) != TYPE_VECTOR2I:
			typed_focus_tiles = false
			break
	_assert(typed_focus_tiles, "Hovering a shortcut target should produce typed focus tiles instead of crashing preview rendering")
	await instance.call("_on_board_tile_clicked", enemy_tile)
	var final_state: Dictionary = instance.get("_combat_state")
	var player_tile: Vector2i = (final_state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO)
	_assert(player_tile == Vector2i(4, 5), "Enemy shortcut clicks should move only the minimum distance needed to attack")
	var enemies: Array = final_state.get("enemies", [])
	var enemy: Dictionary = enemies[0] if not enemies.is_empty() else {}
	_assert(int(enemy.get("hp", 0)) == 90, "Enemy shortcut clicks should still resolve the follow-up attack")
	instance.queue_free()
	await process_frame

func _test_run_scene_aoe_aim_rotates_before_click() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for AOE aim rotation coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var combat: CombatEngine = CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(921, _simple_room_layout(), {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["thunderline"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	combat_state["player"] = {"pos": Vector2i(2, 4), "hp": 20, "max_hp": 20, "block": 0, "stoneskin": 0}
	combat_state["enemies"] = [
		{"id": 1, "type": "crawler", "pos": Vector2i(4, 4), "hp": 20, "max_hp": 20, "block": 0},
		{"id": 2, "type": "harrier", "pos": Vector2i(4, 2), "hp": 20, "max_hp": 20, "block": 0},
		{"id": 3, "type": "acolyte", "pos": Vector2i(6, 4), "hp": 20, "max_hp": 20, "block": 0}
	]
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["thunderline"]
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	combat_state["deck"] = deck
	var run_state: Dictionary = instance.get("_run_state")
	run_state["mode"] = "combat"
	run_state["combat_state"] = combat_state
	instance.set("_run_state", run_state)
	instance.set("_combat_state", combat_state)
	var preview: Dictionary = instance.call("_card_preview_for_index", 0)
	await instance.call("_begin_card_preview", 0, preview)
	instance.call("_on_board_tile_hovered", Vector2i(5, 4))
	var board_view: Node = instance.get_node("Backdrop/Margin/MainVBox/StageRoot/CombatBoard")
	var presentation: Dictionary = board_view.get("presentation")
	var focus_tiles: Array = presentation.get("focus_tiles", [])
	_assert(focus_tiles.has(Vector2i(4, 4)) and focus_tiles.has(Vector2i(6, 4)), "Default line AOE aim should show the full centered east pattern before clicking")
	instance.call("_rotate_aoe_aim", -1)
	instance.call("_on_board_tile_hovered", Vector2i(4, 3))
	presentation = board_view.get("presentation")
	focus_tiles = presentation.get("focus_tiles", [])
	_assert(focus_tiles.has(Vector2i(4, 2)) and focus_tiles.has(Vector2i(4, 4)) and not focus_tiles.has(Vector2i(6, 4)), "Rotating line AOE aim should update the hover pattern before target confirmation")
	await instance.call("_on_board_tile_clicked", Vector2i(4, 3))
	await create_timer(1.5).timeout
	var final_state: Dictionary = instance.get("_combat_state")
	var enemies: Array = final_state.get("enemies", [])
	_assert(int((enemies[1] as Dictionary).get("hp", 0)) < 20, "Rotated Thunderline should hit the selected vertical line")
	_assert(int((enemies[2] as Dictionary).get("hp", 0)) == 20, "Rotated Thunderline should not hit the old horizontal line")
	instance.queue_free()
	await process_frame

func _test_run_scene_push_direction_tiles_filter_closer_tiles() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for push direction filtering coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var combat: CombatEngine = CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(922, _simple_room_layout(), {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["updraft"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	combat_state["player"] = {"pos": Vector2i(2, 4), "hp": 20, "max_hp": 20, "block": 0, "stoneskin": 0}
	combat_state["enemies"] = [
		{"id": 1, "type": "crawler", "pos": Vector2i(3, 4), "hp": 100, "max_hp": 100, "block": 0}
	]
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["updraft"]
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	combat_state["deck"] = deck
	var run_state: Dictionary = instance.get("_run_state")
	run_state["mode"] = "combat"
	run_state["combat_state"] = combat_state
	instance.set("_run_state", run_state)
	instance.set("_combat_state", combat_state)
	var preview: Dictionary = instance.call("_card_preview_for_index", 0)
	await instance.call("_begin_card_preview", 0, preview)
	await instance.call("_on_board_tile_clicked", Vector2i(3, 4))
	var board_view: Node = instance.get_node("Backdrop/Margin/MainVBox/StageRoot/CombatBoard")
	var presentation: Dictionary = board_view.get("presentation")
	var ability_tiles: Array = presentation.get("ability_tiles", [])
	_assert(not ability_tiles.has(Vector2i(2, 4)), "Push direction selection should not show the protagonist tile as a valid closer direction")
	_assert(ability_tiles.has(Vector2i(4, 4)), "Push direction selection should still show directions that move the enemy farther away")
	await instance.call("_on_board_tile_clicked", Vector2i(2, 4))
	_assert(instance.get("_pending_orientation_target_tile") == Vector2i(3, 4), "Clicking an invalid closer push direction should keep direction selection pending")
	await instance.call("_on_board_tile_clicked", Vector2i(4, 4))
	await create_timer(1.5).timeout
	var final_state: Dictionary = instance.get("_combat_state")
	var enemies: Array = final_state.get("enemies", [])
	var enemy: Dictionary = enemies[0] if not enemies.is_empty() else {}
	_assert(enemy.get("pos", Vector2i.ZERO) == Vector2i(5, 4), "Confirming a valid push direction should move the enemy farther from the player")
	instance.queue_free()
	await process_frame

func _test_run_scene_block_card_skips_dead_move() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for dead-move skip coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var combat: CombatEngine = CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(93, _dead_hand_room_layout(), {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["guarded_step"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["guarded_step"]
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	combat_state["deck"] = deck
	instance.set("_combat_state", combat_state)
	var preview: Dictionary = instance.call("_card_preview_for_index", 0)
	_assert(bool(preview.get("playable", false)), "Cards with a self effect should remain playable when their move step has no target")
	_assert(bool(preview.get("complete", false)), "Dead move steps should auto-skip into the card's self effect")
	instance.queue_free()
	await process_frame

func _test_run_scene_targetless_card_click_commits_play() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for targetless click coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var combat: CombatEngine = CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(95, _simple_room_layout(), {
		"hp": 120,
		"max_hp": 200,
		"deck_cards": ["patch_up"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var player: Dictionary = (combat_state.get("player", {}) as Dictionary).duplicate(true)
	player["hp"] = 120
	combat_state["player"] = player
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["patch_up"]
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	combat_state["deck"] = deck
	var run_state: Dictionary = instance.get("_run_state")
	run_state["mode"] = "combat"
	run_state["combat_state"] = combat_state
	instance.set("_run_state", run_state)
	instance.set("_combat_state", combat_state)
	instance.call("_refresh_ui")
	instance.call("_on_card_pressed", 0)
	await create_timer(1.5).timeout
	var committed_state: Dictionary = instance.get("_combat_state")
	var committed_player: Dictionary = committed_state.get("player", {})
	_assert(int(committed_player.get("hp", 0)) == 150, "Clicking a targetless self card should immediately commit its heal")
	_assert(int(committed_player.get("block", 0)) == 20, "Clicking a targetless self card should immediately commit its block")
	_assert(((committed_state.get("deck", {}) as Dictionary).get("hand", []) as Array).is_empty(), "Resolved targetless cards should leave the hand")
	instance.queue_free()
	await process_frame

func _test_run_scene_fallback_attack_uses_scaled_damage() -> void:
	var run_scene_script: Script = load("res://scripts/run_scene.gd")
	_assert(run_scene_script != null, "Run scene script should load for fallback action coverage")
	if run_scene_script == null:
		return
	var instance: Node = run_scene_script.new()
	var attack_actions: Array = instance.call("_fallback_actions", "attack")
	var attack_action: Dictionary = attack_actions[0] as Dictionary
	_assert(int(attack_action.get("damage", 0)) == GameData.fixed_point_amount(2), "Fallback attack should use scaled fixed-point damage")
	_assert(str(instance.call("_fallback_label", "attack")) == "20 Attack", "Fallback attack drag labels should match scaled damage")
	instance.free()

func _test_run_scene_card_play_meter_spends_before_resolution_rewards() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for card play meter spend preview coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var combat: CombatEngine = CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(951, _simple_room_layout(), {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["quick_stab", "quick_stab"],
		"relics": [],
		"hand_size": 2,
		"heal_bonus": 0
	})
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["quick_stab", "quick_stab"]
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	combat_state["deck"] = deck
	var run_state: Dictionary = instance.get("_run_state")
	run_state["mode"] = "combat"
	run_state["combat_state"] = combat_state
	instance.set("_run_state", run_state)
	instance.set("_combat_state", combat_state)
	instance.call("_refresh_ui")
	var count_label: Label = instance.get("_play_meter_count") as Label
	_assert(count_label != null and count_label.text == "2", "Card play meter should start from available combat plays")
	instance.call("_begin_card_play_meter_spend_preview")
	_assert(count_label != null and count_label.text == "1", "Card play meter should spend the played card immediately")
	var rewarded_state: Dictionary = combat_state.duplicate(true)
	rewarded_state["death_bonus_card_plays_this_turn"] = 1
	_assert(int(instance.call("_card_play_count_for_resolution_state", rewarded_state)) == 2, "Death-reward play previews should add to the already-spent meter count")
	instance.queue_free()
	await process_frame

func _test_run_scene_damage_display_matches_bonus() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for damage display coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var combat: CombatEngine = CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(97, _simple_room_layout(), {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["quick_stab"],
		"relics": ["ember_lens"],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["quick_stab"]
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	combat_state["deck"] = deck
	instance.set("_combat_state", combat_state)
	var display: Dictionary = instance.call("_card_widget_display", "quick_stab", combat_state)
	var summary_rows: Array = display.get("summary_rows", [])
	var modifier_lines: Array = display.get("modifier_lines", [])
	_assert(not summary_rows.is_empty(), "Damage cards should render icon summary rows")
	var damage_token: Dictionary = ((summary_rows[0] as Array)[0] as Dictionary)
	_assert(str(damage_token.get("icon", "")) == "melee", "Damage cards should render the action keyword as an icon")
	_assert(int(damage_token.get("value", 0)) == 110, "Damage cards should show final damage, not base damage, when a modifier applies")
	_assert(str(damage_token.get("tone", "")) == "bonus", "Modified damage tokens should carry bonus styling")
	_assert(modifier_lines.is_empty(), "Damage modifiers should live on the modified token instead of a duplicate card-level tooltip")
	_assert(ActionIcons.token_is_modified(damage_token), "Damage cards should mark dynamically modified tokens")
	_assert(ActionIcons.token_tooltip(damage_token).contains("Ember Lens"), "The damage token tooltip should name the modifier source")
	instance.queue_free()
	await process_frame

func _test_run_scene_intensity_condition_rows_mark_activity() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for intensity display coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var combat: CombatEngine = CombatEngine.new()
	var earth_layout: Dictionary = _simple_room_layout()
	earth_layout["element"] = ElementData.EARTH
	var active_state: Dictionary = combat.create_combat(15124, earth_layout, {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["venom_claw"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var active_display: Dictionary = instance.call("_card_widget_display", "venom_claw", active_state)
	var active_token: Dictionary = _first_intensity_requirement_token(active_display.get("summary_rows", []))
	_assert(not active_token.is_empty() and bool(active_token.get("condition_active", false)), "A card that builds enough intensity before its bonus should mark that bonus active")
	var fire_layout: Dictionary = _simple_room_layout()
	fire_layout["element"] = ElementData.FIRE
	var inactive_state: Dictionary = combat.create_combat(15125, fire_layout, {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["venom_claw"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var inactive_display: Dictionary = instance.call("_card_widget_display", "venom_claw", inactive_state)
	var inactive_token: Dictionary = _first_intensity_requirement_token(inactive_display.get("summary_rows", []))
	_assert(not inactive_token.is_empty() and not bool(inactive_token.get("condition_active", false)), "An unmet intensity bonus should not render as active")
	instance.queue_free()
	await process_frame

func _first_intensity_requirement_token(rows: Array) -> Dictionary:
	for row_var: Variant in rows:
		if typeof(row_var) != TYPE_ARRAY:
			continue
		var row: Array = row_var as Array
		for token_var: Variant in row:
			if typeof(token_var) != TYPE_DICTIONARY:
				continue
			var token: Dictionary = token_var
			if str(token.get("kind", "")) == "intensity_requirement":
				return token
	return {}

func _test_run_scene_ranged_cards_show_range() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for ranged-card coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var combat: CombatEngine = CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(101, _simple_room_layout(), {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["bone_dart"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["bone_dart"]
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	combat_state["deck"] = deck
	instance.set("_combat_state", combat_state)
	var display: Dictionary = instance.call("_card_widget_display", "bone_dart", combat_state)
	var summary_rows: Array = display.get("summary_rows", [])
	_assert(not summary_rows.is_empty(), "Ranged cards should render icon summary rows")
	var card_row: Array = summary_rows[0] as Array
	_assert(str((card_row[0] as Dictionary).get("icon", "")) == "ranged", "Ranged cards should show the ranged keyword as an icon")
	_assert(str((card_row[1] as Dictionary).get("icon", "")) == "range" and int((card_row[1] as Dictionary).get("value", 0)) == 4, "Ranged cards should show their range with the shared range icon")
	var board := CombatBoardView.new()
	var intent_rows: Array = board.call("_intent_rows", {"actions": [{"type": "ranged", "damage": 4, "range": 4}]})
	_assert(intent_rows.size() == 1 and str(((intent_rows[0] as Array)[1] as Dictionary).get("icon", "")) == "range", "Enemy shot intents should show attack range with the shared range icon")
	instance.queue_free()
	await process_frame

func _test_run_scene_preview_normalizes_untyped_target_tiles() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for untyped preview-target coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var combat: CombatEngine = CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(104, _simple_room_layout(), {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["guarded_step"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["guarded_step"]
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	combat_state["deck"] = deck
	var run_state: Dictionary = instance.get("_run_state")
	run_state["mode"] = "combat"
	run_state["combat_state"] = combat_state
	instance.set("_run_state", run_state)
	instance.set("_combat_state", combat_state)
	var target_tile := Vector2i(3, 4)
	instance.set("_hovered_board_tile", target_tile)
	await instance.call("_begin_card_preview", 0, {
		"card_id": "guarded_step",
		"state": combat_state,
		"actions": [{"type": "move", "range": 1}],
		"action_index": 0,
		"target_tiles": [target_tile],
		"complete": false,
		"playable": true,
		"action": {"type": "move", "range": 1},
		"skip_allowed": false
	})
	instance.call("_refresh_stage_view")
	var active_preview: Dictionary = instance.call("_active_card_preview")
	var active_targets: Array = active_preview.get("target_tiles", [])
	_assert(active_targets.size() == 1 and active_targets[0] == target_tile, "Run scene previews should preserve Vector2i target tiles when dictionaries provide plain arrays")
	var board_view: Node = instance.get_node("Backdrop/Margin/MainVBox/StageRoot/CombatBoard")
	var move_tiles: Array = board_view.get("move_tiles")
	_assert(move_tiles.has(target_tile), "Stage refresh should accept untyped preview target arrays and surface them on the combat board")
	instance.queue_free()
	await process_frame

func _test_run_scene_illusion_hover_surfaces_preview_unit() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for illusion hover preview coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var combat: CombatEngine = CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(106, _simple_room_layout(), {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["shadow_step"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["shadow_step"]
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	combat_state["deck"] = deck
	var run_state: Dictionary = instance.get("_run_state")
	run_state["mode"] = "combat"
	run_state["combat_state"] = combat_state
	instance.set("_run_state", run_state)
	instance.set("_combat_state", combat_state)
	var preview: Dictionary = instance.call("_card_preview_for_index", 0)
	await instance.call("_begin_card_preview", 0, preview)
	var target_tile := Vector2i(3, 4)
	instance.call("_on_board_tile_hovered", target_tile)
	var board_view: Node = instance.get_node("Backdrop/Margin/MainVBox/StageRoot/CombatBoard")
	var presentation: Dictionary = board_view.get("presentation")
	var preview_units: Array = presentation.get("preview_units", [])
	var ability_tiles: Array = presentation.get("ability_tiles", [])
	var attack_tiles: Array = board_view.get("attack_tiles")
	_assert(ability_tiles.has(target_tile), "Illusion target previews should expose green ability target tiles")
	_assert(not attack_tiles.has(target_tile), "Illusion target previews should stay out of attack target highlights")
	_assert(not bool(presentation.get("pulse_attack_tiles", false)), "Illusion target previews should not request attack target pulsing")
	_assert(preview_units.size() == 1, "Hovering a valid illusion target should surface one placement preview unit")
	if not preview_units.is_empty():
		var preview_unit: Dictionary = preview_units[0] as Dictionary
		_assert(str(preview_unit.get("role", "")) == "illusion_preview", "Illusion target hovers should tag preview units distinctly from placed illusions")
		_assert(preview_unit.get("pos", Vector2i.ZERO) == target_tile, "Illusion preview units should appear on the hovered valid tile")
		_assert(int(preview_unit.get("hp", 0)) > 0, "Illusion preview units should expose the pending illusion health")
	instance.call("_on_board_tile_hovered", Vector2i(5, 2))
	presentation = board_view.get("presentation")
	_assert((presentation.get("preview_units", []) as Array).is_empty(), "Hovering an invalid illusion target should hide the placement preview unit")
	instance.queue_free()
	await process_frame

func _test_run_scene_move_previews_avoid_traps_when_possible() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for trap-aware move preview coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var combat: CombatEngine = CombatEngine.new()
	var layout: Dictionary = _simple_room_layout()
	layout["player_start"] = Vector2i(2, 4)
	layout["enemies"] = [
		{
			"id": 1,
			"type": "crawler",
			"pos": Vector2i(5, 3),
			"hp": 14,
			"max_hp": 14,
			"block": 0
		}
	]
	layout["traps"] = [{
		"id": "trap_3_4",
		"pos": Vector2i(3, 4),
		"element": "fire",
		"damage": 2,
		"burn": 2
	}]
	var combat_state: Dictionary = combat.create_combat(105, layout, {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var run_state: Dictionary = instance.get("_run_state")
	run_state["mode"] = "combat"
	run_state["combat_state"] = combat_state
	instance.set("_run_state", run_state)
	instance.set("_combat_state", combat_state)
	instance.set("_hovered_board_tile", Vector2i(5, 4))
	var preview: Dictionary = {
		"card_id": "test_move_attack",
		"state": combat_state,
		"actions": [
			{"type": "move", "range": 5},
			{"type": "melee", "damage": 4, "range": 1}
		],
		"action_index": 0,
		"target_tiles": [Vector2i(5, 4)],
		"complete": false,
		"playable": true,
		"action": {"type": "move", "range": 5},
		"skip_allowed": false
	}
	var path_tiles: Array = instance.call("_path_tiles_for_preview", preview)
	_assert(not path_tiles.has(Vector2i(3, 4)), "Move previews should prefer trap-free paths when the move range can support them")
	var shortcuts: Dictionary = instance.call("_preview_shortcuts_for_current_action", preview)
	var plans: Dictionary = shortcuts.get("plans", {})
	var shortcut_plan: Dictionary = plans.get(Vector2i(5, 3), {})
	var shortcut_path: Array = shortcut_plan.get("path_tiles", [])
	_assert(not shortcut_path.has(Vector2i(3, 4)), "Move-attack previews should reuse the same trap-avoiding movement path")
	var blink_preview: Dictionary = {
		"card_id": "test_blink_attack",
		"state": combat_state,
		"actions": [
			{"type": "blink", "range": 5},
			{"type": "melee", "damage": 4, "range": 1}
		],
		"action_index": 0,
		"target_tiles": [Vector2i(5, 4)],
		"complete": false,
		"playable": true,
		"action": {"type": "blink", "range": 5},
		"skip_allowed": false
	}
	var blink_path: Array[Vector2i] = combat.path_for_player_action(combat_state, {"type": "blink", "range": 5}, Vector2i(5, 4))
	_assert(blink_path == [Vector2i(5, 4)], "Blink paths should be returned as typed Vector2i arrays")
	var blink_shortcuts: Dictionary = instance.call("_preview_shortcuts_for_current_action", blink_preview)
	var blink_plan: Dictionary = (blink_shortcuts.get("plans", {}) as Dictionary).get(Vector2i(5, 3), {})
	var blink_shortcut_path: Array = blink_plan.get("path_tiles", [])
	_assert(blink_shortcut_path == [Vector2i(5, 4)], "Blink-attack shortcut previews should keep the blink destination as a typed path")
	instance.queue_free()
	await process_frame

func _test_run_scene_hovered_enemy_shows_threat_overlay() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for enemy threat overlay coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var combat: CombatEngine = CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(102, _simple_room_layout(), {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	combat_state["enemies"] = [
		{
			"id": 1,
			"type": "harrier",
			"pos": Vector2i(5, 2),
			"hp": 10,
			"max_hp": 10,
			"block": 0,
			"intent": {
				"name": "Pelt",
				"actions": [
					{"type": "move_toward", "range": 2},
					{"type": "ranged", "damage": 4, "range": 3}
				]
			}
		}
	]
	var run_state: Dictionary = instance.get("_run_state")
	run_state["mode"] = "combat"
	run_state["combat_state"] = combat_state
	instance.set("_run_state", run_state)
	instance.set("_combat_state", combat_state)
	instance.set("_hovered_board_tile", Vector2i(5, 2))
	instance.call("_refresh_stage_view")
	var board_view: Node = instance.get_node("Backdrop/Margin/MainVBox/StageRoot/CombatBoard")
	var move_tiles: Array = board_view.get("move_tiles")
	var attack_tiles: Array = board_view.get("attack_tiles")
	_assert(move_tiles.has(Vector2i(4, 2)), "Hovering an enemy should surface its movement threat tiles on the board")
	_assert(attack_tiles.has(Vector2i(2, 4)), "Hovering an enemy should surface its attack threat tiles on the board")
	_assert(not bool(board_view.get("presentation").get("pulse_attack_tiles", false)), "Enemy threat overlays should keep static attack highlights")
	instance.queue_free()
	await process_frame

func _test_run_scene_animation_lock_preserves_board_animation_presentation() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for animation-lock hover coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var combat: CombatEngine = CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(104, _simple_room_layout(), {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	combat_state["enemies"] = [
		{
			"id": 1,
			"type": "harrier",
			"pos": Vector2i(5, 2),
			"hp": 10,
			"max_hp": 10,
			"block": 0
		}
	]
	var run_state: Dictionary = instance.get("_run_state")
	run_state["mode"] = "combat"
	run_state["combat_state"] = combat_state
	instance.set("_run_state", run_state)
	instance.set("_combat_state", combat_state)
	instance.set("_animation_lock", true)
	var board_view: Node = instance.get_node("Backdrop/Margin/MainVBox/StageRoot/CombatBoard")
	var animated_state: Dictionary = combat_state.duplicate(true)
	var animated_enemies: Array = (animated_state.get("enemies", []) as Array).duplicate(true)
	var animated_enemy: Dictionary = (animated_enemies[0] as Dictionary).duplicate(true)
	var destination_tile := Vector2i(4, 2)
	animated_enemy["pos"] = destination_tile
	animated_enemies[0] = animated_enemy
	animated_state["enemies"] = animated_enemies
	var moving_presentation: Dictionary = {
		"unit_world_positions": {"enemy_1": board_view.call("world_position_for_tile", Vector2i(4, 1))},
		"unit_draw_tiles": {"enemy_1": destination_tile}
	}
	instance.call("_render_board_state", animated_state, moving_presentation)
	instance.call("_on_board_tile_hovered", Vector2i(3, 3))
	_assert_board_kept_animating_enemy(board_view, destination_tile, "Board hover during animation lock")
	instance.call("_render_board_state", animated_state, moving_presentation)
	instance.call("_on_turn_order_enemy_hovered", Vector2i(5, 2), "enemy_1")
	_assert_board_kept_animating_enemy(board_view, destination_tile, "Turn order hover during animation lock")
	instance.call("_render_board_state", animated_state, moving_presentation)
	instance.set("_hovered_card_index", 0)
	instance.call("_on_card_hover_ended", 0)
	_assert_board_kept_animating_enemy(board_view, destination_tile, "Card hover exit during animation lock")
	instance.call("_render_board_state", animated_state, moving_presentation)
	instance.call("_on_turn_order_enemy_unhovered", Vector2i(5, 2), "enemy_1")
	_assert_board_kept_animating_enemy(board_view, destination_tile, "Turn order unhover during animation lock")
	instance.queue_free()
	await process_frame

func _test_run_scene_discard_pile_is_face_up_without_count() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for discard pile coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var combat: CombatEngine = CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(103, _simple_room_layout(), {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["quick_stab"]
	deck["draw"] = ["brace", "quick_stab"]
	deck["discard"] = []
	deck["burned"] = []
	combat_state["deck"] = deck
	var run_state: Dictionary = instance.get("_run_state")
	run_state["mode"] = "combat"
	run_state["combat_state"] = combat_state
	instance.set("_run_state", run_state)
	instance.set("_combat_state", combat_state)
	instance.call("_refresh_pile_visuals")
	instance.call("_open_pile_view", "discard")
	await process_frame
	var pile_dialog: PanelContainer = instance.get("_pile_dialog")
	var pile_empty_label: Label = instance.get("_pile_dialog_empty")
	_assert(pile_dialog != null and pile_dialog.custom_minimum_size.x <= 540.0 and pile_dialog.custom_minimum_size.y <= 260.0, "The empty discard pile dialog should stay compact")
	var pile_close_button: Button = pile_dialog.find_child("CloseButton", true, false) as Button if pile_dialog != null else null
	_assert(pile_close_button != null and absf(pile_close_button.custom_minimum_size.x - pile_close_button.custom_minimum_size.y) <= 1.0, "The pile dialog close control should be a compact square button")
	_assert(pile_empty_label != null and pile_empty_label.visible and pile_empty_label.text == "No cards in this pile.", "The empty discard pile dialog should use final centered empty copy")
	instance.call("_close_pile_view")
	var hosts: Dictionary = instance.get("_pile_visual_hosts")
	var discard_host: Control = hosts.get("discard", null)
	_assert(discard_host != null and discard_host.get_child_count() == 1, "The empty discard pile should render as one card-sized empty frame")
	var badges: Dictionary = instance.get("_pile_badges")
	var draw_badge: Label = badges.get("draw", null)
	var pile_card_size: Vector2 = instance.call("_pile_display_card_size")
	_assert(draw_badge != null and draw_badge.visible and draw_badge.text == "2", "The draw pile should show its remaining card count")
	_assert(draw_badge != null and draw_badge.get_parent() == (instance.get("_pile_content_hosts") as Dictionary).get("draw", null), "The draw count badge should be positioned inside the pile content layer")
	_assert(draw_badge != null and draw_badge.size.x < pile_card_size.x * 0.4 and draw_badge.position.x > pile_card_size.x * 0.65, "The draw count badge should stay as a small top-right badge")
	var discard_badge: Label = badges.get("discard", null)
	_assert(discard_badge != null and not discard_badge.visible, "The discard pile should not display a card count badge")
	deck["discard"] = ["quick_stab"]
	combat_state["deck"] = deck
	instance.set("_combat_state", combat_state)
	instance.call("_refresh_pile_visuals")
	instance.call("_open_pile_view", "discard")
	await process_frame
	_assert(pile_dialog != null and pile_dialog.custom_minimum_size.x < 760.0 and pile_dialog.custom_minimum_size.y <= 450.0, "A one-card discard pile dialog should stay compact around its card")
	instance.call("_close_pile_view")
	discard_host = hosts.get("discard", null)
	var discard_top: Node = discard_host.get_child(discard_host.get_child_count() - 1) if discard_host != null and discard_host.get_child_count() > 0 else null
	var discard_widgets: Array[CardWidget] = _card_widgets_under(discard_top)
	_assert(discard_widgets.size() == 1 and discard_widgets[0].card_id == "quick_stab", "A non-empty discard pile should render the top card with the real card widget")
	var discard_card_size: Vector2 = (discard_top as Control).size if discard_top is Control else Vector2.ZERO
	_assert(discard_card_size.x > 0.0 and absf((discard_card_size.y / discard_card_size.x) - (352.0 / 250.0)) < 0.01, "Discard pile CardWidget should preserve the real card aspect ratio")
	instance.queue_free()
	await process_frame

func _test_run_scene_displays_owned_relic_icons() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for relic HUD coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var run_state: Dictionary = instance.get("_run_state")
	run_state["relics"] = ["ember_lens", "pilgrim_boots", "mirror_shard"]
	instance.set("_run_state", run_state)
	instance.call("_refresh_ui")
	var relic_bar: HFlowContainer = instance.get_node("Backdrop/Margin/MainVBox/TopBar/TitleBox/RelicBar")
	_assert(relic_bar.visible, "The run HUD should show relic icons when the player owns relics")
	_assert(relic_bar.get_child_count() == 3, "The run HUD should render one icon per owned relic")
	instance.queue_free()
	await process_frame

func _test_run_scene_relic_header_keeps_relics_and_intensity_tight() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for relic/intensity HUD layout coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var relic_ids: Array = [
		"iron_lung",
		"ember_lens",
		"pilgrim_boots",
		"mirror_shard",
		"coffin_nails",
		"reinforced_shield",
		"ashen_buckler",
		"flint_edge"
	]
	var combat: CombatEngine = CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(15126, _simple_room_layout(), {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["quick_stab"],
		"relics": relic_ids,
		"hand_size": 1,
		"heal_bonus": 0
	})
	combat_state["relics"] = relic_ids
	var run_state: Dictionary = instance.get("_run_state")
	run_state["mode"] = "combat"
	run_state["relics"] = relic_ids
	run_state["combat_state"] = combat_state
	instance.set("_run_state", run_state)
	instance.set("_combat_state", combat_state)
	instance.call("_refresh_ui")
	await process_frame
	await process_frame
	var relic_bar: HFlowContainer = instance.get_node("Backdrop/Margin/MainVBox/TopBar/TitleBox/RelicBar")
	_assert(relic_bar.visible and relic_bar.get_child_count() == relic_ids.size(), "Relic HUD should render all owned relic icons")
	if relic_bar.get_child_count() > 0:
		var first_row_y: float = (relic_bar.get_child(0) as Control).global_position.y
		for child: Node in relic_bar.get_children():
			var child_control: Control = child as Control
			_assert(child_control != null and absf(child_control.global_position.y - first_row_y) <= 1.0, "The first eight relic HUD icons should stay on one horizontal row")
	var intensity_bar: Control = instance.get("_intensity_bar") as Control
	_assert(intensity_bar != null and intensity_bar.visible, "Combat should show the elemental intensity HUD")
	if intensity_bar != null and intensity_bar.get_child_count() > 0:
		var first_badge: Control = intensity_bar.get_child(0) as Control
		_assert(first_badge.custom_minimum_size.x >= 86.0 and first_badge.custom_minimum_size.y >= 86.0, "Elemental intensity badges should be visibly larger than relic badges")
		_assert(intensity_bar.get_child_count() == 5, "Elemental intensity HUD should show all five elements")
		var top_y: float = first_badge.position.y
		var second_row_y: float = (intensity_bar.get_child(3) as Control).position.y
		for index: int in range(3):
			var badge: Control = intensity_bar.get_child(index) as Control
			_assert(absf(badge.position.y - top_y) <= 1.0, "Elemental intensity HUD should keep the first three icons on the top row")
		for index: int in range(3, 5):
			var badge: Control = intensity_bar.get_child(index) as Control
			_assert(absf(badge.position.y - second_row_y) <= 1.0, "Elemental intensity HUD should center the final two icons on the second row")
		var top_middle: Control = intensity_bar.get_child(1) as Control
		var bottom_left: Control = intensity_bar.get_child(3) as Control
		var bottom_right: Control = intensity_bar.get_child(4) as Control
		var top_middle_center: float = top_middle.position.x + top_middle.size.x * 0.5
		var bottom_pair_center: float = (bottom_left.position.x + bottom_right.position.x + bottom_right.size.x) * 0.5
		_assert(absf(top_middle_center - bottom_pair_center) <= 1.0, "Elemental intensity HUD second row should be centered under the top row")
		var relic_bottom: float = float(instance.call("_relic_bar_visible_bottom_y"))
		var gap: float = intensity_bar.global_position.y - relic_bottom
		_assert(gap >= 0.0 and gap <= 5.0, "Elemental intensity HUD should sit directly under the relic row without a stale layout gap")
	instance.queue_free()
	await process_frame

func _test_run_scene_attack_impact_presentation_drops_projectile_effect() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for attack impact presentation coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var impact_presentation: Dictionary = instance.call("_attack_impact_presentation", {
		"focus_actor_keys": ["player"],
		"focus_tiles": [Vector2i(5, 2)],
		"effect": {"kind": "ranged", "from": Vector2i(2, 4), "to": Vector2i(5, 2)},
		"effect_progress": 1.0,
		"impact_actor_keys": ["enemy_1"],
		"floating_texts": [{"tile": Vector2i(5, 2), "text": "-4"}]
	})
	_assert(not impact_presentation.has("effect"), "Attack impact presentation should not keep a completed projectile effect while redraw-driven impact text animates")
	_assert(not impact_presentation.has("effect_progress"), "Attack impact presentation should clear completed effect progress during impact text")
	_assert((impact_presentation.get("impact_actor_keys", []) as Array).has("enemy_1"), "Attack impact presentation should preserve hit flash actors")
	_assert((impact_presentation.get("floating_texts", []) as Array).size() == 1, "Attack impact presentation should preserve floating combat text")
	instance.queue_free()
	await process_frame

func _test_run_scene_auto_triggers_starting_npc_dialogue() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for NPC dialogue coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var dialogue_active: bool = bool(instance.get("_dialogue_active"))
	var speaker_label: Label = instance.get("_dialogue_name_label")
	var text_label: RichTextLabel = instance.get("_dialogue_text_label")
	var dialogue_dialog: PanelContainer = instance.get("_dialogue_dialog")
	var dialogue_footer: HBoxContainer = instance.get("_dialogue_footer")
	_assert(dialogue_active, "Starting in the waypoint should auto-trigger the friendly NPC dialogue")
	_assert(speaker_label != null and speaker_label.text == "Emaciated Man", "The start-room dialogue should identify the Emaciated Man as the speaker")
	_assert(text_label != null and text_label.text == "Hehehe. You're back...so soon.", "The opening NPC line should match the scripted default dialogue")
	_assert(dialogue_dialog != null and dialogue_dialog.custom_minimum_size.x <= 1200.0, "The opening NPC dialogue should stay narrower than the full viewport")
	_assert(dialogue_dialog != null and dialogue_dialog.custom_minimum_size.y <= 160.0, "The opening NPC dialogue should use a compact spoken-line panel")
	_assert(dialogue_footer != null and dialogue_footer.custom_minimum_size.y <= 40.0, "The opening NPC dialogue should not reserve choice-button height for a hint-only footer")
	instance.call("_complete_current_dialogue_line")
	instance.call("_advance_dialogue")
	_assert(int(instance.get("_dialogue_line_index")) == 1, "Advancing after the first line should move to the second line")
	_assert(text_label != null and text_label.text == "His creations got the best of you again.", "The second NPC line should preserve its trailing period")
	instance.call("_complete_current_dialogue_line")
	instance.call("_advance_dialogue")
	_assert(text_label != null and text_label.text == "Maybe this time's the one. Then again...probably not.", "The final NPC line should preserve its trailing period")
	instance.call("_complete_current_dialogue_line")
	instance.call("_advance_dialogue")
	_assert(not bool(instance.get("_dialogue_active")), "Advancing after the last NPC line should close the dialogue overlay")
	instance.queue_free()
	await process_frame

func _test_run_scene_character_stats_overlay_opens() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for character stats UI coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var progression: Dictionary = ProgressionStore.add_embers(
		ProgressionStore.default_data(),
		180
	)
	var run_state: Dictionary = instance.get("_run_state")
	run_state["progression"] = progression
	run_state["held_embers"] = 180
	run_state["unbanked_embers"] = 180
	instance.set("_run_state", run_state)
	instance.set("_progression", progression)
	instance.call("_close_dialogue")
	instance.call("_open_card_upgrade_overlay")
	await process_frame
	var upgrade_scrim: ColorRect = instance.get("_upgrade_scrim")
	var character_dialog: PanelContainer = instance.get("_upgrade_dialog")
	var stats_dialog_size: Vector2 = character_dialog.custom_minimum_size if character_dialog != null else Vector2.ZERO
	var stats_dialog_actual_size: Vector2 = character_dialog.size if character_dialog != null else Vector2.ZERO
	_assert(upgrade_scrim != null and upgrade_scrim.visible, "Opening the character menu should show the character stats overlay")
	_assert(upgrade_scrim.z_index >= 1200 and not upgrade_scrim.z_as_relative, "The character overlay should render above combat hand cards")
	_assert(_label_with_text(upgrade_scrim, "Character") != null, "The character overlay should use the Character title")
	_assert(_label_with_text(upgrade_scrim, "Level 1") != null, "The character overlay should show current level")
	_assert(_label_with_text(upgrade_scrim, "Held embers 180") != null, "The character overlay should show held embers")
	var character_art: TextureRect = upgrade_scrim.find_child("ProgressionCharacterArt", true, false) as TextureRect
	_assert(character_art != null and character_art.texture != null, "The character overlay should anchor the status panel with protagonist art")
	_assert(_label_with_text(upgrade_scrim, "Might") != null, "The character overlay should list physical stats")
	_assert(_label_with_text(upgrade_scrim, "Fire Magick") != null, "The character overlay should list elemental magick stats")
	instance.call("_on_character_stats_pressed")
	await process_frame
	_assert(character_dialog != null and character_dialog.custom_minimum_size == stats_dialog_size, "Switching from Stats to Gear should keep the character dialog size stable")
	_assert(_button_with_text(upgrade_scrim, "Gear") != null, "The character menu should expose a Gear tab")
	_assert(_button_with_text(upgrade_scrim, "Magic") != null, "The character menu should expose a Magic tab")
	_assert(_button_with_text(upgrade_scrim, "Stats") != null, "The character menu should keep the Stats tab available")
	_assert(_label_with_text(upgrade_scrim, "Loadout") != null, "The gear overlay should show equipped slots")
	_assert(_label_with_text(upgrade_scrim, "Inventory") != null, "The gear overlay should show inventory")
	_assert(_label_with_text(upgrade_scrim, "Deck") != null, "The gear overlay should show deck cards")
	_assert(_label_with_text(upgrade_scrim, "Attuned Magic 6/6") != null, "The gear overlay should include active attuned magic in the current deck")
	_assert(_label_with_text(upgrade_scrim, "Rewards") == null, "The gear overlay should not use the old Rewards deck heading")
	_assert(_label_with_text(upgrade_scrim, "Pale Spark") != null, "The gear overlay should show default attuned magic cards")
	var equipment_art: TextureRect = upgrade_scrim.find_child("EquipmentCharacterArt", true, false) as TextureRect
	_assert(equipment_art != null and equipment_art.texture != null, "The gear overlay should keep protagonist art visible")
	_assert(character_dialog != null and character_dialog.size == stats_dialog_actual_size, "Switching from Stats to Gear should keep the visible character dialog size stable")
	_assert(_label_with_text(upgrade_scrim, "Quick Stab, +2") == null, "Equipped loadout slots should not show a granted-card summary subline")
	var gear_run_state: Dictionary = instance.get("_run_state")
	var collected_equipment: Array = (gear_run_state.get("collected_equipment", []) as Array).duplicate()
	if not collected_equipment.has("iron_cleaver"):
		collected_equipment.append("iron_cleaver")
	gear_run_state["equipment_inventory"] = ["iron_cleaver"]
	gear_run_state["collected_equipment"] = collected_equipment
	gear_run_state["reward_cards"] = ["spark_dart", "frostbolt", "firebrand_volley", "chain_bolt", "static_lash"]
	gear_run_state["attuned_magic_cards"] = ["spark_dart", "frostbolt", "firebrand_volley", "chain_bolt", "pale_spark", "pale_spark"]
	gear_run_state["magic_inventory"] = ["static_lash"]
	instance.set("_run_state", gear_run_state)
	instance.call("_rebuild_progression_overlay")
	_assert(_label_with_text(upgrade_scrim, "Iron Cleaver") != null, "The gear overlay should render carried equipment")
	_assert(_label_with_text(upgrade_scrim, "Learned Magic") == null, "The gear overlay should not show the magic reserve panel")
	_assert(_label_with_text(upgrade_scrim, "Static Lash") == null, "The gear overlay deck should not show inactive reserve magic")
	_assert((instance.get("_magic_inventory_tiles") as Dictionary).is_empty(), "The gear overlay should not create reserve magic drag targets")
	_assert((instance.get("_magic_attuned_tiles") as Dictionary).is_empty(), "The gear overlay should not create attuned magic drag targets")
	instance.call("_switch_character_overlay_mode", "magic")
	await process_frame
	_assert(_label_with_text(upgrade_scrim, "Attuned Magic") != null, "The magic overlay should show attuned spell slots")
	_assert(_label_with_text(upgrade_scrim, "Learned Magic") != null, "The magic overlay should show learned reserve spells")
	_assert(_label_with_text(upgrade_scrim, "Deck") != null, "The magic overlay should show the current deck")
	_assert(_label_with_text(upgrade_scrim, "Static Lash") != null, "The magic overlay should render reserve magic cards")
	var magic_inventory_tiles: Dictionary = instance.get("_magic_inventory_tiles")
	var magic_attuned_tiles: Dictionary = instance.get("_magic_attuned_tiles")
	var reserve_tile: Control = magic_inventory_tiles.get(0, null) as Control
	var attuned_tile: Control = magic_attuned_tiles.get(4, null) as Control
	_assert(reserve_tile != null and _control_descendants_ignore_mouse(reserve_tile), "Reserve magic card tile children should be passive for stable hover and drag")
	_assert(attuned_tile != null and _control_descendants_ignore_mouse(attuned_tile), "Attuned magic card tile children should be passive for stable hover and drag")
	_assert(reserve_tile != null and reserve_tile.find_child("CardBadgeArt", true, false) is TextureRect, "Reserve magic card tiles should use card art as their visual background")
	_assert(attuned_tile != null and attuned_tile.find_child("CardBadgeArt", true, false) is TextureRect, "Attuned magic card tiles should use card art as their visual background")
	var magic_press := InputEventMouseButton.new()
	magic_press.button_index = MOUSE_BUTTON_LEFT
	magic_press.pressed = true
	magic_press.position = reserve_tile.get_global_rect().get_center() if reserve_tile != null else Vector2.ZERO
	magic_press.global_position = magic_press.position
	if reserve_tile != null:
		reserve_tile.call("_gui_input", magic_press)
	await process_frame
	_assert(str(instance.get("_magic_drag_card_id")) == "static_lash", "Pressing a learned magic tile should start a visible magic drag")
	var magic_release := InputEventMouseButton.new()
	magic_release.button_index = MOUSE_BUTTON_LEFT
	magic_release.pressed = false
	magic_release.position = attuned_tile.get_global_rect().get_center() if attuned_tile != null else Vector2.ZERO
	magic_release.global_position = magic_release.position
	if attuned_tile != null:
		attuned_tile.call("_gui_input", magic_release)
	await process_frame
	await process_frame
	await create_timer(0.20).timeout
	var magic_state: Dictionary = instance.get("_run_state")
	_assert(str((magic_state.get("attuned_magic_cards", []) as Array)[4]) == "static_lash", "Swapping from the magic overlay should attune reserve magic into late default slots")
	_assert((magic_state.get("magic_inventory", []) as Array).has("pale_spark"), "Swapping from the magic overlay should move replaced default magic to reserve")
	_assert((magic_state.get("deck_cards", []) as Array).has("static_lash"), "Swapping from the magic overlay should rebuild the active deck with attuned magic")
	magic_state["attuned_magic_cards"] = ["spark_dart", "frostbolt", "firebrand_volley", "chain_bolt", "pale_spark", "pale_spark"]
	magic_state["magic_inventory"] = ["static_lash"]
	instance.set("_run_state", magic_state)
	instance.call("_rebuild_progression_overlay")
	await process_frame
	magic_inventory_tiles = instance.get("_magic_inventory_tiles")
	magic_attuned_tiles = instance.get("_magic_attuned_tiles")
	reserve_tile = magic_inventory_tiles.get(0, null) as Control
	attuned_tile = magic_attuned_tiles.get(4, null) as Control
	if reserve_tile != null:
		magic_press.position = reserve_tile.get_global_rect().get_center()
		magic_press.global_position = magic_press.position
		reserve_tile.call("_gui_input", magic_press)
	await process_frame
	var double_release_position: Vector2 = attuned_tile.get_global_rect().get_center() if attuned_tile != null else Vector2.ZERO
	instance.call("_update_magic_overlay_drag", double_release_position)
	instance.call("_release_magic_overlay_drag", double_release_position)
	instance.call("_release_magic_overlay_drag", double_release_position)
	await process_frame
	await create_timer(0.30).timeout
	magic_state = instance.get("_run_state")
	_assert(str((magic_state.get("attuned_magic_cards", []) as Array)[4]) == "static_lash", "Duplicate magic release events should not swap the same spells back")
	_assert((magic_state.get("magic_inventory", []) as Array).has("pale_spark"), "Duplicate magic release events should leave the replaced default in learned magic")
	magic_state["attuned_magic_cards"] = ["spark_dart", "frostbolt", "firebrand_volley", "chain_bolt", "pale_spark", "pale_spark"]
	magic_state["magic_inventory"] = ["static_lash"]
	instance.set("_run_state", magic_state)
	instance.call("_rebuild_progression_overlay")
	await process_frame
	magic_inventory_tiles = instance.get("_magic_inventory_tiles")
	magic_attuned_tiles = instance.get("_magic_attuned_tiles")
	reserve_tile = magic_inventory_tiles.get(0, null) as Control
	attuned_tile = magic_attuned_tiles.get(4, null) as Control
	var overlap_press := InputEventMouseButton.new()
	overlap_press.button_index = MOUSE_BUTTON_LEFT
	overlap_press.pressed = true
	overlap_press.position = reserve_tile.get_global_rect().get_center() if reserve_tile != null else Vector2.ZERO
	overlap_press.global_position = overlap_press.position
	if reserve_tile != null:
		reserve_tile.call("_gui_input", overlap_press)
	await process_frame
	var off_target_release_position: Vector2 = Vector2.ZERO
	if attuned_tile != null:
		var attuned_rect: Rect2 = attuned_tile.get_global_rect()
		off_target_release_position = attuned_rect.position + Vector2(-16.0, attuned_rect.size.y * 0.5)
	instance.call("_update_magic_overlay_drag", off_target_release_position)
	await process_frame
	_assert(instance.call("_magic_tile_at", off_target_release_position).is_empty(), "The off-target magic release fixture should put the cursor outside the target tile")
	instance.call("_release_magic_overlay_drag", off_target_release_position)
	await process_frame
	await process_frame
	await create_timer(0.20).timeout
	magic_state = instance.get("_run_state")
	_assert(str((magic_state.get("attuned_magic_cards", []) as Array)[4]) == "static_lash", "Magic drop should resolve by held-card overlap when the cursor is just outside the target slot")
	magic_state["attuned_magic_cards"] = ["spark_dart", "frostbolt", "firebrand_volley", "chain_bolt", "pale_spark", "pale_spark"]
	magic_state["magic_inventory"] = ["static_lash"]
	instance.set("_run_state", magic_state)
	instance.call("_rebuild_progression_overlay")
	await process_frame
	magic_inventory_tiles = instance.get("_magic_inventory_tiles")
	magic_attuned_tiles = instance.get("_magic_attuned_tiles")
	reserve_tile = magic_inventory_tiles.get(0, null) as Control
	attuned_tile = magic_attuned_tiles.get(4, null) as Control
	var attuned_press := InputEventMouseButton.new()
	attuned_press.button_index = MOUSE_BUTTON_LEFT
	attuned_press.pressed = true
	attuned_press.position = attuned_tile.get_global_rect().get_center() if attuned_tile != null else Vector2.ZERO
	attuned_press.global_position = attuned_press.position
	if attuned_tile != null:
		attuned_tile.call("_gui_input", attuned_press)
	await process_frame
	var inventory_panel: Control = instance.get("_magic_inventory_drop_panel") as Control
	var panel_release_position: Vector2 = Vector2.ZERO
	if inventory_panel != null:
		var inventory_panel_rect: Rect2 = inventory_panel.get_global_rect()
		panel_release_position = inventory_panel_rect.position + Vector2(inventory_panel_rect.size.x * 0.52, inventory_panel_rect.size.y * 0.58)
	instance.call("_update_magic_overlay_drag", panel_release_position)
	await process_frame
	_assert(instance.call("_magic_tile_at", panel_release_position).is_empty(), "The magic panel release fixture should put the cursor in learned-panel whitespace")
	instance.call("_release_magic_overlay_drag", panel_release_position)
	await process_frame
	await process_frame
	await create_timer(0.20).timeout
	magic_state = instance.get("_run_state")
	_assert(str((magic_state.get("attuned_magic_cards", []) as Array)[4]) == "static_lash", "Dragging an attuned spell into learned-panel whitespace should swap with the nearest learned magic")
	instance.call("_switch_character_overlay_mode", "equipment")
	await process_frame
	var source_rect: Rect2 = instance.call("_equipment_inventory_icon_rect", "iron_cleaver")
	var tile_map: Dictionary = instance.get("_equipment_inventory_tiles")
	var source_tile: Control = tile_map.get("iron_cleaver", null) as Control
	_assert(source_tile != null and _control_descendants_ignore_mouse(source_tile), "Equipment inventory tile children should be passive so icon and text share one hover/drag target")
	var source_icon_chip: Control = source_tile.find_child("EquipmentIconChip", true, false) as Control if source_tile != null else null
	_assert(source_icon_chip != null and source_icon_chip.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Equipment inventory icon should be a passive part of the parent tile")
	_assert(source_icon_chip != null and source_icon_chip.tooltip_text.is_empty(), "Equipment inventory icon should not own a separate hover tooltip from its parent tile")
	_assert(source_icon_chip != null and absf(source_icon_chip.size.x - source_icon_chip.size.y) <= 1.0, "Equipment inventory icon should stay square inside the single drag tile")
	instance.call("_begin_equipment_overlay_drag", "iron_cleaver", source_rect, source_tile, source_rect.get_center())
	await process_frame
	var equipment_fx_layer: Control = instance.get("_equipment_fx_layer")
	var held_proxy: Control = null
	if equipment_fx_layer != null:
		held_proxy = equipment_fx_layer.find_child("EquipmentHeldProxy", true, false) as Control
	_assert(held_proxy != null and held_proxy.find_child("EquipmentGhostTexture", true, false) is TextureRect, "Equipment drag should show a lifted in-scene gear icon")
	_assert(held_proxy != null and held_proxy.modulate.a < 0.9, "Equipment drag icon should be translucent enough to read as held")
	_assert(source_tile == null or source_tile.modulate.a < 0.5, "Equipment drag should dim the source inventory tile")
	_assert(held_proxy != null and _label_with_text(held_proxy, "Iron Cleaver") == null, "Equipment held drag should be icon-first instead of a text plaque")
	instance.call("_cancel_equipment_overlay_drag", false)
	await process_frame
	var equipment_tooltip: Control = instance.call("_build_equipment_tooltip_panel", "iron_cleaver") as Control
	root.add_child(equipment_tooltip)
	await process_frame
	_assert(_card_widget_count_under(equipment_tooltip) == GameData.equipment_cards("iron_cleaver").size(), "Equipment hover should show real CardWidget previews for every granted card")
	for widget: CardWidget in _card_widgets_under(equipment_tooltip):
		_assert(widget.size.x > 0.0 and absf((widget.size.y / widget.size.x) - (352.0 / 250.0)) < 0.01, "Equipment tooltip card previews should preserve the real card aspect ratio")
	equipment_tooltip.queue_free()
	var card_tooltip: Control = instance.call("_build_card_tooltip_panel", "cleaver_hook") as Control
	root.add_child(card_tooltip)
	await process_frame
	_assert(_card_widget_count_under(card_tooltip) == 1, "Deck card hover should show a real CardWidget preview")
	for widget: CardWidget in _card_widgets_under(card_tooltip):
		_assert(widget.size.x > 0.0 and absf((widget.size.y / widget.size.x) - (352.0 / 250.0)) < 0.01, "Card tooltip previews should preserve the real card aspect ratio")
	card_tooltip.queue_free()
	var deck_badge: Control = instance.call("_build_equipment_card_badge", "cleaver_hook", ElementData.accent(GameData.card_element("cleaver_hook"))) as Control
	root.add_child(deck_badge)
	await process_frame
	var deck_badge_art: TextureRect = deck_badge.find_child("CardBadgeArt", true, false) as TextureRect
	_assert(deck_badge_art != null and deck_badge_art.texture != null, "Deck card badges should use the card art as their visual background")
	deck_badge.queue_free()
	instance.call("_equip_equipment_from_overlay", "iron_cleaver")
	await process_frame
	var equipped_state: Dictionary = instance.get("_run_state")
	_assert(str((equipped_state.get("equipped_equipment", {}) as Dictionary).get("weapon", "")) == "iron_cleaver", "Equipping from the gear overlay should update the weapon slot")
	_assert((equipped_state.get("equipment_inventory", []) as Array).has("training_sword"), "Equipping from the gear overlay should return the old weapon to inventory")
	var equipped_deck: Array = equipped_state.get("deck_cards", []) as Array
	_assert(equipped_deck.has("cleaver_hook") and equipped_deck.has("needle_flurry") and equipped_deck.has("butcher_chop"), "Equipping from the gear overlay should add the new weapon cards")
	_assert(not equipped_deck.has("whirlwind_slash") and not equipped_deck.has("bloody_lunge"), "Equipping from the gear overlay should remove the previous weapon cards")
	var board_view: CombatBoardView = instance.get_node("Backdrop/Margin/MainVBox/StageRoot/CombatBoard") as CombatBoardView
	var board_presentation: Dictionary = board_view.get("presentation") if board_view != null else {}
	_assert(str((board_presentation.get("equipped_equipment", {}) as Dictionary).get("weapon", "")) == "iron_cleaver", "Equipping gear should refresh board presentation for future player equipment art")
	instance.call("_switch_character_overlay_mode", "stats")
	await process_frame
	_assert(character_dialog != null and character_dialog.custom_minimum_size == stats_dialog_size, "Switching from Gear back to Stats should keep the character dialog size stable")
	_assert(character_dialog != null and character_dialog.size == stats_dialog_actual_size, "Switching from Gear back to Stats should keep the visible character dialog size stable")
	instance.call("_close_card_upgrade_overlay")
	instance.call("_open_level_up_overlay")
	var upgrade_dialog: PanelContainer = instance.get("_upgrade_dialog")
	_assert(upgrade_dialog != null and upgrade_dialog.custom_minimum_size.y <= 560.0, "The campfire level-up overlay should stay short enough to keep its action row visible")
	_assert(_label_with_text(upgrade_scrim, "Draw Strength") != null, "The campfire level-up overlay should use the Draw Strength title")
	_assert(_label_with_text(upgrade_scrim, "Choose 2 different stats.") != null, "The level-up overlay should explain the two-stat pick")
	_assert(_button_with_text(upgrade_scrim, "+") != null, "The level-up overlay should use plus buttons instead of set buttons")
	_assert(_button_with_text(upgrade_scrim, "-") != null, "The level-up overlay should use minus buttons beside stat values")
	_assert(_button_with_text(upgrade_scrim, "Set") == null, "The level-up overlay should not show old select buttons")
	instance.queue_free()
	await process_frame

func _test_run_scene_logs_local_analytics() -> void:
	AnalyticsStore.clear_storage()
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for analytics coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var combat: CombatEngine = CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(118, _simple_room_layout(), {
		"hp": 120,
		"max_hp": 200,
		"deck_cards": ["patch_up"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var player: Dictionary = (combat_state.get("player", {}) as Dictionary).duplicate(true)
	player["hp"] = 120
	combat_state["player"] = player
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["patch_up"]
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	combat_state["deck"] = deck
	combat_state["analytics"] = {"combat_id": "test_run_c001"}
	var run_state: Dictionary = instance.get("_run_state")
	run_state["mode"] = "combat"
	run_state["deck_cards"] = ["patch_up"]
	run_state["combat_state"] = combat_state
	run_state["analytics"] = {"run_id": "test_run", "combat_counter": 1}
	instance.set("_run_state", run_state)
	instance.set("_combat_state", combat_state)
	instance.call("_refresh_ui")
	instance.call("_analytics_log_playable_cards")
	instance.call("_on_card_pressed", 0)
	await create_timer(1.5).timeout
	var reward_run_state: Dictionary = instance.get("_run_state")
	reward_run_state["mode"] = "reward"
	reward_run_state["pending_reward"] = {
		"cards": ["spark_dart", "brace", "frostbolt"],
		"heal_amount": RunEngine.REWARD_HEAL,
		"ember_amount": 4
	}
	instance.set("_run_state", reward_run_state)
	instance.call("_refresh_ui")
	instance.call("_on_reward_card_pressed", "spark_dart")
	await process_frame
	var events: Array[Dictionary] = AnalyticsStore.load_all_events()
	var playable_events: Array[Dictionary] = _analytics_events_by_type(events, "card_became_playable")
	var played_events: Array[Dictionary] = _analytics_events_by_type(events, "card_played")
	var reward_events: Array[Dictionary] = _analytics_events_by_type(events, "reward_choice")
	_assert(not playable_events.is_empty(), "Combat analytics should record when a drawn card becomes playable")
	_assert(not played_events.is_empty(), "Combat analytics should record card play events")
	_assert(not reward_events.is_empty(), "Reward analytics should record reward choices")
	var play_event: Dictionary = played_events[played_events.size() - 1]
	var play_payload: Dictionary = play_event.get("payload", {})
	_assert(str(play_event.get("card_id", "")) == "patch_up", "Card play analytics should record the played card id")
	_assert(int(play_payload.get("player_heal_gained", 0)) == 30, "Card play analytics should capture observed healing")
	_assert(int(play_payload.get("player_block_gained", 0)) == 20, "Card play analytics should capture observed block gain")
	_assert(play_payload.has("card_plays_gained"), "Card play analytics should include current-turn play bonuses")
	_assert(play_payload.has("illusions_created"), "Card play analytics should include created illusion counts")
	_assert(play_payload.has("elemental_intensity_spent"), "Card play analytics should include intensity spent by relic payoffs")
	_assert(play_payload.has("terrain_hp_damage"), "Card play analytics should include terrain damage")
	_assert(play_payload.has("terrain_destroyed"), "Card play analytics should include destroyed terrain")
	_assert(play_payload.has("traps_triggered"), "Card play analytics should include triggered traps")
	_assert(play_payload.has("pickups_collected"), "Card play analytics should include collected battlefield pickups")
	_assert(bool((play_payload.get("enemy_status_applied", {}) as Dictionary).has("immobilize")), "Card play analytics should include enemy immobilize application")
	_assert(bool((play_payload.get("player_status_applied", {}) as Dictionary).has("immobilize")), "Card play analytics should include player immobilize application")
	var reward_event: Dictionary = reward_events[reward_events.size() - 1]
	var reward_payload: Dictionary = reward_event.get("payload", {})
	_assert(str(reward_payload.get("choice_kind", "")) == "card", "Reward analytics should distinguish card picks from heal skips")
	_assert(str(reward_payload.get("selected_card_id", "")) == "spark_dart", "Reward analytics should record the selected reward card")
	instance.queue_free()
	await process_frame

func _test_main_menu_shows_continue_for_saved_run() -> void:
	var main_menu_scene: PackedScene = load("res://scenes/main_menu.tscn")
	if main_menu_scene == null:
		_failures.append("Main menu scene should load for continue-button coverage")
		return
	var run_engine: RunEngine = RunEngine.new()
	ProgressionStore.save_run_state(run_engine.create_new_run(88, ProgressionStore.default_data()))
	var instance: Node = main_menu_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var continue_button: Button = instance.get_node("Backdrop/Margin/Center/BodyRow/HeroPanel/HeroMargin/HeroVBox/ButtonRow/ContinueButton")
	var boss_button: Button = instance.get_node("Backdrop/Margin/Center/BodyRow/HeroPanel/HeroMargin/HeroVBox/ButtonRow/BossButton")
	_assert(continue_button.visible, "Main menu should expose Continue when a saved run exists")
	_assert(not boss_button.visible, "Main menu should keep the debug boss shortcut hidden by default")
	instance.queue_free()
	ProgressionStore.clear_saved_run()
	await process_frame

func _analytics_events_by_type(events: Array[Dictionary], event_type: String) -> Array[Dictionary]:
	var filtered: Array[Dictionary] = []
	for event: Dictionary in events:
		if str(event.get("event_type", "")) == event_type:
			filtered.append(event)
	return filtered

func _set_enemy_intent(state: Dictionary, enemy_index: int, intent: Dictionary) -> void:
	var enemies: Array = (state.get("enemies", []) as Array).duplicate(true)
	if enemy_index < 0 or enemy_index >= enemies.size():
		return
	var enemy: Dictionary = enemies[enemy_index]
	enemy["intent"] = intent.duplicate(true)
	enemy["block"] = 0
	enemies[enemy_index] = enemy
	state["enemies"] = enemies

func _enemy_intent_by_id(enemy_type: String, intent_id: String) -> Dictionary:
	for intent_var: Variant in GameData.enemy_def(enemy_type).get("intents", []):
		if typeof(intent_var) != TYPE_DICTIONARY:
			continue
		var intent: Dictionary = intent_var
		if str(intent.get("id", "")) == intent_id:
			return intent.duplicate(true)
	return {}

func _simple_room_layout() -> Dictionary:
	return {
		"name": "Test Room",
		"coord": Vector2i(1, 0),
		"type": "combat",
		"grid": _simple_grid(),
		"player_start": Vector2i(2, 4),
		"enemies": [
			{
				"id": 1,
				"type": "crawler",
				"pos": Vector2i(5, 2),
				"hp": 14,
				"max_hp": 14,
				"block": 0
			}
		],
		"loot": []
	}

func _aoe_test_room_layout() -> Dictionary:
	return {
		"name": "Area Room",
		"coord": Vector2i(1, 1),
		"type": "combat",
		"grid": _simple_grid(),
		"player_start": Vector2i(2, 5),
		"enemies": [
			{
				"id": 1,
				"type": "crawler",
				"pos": Vector2i(4, 3),
				"hp": 14,
				"max_hp": 14,
				"block": 0
			},
			{
				"id": 2,
				"type": "harrier",
				"pos": Vector2i(5, 3),
				"hp": 10,
				"max_hp": 10,
				"block": 0
			}
		],
		"loot": []
	}

func _zekarion_test_room_layout(depth: int = 4, coord: Vector2i = Vector2i(4, 0)) -> Dictionary:
	return {
		"name": "Tempest God's Perch",
		"coord": coord,
		"depth": depth,
		"type": "boss",
		"element": ElementData.LIGHTNING,
		"grid": _simple_grid(),
		"player_start": Vector2i(2, 6),
		"enemies": [
			{
				"id": 1,
				"type": "zekarion",
				"element": ElementData.LIGHTNING,
				"pos": Vector2i(4, 3),
				"footprint": Vector2i(2, 2),
				"hp": 72,
				"max_hp": 72,
				"block": 0
			},
			{
				"id": 2,
				"type": "lightning_wisp",
				"element": ElementData.LIGHTNING,
				"pos": Vector2i(2, 3),
				"hp": 6,
				"max_hp": 6,
				"block": 0
			},
			{
				"id": 3,
				"type": "lightning_wisp",
				"element": ElementData.LIGHTNING,
				"pos": Vector2i(6, 5),
				"hp": 6,
				"max_hp": 6,
				"block": 0
			}
		],
		"loot": []
	}

func _defeated_zekarion_combat_state(depth: int, coord: Vector2i) -> Dictionary:
	var combat_state: Dictionary = _zekarion_test_room_layout(depth, coord)
	combat_state["room_name"] = "Tempest God's Perch"
	combat_state["room_coord"] = coord
	combat_state["room_depth"] = depth
	combat_state["room_type"] = "boss"
	combat_state["room_element"] = ElementData.LIGHTNING
	combat_state["player"] = {
		"pos": Vector2i(2, 6),
		"hp": 9,
		"max_hp": 36,
		"block": 0,
		"stoneskin": 0
	}
	for index: int in range((combat_state.get("enemies", []) as Array).size()):
		var enemy: Dictionary = (combat_state.get("enemies", []) as Array)[index]
		if str(enemy.get("type", "")) == "zekarion":
			enemy["hp"] = 0
			(combat_state.get("enemies", []) as Array)[index] = enemy
	return combat_state

func _dead_hand_room_layout() -> Dictionary:
	return {
		"name": "Dead Hand Room",
		"coord": Vector2i(2, 2),
		"type": "combat",
		"grid": [
			["wall", "wall", "wall", "wall", "wall", "wall", "wall"],
			["wall", "ash", "ash", "wall", "ash", "ash", "wall"],
			["wall", "ash", "wall", "wall", "wall", "ash", "wall"],
			["wall", "wall", "wall", "ash", "wall", "wall", "wall"],
			["wall", "ash", "wall", "wall", "wall", "ash", "wall"],
			["wall", "ash", "ash", "wall", "ash", "ash", "wall"],
			["wall", "wall", "wall", "wall", "wall", "wall", "wall"]
		],
		"player_start": Vector2i(3, 3),
		"enemies": [
			{
				"id": 1,
				"type": "crawler",
				"pos": Vector2i(1, 1),
				"hp": 14,
				"max_hp": 14,
				"block": 0
			}
		],
		"loot": []
	}

func _optional_followup_room_layout() -> Dictionary:
	return {
		"name": "Optional Followup",
		"coord": Vector2i(3, 1),
		"type": "combat",
		"grid": _simple_grid(),
		"player_start": Vector2i(2, 5),
		"enemies": [
			{
				"id": 1,
				"type": "crawler",
				"pos": Vector2i(6, 1),
				"hp": 14,
				"max_hp": 14,
				"block": 0
			}
		],
		"loot": []
	}

func _find_route_to_coord(run_engine: RunEngine, start_state: Dictionary, target: Vector2i, max_steps: int = 20) -> Array:
	var queue: Array = [{"state": start_state.duplicate(true), "path": []}]
	var visited: Dictionary = {}
	while not queue.is_empty():
		var entry: Dictionary = queue.pop_front()
		var state: Dictionary = entry.get("state", {})
		var path: Array = (entry.get("path", []) as Array).duplicate()
		var key: String = _route_search_key(state)
		if visited.has(key):
			continue
		visited[key] = true
		if state.get("current_room", Vector2i(999, 999)) == target:
			return path
		if path.size() >= max_steps:
			continue
		for move: Vector2i in run_engine.available_moves(state):
			var next_path: Array = path.duplicate()
			next_path.append(move)
			queue.append({
				"state": _route_state_after_step(run_engine, state, move),
				"path": next_path
			})
	return []

func _route_state_after_step(run_engine: RunEngine, state: Dictionary, move: Vector2i) -> Dictionary:
	return _route_clear_current_combat(run_engine, run_engine.move_to_room(state, move))

func _route_clear_current_combat(run_engine: RunEngine, state: Dictionary) -> Dictionary:
	if str(state.get("mode", "")) != "combat":
		return state
	var next_state: Dictionary = state.duplicate(true)
	var rooms: Dictionary = next_state.get("rooms", {}).duplicate(true)
	var current: Vector2i = next_state.get("current_room", Vector2i.ZERO)
	var room_key: String = "%d,%d" % [current.x, current.y]
	var room: Dictionary = run_engine.room_metadata(next_state, current).duplicate(true)
	room["cleared"] = true
	rooms[room_key] = room
	next_state["rooms"] = rooms
	next_state["mode"] = "room"
	next_state["combat_state"] = {}
	return run_engine.repair_loaded_run_state(next_state)

func _route_search_key(state: Dictionary) -> String:
	var flags: Array[String] = []
	var rooms: Dictionary = state.get("rooms", {})
	for room_key_var: Variant in rooms.keys():
		var room_key: String = str(room_key_var)
		var room: Dictionary = rooms[room_key]
		if bool(room.get("revealed", false)) or bool(room.get("sealed", false)):
			flags.append("%s:%d:%d" % [room_key, int(room.get("revealed", false)), int(room.get("sealed", false))])
	flags.sort()
	var current: Vector2i = state.get("current_room", Vector2i.ZERO)
	return "%d,%d|%s" % [current.x, current.y, ",".join(flags)]

func _first_loot_of_kind(combat_state: Dictionary, loot_kind: String) -> Dictionary:
	for loot_var: Variant in combat_state.get("loot", []):
		if typeof(loot_var) != TYPE_DICTIONARY:
			continue
		var loot: Dictionary = loot_var
		if str(loot.get("kind", "")) == loot_kind:
			return loot
	return {}

func _simple_grid() -> Array:
	var grid: Array = []
	for y: int in range(8):
		var row: Array[String] = []
		for x: int in range(8):
			if x == 0 or y == 0 or x == 7 or y == 7:
				row.append("wall")
			else:
				row.append("ash")
		grid.append(row)
	return grid

func _enemy_footprint_tiles_for_test(enemy: Dictionary) -> Array[Vector2i]:
	var origin: Vector2i = enemy.get("pos", Vector2i.ZERO)
	var footprint: Vector2i = enemy.get("footprint", Vector2i.ONE)
	var tiles: Array[Vector2i] = []
	for y: int in range(maxi(1, footprint.y)):
		for x: int in range(maxi(1, footprint.x)):
			tiles.append(origin + Vector2i(x, y))
	return tiles

func _find_boundary_segment(segments: Array, orientation: String) -> Dictionary:
	for segment_var: Variant in segments:
		if typeof(segment_var) != TYPE_DICTIONARY:
			continue
		var segment: Dictionary = segment_var
		if str(segment.get("orientation", "")) == orientation:
			return segment
	return {}

func _buttons_under(node: Node) -> Array[Button]:
	var buttons: Array[Button] = []
	if node is Button:
		buttons.append(node)
	for child: Node in node.get_children():
		buttons.append_array(_buttons_under(child))
	return buttons

func _button_with_text(node: Node, text: String) -> Button:
	for button: Button in _buttons_under(node):
		if button.text == text:
			return button
	return null

func _labels_under(node: Node) -> Array[Label]:
	var labels: Array[Label] = []
	if node is Label:
		labels.append(node)
	for child: Node in node.get_children():
		labels.append_array(_labels_under(child))
	return labels

func _label_with_text(node: Node, text: String) -> Label:
	for label: Label in _labels_under(node):
		if label.text == text:
			return label
	return null

func _texture_rects_under(node: Node) -> Array[TextureRect]:
	var texture_rects: Array[TextureRect] = []
	if node is TextureRect:
		texture_rects.append(node)
	for child: Node in node.get_children():
		texture_rects.append_array(_texture_rects_under(child))
	return texture_rects

func _control_descendants_ignore_mouse(node: Node) -> bool:
	for child: Node in node.get_children():
		if child is Control and (child as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
			return false
		if not _control_descendants_ignore_mouse(child):
			return false
	return true

func _card_widget_count_under(node: Node) -> int:
	if node == null:
		return 0
	var count: int = 1 if node.get_script() == CardWidgetScript else 0
	for child: Node in node.get_children():
		count += _card_widget_count_under(child)
	return count

func _card_widgets_under(node: Node) -> Array[CardWidget]:
	var widgets: Array[CardWidget] = []
	if node == null:
		return widgets
	if node.get_script() == CardWidgetScript:
		widgets.append(node as CardWidget)
	for child: Node in node.get_children():
		widgets.append_array(_card_widgets_under(child))
	return widgets

func _run_scene_choice_button_host(instance: Node) -> Node:
	var overlay: Node = instance.get("_choice_button_overlay") as Node
	if overlay != null and overlay.get_child_count() > 0:
		return overlay
	return instance.get_node("Backdrop/Margin/MainVBox/BottomStack/HandRow/LeftActionStack/ChoiceBar")

func _assert_button_uses_native_ratio(button: Button, min_height: float, message: String) -> void:
	var minimum_size: Vector2 = button.custom_minimum_size
	_assert(minimum_size.y >= min_height, message)
	if minimum_size.y <= 0.0:
		_failures.append("%s should have a positive minimum height" % message)
		return
	var ratio: float = minimum_size.x / minimum_size.y
	_assert(is_equal_approx(ratio, UiSkin.BUTTON_TEXTURE_ASPECT), "%s should preserve the button art ratio" % message)

func _assert_board_kept_animating_enemy(board_view: Node, expected_tile: Vector2i, context: String) -> void:
	var rendered_state: Dictionary = board_view.get("combat_state")
	var enemies: Array = rendered_state.get("enemies", [])
	if enemies.is_empty():
		_failures.append("%s should keep a rendered enemy on the board" % context)
		return
	var enemy: Dictionary = enemies[0]
	_assert(enemy.get("pos", Vector2i.ZERO) == expected_tile, "%s should not redraw stale combat state over the active animation" % context)
	var presentation: Dictionary = board_view.get("presentation")
	_assert((presentation.get("unit_world_positions", {}) as Dictionary).has("enemy_1"), "%s should preserve moving unit presentation" % context)
	_assert((presentation.get("unit_draw_tiles", {}) as Dictionary).has("enemy_1"), "%s should preserve moving unit draw tile" % context)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
