extends SceneTree

const GameData = preload("res://scripts/game_data.gd")
const AnalyticsStore = preload("res://scripts/analytics_store.gd")
const ActionIcons = preload("res://scripts/action_icon_library.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RoomGenerator = preload("res://scripts/room_generator.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")
const CombatBoardView = preload("res://scripts/combat_board_view.gd")
const LabyrinthMapView = preload("res://scripts/labyrinth_map_view.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const DialogueEngine = preload("res://scripts/dialogue_engine.gd")
const HandFanContainer = preload("res://scripts/hand_fan_container.gd")
const PathUtils = preload("res://scripts/path_utils.gd")
const RoomIcons = preload("res://scripts/room_icon_library.gd")
const UiTooltipPanel = preload("res://scripts/ui_tooltip_panel.gd")

var _failures: Array[String] = []

func _initialize() -> void:
	ProgressionStore.set_storage_path("user://labyrinth_progression_test.json")
	ProgressionStore.set_run_storage_path("user://labyrinth_run_test.save")
	AnalyticsStore.set_storage_dir("user://labyrinth_analytics_test")
	AnalyticsStore.clear_storage()
	var default_progression: Dictionary = ProgressionStore.default_data()
	_assert(GameData.cards().size() >= 20, "Card data should load")
	_assert(GameData.enemies().size() >= 5, "Enemy data should load")
	_assert(GameData.npcs().size() >= 1, "NPC data should load")
	_assert(GameData.relics().size() >= 5, "Relic data should load")
	_assert(GameData.upgrades().size() >= 3, "Upgrade data should load")
	_test_room_generation_is_deterministic()
	_test_room_generation_keeps_spawn_reachable()
	_test_room_generation_enemy_spawns_keep_player_halo()
	_test_room_generation_blocks_door_tiles()
	_test_room_generation_uses_perimeter_walls_only()
	_test_room_generation_uses_stone_floor_with_moss_accents()
	_test_room_generation_populates_elemental_traps()
	_test_campfire_room_uses_bonfire_layout()
	_test_room_generation_scales_enemy_density()
	_test_boss_room_spawns_zekarion_with_wisps()
	_test_start_room_spawns_emaciated_man()
	_test_fatigue_draws_cost_health_and_burn_removes_card()
	_test_two_card_turn_draw_flow()
	_test_enemy_death_grants_card_play_and_embers()
	_test_summoned_enemy_death_does_not_grant_card_play()
	_test_hand_draw_caps_at_eight()
	_test_first_attack_bonus_damage_math()
	_test_healing_cards_are_burned_and_downweighted()
	_test_low_movement_enemies_advance_without_outpacing_crawlers()
	_test_player_block_absorbs_full_enemy_phase()
	_test_enemy_preview_block_mitigates_current_turn_damage()
	_test_aoe_hits_multiple_targets()
	_test_close_aoe_hits_adjacent_targets()
	_test_enemy_phase_preserves_preview_cycle()
	_test_elemental_room_rewards_follow_affinity(default_progression)
	_test_chain_hits_clustered_enemies()
	_test_freeze_and_shock_control_turn_flow()
	_test_traps_trigger_and_apply_current_turn_control()
	_test_traps_roll_control_to_next_turn_when_no_plays_remain()
	_test_move_paths_only_cross_required_traps()
	_test_poison_and_stoneskin_behaviors()
	_test_out_of_range_elemental_enemy_attack_skips_step()
	_test_enemy_threat_tiles_follow_intent()
	_test_zekarion_summons_wisps_when_alone()
	_test_summoned_wisps_receive_preview_intents()
	_test_zekarion_ignores_shock_status()
	_test_enemy_pathfinding_avoids_traps()
	_test_shallow_elemental_enemy_actions_scale_back()
	_test_status_badges_surface_countdowns()
	_test_player_restriction_badges_show_turn_lock()
	_test_trap_tooltip_surfaces_damage_and_effect()
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
	_test_trial_enemy_art_uses_matching_idle_sheets()
	_test_zekarion_uses_matching_idle_sheet()
	_test_lightning_wisp_uses_normal_loop_idle_sheet()
	_test_emaciated_man_uses_matching_idle_sheet()
	_test_unit_hud_stacks_above_sprite_art()
	_test_combat_board_zooms_to_rendered_room_bounds()
	_test_foreground_props_fade_when_covering_behind_units()
	_test_pillar_art_fits_bottom_center_without_stretching()
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
	_test_combat_board_draw_order_tracks_moving_unit_world_position()
	_test_keyword_icon_library_surfaces_tooltips()
	_test_room_icon_library_covers_door_room_types()
	_test_minimap_uses_door_icons_and_greys_cleared_rooms()
	_test_combat_board_loads_door_icons_for_room_types()
	_test_run_map_room_types()
	_test_run_map_ring_links_and_outward_quarter()
	_test_run_map_seals_departed_rooms()
	_test_run_map_never_moves_back_toward_center()
	_test_empty_treasure_room_falls_back_to_room_mode()
	_test_loaded_run_repairs_stranded_room_visibility()
	_test_combat_finish_generates_reward_state()
	_test_boss_victory_restores_player_health()
	_test_progression_save_and_purchase(default_progression)
	_test_emaciated_man_unlocks_card_upgrade_dialogue()
	_test_recovery_marker_flow()
	_test_recovery_marker_expires_after_next_run()
	_test_run_state_save_and_load()
	_test_hand_fan_layout_lifts_center_cards()
	_test_default_theme_uses_pixel_font()
	await _test_main_scenes_instantiate()
	await _test_run_scene_debug_boss_fixture_boots()
	await _test_run_scene_offers_pass_during_combat()
	await _test_run_scene_offers_pass_when_hand_dead()
	await _test_run_scene_campfire_choices_use_context_overlay()
	await _test_run_scene_optional_followup_attack_stays_playable()
	await _test_run_scene_move_attack_shortcut_clicks_enemy()
	await _test_run_scene_block_card_skips_dead_move()
	await _test_run_scene_targetless_card_click_commits_play()
	await _test_run_scene_damage_display_matches_bonus()
	await _test_run_scene_ranged_cards_show_range()
	await _test_run_scene_preview_normalizes_untyped_target_tiles()
	await _test_run_scene_move_previews_avoid_traps_when_possible()
	await _test_run_scene_hovered_enemy_shows_threat_overlay()
	await _test_run_scene_discard_pile_is_face_up_without_count()
	await _test_run_scene_displays_owned_relic_icons()
	await _test_run_scene_auto_triggers_starting_npc_dialogue()
	await _test_run_scene_card_upgrade_overlay_opens()
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

func _test_campfire_room_uses_bonfire_layout() -> void:
	var generator: RoomGenerator = RoomGenerator.new()
	var room: Dictionary = generator.generate_room(91, {
		"coord": Vector2i(2, 0),
		"depth": 2,
		"type": "campfire"
	}, Vector2i(1, 0))
	var grid: Array = room.get("grid", [])
	for pillar_tile: Vector2i in [Vector2i(2, 2), Vector2i(6, 2), Vector2i(2, 6), Vector2i(6, 6)]:
		_assert(str((grid[pillar_tile.y] as Array)[pillar_tile.x]) == "pillar", "Campfire rooms should place pillars on the second-to-last ring corners")
	for y: int in range(3, 6):
		for x: int in range(3, 6):
			_assert(str((grid[y] as Array)[x]) == "ash", "The campfire bonfire footprint should remain floor tiles")
	var floor_moss: Array = (room.get("moss", {}) as Dictionary).get("floor", [])
	for tile: Vector2i in floor_moss:
		_assert(tile.x < 3 or tile.x > 5 or tile.y < 3 or tile.y > 5, "Campfire moss should leave the 3x3 bonfire footprint visually clear")

func _test_room_generation_populates_elemental_traps() -> void:
	var generator: RoomGenerator = RoomGenerator.new()
	var trap_count_histogram: Dictionary = {}
	var total_center_distance: float = 0.0
	var total_traps: int = 0
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
			total_center_distance += pos.distance_to(Vector2(4.0, 4.0))
			if pos.x <= 2 and pos.y <= 2 or pos.x <= 2 and pos.y >= 6 or pos.x >= 6 and pos.y <= 2 or pos.x >= 6 and pos.y >= 6:
				corner_traps += 1
			total_traps += 1
			occupied[pos] = true
	_assert(trap_count_histogram.has(2) and trap_count_histogram.has(3), "Trap counts should vary between two and three across generated rooms")
	_assert(total_center_distance / float(total_traps) < 2.2, "Trap placement should favor central traversal lanes over room corners")
	_assert(corner_traps < total_traps / 4, "Trap placement should rarely choose room-corner bands")

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
	var boss_room: Dictionary = generator.generate_room(27, {
		"coord": Vector2i(4, 0),
		"depth": 4,
		"type": "boss"
	}, Vector2i(1, 0))
	_assert((depth_one_room.get("enemies", []) as Array).size() >= 3, "Opening combat rooms should pack at least three enemies")
	_assert((depth_three_room.get("enemies", []) as Array).size() >= 5, "Outer combat rooms should feel denser than the opening ring")
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
		"deck_cards": ["shadow_gate", "quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var deck: Dictionary = state.get("deck", {}).duplicate(true)
	deck["hand"] = ["shadow_gate"]
	deck["draw"] = []
	deck["discard"] = ["quick_stab"]
	state["deck"] = deck
	var hp_before: int = int((state.get("player", {}) as Dictionary).get("hp", 0))
	state = combat.finish_player_card(state, 0)
	_assert((state.get("deck", {}) as Dictionary).get("burned", []).has("shadow_gate"), "Burn cards should move to the burned pile")
	state = combat.prepare_next_player_turn(state)
	var hp_after: int = int((state.get("player", {}) as Dictionary).get("hp", 0))
	_assert(hp_after == hp_before - 2, "Cycling the deck should deal fatigue damage")
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
			"hp": 14,
			"max_hp": 14,
			"block": 4
		}
	]
	var action: Dictionary = {"type": "melee", "damage": 6, "range": 1}
	_assert(combat.final_damage_for_player_action(state, action) == 8, "Displayed attack damage should include the first-attack bonus before the card resolves")
	state = combat.apply_player_action(state, action, Vector2i(3, 4))
	var enemy: Dictionary = (state.get("enemies", []) as Array)[0]
	_assert(int(enemy.get("block", 0)) == 0, "Damage should remove enemy block before health")
	_assert(int(enemy.get("hp", 0)) == 10, "A 6-damage strike with Ember Lens into 4 block should deal 4 health damage")
	_assert(combat.attack_bonus_for_current_turn(state) == 0, "The first-attack bonus should be consumed after the hit resolves")

func _test_healing_cards_are_burned_and_downweighted() -> void:
	for card_id: String in ["patch_up", "rallying_breath", "last_light"]:
		var card: Dictionary = GameData.card_def(card_id)
		_assert(bool(card.get("burn", false)), "Healing cards should burn so recovery is a shorter-term tactical choice")
	_assert(int((GameData.card_def("patch_up").get("actions", [])[0] as Dictionary).get("amount", 0)) <= 3, "Patch Up should heal less than the original starter version")
	_assert(int((GameData.card_def("rallying_breath").get("actions", [])[0] as Dictionary).get("amount", 0)) <= 4, "Rallying Breath should heal less than the original common version")
	_assert(int((GameData.card_def("last_light").get("actions", [])[0] as Dictionary).get("amount", 0)) <= 6, "Last Light should heal less than the original rare version")
	_assert(GameData.reward_offer_weight("rallying_breath") < GameData.reward_offer_weight("iron_wheel"), "Healing cards should be rarer reward offers than standard non-heal cards")

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

func _test_enemy_preview_block_mitigates_current_turn_damage() -> void:
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
	_assert(int(blocked_enemy.get("block", 0)) == 4, "Enemy block should appear as soon as the intent is revealed")
	state = combat.apply_player_action(state, {"type": "melee", "damage": 6, "range": 1}, Vector2i(3, 4))
	blocked_enemy = (state.get("enemies", []) as Array)[0]
	_assert(int(blocked_enemy.get("hp", 0)) == 12, "Revealed enemy block should mitigate the current player turn immediately")
	_assert(int(blocked_enemy.get("block", 0)) == 0, "Enemy block should be reduced before health when struck")

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
	state["player"] = {"pos": Vector2i(4, 4), "hp": 20, "max_hp": 20, "block": 0, "stoneskin": 0}
	state["enemies"] = [
		{"id": 1, "type": "crawler", "pos": Vector2i(4, 3), "hp": 14, "max_hp": 14, "block": 0},
		{"id": 2, "type": "harrier", "pos": Vector2i(5, 4), "hp": 10, "max_hp": 10, "block": 0},
		{"id": 3, "type": "acolyte", "pos": Vector2i(5, 5), "hp": 12, "max_hp": 12, "block": 0}
	]
	var action: Dictionary = GameData.card_def("whirlwind_slash").get("actions", [])[0]
	state = combat.apply_player_action(state, action)
	var enemies: Array = state.get("enemies", [])
	_assert(int((enemies[0] as Dictionary).get("hp", 0)) == 8, "Close AOE should hit the northern adjacent tile")
	_assert(int((enemies[1] as Dictionary).get("hp", 0)) == 4, "Close AOE should hit the eastern adjacent tile")
	_assert(int((enemies[2] as Dictionary).get("hp", 0)) == 12, "Close AOE should not hit diagonal tiles")

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
		elif card_element == "none":
			neutral_count += 1
	_assert(elemental_count == 2, "Elemental combat rewards should offer two cards from the room's element")
	_assert(neutral_count == 1, "Elemental combat rewards should keep one neutral choice")

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
	var shallow_fire: Dictionary = combat.call("_elementalize_enemy_action", {"type": "melee", "damage": 4, "range": 1}, "fire", 1)
	var deep_fire: Dictionary = combat.call("_elementalize_enemy_action", {"type": "melee", "damage": 4, "range": 1}, "fire", 3)
	_assert(int(shallow_fire.get("burn", 0)) < int(deep_fire.get("burn", 0)), "Shallow elemental rooms should use lighter status payloads than deeper rooms")

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
	_assert(not move_tiles.has(Vector2i(6, 2)), "Advancing threat previews should exclude tiles that move farther from the player")
	_assert(attack_tiles.has(Vector2i(2, 4)), "Threat previews should include the player's tile when the intent can connect after moving")
	_assert(not attack_tiles.has(Vector2i(4, 2)), "Attack overlays should stay separate from the movement tiles they build from")

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
		"stun": 1,
		"poison": {"damage": 4, "delay": 2}
	})
	_assert(badges.size() == 5, "Status badges should surface each active elemental status independently")
	_assert(str((badges[0] as Dictionary).get("icon", "")) == "burn", "Burn badges should use the shared burn icon")
	_assert(int((badges[0] as Dictionary).get("count", 0)) == 5, "Burn badges should show their remaining countdown")
	_assert(str((badges[3] as Dictionary).get("icon", "")) == "stun", "Stun badges should use the shared stun icon")
	_assert(str((badges[4] as Dictionary).get("icon", "")) == "poison", "Poison badges should use the shared poison icon")
	_assert(int((badges[4] as Dictionary).get("count", 0)) == 2, "Poison badges should show the turns remaining before it lands")

func _test_player_restriction_badges_show_turn_lock() -> void:
	var board := CombatBoardView.new()
	var statuses: Dictionary = board.call("_player_display_statuses", {"burn": 0, "freeze": 0, "shock": 0}, {"frozen": true, "shocked": false})
	_assert(int(statuses.get("freeze", 0)) == 1, "Frozen turns should still surface a freeze badge even after the restriction consumes the stored counter")
	statuses = board.call("_player_display_statuses", {"burn": 0, "freeze": 0, "shock": 0}, {"frozen": false, "shocked": true})
	_assert(int(statuses.get("shock", 0)) == 1, "Shocked turns should still surface a shock badge even after the restriction consumes the stored counter")
	statuses = board.call("_player_display_statuses", {"burn": 0, "freeze": 0, "shock": 0, "stun": 0}, {"frozen": false, "shocked": false, "stunned": true})
	_assert(int(statuses.get("stun", 0)) == 1, "Stunned turns should still surface a stun badge even after the restriction consumes the stored counter")

func _test_trap_tooltip_surfaces_damage_and_effect() -> void:
	var board := CombatBoardView.new()
	var tooltip: String = str(board.call("_trap_tooltip_text", {
		"element": "air",
		"damage": 3,
		"stun": 1
	}))
	_assert(tooltip.contains("Air Trap"), "Trap tooltips should identify their elemental type")
	_assert(tooltip.contains("3 damage"), "Trap tooltips should show trap damage")
	_assert(tooltip.contains("Stun"), "Trap tooltips should surface the trap's elemental effect")

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
				{"type": "ranged", "damage": 8, "range": 6, "shock": 1}
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

func _test_foreground_props_fade_when_covering_behind_units() -> void:
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
	var flat_tint: Color = board.call("_foreground_blocker_tint", "door", blocker_tile, prop_rect, [behind_unit])
	_assert(is_equal_approx(flat_tint.a, 1.0), "Flat door terrain should not use foreground obstruction fading")
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
	board.free()

func _test_keyword_icon_library_surfaces_tooltips() -> void:
	var row: Array = ActionIcons.tokens_for_action({"type": "ranged", "damage": 4, "range": 4, "poison": 2})
	_assert(row.size() == 3, "Ranged actions should tokenize into action, range, and status icons")
	_assert(str((row[0] as Dictionary).get("icon", "")) == "ranged", "Ranged action tokens should use the bow icon")
	_assert(str((row[1] as Dictionary).get("icon", "")) == "range", "Ranged action tokens should include the shared range icon")
	_assert(str((row[2] as Dictionary).get("icon", "")) == "poison", "Status keywords should use their shared icon token")
	var aoe_row: Array = ActionIcons.tokens_for_action({"type": "aoe", "damage": 5, "range": 0, "pattern": [[0, -1], [1, 0], [0, 1], [-1, 0]]})
	_assert(str((aoe_row[1] as Dictionary).get("kind", "")) == "aoe_pattern", "AOE actions should surface a tile pattern token")
	_assert(bool((aoe_row[1] as Dictionary).get("show_origin", false)), "Close AOE pattern tokens should include the player origin tile")
	_assert(ActionIcons.tooltip("poison").contains("Delayed damage"), "Keyword icon tooltips should include readable descriptions")
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
	map_view.free()

func _test_combat_board_loads_door_icons_for_room_types() -> void:
	var board := CombatBoardView.new()
	board.call("_load_assets")
	var textures: Dictionary = board.get("_door_icon_textures") as Dictionary
	for icon_id: String in ["fire", "combat", "campfire", "treasure", "boss"]:
		_assert(textures.get(icon_id, null) != null, "Combat board should load door icons for elemental and non-combat destinations")
	board.free()

func _test_run_map_room_types() -> void:
	var run_engine: RunEngine = RunEngine.new()
	var progression: Dictionary = ProgressionStore.prepare_for_new_run(ProgressionStore.default_data())
	var run_state: Dictionary = run_engine.create_new_run(13, progression)
	_assert(str(run_engine.room_metadata(run_state, Vector2i.ZERO).get("type", "")) == "start", "Origin should be the start room")
	_assert(str(run_engine.room_metadata(run_state, Vector2i(2, 0)).get("type", "")) == "campfire", "Axis depth-2 rooms should be campfire rooms")
	_assert(str(run_engine.room_metadata(run_state, Vector2i(4, 0)).get("type", "")) == "boss", "Outer ring should be boss territory")

func _test_run_map_ring_links_and_outward_quarter() -> void:
	var run_engine: RunEngine = RunEngine.new()
	var run_state: Dictionary = run_engine.create_new_run(13, ProgressionStore.default_data())
	for depth: int in range(1, 4):
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
	var combat_state: Dictionary = run_state.get("combat_state", {}).duplicate(true)
	for enemy_index: int in range((combat_state.get("enemies", []) as Array).size()):
		var enemy: Dictionary = (combat_state.get("enemies", []) as Array)[enemy_index]
		enemy["hp"] = 0
		(combat_state.get("enemies", []) as Array)[enemy_index] = enemy
	combat_state["room_embers"] = 12
	run_state = run_engine.finish_combat(run_state, combat_state)
	_assert(str(run_state.get("mode", "")) == "reward", "Winning a non-boss combat should transition to the reward state")
	_assert(int(run_state.get("unbanked_embers", 0)) >= 12, "Combat victory should award embers to the run")
	_assert((run_state.get("pending_reward", {}) as Dictionary).get("cards", []).size() == 3, "Combat rewards should offer three card choices")

func _test_boss_victory_restores_player_health() -> void:
	var run_engine: RunEngine = RunEngine.new()
	var run_state: Dictionary = run_engine.create_new_run(29, ProgressionStore.default_data())
	run_state["current_room"] = Vector2i(4, 0)
	var rooms: Dictionary = run_state.get("rooms", {}).duplicate(true)
	rooms["4,0"] = {
		"coord": Vector2i(4, 0),
		"depth": 4,
		"type": "boss",
		"element": ElementData.LIGHTNING,
		"revealed": true,
		"visited": true,
		"cleared": false,
		"connections": []
	}
	run_state["rooms"] = rooms
	run_state["player_hp"] = 9
	run_state["player_max_hp"] = 36
	var combat_state: Dictionary = _zekarion_test_room_layout()
	combat_state["room_name"] = "Tempest God's Perch"
	combat_state["room_coord"] = Vector2i(4, 0)
	combat_state["room_depth"] = 4
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
	run_state = run_engine.finish_combat(run_state, combat_state)
	_assert(str(run_state.get("mode", "")) == "victory", "Defeating Zekarion should end the run in victory")
	_assert(int(run_state.get("player_hp", 0)) == int(run_state.get("player_max_hp", 0)), "Defeating Zekarion should restore the player to full health")

func _test_progression_save_and_purchase(default_progression: Dictionary) -> void:
	var data: Dictionary = ProgressionStore.add_embers(default_progression, 1000)
	_assert(ProgressionStore.save_data(data), "Progression save should succeed")
	var loaded: Dictionary = ProgressionStore.load_data()
	_assert(int(loaded.get("embers", 0)) == 1000, "Saved progression embers should reload")
	var elements: Array = GameData.upgradeable_elements_for_card("quick_stab", loaded)
	var damage_element: Dictionary = {}
	var action_element: Dictionary = {}
	for element_var: Variant in elements:
		var element: Dictionary = element_var
		if str(element.get("kind", "")) == "stat" and str(element.get("field", "")) == "damage":
			damage_element = element
		if str(element.get("kind", "")) == "action":
			action_element = element
	_assert(not damage_element.is_empty(), "Permanent card upgrades should expose card elements the player can customize")
	_assert(not action_element.is_empty(), "Permanent card upgrades should include card-level action additions")
	var action_options: Array = GameData.upgrade_options_for_element("quick_stab", action_element, loaded)
	_assert(action_options.size() >= 3, "Action additions should offer multiple upgrade choices")
	var action_preview: Dictionary = GameData.preview_card_with_mod("quick_stab", action_options[0], loaded)
	_assert((action_preview.get("actions", []) as Array).size() == 2, "Action addition previews should show the added action on the card")
	var options: Array = GameData.upgrade_options_for_element("quick_stab", damage_element, loaded)
	_assert(options.size() >= 3, "Damage elements should offer multiple upgrade strengths")
	var damage_mod: Dictionary = options[0]
	var cost: int = int(damage_mod.get("cost", 0))
	_assert(cost >= 100, "Starter card upgrade costs should be tuned above short-run ember payouts")
	loaded = ProgressionStore.purchase_card_mod(loaded, "quick_stab", damage_mod)
	var card_mods: Dictionary = loaded.get("card_mods", {}) as Dictionary
	_assert((card_mods.get("quick_stab", []) as Array).size() == 1, "Purchased card mods should stack under their base card id")
	_assert(int(loaded.get("embers", 0)) == 1000 - cost, "Card mod purchases should deduct their computed ember cost")
	var upgraded_card: Dictionary = GameData.card_def_for_progression("quick_stab", loaded)
	var upgraded_action: Dictionary = (upgraded_card.get("actions", []) as Array)[0]
	_assert(int(upgraded_action.get("damage", 0)) == 10, "Purchased card mods should alter future card definitions")
	var second_options: Array = GameData.upgrade_options_for_element("quick_stab", damage_element, loaded)
	var second_mod: Dictionary = second_options[0]
	var second_cost: int = int(second_mod.get("cost", 0))
	_assert(second_cost > cost, "Stacking more upgrades onto one card should become increasingly expensive")
	loaded = ProgressionStore.purchase_card_mod(loaded, "quick_stab", second_mod)
	_assert(GameData.card_upgrade_count(loaded, "quick_stab") == 2, "A card should be able to carry multiple permanent mods")
	var combat: CombatEngine = CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(9, _simple_room_layout(), {
		"hp": 12,
		"max_hp": 20,
		"deck_cards": ["quick_stab"],
		"card_upgrades": loaded.get("card_upgrades", {}),
		"card_mods": loaded.get("card_mods", {}),
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	_assert(int(((combat.card_def("quick_stab", combat_state).get("actions", []) as Array)[0] as Dictionary).get("damage", 0)) == 11, "Combat should resolve stacked card mods from progression")

func _test_emaciated_man_unlocks_card_upgrade_dialogue() -> void:
	var dialogue_engine: DialogueEngine = DialogueEngine.new()
	var room: Dictionary = {
		"coord": Vector2i.ZERO,
		"npcs": [{"id": "emaciated_man"}]
	}
	var progression: Dictionary = ProgressionStore.mark_rested_at_fire(ProgressionStore.default_data())
	var dialogue: Dictionary = dialogue_engine.build_room_dialogue(room, {}, progression)
	var lines: Array = dialogue.get("lines", [])
	_assert(lines.size() == 7, "Resting at a fire should unlock the Emaciated Man's card-upgrade dialogue")
	_assert(bool(dialogue.get("marks_fire_rest_seen", false)), "The one-time fire-rest dialogue should mark itself consumed after it closes")
	_assert(str((lines[1] as Dictionary).get("bbcode", "")).contains("[i]intoxicating[/i]"), "The fire-rest dialogue should italicize intoxicating")
	var options: Array = (lines[lines.size() - 1] as Dictionary).get("options", [])
	_assert(options.size() == 2, "The awakened dialogue should offer touch and journey choices")
	_assert(str((options[0] as Dictionary).get("action", "")) == "open_card_upgrades", "Touching the Emaciated Man should open the card upgrade UI")
	_assert(str((options[1] as Dictionary).get("action", "")) == "close", "Beginning the journey again should close dialogue")
	progression = ProgressionStore.mark_fire_rest_dialogue_seen(progression)
	dialogue = dialogue_engine.build_room_dialogue(room, {}, progression)
	lines = dialogue.get("lines", [])
	_assert(lines.size() == 3, "After the fire-rest line is consumed, future runs should return to the default Emaciated Man dialogue")
	_assert(str((lines[0] as Dictionary).get("text", "")) == "Hehehe. You're back...so soon.", "Unlocked runs should still use the default start-room dialogue text")
	options = (lines[lines.size() - 1] as Dictionary).get("options", [])
	_assert(options.size() == 2, "Unlocked default dialogue should still offer touch and journey choices")
	_assert(str((options[0] as Dictionary).get("action", "")) == "open_card_upgrades", "Touch should remain available after the one-time fire-rest dialogue")

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
	var route: Array = _find_route_to_coord(run_engine, run_state, recovery_coord)
	_assert(not route.is_empty(), "Recovery markers should still be reachable on the next run")
	for step: Vector2i in route:
		run_state = run_engine.move_to_room(run_state, step)
	_assert(int(run_state.get("unbanked_embers", 0)) == 23, "Reaching the recovery room on the next run should restore lost embers")
	_assert(str(run_state.get("notice", "")).contains("Recovered"), "Recovery should leave a short room notice")
	_assert(ProgressionStore.recovery_marker(run_state.get("progression", {})).is_empty(), "Recovering lost embers should clear the marker")

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
	_assert((run_state.get("deck_cards", []) as Array).size() > GameData.starting_deck().size(), "Debug boss fixture should grant a progressed deck")
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
	var choice_bar: HBoxContainer = instance.get_node("Backdrop/Margin/MainVBox/BottomStack/ChoiceBar")
	var pass_found: bool = false
	for child: Node in choice_bar.get_children():
		if child is Button and (child as Button).text == "Pass":
			pass_found = true
			break
	_assert(pass_found, "Combat UI should always offer Pass when the player can end the turn manually")
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
	var choice_bar: HBoxContainer = instance.get_node("Backdrop/Margin/MainVBox/BottomStack/ChoiceBar")
	var pass_found: bool = false
	for child: Node in choice_bar.get_children():
		if child is Button and (child as Button).text == "Pass":
			pass_found = true
			break
	_assert(pass_found, "Combat UI should offer Pass when the hand has no playable cards")
	instance.queue_free()
	await process_frame

func _test_run_scene_campfire_choices_use_context_overlay() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for campfire overlay coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var run_state: Dictionary = instance.get("_run_state")
	run_state["mode"] = "campfire"
	instance.set("_run_state", run_state)
	instance.call("_refresh_choice_bar")
	var choice_bar: HBoxContainer = instance.get_node("Backdrop/Margin/MainVBox/BottomStack/ChoiceBar")
	var overlay: PanelContainer = instance.get_node("Backdrop/Margin/MainVBox/StageRoot/ContextChoiceOverlay")
	var overlay_button_count: int = 0
	var found_sit: bool = false
	var found_leave: bool = false
	for button: Button in _buttons_under(overlay):
		overlay_button_count += 1
		found_sit = found_sit or button.text == "Sit"
		found_leave = found_leave or button.text == "Leave"
	_assert(not choice_bar.visible, "Campfire choices should no longer sit in the bottom choice bar")
	_assert(overlay.visible, "Campfire choices should use the floating board context overlay")
	_assert(overlay_button_count == 2 and found_sit and found_leave, "Campfire context overlay should expose large Sit and Leave buttons")
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
		"hp": 14,
		"max_hp": 14,
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
	_assert(int(enemy.get("hp", 0)) == 9, "Enemy shortcut clicks should still resolve the follow-up attack")
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
		"hp": 12,
		"max_hp": 20,
		"deck_cards": ["patch_up"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var player: Dictionary = (combat_state.get("player", {}) as Dictionary).duplicate(true)
	player["hp"] = 12
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
	_assert(int(committed_player.get("hp", 0)) == 15, "Clicking a targetless self card should immediately commit its heal")
	_assert(int(committed_player.get("block", 0)) == 2, "Clicking a targetless self card should immediately commit its block")
	_assert(((committed_state.get("deck", {}) as Dictionary).get("hand", []) as Array).is_empty(), "Resolved targetless cards should leave the hand")
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
	_assert(int(damage_token.get("value", 0)) == 11, "Damage cards should show final damage, not base damage, when a modifier applies")
	_assert(str(damage_token.get("tone", "")) == "bonus", "Modified damage tokens should carry bonus styling")
	_assert(modifier_lines.size() == 1, "Damage cards should surface active damage modifiers for the tooltip")
	_assert(str(modifier_lines[0]).contains("Ember Lens"), "The damage tooltip should name the modifier source")
	instance.queue_free()
	await process_frame

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
	discard_host = hosts.get("discard", null)
	var discard_top: Node = discard_host.get_child(discard_host.get_child_count() - 1) if discard_host != null and discard_host.get_child_count() > 0 else null
	_assert(discard_top is CardWidget and (discard_top as CardWidget).card_id == "quick_stab", "A non-empty discard pile should render the top card with the real card widget")
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
	_assert(dialogue_active, "Starting in the waypoint should auto-trigger the friendly NPC dialogue")
	_assert(speaker_label != null and speaker_label.text == "Emaciated Man", "The start-room dialogue should identify the Emaciated Man as the speaker")
	_assert(text_label != null and text_label.text == "Hehehe. You're back...so soon.", "The opening NPC line should match the scripted default dialogue")
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

func _test_run_scene_card_upgrade_overlay_opens() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for card upgrade UI coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var progression: Dictionary = ProgressionStore.add_embers(
		ProgressionStore.mark_rested_at_fire(ProgressionStore.default_data()),
		100
	)
	var run_state: Dictionary = instance.get("_run_state")
	run_state["progression"] = progression
	instance.set("_run_state", run_state)
	instance.set("_progression", progression)
	instance.call("_close_dialogue")
	instance.call("_open_card_upgrade_overlay")
	var upgrade_scrim: ColorRect = instance.get("_upgrade_scrim")
	var card_list: VBoxContainer = instance.get("_upgrade_card_list")
	var element_list: VBoxContainer = instance.get("_upgrade_element_list")
	var option_list: VBoxContainer = instance.get("_upgrade_option_list")
	_assert(upgrade_scrim != null and upgrade_scrim.visible, "Touching the Emaciated Man should show the card upgrade overlay")
	_assert(card_list != null and card_list.get_child_count() == GameData.upgradeable_card_ids().size(), "The card upgrade overlay should list cards first")
	_assert(element_list != null and element_list.get_child_count() > 0, "Selecting a card should reveal upgradeable card elements")
	_assert(option_list != null and option_list.get_child_count() > 0, "Selecting a card element should reveal purchasable upgrade options")
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
		"hp": 12,
		"max_hp": 20,
		"deck_cards": ["patch_up"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var player: Dictionary = (combat_state.get("player", {}) as Dictionary).duplicate(true)
	player["hp"] = 12
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
		"heal_amount": 6,
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
	_assert(int(play_payload.get("player_heal_gained", 0)) == 3, "Card play analytics should capture observed healing")
	_assert(int(play_payload.get("player_block_gained", 0)) == 2, "Card play analytics should capture observed block gain")
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
	_assert(continue_button.visible, "Main menu should expose Continue when a saved run exists")
	instance.queue_free()
	ProgressionStore.clear_saved_run()
	await process_frame

func _analytics_events_by_type(events: Array[Dictionary], event_type: String) -> Array[Dictionary]:
	var filtered: Array[Dictionary] = []
	for event: Dictionary in events:
		if str(event.get("event_type", "")) == event_type:
			filtered.append(event)
	return filtered

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

func _zekarion_test_room_layout() -> Dictionary:
	return {
		"name": "Tempest God's Perch",
		"coord": Vector2i(4, 0),
		"depth": 4,
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
				"state": run_engine.move_to_room(state, move),
				"path": next_path
			})
	return []

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

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
