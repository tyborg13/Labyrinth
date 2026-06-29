extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const PathUtils = preload("res://scripts/path_utils.gd")
const ElementData = preload("res://scripts/element_data.gd")

const PROJECTILE_PREVIEW_LOOP_SECONDS: float = 2.4

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	DirAccess.make_dir_recursive_absolute("user://motion_probes")
	_clear_probe_output("user://motion_probes")
	ProgressionStore.set_storage_path("user://labyrinth_progression_motion_probe.json")
	ProgressionStore.set_run_storage_path("user://labyrinth_run_motion_probe.save")
	ProgressionStore.clear_saved_run()
	await _capture_motion_states()
	print(ProjectSettings.globalize_path("user://motion_probes"))
	quit()

func _capture_motion_states() -> void:
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame
	var probe_run_engine := RunEngine.new()
	instance.call("_load_run_state", probe_run_engine.create_new_run(456, ProgressionStore.default_data()))
	await process_frame
	await process_frame

	var run_state: Dictionary = instance.get("_run_state")
	var run_engine = instance.get("_run_engine")
	var combat_coord: Vector2i = Vector2i.ZERO
	for coord: Vector2i in run_engine.available_moves(run_state):
		var room: Dictionary = run_engine.room_metadata(run_state, coord)
		if str(room.get("type", "")) == "combat":
			combat_coord = coord
			break
	if combat_coord == Vector2i.ZERO:
		instance.queue_free()
		await process_frame
		return

	instance.call("_on_map_view_room_selected", combat_coord)
	await create_timer(0.95).timeout
	await process_frame
	await process_frame
	await _save_root_screenshot("user://motion_probes/motion_00_combat_base.png")

	await _capture_card_fx(instance)
	await _capture_draw_fx(instance)
	await _capture_player_melee_fx(instance)
	await _capture_player_attack_fx(instance)
	await _capture_player_ranged_impact_fx(instance)
	await _capture_player_aoe_fx(instance)
	await _capture_defense_heal_cast_fx(instance)
	await _capture_enemy_phase_fx(instance)
	await _capture_ember_fx(instance)
	await _capture_fatigue_fx(instance)
	await _capture_turn_order_fx(instance)

	instance.queue_free()
	await process_frame

func _capture_card_fx(instance: Node) -> void:
	var card_id: String = str(instance.call("_card_id_for_hand_index", 0))
	var source_rect: Rect2 = instance.call("_hand_card_global_rect", 0)
	var card_size: Vector2 = source_rect.size
	if card_id.is_empty() or card_size.x <= 0.0 or card_size.y <= 0.0:
		return
	instance.set("_animating_hand_card_index", 0)
	instance.call("_refresh_ui")
	await process_frame
	instance.call("_animate_card_play_fx", card_id, source_rect, card_size)
	await create_timer(0.05).timeout
	await process_frame
	await _save_root_screenshot("user://motion_probes/motion_10_card_play_lift.png")
	await create_timer(0.12).timeout
	await process_frame
	await _save_root_screenshot("user://motion_probes/motion_11_card_play_fade.png")
	await create_timer(0.25).timeout
	await process_frame

	instance.call("_animate_card_to_pile_fx", card_id, "discard", card_size)
	await create_timer(0.07).timeout
	await process_frame
	await _save_root_screenshot("user://motion_probes/motion_12_card_to_pile_mid.png")
	await create_timer(0.28).timeout
	await process_frame
	instance.set("_animating_hand_card_index", -1)
	instance.call("_refresh_ui")
	await process_frame

func _capture_draw_fx(instance: Node) -> void:
	var combat_state: Dictionary = (instance.get("_combat_state") as Dictionary).duplicate(true)
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["quick_stab"]
	deck["draw"] = ["brace", "lantern_shot", "patch_up"]
	deck["discard"] = []
	deck["burned"] = []
	combat_state["deck"] = deck
	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run_state["mode"] = "combat"
	run_state["combat_state"] = combat_state
	instance.set("_run_state", run_state)
	instance.set("_combat_state", combat_state)
	instance.call("_refresh_ui")
	await process_frame
	await process_frame

	var draw_entries: Array[Dictionary] = []
	draw_entries.append({"card_id": "brace", "index": 1, "total": 3})
	draw_entries.append({"card_id": "lantern_shot", "index": 2, "total": 3})
	instance.call("_animate_draw_cards_fx", draw_entries)
	await create_timer(0.06).timeout
	await process_frame
	await _save_root_screenshot("user://motion_probes/motion_20_draw_first_mid.png")
	await create_timer(0.22).timeout
	await process_frame
	await _save_root_screenshot("user://motion_probes/motion_21_draw_second_mid.png")
	await create_timer(0.42).timeout
	await process_frame

func _capture_player_melee_fx(instance: Node) -> void:
	var combat_state: Dictionary = await _prepare_impact_probe_state(
		instance,
		Vector2i(3, 4),
		[
			{"id": 1, "type": "crawler", "pos": Vector2i(4, 4), "hp": 100, "max_hp": 100, "block": 0}
		],
		["hearth_rush"]
	)
	var combat_engine = instance.get("_combat_engine")
	var action: Dictionary = {"type": "melee", "damage": 5, "range": 1, "_card_element": "fire"}
	var target_tile := Vector2i(4, 4)
	var after_state: Dictionary = combat_engine.apply_player_action(combat_state.duplicate(true), action, target_tile)
	instance.call("_animate_player_action_step", combat_state.duplicate(true), after_state, "hearth_rush", action, target_tile)
	await create_timer(0.31).timeout
	await process_frame
	await _save_root_screenshot("user://motion_probes/motion_22_player_melee_fire_impact.png")
	await create_timer(0.34).timeout
	await process_frame
	await _save_root_screenshot("user://motion_probes/motion_22b_player_melee_fire_faded.png")
	instance.call("_refresh_ui")
	await process_frame

func _capture_player_attack_fx(instance: Node) -> void:
	await _capture_projectile_preview_loop(instance)
	await _capture_projectile_variant(
		instance,
		"bone_dart",
		{"type": "ranged", "damage": 5, "range": 4},
		Vector2i(5, 4),
		"user://motion_probes/motion_23_projectile_neutral_travel.png"
	)
	await _capture_projectile_variant(
		instance,
		"firebrand_volley",
		{"type": "ranged", "damage": 4, "range": 5, "_card_element": ElementData.FIRE},
		Vector2i(5, 4),
		"user://motion_probes/motion_24_projectile_fire_travel.png"
	)
	await _capture_projectile_variant(
		instance,
		"lodestone_reversal",
		{"type": "pull", "damage": 3, "range": 5, "amount": 2, "_card_element": ElementData.LIGHTNING},
		Vector2i(5, 4),
		"user://motion_probes/motion_25_projectile_lightning_pull_travel.png"
	)

func _capture_projectile_preview_loop(instance: Node) -> void:
	var target_tile := Vector2i(5, 4)
	var combat_state: Dictionary = _projectile_probe_state(instance, target_tile)
	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run_state["mode"] = "combat"
	run_state["combat_state"] = combat_state
	instance.set("_run_state", run_state)
	instance.set("_combat_state", combat_state)
	instance.call("_reset_card_resolution")
	instance.set("_animation_lock", false)
	instance.set("_card_play_count_override", -1)
	instance.call("_refresh_ui")
	await process_frame
	await process_frame
	var presentation: Dictionary = {
		"focus_tiles": [target_tile],
		"focus_color": Color(0.95, 0.62, 0.37, 0.22),
		"effect": {
			"kind": "ranged",
			"from": Vector2i(2, 4),
			"to": target_tile,
			"preview": true,
			"element": ElementData.FIRE
		},
		"effect_progress": 1.0
	}
	await _wait_for_projectile_preview_phase(0.24, 0.34)
	instance.call("_render_board_state", combat_state, presentation)
	await process_frame
	await _save_root_screenshot("user://motion_probes/motion_22_projectile_preview_loop_a.png")
	await _wait_for_projectile_preview_phase(0.58, 0.68)
	instance.call("_render_board_state", combat_state, presentation)
	await process_frame
	await _save_root_screenshot("user://motion_probes/motion_22_projectile_preview_loop_b.png")
	instance.call("_refresh_ui")
	await process_frame

func _capture_projectile_variant(instance: Node, card_id: String, action: Dictionary, preferred_target: Vector2i, output_path: String) -> void:
	var combat_state: Dictionary = _projectile_probe_state(instance, preferred_target)
	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run_state["mode"] = "combat"
	run_state["combat_state"] = combat_state
	instance.set("_run_state", run_state)
	instance.set("_combat_state", combat_state)
	instance.call("_reset_card_resolution")
	instance.set("_animation_lock", false)
	instance.set("_card_play_count_override", -1)
	instance.call("_refresh_ui")
	await process_frame
	await process_frame

	var combat_engine = instance.get("_combat_engine")
	var valid_targets: Array[Vector2i] = combat_engine.valid_targets_for_player_action(combat_state, action)
	var target_tile: Vector2i = preferred_target if valid_targets.has(preferred_target) else _first_enemy_target_tile(combat_state, valid_targets)
	if target_tile.x < 0:
		return
	var after_state: Dictionary = combat_engine.apply_player_action(combat_state.duplicate(true), action, target_tile)
	instance.call("_animate_player_action_step", combat_state.duplicate(true), after_state, card_id, action, target_tile)
	await create_timer(0.12).timeout
	await process_frame
	await _save_root_screenshot(output_path)
	await create_timer(0.78).timeout
	await process_frame
	instance.call("_refresh_ui")
	await process_frame

func _capture_player_ranged_impact_fx(instance: Node) -> void:
	var combat_state: Dictionary = await _prepare_impact_probe_state(
		instance,
		Vector2i(2, 4),
		[
			{"id": 1, "type": "harrier", "pos": Vector2i(5, 4), "hp": 100, "max_hp": 100, "block": 0}
		],
		["frostbolt"]
	)
	var combat_engine = instance.get("_combat_engine")
	var action: Dictionary = {"type": "ranged", "damage": 5, "range": 8, "_card_element": ElementData.ICE}
	var preferred_target := Vector2i(5, 4)
	var valid_targets: Array[Vector2i] = combat_engine.valid_targets_for_player_action(combat_state, action)
	var target_tile: Vector2i = preferred_target if valid_targets.has(preferred_target) else _first_enemy_target_tile(combat_state, valid_targets)
	if target_tile.x < 0:
		return
	var after_state: Dictionary = combat_engine.apply_player_action(combat_state.duplicate(true), action, target_tile)
	instance.call("_animate_player_action_step", combat_state.duplicate(true), after_state, "frostbolt", action, target_tile)
	await create_timer(0.12).timeout
	await process_frame
	await _save_root_screenshot("user://motion_probes/motion_24b_player_ranged_ice_travel.png")
	await create_timer(0.20).timeout
	await process_frame
	await _save_root_screenshot("user://motion_probes/motion_24c_player_ranged_ice_impact.png")
	await create_timer(0.34).timeout
	await process_frame
	await _save_root_screenshot("user://motion_probes/motion_24d_player_ranged_ice_faded.png")
	instance.call("_refresh_ui")
	await process_frame

func _projectile_probe_state(instance: Node, target_tile: Vector2i) -> Dictionary:
	var combat_state: Dictionary = (instance.get("_combat_state") as Dictionary).duplicate(true)
	combat_state["player"] = {"pos": Vector2i(2, 4), "hp": 24, "max_hp": 24, "block": 0, "stoneskin": 0}
	combat_state["current_actor"] = {"kind": "player", "key": "player"}
	combat_state["cards_played_this_turn"] = 0
	combat_state["death_bonus_card_plays_this_turn"] = 0
	combat_state["card_play_bonus_this_turn"] = 0
	combat_state.erase("player_turn_restrictions")
	combat_state["enemies"] = [
		{"id": 1, "type": "crawler", "pos": target_tile, "hp": 100, "max_hp": 100, "block": 0}
	]
	combat_state["traps"] = []
	combat_state["terrain"] = []
	combat_state["illusions"] = []
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["bone_dart", "firebrand_volley", "lodestone_reversal"]
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	combat_state["deck"] = deck
	return combat_state

func _wait_for_projectile_preview_phase(min_phase: float, max_phase: float) -> void:
	for _index: int in range(180):
		var phase: float = wrapf((float(Time.get_ticks_msec()) / 1000.0) / PROJECTILE_PREVIEW_LOOP_SECONDS, 0.0, 1.0)
		if phase >= min_phase and phase <= max_phase:
			return
		await create_timer(0.02).timeout

func _capture_player_aoe_fx(instance: Node) -> void:
	var combat_state: Dictionary = (instance.get("_combat_state") as Dictionary).duplicate(true)
	combat_state["player"] = {"pos": Vector2i(2, 4), "hp": 24, "max_hp": 24, "block": 0, "stoneskin": 0}
	combat_state["current_actor"] = {"kind": "player", "key": "player"}
	combat_state["cards_played_this_turn"] = 0
	combat_state["death_bonus_card_plays_this_turn"] = 0
	combat_state["card_play_bonus_this_turn"] = 0
	combat_state.erase("player_turn_restrictions")
	combat_state["enemies"] = [
		{"id": 1, "type": "crawler", "pos": Vector2i(4, 4), "hp": 100, "max_hp": 100, "block": 0},
		{"id": 2, "type": "harrier", "pos": Vector2i(5, 4), "hp": 100, "max_hp": 100, "block": 0},
		{"id": 3, "type": "acolyte", "pos": Vector2i(6, 4), "hp": 100, "max_hp": 100, "block": 0}
	]
	combat_state["traps"] = []
	combat_state["terrain"] = []
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["thunderline", "updraft"]
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	combat_state["deck"] = deck
	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run_state["mode"] = "combat"
	run_state["combat_state"] = combat_state
	instance.set("_run_state", run_state)
	instance.set("_combat_state", combat_state)
	instance.call("_reset_card_resolution")
	instance.set("_animation_lock", false)
	instance.set("_card_play_count_override", -1)
	instance.call("_refresh_ui")
	await process_frame
	await process_frame

	var combat_engine = instance.get("_combat_engine")
	var action: Dictionary = {
		"type": "aoe",
		"damage": 50,
		"range": 6,
		"pattern": [[0, 0], [1, 0], [2, 0]],
		"rotate": true,
		"_card_element": "lightning",
		"orientation": Vector2i(1, 0)
	}
	var target_tile := Vector2i(4, 4)
	var after_state: Dictionary = combat_engine.apply_player_action(combat_state.duplicate(true), action, target_tile)
	instance.call("_animate_player_action_step", combat_state.duplicate(true), after_state, "thunderline", action, target_tile)
	await create_timer(0.10).timeout
	await process_frame
	await _save_root_screenshot("user://motion_probes/motion_26_player_aoe_windup.png")
	await create_timer(0.24).timeout
	await process_frame
	await _save_root_screenshot("user://motion_probes/motion_27_player_aoe_impact.png")
	await create_timer(0.34).timeout
	await process_frame
	await _save_root_screenshot("user://motion_probes/motion_27b_player_aoe_faded.png")
	instance.call("_refresh_ui")
	await process_frame

func _prepare_impact_probe_state(instance: Node, player_tile: Vector2i, enemies: Array, hand: Array) -> Dictionary:
	var combat_state: Dictionary = (instance.get("_combat_state") as Dictionary).duplicate(true)
	combat_state["player"] = {"pos": player_tile, "hp": 24, "max_hp": 24, "block": 0, "stoneskin": 0}
	combat_state["current_actor"] = {"kind": "player", "key": "player"}
	combat_state["cards_played_this_turn"] = 0
	combat_state["death_bonus_card_plays_this_turn"] = 0
	combat_state["card_play_bonus_this_turn"] = 0
	combat_state.erase("player_turn_restrictions")
	combat_state["enemies"] = enemies.duplicate(true)
	combat_state["traps"] = []
	combat_state["terrain"] = []
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = hand.duplicate()
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	combat_state["deck"] = deck
	_apply_probe_combat_state(instance, combat_state)
	await process_frame
	await process_frame
	return combat_state

func _capture_defense_heal_cast_fx(instance: Node) -> void:
	var combat_state: Dictionary = await _prepare_impact_probe_state(
		instance,
		Vector2i(2, 4),
		[
			{"id": 1, "type": "crawler", "pos": Vector2i(5, 4), "hp": 80, "max_hp": 80, "block": 0, "stoneskin": 0}
		],
		["guarded_step", "patch_up", "stone_plate"]
	)
	var base_player: Dictionary = (combat_state.get("player", {}) as Dictionary).duplicate(true)
	base_player["hp"] = 16
	base_player["max_hp"] = 24
	combat_state["player"] = base_player
	_apply_probe_combat_state(instance, combat_state)
	await process_frame
	await process_frame

	var block_before: Dictionary = combat_state.duplicate(true)
	var block_after: Dictionary = block_before.duplicate(true)
	var block_player: Dictionary = (block_after.get("player", {}) as Dictionary).duplicate(true)
	block_player["block"] = 6
	block_after["player"] = block_player
	instance.call("_animate_player_action_step", block_before, block_after, "guarded_step", {"type": "block", "amount": 6}, Vector2i(-1, -1))
	await create_timer(0.11).timeout
	await process_frame
	await _save_root_screenshot("user://motion_probes/motion_28_player_block_flare.png")
	await create_timer(0.34).timeout
	await process_frame

	var heal_before: Dictionary = combat_state.duplicate(true)
	var heal_player: Dictionary = (heal_before.get("player", {}) as Dictionary).duplicate(true)
	heal_player["hp"] = 14
	heal_player["block"] = 0
	heal_before["player"] = heal_player
	_apply_probe_combat_state(instance, heal_before)
	await process_frame
	var heal_after: Dictionary = heal_before.duplicate(true)
	var healed_player: Dictionary = (heal_after.get("player", {}) as Dictionary).duplicate(true)
	healed_player["hp"] = 19
	heal_after["player"] = healed_player
	instance.call("_animate_player_action_step", heal_before, heal_after, "patch_up", {"type": "heal", "amount": 5}, Vector2i(-1, -1))
	await create_timer(0.13).timeout
	await process_frame
	await _save_root_screenshot("user://motion_probes/motion_29_player_heal_motes.png")
	await create_timer(0.34).timeout
	await process_frame

	var skin_before: Dictionary = combat_state.duplicate(true)
	var skin_player: Dictionary = (skin_before.get("player", {}) as Dictionary).duplicate(true)
	skin_player["hp"] = 18
	skin_player["block"] = 0
	skin_player["stoneskin"] = 0
	skin_before["player"] = skin_player
	_apply_probe_combat_state(instance, skin_before)
	await process_frame
	var skin_after: Dictionary = skin_before.duplicate(true)
	var armored_player: Dictionary = (skin_after.get("player", {}) as Dictionary).duplicate(true)
	armored_player["stoneskin"] = 5
	skin_after["player"] = armored_player
	instance.call("_animate_player_action_step", skin_before, skin_after, "stone_plate", {"type": "stoneskin", "amount": 5}, Vector2i(-1, -1))
	await create_timer(0.13).timeout
	await process_frame
	await _save_root_screenshot("user://motion_probes/motion_32_player_stoneskin_shards.png")
	await create_timer(0.34).timeout
	await process_frame

	var enemy_before: Dictionary = combat_state.duplicate(true)
	_apply_probe_combat_state(instance, enemy_before)
	await process_frame
	var enemy_step := {
		"kind": "stoneskin",
		"actor_key": "enemy_1",
		"actor_name": "Crawler",
		"label": "Stone Shell",
		"tile": Vector2i(5, 4),
		"amount": 4
	}
	instance.call("_animate_enemy_phase_steps", enemy_before, [enemy_step])
	await create_timer(0.13).timeout
	await process_frame
	await _save_root_screenshot("user://motion_probes/motion_33_enemy_stoneskin_ring.png")
	await create_timer(0.34).timeout
	await process_frame
	instance.call("_refresh_ui")
	await process_frame

func _capture_enemy_phase_fx(instance: Node) -> void:
	var combat_state: Dictionary = (instance.get("_combat_state") as Dictionary).duplicate(true)
	var enemy: Dictionary = _first_live_enemy(combat_state)
	if enemy.is_empty():
		return
	var from_tile: Vector2i = enemy.get("pos", Vector2i.ZERO)
	var to_tile: Vector2i = _probe_enemy_move_tile(combat_state, enemy)
	if to_tile == from_tile:
		return
	var step := {
		"kind": "move",
		"actor_key": "enemy_%d" % int(enemy.get("id", -1)),
		"actor_name": str(enemy.get("name", "Enemy")),
		"label": "Advance",
		"from": from_tile,
		"to": to_tile
	}
	instance.call("_animate_move_step", combat_state, step)
	await create_timer(0.14).timeout
	await process_frame
	await _save_root_screenshot("user://motion_probes/motion_25_enemy_move_mid.png")
	await create_timer(0.52).timeout
	await process_frame
	instance.call("_refresh_ui")
	await process_frame

func _capture_ember_fx(instance: Node) -> void:
	instance.call("_animate_ember_reward", Vector2i(4, 4), 8, 0, 8)
	await create_timer(0.10).timeout
	await process_frame
	await _save_root_screenshot("user://motion_probes/motion_30_ember_motes_mid.png")
	await create_timer(0.55).timeout
	await process_frame
	await _save_root_screenshot("user://motion_probes/motion_31_ember_counter_pulse.png")

func _capture_fatigue_fx(instance: Node) -> void:
	var combat_state: Dictionary = (instance.get("_combat_state") as Dictionary).duplicate(true)
	var player_pos: Vector2i = (combat_state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO)
	var fatigue_events: Array[Dictionary] = []
	fatigue_events.append({"cycle": 2, "amount": 4, "tile": player_pos})
	instance.call("_animate_fatigue_damage", combat_state, fatigue_events)
	await create_timer(0.12).timeout
	await process_frame
	await _save_root_screenshot("user://motion_probes/motion_40_fatigue_rise.png")
	await create_timer(0.42).timeout
	await process_frame
	await _save_root_screenshot("user://motion_probes/motion_41_fatigue_linger.png")
	await create_timer(1.10).timeout
	await process_frame

func _capture_turn_order_fx(instance: Node) -> void:
	var combat_state: Dictionary = (instance.get("_combat_state") as Dictionary).duplicate(true)
	var combat_engine = instance.get("_combat_engine")
	var scheduled_state: Dictionary = combat_engine.finish_player_activation(combat_state.duplicate(true))
	instance.call("_animate_turn_order_transition_between_states", combat_state.duplicate(true), scheduled_state.duplicate(true))
	await create_timer(0.10).timeout
	await process_frame
	await _save_root_screenshot("user://motion_probes/motion_50_turn_order_pop.png")
	await create_timer(0.34).timeout
	await process_frame
	await _save_root_screenshot("user://motion_probes/motion_51_turn_order_slide.png")

func _first_live_enemy(combat_state: Dictionary) -> Dictionary:
	for enemy_var: Variant in combat_state.get("enemies", []):
		if typeof(enemy_var) != TYPE_DICTIONARY:
			continue
		var enemy: Dictionary = enemy_var as Dictionary
		if int(enemy.get("hp", 1)) > 0:
			return enemy
	return {}

func _probe_enemy_move_tile(combat_state: Dictionary, enemy: Dictionary) -> Vector2i:
	var from_tile: Vector2i = enemy.get("pos", Vector2i.ZERO)
	var directions: Array[Vector2i] = [
		Vector2i(1, 0),
		Vector2i(0, 1),
		Vector2i(-1, 0),
		Vector2i(0, -1)
	]
	for direction: Vector2i in directions:
		var candidate: Vector2i = from_tile + direction
		if _probe_actor_can_fit(combat_state, enemy, candidate):
			return candidate
	return from_tile

func _first_enemy_target_tile(combat_state: Dictionary, valid_targets: Array[Vector2i]) -> Vector2i:
	for target_tile: Vector2i in valid_targets:
		for enemy_var: Variant in combat_state.get("enemies", []):
			if typeof(enemy_var) != TYPE_DICTIONARY:
				continue
			var enemy: Dictionary = enemy_var as Dictionary
			if int(enemy.get("hp", 0)) <= 0:
				continue
			for enemy_tile: Vector2i in _probe_unit_tiles(enemy):
				if enemy_tile == target_tile:
					return target_tile
	return Vector2i(-1, -1)

func _probe_actor_can_fit(combat_state: Dictionary, enemy: Dictionary, anchor: Vector2i) -> bool:
	var grid: Array = combat_state.get("grid", [])
	var footprint: Vector2i = enemy.get("footprint", Vector2i.ONE)
	for y: int in range(maxi(1, footprint.y)):
		for x: int in range(maxi(1, footprint.x)):
			var tile := anchor + Vector2i(x, y)
			if not PathUtils.is_passable(grid, tile):
				return false
			if _probe_tile_occupied(combat_state, tile, int(enemy.get("id", -1))):
				return false
	return true

func _probe_tile_occupied(combat_state: Dictionary, tile: Vector2i, moving_enemy_id: int) -> bool:
	var player: Dictionary = combat_state.get("player", {})
	if int(player.get("hp", 0)) > 0 and player.get("pos", Vector2i.ZERO) == tile:
		return true
	for enemy_var: Variant in combat_state.get("enemies", []):
		if typeof(enemy_var) != TYPE_DICTIONARY:
			continue
		var enemy: Dictionary = enemy_var as Dictionary
		if int(enemy.get("id", -1)) == moving_enemy_id or int(enemy.get("hp", 0)) <= 0:
			continue
		for occupied_tile: Vector2i in _probe_unit_tiles(enemy):
			if occupied_tile == tile:
				return true
	for illusion_var: Variant in combat_state.get("illusions", []):
		if typeof(illusion_var) != TYPE_DICTIONARY:
			continue
		var illusion: Dictionary = illusion_var as Dictionary
		if int(illusion.get("hp", 0)) > 0 and illusion.get("pos", Vector2i.ZERO) == tile:
			return true
	for terrain_var: Variant in combat_state.get("terrain", []):
		if typeof(terrain_var) != TYPE_DICTIONARY:
			continue
		var terrain: Dictionary = terrain_var as Dictionary
		if int(terrain.get("hp", 0)) > 0 and terrain.get("pos", Vector2i.ZERO) == tile:
			return true
	return false

func _probe_unit_tiles(unit: Dictionary) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	var anchor: Vector2i = unit.get("pos", Vector2i.ZERO)
	var footprint: Vector2i = unit.get("footprint", Vector2i.ONE)
	for y: int in range(maxi(1, footprint.y)):
		for x: int in range(maxi(1, footprint.x)):
			tiles.append(anchor + Vector2i(x, y))
	return tiles

func _apply_probe_combat_state(instance: Node, combat_state: Dictionary) -> void:
	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run_state["mode"] = "combat"
	run_state["combat_state"] = combat_state
	instance.set("_run_state", run_state)
	instance.set("_combat_state", combat_state)
	instance.call("_reset_card_resolution")
	instance.set("_animation_lock", false)
	instance.set("_card_play_count_override", -1)
	instance.call("_refresh_ui")

func _save_root_screenshot(output_path: String) -> void:
	var image: Image = root.get_viewport().get_texture().get_image()
	image.save_png(output_path)

func _clear_probe_output(output_dir: String) -> void:
	var dir := DirAccess.open(output_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".png"):
			dir.remove(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
