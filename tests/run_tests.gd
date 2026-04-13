extends SceneTree

const GameData = preload("res://scripts/game_data.gd")
const ActionIcons = preload("res://scripts/action_icon_library.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RoomGenerator = preload("res://scripts/room_generator.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")
const CombatBoardView = preload("res://scripts/combat_board_view.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const PathUtils = preload("res://scripts/path_utils.gd")
const UiTooltipPanel = preload("res://scripts/ui_tooltip_panel.gd")

var _failures: Array[String] = []

func _initialize() -> void:
	ProgressionStore.set_storage_path("user://labyrinth_progression_test.json")
	ProgressionStore.set_run_storage_path("user://labyrinth_run_test.save")
	var default_progression: Dictionary = ProgressionStore.default_data()
	_assert(GameData.cards().size() >= 20, "Card data should load")
	_assert(GameData.enemies().size() >= 5, "Enemy data should load")
	_assert(GameData.npcs().size() >= 1, "NPC data should load")
	_assert(GameData.relics().size() >= 5, "Relic data should load")
	_assert(GameData.upgrades().size() >= 3, "Upgrade data should load")
	_test_room_generation_is_deterministic()
	_test_room_generation_keeps_spawn_reachable()
	_test_room_generation_blocks_door_tiles()
	_test_room_generation_scales_enemy_density()
	_test_start_room_spawns_emaciated_man()
	_test_fatigue_draws_cost_health_and_burn_removes_card()
	_test_two_card_turn_draw_flow()
	_test_hand_draw_caps_at_eight()
	_test_first_attack_bonus_damage_math()
	_test_healing_cards_are_burned_and_downweighted()
	_test_player_block_absorbs_full_enemy_phase()
	_test_enemy_preview_block_mitigates_current_turn_damage()
	_test_blast_hits_multiple_targets()
	_test_enemy_phase_preserves_preview_cycle()
	_test_elemental_room_rewards_follow_affinity(default_progression)
	_test_chain_hits_clustered_enemies()
	_test_freeze_and_shock_control_turn_flow()
	_test_poison_and_stoneskin_behaviors()
	_test_out_of_range_elemental_enemy_attack_skips_step()
	_test_enemy_threat_tiles_follow_intent()
	_test_shallow_elemental_enemy_actions_scale_back()
	_test_status_badges_surface_countdowns()
	_test_player_restriction_badges_show_turn_lock()
	_test_enemy_intent_name_reserves_header_line()
	_test_enemy_hud_layout_stays_centered_when_clear()
	_test_enemy_hud_layout_offsets_away_from_reserved_ui()
	_test_enemy_art_scale_preserves_center()
	_test_enemy_art_offset_shifts_sprite_vertically()
	_test_enemy_intent_popup_expands_for_long_titles()
	_test_crawler_idle_sheet_surfaces_for_idle_enemy()
	_test_emaciated_man_uses_static_placeholder_art()
	_test_acolyte_idle_sheet_honors_row_major_layout()
	_test_acolyte_idle_speed_matches_default_cadence()
	_test_unit_hud_stacks_above_sprite_art()
	_test_foreground_props_fade_when_covering_behind_units()
	_test_combat_board_hides_inactive_doors_but_preserves_locked_ones()
	_test_combat_board_draw_order_tracks_moving_unit_world_position()
	_test_keyword_icon_library_surfaces_tooltips()
	_test_run_map_room_types()
	_test_run_map_ring_links_and_outward_quarter()
	_test_run_map_seals_departed_rooms()
	_test_run_map_never_moves_back_toward_center()
	_test_empty_treasure_room_falls_back_to_room_mode()
	_test_combat_finish_generates_reward_state()
	_test_progression_save_and_purchase(default_progression)
	_test_recovery_marker_flow()
	_test_recovery_marker_expires_after_next_run()
	_test_run_state_save_and_load()
	_test_default_theme_uses_pixel_font()
	await _test_main_scenes_instantiate()
	await _test_run_scene_offers_pass_during_combat()
	await _test_run_scene_offers_pass_when_hand_dead()
	await _test_run_scene_optional_followup_attack_stays_playable()
	await _test_run_scene_move_attack_shortcut_clicks_enemy()
	await _test_run_scene_block_card_skips_dead_move()
	await _test_run_scene_targetless_card_click_commits_play()
	await _test_run_scene_damage_display_matches_bonus()
	await _test_run_scene_ranged_cards_show_range()
	await _test_run_scene_preview_normalizes_untyped_target_tiles()
	await _test_run_scene_hovered_enemy_shows_threat_overlay()
	await _test_run_scene_empty_discard_uses_short_caption()
	await _test_run_scene_displays_owned_relic_icons()
	await _test_run_scene_auto_triggers_starting_npc_dialogue()
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

func _test_blast_hits_multiple_targets() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = combat.create_combat(4, _blast_test_room_layout(), {
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
	_assert(int((enemies[0] as Dictionary).get("hp", 0)) < int((enemies[0] as Dictionary).get("max_hp", 0)), "Blast should damage the first target")
	_assert(int((enemies[1] as Dictionary).get("hp", 0)) < int((enemies[1] as Dictionary).get("max_hp", 0)), "Blast should damage the second target in the radius")

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
	var layout: Dictionary = _blast_test_room_layout()
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
		if str(step.get("kind", "")) in ["melee", "ranged", "blast", "push", "pull"]:
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

func _test_status_badges_surface_countdowns() -> void:
	var board := CombatBoardView.new()
	var badges: Array = board.call("_unit_status_badges", {
		"burn": 5,
		"freeze": 1,
		"shock": 1,
		"poison": {"damage": 4, "delay": 2}
	})
	_assert(badges.size() == 4, "Status badges should surface each active elemental status independently")
	_assert(str((badges[0] as Dictionary).get("icon", "")) == "burn", "Burn badges should use the shared burn icon")
	_assert(int((badges[0] as Dictionary).get("count", 0)) == 5, "Burn badges should show their remaining countdown")
	_assert(str((badges[3] as Dictionary).get("icon", "")) == "poison", "Poison badges should use the shared poison icon")
	_assert(int((badges[3] as Dictionary).get("count", 0)) == 2, "Poison badges should show the turns remaining before it lands")

func _test_player_restriction_badges_show_turn_lock() -> void:
	var board := CombatBoardView.new()
	var statuses: Dictionary = board.call("_player_display_statuses", {"burn": 0, "freeze": 0, "shock": 0}, {"frozen": true, "shocked": false})
	_assert(int(statuses.get("freeze", 0)) == 1, "Frozen turns should still surface a freeze badge even after the restriction consumes the stored counter")
	statuses = board.call("_player_display_statuses", {"burn": 0, "freeze": 0, "shock": 0}, {"frozen": false, "shocked": true})
	_assert(int(statuses.get("shock", 0)) == 1, "Shocked turns should still surface a shock badge even after the restriction consumes the stored counter")

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

func _test_enemy_hud_layout_stays_centered_when_clear() -> void:
	var board := CombatBoardView.new()
	board.size = Vector2(960.0, 680.0)
	var font: Font = load("res://fonts/PressStart2P-Regular.tres")
	var center := Vector2(320.0, 240.0)
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
	var font: Font = load("res://fonts/PressStart2P-Regular.tres")
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
	_assert(is_equal_approx(scaled_rect.size.x, fitted_rect.size.x * 0.75), "Crawler art scale should shrink the fitted sprite width")
	_assert(is_equal_approx(scaled_rect.size.y, fitted_rect.size.y * 0.75), "Crawler art scale should shrink the fitted sprite height")
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
	var font: Font = load("res://fonts/PressStart2P-Regular.tres")
	var width: float = float(board.call("_enemy_intent_popup_width", {
		"name": "Skitter Strike",
		"actions": [{"type": "melee", "damage": 4, "range": 1}]
	}, [[{"icon": "melee"}, {"icon": "damage", "value": 4}]], font))
	_assert(width > 136.0, "Long enemy intent titles should widen the popup instead of clipping")

func _test_crawler_idle_sheet_surfaces_for_idle_enemy() -> void:
	var board := CombatBoardView.new()
	board.visible = true
	board.call("_load_assets")
	board.combat_state = {
		"player": {"hp": 20},
		"enemies": [{"id": 1, "type": "crawler", "hp": 14}]
	}
	board.presentation = {}
	var crawler_unit := {"key": "enemy_1", "type": "crawler"}
	var idle_frames: Array = board.call("_unit_idle_frames", crawler_unit)
	_assert(idle_frames.size() == 8, "Crawler idle sheets should load into 8 animation frames")
	var idle_texture: Texture2D = board.call("_texture_for_unit", crawler_unit)
	var base_texture: Texture2D = (board.get("_unit_textures") as Dictionary).get("crawler", null)
	_assert(idle_texture != null and idle_texture != base_texture, "Idle crawlers should render from the idle sheet instead of the base texture")
	board.presentation = {"focus_actor_keys": ["enemy_1"], "effect": {"type": "attack"}}
	var focused_texture: Texture2D = board.call("_texture_for_unit", crawler_unit)
	_assert(focused_texture == base_texture, "Focused crawlers should stop using idle frames while acting")

func _test_emaciated_man_uses_static_placeholder_art() -> void:
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
	_assert(idle_frames.is_empty(), "Emaciated Man placeholder art should not load an idle sheet")
	_assert(npc_texture != null, "Emaciated Man placeholder art should load for board rendering")
	_assert(npc_texture != acolyte_texture, "Emaciated Man should not reuse the Ash Acolyte texture")

func _test_acolyte_idle_sheet_honors_row_major_layout() -> void:
	var board := CombatBoardView.new()
	board.call("_load_assets")
	var acolyte_unit := {"type": "acolyte", "pos": Vector2i.ZERO}
	var idle_frames: Array = board.call("_unit_idle_frames", acolyte_unit)
	_assert(idle_frames.size() == 8, "Acolyte idle sheets should load into 8 animation frames")
	var first_frame: AtlasTexture = idle_frames[0] as AtlasTexture
	var second_frame: AtlasTexture = idle_frames[1] as AtlasTexture
	var fifth_frame: AtlasTexture = idle_frames[4] as AtlasTexture
	_assert(first_frame != null and second_frame != null and fifth_frame != null, "Acolyte idle frames should be atlas-backed slices of the idle sheet")
	_assert(first_frame.region.size == Vector2(1024.0, 1020.0), "Acolyte idle frames should respect the custom 2x4 sheet layout")
	_assert(first_frame.region.position == Vector2.ZERO, "The first acolyte idle frame should start at the top-left of the sheet")
	_assert(second_frame.region.position == Vector2(1024.0, 0.0), "Row-major acolyte idle sheets should advance to the next column before moving down")
	_assert(fifth_frame.region.position == Vector2(0.0, 2040.0), "Row-major acolyte idle sheets should wrap to the next row after two frames")

func _test_acolyte_idle_speed_matches_default_cadence() -> void:
	var board := CombatBoardView.new()
	board.call("_load_assets")
	var acolyte_unit := {"type": "acolyte", "pos": Vector2i.ZERO}
	var crawler_unit := {"type": "crawler", "pos": Vector2i.ZERO}
	_assert(is_equal_approx(float(board.call("_unit_idle_frame_seconds", acolyte_unit)), 0.1), "Acolyte idle frames should fall back to the default cadence when no override is set")
	_assert(is_equal_approx(float(board.call("_unit_idle_frame_seconds", crawler_unit)), 0.1), "Units without an override should keep the default idle cadence")
	board.set("_idle_elapsed", 0.09)
	_assert(int(board.call("_idle_frame_index", acolyte_unit)) == 0, "Acolyte idle animation should still be on the first frame just before 0.1 seconds")
	board.set("_idle_elapsed", 0.11)
	_assert(int(board.call("_idle_frame_index", acolyte_unit)) == 1, "Acolyte idle animation should advance after the 0.1-second mark")

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

func _test_combat_board_hides_inactive_doors_but_preserves_locked_ones() -> void:
	var board := CombatBoardView.new()
	var grid: Array = _simple_grid()
	grid[0][4] = "door"
	var door_tile := Vector2i(4, 0)
	board.set_combat_state({"grid": grid}, [], [], Vector2i(-1, -1), "", "", {}, {}, {})
	_assert(board.call("_display_tile_id", "door", door_tile) == "wall", "Inactive doors should render as uninterrupted walls")
	board.set_combat_state({"grid": grid}, [], [], Vector2i(-1, -1), "", "", {}, {}, {"active_door_tiles": {door_tile: true}})
	_assert(board.call("_display_tile_id", "door", door_tile) == "door", "Combat presentation should still show active connected doors")
	board.set_combat_state({"grid": grid}, [], [], Vector2i(-1, -1), "", "", {door_tile: "N"}, {}, {})
	_assert(board.call("_display_tile_id", "door", door_tile) == "door", "Usable exits should still render as doors")
	board.set_combat_state({"grid": grid}, [], [], Vector2i(-1, -1), "", "", {}, {}, {"locked_door_tiles": {door_tile: true}})
	_assert(board.call("_display_tile_id", "door", door_tile) == "door", "Previously sealed traversal doors should stay visible as doors")
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
	_assert(ActionIcons.tooltip("poison").contains("Delayed damage"), "Keyword icon tooltips should include readable descriptions")
	var tooltip_panel: PanelContainer = UiTooltipPanel.make_text(ActionIcons.tooltip("poison"))
	_assert(tooltip_panel.get_child_count() == 1, "Keyword tooltip text should render as a custom panel instead of the default engine tooltip")
	tooltip_panel.free()

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

func _test_progression_save_and_purchase(default_progression: Dictionary) -> void:
	var data: Dictionary = ProgressionStore.add_embers(default_progression, 100)
	_assert(ProgressionStore.save_data(data), "Progression save should succeed")
	var loaded: Dictionary = ProgressionStore.load_data()
	_assert(int(loaded.get("embers", 0)) == 100, "Saved progression embers should reload")
	loaded = ProgressionStore.purchase_upgrade(loaded, "stitched_vitals")
	_assert(ProgressionStore.has_upgrade(loaded, "stitched_vitals"), "Purchased upgrades should be tracked")
	_assert(int(loaded.get("embers", 0)) == 70, "Upgrade purchase should deduct its ember cost")

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
		_assert(font.resource_path.ends_with("PressStart2P-Regular.tres"), "The default theme should use the bundled pixel font")
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
	_assert(int(damage_token.get("value", 0)) == 8, "Damage cards should show final damage, not base damage, when a modifier applies")
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

func _test_run_scene_empty_discard_uses_short_caption() -> void:
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
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	combat_state["deck"] = deck
	var run_state: Dictionary = instance.get("_run_state")
	run_state["mode"] = "combat"
	run_state["combat_state"] = combat_state
	instance.set("_run_state", run_state)
	instance.set("_combat_state", combat_state)
	instance.call("_refresh_pile_visuals")
	var captions: Dictionary = instance.get("_pile_captions")
	var discard_caption: Label = captions.get("discard", null)
	_assert(discard_caption != null and discard_caption.text == "DISC", "An empty discard pile should keep the short DISC caption instead of stretching to DISCARD")
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
	var text_label: Label = instance.get("_dialogue_text_label")
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

func _blast_test_room_layout() -> Dictionary:
	return {
		"name": "Blast Room",
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

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
