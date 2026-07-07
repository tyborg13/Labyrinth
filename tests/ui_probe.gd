extends SceneTree

const GameData = preload("res://scripts/game_data.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")

const DOOR_OPENING_PROBE_DIR: String = "user://probes/door_opening"
const DOOR_OPENING_PROBE_FRAMES: int = 8

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://probes"))
	_clear_probe_output("user://probes")
	ProgressionStore.set_storage_path("user://labyrinth_progression_probe.json")
	ProgressionStore.set_run_storage_path("user://labyrinth_run_probe.save")
	ProgressionStore.clear_saved_run()
	await _capture_scene("res://scenes/main_menu.tscn", "user://probes/main_menu.png")
	await _capture_run_states()
	print(ProjectSettings.globalize_path("user://probes"))
	quit()

func _capture_scene(scene_path: String, output_path: String) -> void:
	var packed: PackedScene = load(scene_path)
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame
	await _save_root_screenshot(output_path)
	instance.queue_free()
	await process_frame

func _capture_grimoire_snapshot(instance: Node, output_path: String) -> void:
	instance.call("_open_grimoire_overlay")
	await process_frame
	await process_frame
	await _save_root_screenshot(output_path)
	instance.call("_close_grimoire_overlay")
	await process_frame
	await process_frame

func _capture_run_states() -> void:
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame
	var probe_run_engine := RunEngine.new()
	instance.call("_load_run_state", probe_run_engine.create_new_run(123, ProgressionStore.default_data()))
	await process_frame
	await process_frame
	await _save_root_screenshot("user://probes/run_start.png")
	await _capture_and_clear_start_dialogue(instance)
	await _capture_grimoire_snapshot(instance, "user://probes/run_grimoire_start.png")
	var combat_coord: Vector2i = _first_available_room_coord_of_type(instance, "combat")
	if combat_coord != Vector2i.ZERO:
		await _capture_door_opening_probe(instance, combat_coord)

	instance.call("_open_large_map")
	await process_frame
	await process_frame
	await _save_root_screenshot("user://probes/run_large_map.png")
	instance.call("_close_large_map")
	await process_frame
	await process_frame

	instance.call("_open_character_stats_overlay")
	await process_frame
	await process_frame
	await _save_root_screenshot("user://probes/run_character_overlay.png")
	instance.call("_close_card_upgrade_overlay")
	await process_frame
	await process_frame

	if combat_coord != Vector2i.ZERO:
		await instance.call("_on_map_view_room_selected", combat_coord)
		await process_frame
		await process_frame
		var pre_battle_scrim: Control = instance.get("_pre_battle_scrim") as Control
		if pre_battle_scrim != null and pre_battle_scrim.visible:
			await create_timer(0.24).timeout
			await _save_root_screenshot("user://probes/run_pre_battle.png")
			await instance.call("_on_pre_battle_start_pressed")
		await create_timer(0.95).timeout
		await process_frame
		await process_frame
		await _save_root_screenshot("user://probes/run_combat.png")
		await _capture_grimoire_snapshot(instance, "user://probes/run_grimoire_combat.png")
		await _capture_turn_order_probe(instance)
		await _capture_pass_preview_probe(instance)
		var combat_state: Dictionary = instance.get("_combat_state")
		var ranged_deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
		if ranged_deck.get("hand", []).is_empty():
			ranged_deck["hand"] = ["bone_dart"]
		else:
			ranged_deck["hand"][0] = "bone_dart"
		combat_state["deck"] = ranged_deck
		var ranged_run_state: Dictionary = instance.get("_run_state")
		ranged_run_state["combat_state"] = combat_state
		instance.set("_run_state", ranged_run_state)
		instance.set("_combat_state", combat_state)
		instance.call("_refresh_ui")
		await process_frame
		await process_frame
		await _save_root_screenshot("user://probes/run_combat_ranged_card.png")
		combat_state["relics"] = ["ember_lens", "pilgrim_boots", "mirror_shard"]
		var combat_deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
		if combat_deck.get("hand", []).is_empty():
			combat_deck["hand"] = ["quick_stab"]
		else:
			combat_deck["hand"][0] = "quick_stab"
		combat_state["deck"] = combat_deck
		var run_state_with_bonus: Dictionary = instance.get("_run_state")
		run_state_with_bonus["relics"] = ["ember_lens", "pilgrim_boots", "mirror_shard"]
		var rooms: Dictionary = (run_state_with_bonus.get("rooms", {}) as Dictionary).duplicate(true)
		for room_key: String in rooms.keys():
			var room_state: Dictionary = (rooms[room_key] as Dictionary).duplicate(true)
			if room_state.get("coord", Vector2i.ZERO) == Vector2i.ZERO:
				room_state["cleared"] = true
			elif room_state.get("coord", Vector2i.ZERO) == combat_coord:
				room_state["cleared"] = false
			elif bool(room_state.get("revealed", false)):
				room_state["cleared"] = true
			rooms[room_key] = room_state
		run_state_with_bonus["rooms"] = rooms
		run_state_with_bonus["combat_state"] = combat_state
		instance.set("_run_state", run_state_with_bonus)
		instance.set("_combat_state", combat_state)
		instance.call("_refresh_ui")
		await process_frame
		await process_frame
		await _save_root_screenshot("user://probes/run_combat_damage_bonus.png")
		var hand_box: Control = instance.get_node("Backdrop/Margin/MainVBox/BottomStack/HandRow/HandScroll/HandCenter/HandBox")
		if hand_box.get_child_count() > 0:
			var slot: Node = hand_box.get_child(0)
			var widget_node: Node = _first_node_with_method(slot, "_make_custom_tooltip")
			var widget: Control = widget_node as Control
			if widget != null:
				var tooltip: Variant = widget.call("_make_custom_tooltip", "modifiers")
				if tooltip != null and tooltip is Control:
					var tooltip_control: Control = tooltip
					tooltip_control.position = widget.global_position + Vector2(widget.size.x + 12.0, 8.0)
					root.add_child(tooltip_control)
					await process_frame
					await process_frame
					await _save_root_screenshot("user://probes/run_combat_damage_tooltip.png")
					tooltip_control.queue_free()
					await process_frame
		await _capture_orientation_previews(instance)
		instance.call("_open_menu_overlay")
		await process_frame
		await process_frame
		await _save_root_screenshot("user://probes/run_menu.png")
		instance.call("_close_menu_overlay")
		await _capture_pile_overlay_snapshot(instance, "draw", ["bloody_lunge", "guarded_step", "hamstring_shot", "patch_up", "sidestep_slash"], "user://probes/run_draw_pile.png")
		await _capture_pile_overlay_snapshot(instance, "discard", [], "user://probes/run_discard_pile_empty.png")
		instance.call("_on_card_drag_started", 0)
		await process_frame
		await process_frame
		instance.call("_update_drag_proxy_position", Vector2(640.0, 430.0))
		instance.call("_update_drag_overlay_hover", "move")
		await process_frame
		await process_frame
		await _save_root_screenshot("user://probes/run_drag_overlay_move.png")
		instance.call("_commit_drag_drop", "move")
		await create_timer(0.25).timeout
		await process_frame
		await process_frame
		var drag_preview: Dictionary = instance.call("_active_card_preview")
		var drag_targets: Array = drag_preview.get("target_tiles", [])
		if not drag_targets.is_empty():
			instance.call("_on_board_tile_hovered", drag_targets[0])
			await process_frame
			await process_frame
			await _save_root_screenshot("user://probes/run_fallback_move_target.png")
			instance.call("_on_cancel_requested")
			await process_frame
			await process_frame
		var card_index: int = _targeted_card_index(instance)
		instance.call("_on_card_hover_started", card_index)
		await process_frame
		await process_frame
		await _save_root_screenshot("user://probes/run_combat_card_hover.png")
		instance.call("_on_card_pressed", card_index)
		var preview: Dictionary = instance.call("_active_card_preview")
		var target_tiles: Array = preview.get("target_tiles", [])
		if not target_tiles.is_empty():
			instance.call("_on_board_tile_hovered", target_tiles[0])
			await process_frame
			await process_frame
			await _save_root_screenshot("user://probes/run_combat_target_hover.png")
		await process_frame
		await process_frame
		await _save_root_screenshot("user://probes/run_combat_card_selected.png")
		if not target_tiles.is_empty():
			instance.call("_on_board_tile_clicked", target_tiles[0])
			await create_timer(2.1).timeout
			await process_frame
			await process_frame
			await _save_root_screenshot("user://probes/run_combat_after_play.png")
		await _capture_pile_overlay_snapshot(instance, "discard", ["quick_stab"], "user://probes/run_discard_pile.png")

	var reward_run_state: Dictionary = instance.get("_run_state")
	reward_run_state["mode"] = "reward"
	reward_run_state["pending_reward"] = {
		"cards": ["quick_stab", "bone_dart", "sidestep_slash", "patch_up"],
		"heal_amount": RunEngine.REWARD_HEAL,
		"ember_amount": 0
	}
	instance.set("_run_state", reward_run_state)
	instance.set("_selected_card_index", -1)
	instance.set("_drag_card_index", -1)
	instance.call("_refresh_ui")
	await process_frame
	await process_frame
	await _save_root_screenshot("user://probes/run_reward.png")

	await _capture_special_room_states(instance, probe_run_engine)

	instance.queue_free()
	await process_frame

func _first_node_with_method(node: Node, method_name: String) -> Node:
	if node.has_method(method_name):
		return node
	for child: Node in node.get_children():
		var found: Node = _first_node_with_method(child, method_name)
		if found != null:
			return found
	return null

func _capture_and_clear_start_dialogue(instance: Node) -> void:
	for frame_index: int in range(4):
		if bool(instance.get("_dialogue_active")):
			break
		await process_frame
	if bool(instance.get("_dialogue_active")):
		instance.call("_complete_current_dialogue_line")
		await process_frame
		await process_frame
		await _save_root_screenshot("user://probes/run_start_dialogue_full.png")
	for attempt: int in range(4):
		if not bool(instance.get("_dialogue_active")):
			break
		instance.call("_close_dialogue")
		await process_frame
	await process_frame

func _capture_special_room_states(instance: Node, probe_run_engine: RunEngine) -> void:
	var progression: Dictionary = ProgressionStore.set_embers(ProgressionStore.default_data(), 180)
	var base_state: Dictionary = probe_run_engine.create_new_run(321, progression)
	var campfire_state: Dictionary = _run_state_for_room(probe_run_engine, base_state, Vector2i(2, 0), "campfire", Vector2i(1, 0))
	campfire_state["player_hp"] = 120
	campfire_state["player_max_hp"] = 360
	instance.call("_load_run_state", campfire_state)
	await process_frame
	await process_frame
	await _save_root_screenshot("user://probes/run_campfire.png")

	instance.call("_open_level_up_overlay")
	await process_frame
	await process_frame
	await _save_root_screenshot("user://probes/run_level_up_overlay.png")
	instance.call("_close_card_upgrade_overlay")
	await process_frame
	await process_frame

	var treasure_coord: Vector2i = _first_room_coord_of_type(probe_run_engine, base_state, "treasure")
	var treasure_state: Dictionary = _run_state_for_room(probe_run_engine, base_state, treasure_coord, "treasure", Vector2i(1, 0))
	treasure_state["pending_relics"] = ["iron_lung", "ember_lens", "pilgrim_boots"]
	instance.call("_load_run_state", treasure_state)
	await process_frame
	await process_frame
	await _save_root_screenshot("user://probes/run_treasure.png")

	var victory_state: Dictionary = _run_state_for_room(probe_run_engine, base_state, Vector2i(8, 0), "victory", Vector2i(1, 0))
	victory_state["victory"] = true
	victory_state["held_embers"] = 42
	instance.call("_load_run_state", victory_state)
	await process_frame
	await process_frame
	await _save_root_screenshot("user://probes/run_victory.png")

	var defeat_state: Dictionary = _run_state_for_room(probe_run_engine, base_state, Vector2i(1, 0), "defeat", Vector2i(1, 0))
	defeat_state["player_hp"] = 0
	defeat_state["held_embers"] = 23
	instance.call("_load_run_state", defeat_state)
	await create_timer(3.45).timeout
	await process_frame
	await process_frame
	await _save_root_screenshot("user://probes/run_defeat.png")

func _first_available_room_coord_of_type(instance: Node, room_type: String) -> Vector2i:
	var run_state: Dictionary = instance.get("_run_state")
	var run_engine = instance.get("_run_engine")
	for coord: Vector2i in run_engine.available_moves(run_state):
		var room: Dictionary = run_engine.room_metadata(run_state, coord)
		if str(room.get("type", "")) == room_type:
			return coord
	return Vector2i.ZERO

func _capture_door_opening_probe(instance: Node, destination_coord: Vector2i) -> void:
	var door_tile: Vector2i = instance.call("_door_tile_for_destination", destination_coord)
	if door_tile.x < 0:
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DOOR_OPENING_PROBE_DIR))
	_clear_probe_output(DOOR_OPENING_PROBE_DIR)
	var previous_lock: bool = bool(instance.get("_animation_lock"))
	var previous_hover: Vector2i = instance.get("_hovered_board_tile")
	var previous_presentation: Dictionary = (instance.get("_board_presentation") as Dictionary).duplicate(true)
	instance.set("_animation_lock", true)
	instance.set("_hovered_board_tile", door_tile)
	for frame: int in range(DOOR_OPENING_PROBE_FRAMES):
		var progress: float = 1.0 if DOOR_OPENING_PROBE_FRAMES <= 1 else float(frame) / float(DOOR_OPENING_PROBE_FRAMES - 1)
		instance.set("_board_presentation", {
			"door_opening": {
				"tile": door_tile,
				"frame": frame,
				"progress": progress
			}
		})
		instance.call("_refresh_stage_view")
		await process_frame
		await process_frame
		await _save_root_screenshot("%s/frame_%02d.png" % [DOOR_OPENING_PROBE_DIR, frame])
	instance.set("_board_presentation", previous_presentation)
	instance.set("_hovered_board_tile", previous_hover)
	instance.set("_animation_lock", previous_lock)
	instance.call("_refresh_stage_view")
	await process_frame

func _run_state_for_room(probe_run_engine: RunEngine, source_state: Dictionary, coord: Vector2i, mode: String, travel_dir: Vector2i) -> Dictionary:
	var state: Dictionary = source_state.duplicate(true)
	var room: Dictionary = probe_run_engine.room_metadata(state, coord).duplicate(true)
	room["revealed"] = true
	room["visited"] = true
	room["cleared"] = mode == "room"
	var rooms: Dictionary = (state.get("rooms", {}) as Dictionary).duplicate(true)
	rooms[_room_key(coord)] = room
	state["rooms"] = rooms
	state["current_room"] = coord
	state["current_room_layout"] = probe_run_engine.call("_display_layout_for_room", int(state.get("seed", 0)), room, travel_dir)
	state["mode"] = mode
	state["combat_state"] = {}
	state["pending_reward"] = {}
	state["pending_relics"] = []
	return state

func _first_room_coord_of_type(probe_run_engine: RunEngine, state: Dictionary, room_type: String) -> Vector2i:
	for radius: int in range(1, 9):
		for x: int in range(-radius, radius + 1):
			for y: int in range(-radius, radius + 1):
				var coord := Vector2i(x, y)
				if maxi(absi(x), absi(y)) != radius:
					continue
				if str(probe_run_engine.room_metadata(state, coord).get("type", "")) == room_type:
					return coord
	return Vector2i.ZERO

func _room_key(coord: Vector2i) -> String:
	return "%d,%d" % [coord.x, coord.y]

func _capture_turn_order_probe(instance: Node) -> void:
	var combat_state: Dictionary = (instance.get("_combat_state") as Dictionary).duplicate(true)
	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run_state["mode"] = "combat"
	run_state["combat_state"] = combat_state
	instance.set("_run_state", run_state)
	instance.set("_combat_state", combat_state.duplicate(true))
	instance.call("_refresh_ui")
	await process_frame
	await process_frame
	await _save_root_screenshot("user://probes/run_turn_order_before_pass.png")

	var combat_engine = instance.get("_combat_engine")
	var scheduled_state: Dictionary = combat_engine.finish_player_activation(combat_state.duplicate(true))
	instance.call("_animate_turn_order_transition_between_states", combat_state.duplicate(true), scheduled_state.duplicate(true))
	await create_timer(0.10).timeout
	await process_frame
	await _save_root_screenshot("user://probes/run_turn_order_player_pop_mid.png")
	await create_timer(0.55).timeout
	await process_frame
	await _save_root_screenshot("user://probes/run_turn_order_player_reslot.png")

	var reset_state: Dictionary = combat_state.duplicate(true)
	run_state = (instance.get("_run_state") as Dictionary).duplicate(true)
	run_state["mode"] = "combat"
	run_state["combat_state"] = reset_state
	instance.set("_run_state", run_state)
	instance.set("_combat_state", reset_state)
	instance.set("_turn_order_animating", false)
	instance.call("_refresh_ui")
	await process_frame
	await process_frame
	instance.call("_on_pass_turn_pressed")
	await create_timer(3.2).timeout
	await process_frame
	await process_frame
	await _save_root_screenshot("user://probes/run_turn_order_after_pass_full.png")

func _capture_pass_preview_probe(instance: Node) -> void:
	var base_state: Dictionary = (instance.get("_combat_state") as Dictionary).duplicate(true)
	if base_state.is_empty():
		return
	var danger_state: Dictionary = _pass_preview_probe_state(base_state, "danger")
	_install_pass_preview_probe_state(instance, danger_state)
	await process_frame
	await process_frame
	_require_pass_preview_chip(instance, "danger")
	await _save_root_screenshot("user://probes/run_pass_preview_danger.png")

	await instance.call("_on_card_pressed", 0)
	await process_frame
	await process_frame
	_require_pass_preview_chip(instance, "selected card")
	await _save_root_screenshot("user://probes/run_pass_preview_selected_card.png")

	var move_target: Vector2i = _pass_preview_probe_move_target(instance.get("_pending_target_tiles") as Array, Vector2i(3, 4))
	if move_target.x >= 0:
		instance.call("_on_board_tile_hovered", move_target)
		await process_frame
		await process_frame
		_require_pass_preview_chip(instance, "selected move hover")
		await _save_root_screenshot("user://probes/run_pass_preview_selected_move_hover.png")

	var after_card_state: Dictionary = _pass_preview_probe_after_guarded_step(instance, danger_state)
	_install_pass_preview_probe_state(instance, after_card_state)
	await process_frame
	await process_frame
	_require_pass_preview_chip(instance, "after card")
	await _save_root_screenshot("user://probes/run_pass_preview_after_card.png")

	var safe_state: Dictionary = _pass_preview_probe_state(base_state, "safe")
	_install_pass_preview_probe_state(instance, safe_state)
	await process_frame
	await process_frame
	_require_pass_preview_chip(instance, "safe")
	await _save_root_screenshot("user://probes/run_pass_preview_safe.png")

	var layered_state: Dictionary = _pass_preview_probe_state(base_state, "layered")
	_install_pass_preview_probe_state(instance, layered_state)
	await process_frame
	await process_frame
	_require_pass_preview_chip(instance, "layered")
	await _save_root_screenshot("user://probes/run_pass_preview_layered.png")

	var unrevealed_state: Dictionary = _pass_preview_probe_state(base_state, "unrevealed")
	_install_pass_preview_probe_state(instance, unrevealed_state)
	await process_frame
	await process_frame
	_require_pass_preview_chip(instance, "unrevealed")
	await _save_root_screenshot("user://probes/run_pass_preview_unrevealed.png")

	_install_pass_preview_probe_state(instance, safe_state)
	await process_frame

func _install_pass_preview_probe_state(instance: Node, combat_state: Dictionary) -> void:
	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run_state["mode"] = "combat"
	run_state["combat_state"] = combat_state.duplicate(true)
	instance.set("_run_state", run_state)
	instance.set("_combat_state", combat_state.duplicate(true))
	instance.set("_animation_lock", false)
	instance.set("_drag_card_index", -1)
	instance.set("_card_play_count_override", -1)
	instance.call("_reset_card_resolution")
	instance.call("_refresh_ui")

func _pass_preview_probe_state(base_state: Dictionary, kind: String) -> Dictionary:
	var state: Dictionary = base_state.duplicate(true)
	var enemy_pos: Vector2i = Vector2i(3, 4)
	var enemy_intent: Dictionary = {"name": "Claw", "time": 1, "actions": [{"type": "melee", "damage": 5, "range": 1}]}
	if kind == "safe":
		enemy_pos = Vector2i(6, 4)
		enemy_intent = {"name": "Claw", "time": 1, "actions": [{"type": "melee", "damage": 5, "range": 1}]}
	elif kind == "layered":
		enemy_intent = {"name": "Crush", "time": 1, "actions": [{"type": "melee", "damage": 12, "range": 1}]}
	elif kind == "unrevealed":
		enemy_pos = Vector2i(6, 4)
	state["player"] = {
		"pos": Vector2i(2, 4),
		"hp": 24,
		"max_hp": 24,
		"block": 3 if kind == "layered" else 0,
		"stoneskin": 4 if kind == "layered" else 0,
		"burn": 0,
		"bleed": 0,
		"expose": 0,
		"freeze": 0,
		"shock": 0,
		"immobilize": false,
		"poison": {"damage": 0, "trigger": 0, "stacks": []}
	}
	state["enemies"] = [{
		"id": 1,
		"type": "crawler",
		"pos": enemy_pos,
		"hp": 14,
		"max_hp": 14,
		"block": 0,
		"stoneskin": 0,
		"burn": 0,
		"bleed": 0,
		"expose": 0,
		"freeze": 0,
		"shock": 0,
		"immobilize": false,
		"poison": {"damage": 0, "trigger": 0, "stacks": []},
		"intent": enemy_intent
	}]
	state["illusions"] = []
	state["traps"] = []
	state["terrain"] = []
	state["grid"] = _pass_preview_probe_simple_grid()
	state["deck"] = {
		"hand": ["guarded_step", "quick_stab"],
		"draw": ["patch_up", "bone_dart"],
		"discard": ["sidestep_slash"],
		"burned": [],
		"cycles": 0,
		"fatigue_base": 15
	}
	state["cards_per_turn"] = 2
	state["draw_per_turn"] = 2
	state["cards_played_this_turn"] = 0
	state["death_bonus_card_plays_this_turn"] = 0
	state["card_play_bonus_this_turn"] = 0
	state["player_turn_time_spent"] = 20 if kind == "unrevealed" else 0
	state["player_turn_restrictions"] = {"frozen": false, "shocked": false, "immobilized": false}
	state["pending_player_trap_restriction"] = ""
	state["turn_flags"] = {"first_attack_bonus_used": false, "first_move_bonus_used": false}
	state["initiative_clock"] = 0
	state["activation_seq"] = 1
	state["current_actor"] = {
		"kind": "player",
		"actor_key": "player",
		"name": "Reaver",
		"type": "player",
		"team": "player",
		"time": 0,
		"seq": 0
	}
	state["turn_queue"] = [{
		"kind": "enemy",
		"actor_key": "enemy_1",
		"enemy_id": 1,
		"type": "crawler",
		"name": "Tunnel Crawler",
		"team": "enemy",
		"time": 1,
		"seq": 1,
		"pos": enemy_pos
	}]
	return state

func _pass_preview_probe_simple_grid() -> Array:
	var grid: Array = []
	for y: int in range(8):
		var row: Array[String] = []
		for x: int in range(8):
			row.append("wall" if x == 0 or y == 0 or x == 7 or y == 7 else "ash")
		grid.append(row)
	return grid

func _pass_preview_probe_move_target(target_tiles: Array, enemy_pos: Vector2i) -> Vector2i:
	var best_tile: Vector2i = Vector2i(-1, -1)
	var best_distance: int = -1
	for tile_var: Variant in target_tiles:
		if typeof(tile_var) != TYPE_VECTOR2I:
			continue
		var tile: Vector2i = tile_var
		var distance: int = absi(tile.x - enemy_pos.x) + absi(tile.y - enemy_pos.y)
		if distance > best_distance:
			best_distance = distance
			best_tile = tile
	return best_tile

func _pass_preview_probe_after_guarded_step(instance: Node, source_state: Dictionary) -> Dictionary:
	var combat_engine = instance.get("_combat_engine")
	var state: Dictionary = source_state.duplicate(true)
	var actions: Array = GameData.card_def("guarded_step").get("actions", [])
	for action_index: int in range(actions.size()):
		if typeof(actions[action_index]) != TYPE_DICTIONARY:
			continue
		var action: Dictionary = actions[action_index]
		if combat_engine.player_action_needs_target(action):
			var target_tiles: Array = combat_engine.valid_targets_for_player_action(state, action)
			var move_target: Vector2i = _pass_preview_probe_move_target(target_tiles, Vector2i(3, 4))
			if move_target.x >= 0:
				state = combat_engine.apply_player_action(state, action, move_target)
		else:
			state = combat_engine.apply_player_action(state, action)
	return combat_engine.finish_player_card(state, 0)

func _require_pass_preview_chip(instance: Node, label: String) -> void:
	var row: Node = _first_node_named(instance, "PassPreviewDamageRow")
	if row == null or _pass_preview_probe_damage_text(row).is_empty():
		push_error("Missing pass preview damage values during %s pass preview probe" % label)

func _pass_preview_probe_damage_text(row: Node) -> String:
	if row == null:
		return ""
	var parts := PackedStringArray()
	for label: Label in _pass_preview_probe_damage_labels(row):
		parts.append(label.text)
	return " ".join(parts)

func _pass_preview_probe_damage_labels(node: Node) -> Array[Label]:
	var labels: Array[Label] = []
	if node is Label and _pass_preview_probe_is_damage_value(node as Label):
		labels.append(node as Label)
	for child: Node in node.get_children():
		labels.append_array(_pass_preview_probe_damage_labels(child))
	return labels

func _pass_preview_probe_is_damage_value(label: Label) -> bool:
	return [
		"PassPreviewStoneSkinLoss",
		"PassPreviewBlockLoss",
		"PassPreviewHpLoss",
		"PassPreviewSafe",
		"PassPreviewDefeat"
	].has(str(label.name))

func _first_node_named(node: Node, node_name: String) -> Node:
	if node.name == node_name:
		return node
	for child: Node in node.get_children():
		var found: Node = _first_node_named(child, node_name)
		if found != null:
			return found
	return null

func _capture_orientation_previews(instance: Node) -> void:
	instance.call("_reset_card_resolution")
	instance.set("_animation_lock", false)
	instance.set("_card_play_count_override", -1)
	var combat_state: Dictionary = (instance.get("_combat_state") as Dictionary).duplicate(true)
	combat_state["player"] = {"pos": Vector2i(2, 4), "hp": 24, "max_hp": 24, "block": 0, "stoneskin": 0}
	combat_state["current_actor"] = {"kind": "player", "key": "player"}
	combat_state["cards_played_this_turn"] = 0
	combat_state["death_bonus_card_plays_this_turn"] = 0
	combat_state["card_play_bonus_this_turn"] = 0
	combat_state.erase("player_turn_restrictions")
	combat_state["enemies"] = [
		{"id": 1, "type": "crawler", "pos": Vector2i(4, 4), "hp": 14, "max_hp": 14, "block": 0},
		{"id": 2, "type": "harrier", "pos": Vector2i(4, 2), "hp": 10, "max_hp": 10, "block": 0},
		{"id": 3, "type": "acolyte", "pos": Vector2i(6, 4), "hp": 12, "max_hp": 12, "block": 0}
	]
	combat_state["traps"] = []
	combat_state["terrain"] = []
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["thunderline", "updraft"]
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
	await process_frame
	await process_frame
	instance.call("_on_card_pressed", 0)
	await process_frame
	await process_frame
	var thunder_target: Vector2i = Vector2i(5, 4)
	instance.call("_on_board_tile_hovered", thunder_target)
	await process_frame
	await process_frame
	await _save_root_screenshot("user://probes/run_thunderline_target_hover.png")
	instance.call("_rotate_aoe_aim", -1)
	await process_frame
	instance.call("_on_board_tile_hovered", Vector2i(4, 3))
	await process_frame
	await process_frame
	await _save_root_screenshot("user://probes/run_thunderline_orientation_north.png")
	instance.call("_on_cancel_requested")
	await process_frame

	combat_state = (instance.get("_combat_state") as Dictionary).duplicate(true)
	combat_state["player"] = {"pos": Vector2i(2, 4), "hp": 24, "max_hp": 24, "block": 0, "stoneskin": 0}
	combat_state["current_actor"] = {"kind": "player", "key": "player"}
	combat_state["cards_played_this_turn"] = 0
	combat_state["death_bonus_card_plays_this_turn"] = 0
	combat_state["card_play_bonus_this_turn"] = 0
	combat_state.erase("player_turn_restrictions")
	combat_state["enemies"] = [
		{"id": 1, "type": "crawler", "pos": Vector2i(3, 4), "hp": 100, "max_hp": 100, "block": 0}
	]
	deck = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["updraft"]
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	combat_state["deck"] = deck
	run_state = instance.get("_run_state")
	run_state["mode"] = "combat"
	run_state["combat_state"] = combat_state
	instance.set("_run_state", run_state)
	instance.set("_combat_state", combat_state)
	instance.call("_refresh_ui")
	await process_frame
	await process_frame
	instance.call("_on_card_pressed", 0)
	await process_frame
	instance.call("_on_board_tile_clicked", Vector2i(3, 4))
	await create_timer(0.30).timeout
	await process_frame
	instance.call("_on_board_tile_hovered", Vector2i(4, 4))
	await process_frame
	await process_frame
	await _save_root_screenshot("user://probes/run_push_orientation_north.png")
	instance.call("_on_cancel_requested")
	await process_frame

func _save_root_screenshot(output_path: String) -> void:
	var image: Image = root.get_viewport().get_texture().get_image()
	image.save_png(output_path)

func _clear_probe_output(output_dir: String) -> void:
	var absolute_dir: String = ProjectSettings.globalize_path(output_dir)
	_clear_probe_output_absolute(absolute_dir)

func _clear_probe_output_absolute(absolute_dir: String) -> void:
	var dir := DirAccess.open(absolute_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var entry: String = dir.get_next()
		if entry.is_empty():
			break
		if entry in [".", ".."]:
			continue
		var child_path: String = absolute_dir.path_join(entry)
		if dir.current_is_dir():
			_clear_probe_output_absolute(child_path)
			DirAccess.remove_absolute(child_path)
		else:
			DirAccess.remove_absolute(child_path)
	dir.list_dir_end()

func _capture_pile_overlay_snapshot(instance: Node, pile_kind: String, forced_cards: Array, output_path: String) -> void:
	var combat_state: Dictionary = (instance.get("_combat_state") as Dictionary).duplicate(true)
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck[pile_kind] = forced_cards.duplicate()
	combat_state["deck"] = deck
	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run_state["mode"] = "combat"
	run_state["combat_state"] = combat_state
	instance.set("_run_state", run_state)
	instance.set("_combat_state", combat_state)
	instance.call("_refresh_ui")
	await process_frame
	await process_frame
	instance.call("_open_pile_view", pile_kind)
	await process_frame
	await process_frame
	await _save_root_screenshot(output_path)
	instance.call("_close_pile_view")
	await process_frame

func _targeted_card_index(instance: Node) -> int:
	var combat_state: Dictionary = instance.get("_combat_state")
	var combat_engine = instance.get("_combat_engine")
	var hand: Array = (combat_state.get("deck", {}) as Dictionary).get("hand", [])
	for index: int in range(hand.size()):
		var preview: Dictionary = instance.call("_card_preview_for_index", index)
		if not bool(preview.get("playable", false)):
			continue
		if bool(preview.get("complete", false)):
			continue
		return index
	return 0
