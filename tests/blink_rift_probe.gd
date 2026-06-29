extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")

const OUTPUT_DIR := "user://blink_rift_probe"

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	_clear_probe_output(OUTPUT_DIR)
	ProgressionStore.set_storage_path("user://labyrinth_progression_blink_rift_probe.json")
	ProgressionStore.set_run_storage_path("user://labyrinth_run_blink_rift_probe.save")
	ProgressionStore.clear_saved_run()
	await _capture_blink_rift_states()
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	quit()

func _capture_blink_rift_states() -> void:
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
	var combat_coord: Vector2i = _first_combat_coord(run_engine, run_state)
	if combat_coord == Vector2i.ZERO:
		instance.queue_free()
		await process_frame
		return

	instance.call("_on_map_view_room_selected", combat_coord)
	await create_timer(0.95).timeout
	await process_frame
	await process_frame

	var base_state: Dictionary = _prepared_blink_state(instance.get("_combat_state") as Dictionary)
	await _capture_blink_sequence(instance, base_state, "long", 4, 8, "shadow_gate")
	await _capture_blink_sequence(instance, base_state, "short", 1, 2, "shadow_step")

	instance.queue_free()
	await process_frame

func _first_combat_coord(run_engine: RunEngine, run_state: Dictionary) -> Vector2i:
	for coord: Vector2i in run_engine.available_moves(run_state):
		var room: Dictionary = run_engine.room_metadata(run_state, coord)
		if str(room.get("type", "")) == "combat":
			return coord
	return Vector2i.ZERO

func _prepared_blink_state(source_state: Dictionary) -> Dictionary:
	var combat_state: Dictionary = source_state.duplicate(true)
	var player: Dictionary = (combat_state.get("player", {}) as Dictionary).duplicate(true)
	player["hp"] = maxi(1, int(player.get("hp", 24)))
	player["max_hp"] = maxi(int(player.get("hp", 24)), int(player.get("max_hp", 24)))
	player["block"] = 0
	player["stoneskin"] = 0
	combat_state["player"] = player
	combat_state["current_actor"] = {"kind": "player", "key": "player"}
	combat_state["cards_played_this_turn"] = 0
	combat_state["death_bonus_card_plays_this_turn"] = 0
	combat_state["card_play_bonus_this_turn"] = 0
	combat_state["traps"] = []
	combat_state.erase("player_turn_restrictions")
	return combat_state

func _capture_blink_sequence(instance: Node, combat_state: Dictionary, label: String, min_distance: int, range_value: int, card_id: String) -> void:
	var working_state: Dictionary = combat_state.duplicate(true)
	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run_state["mode"] = "combat"
	run_state["combat_state"] = working_state
	instance.set("_run_state", run_state)
	instance.set("_combat_state", working_state)
	instance.call("_reset_card_resolution")
	instance.set("_animation_lock", false)
	instance.set("_card_play_count_override", -1)
	instance.call("_refresh_ui")
	await process_frame
	await process_frame

	var combat_engine = instance.get("_combat_engine")
	var action: Dictionary = {"type": "blink", "range": range_value}
	var valid_targets: Array[Vector2i] = combat_engine.valid_targets_for_player_action(working_state, action)
	var target_tile: Vector2i = _blink_probe_target(working_state, valid_targets, min_distance)
	if target_tile.x < 0:
		return
	await _capture_blink_preview(instance, working_state, target_tile, label)
	var after_state: Dictionary = combat_engine.apply_player_action(working_state.duplicate(true), action, target_tile)
	instance.call("_animate_player_action_step", working_state.duplicate(true), after_state, card_id, action, target_tile)
	await create_timer(0.12).timeout
	await process_frame
	await _save_root_screenshot("%s/blink_rift_%s_mid.png" % [OUTPUT_DIR, label])
	await create_timer(0.20).timeout
	await process_frame
	instance.call("_render_board_state", after_state, _settled_blink_presentation(working_state, after_state))
	await process_frame
	await _save_root_screenshot("%s/blink_rift_%s_settled.png" % [OUTPUT_DIR, label])
	await create_timer(0.26).timeout
	await process_frame
	instance.call("_refresh_ui")
	await process_frame

func _capture_blink_preview(instance: Node, combat_state: Dictionary, target_tile: Vector2i, label: String) -> void:
	instance.call("_render_board_state", combat_state, _preview_blink_presentation(combat_state, target_tile))
	await process_frame
	await _save_root_screenshot("%s/blink_rift_%s_preview.png" % [OUTPUT_DIR, label])
	await process_frame

func _preview_blink_presentation(combat_state: Dictionary, target_tile: Vector2i) -> Dictionary:
	var player: Dictionary = combat_state.get("player", {})
	var player_tile: Vector2i = player.get("pos", Vector2i.ZERO)
	return {
		"focus_actor_keys": ["player"],
		"focus_actor_color": Color(0.53, 0.48, 0.92, 0.82),
		"focus_tiles": [player_tile, target_tile],
		"focus_color": Color(0.53, 0.48, 0.92, 0.20),
		"path_tiles": [target_tile],
		"effect": {"kind": "blink", "from": player_tile, "to": target_tile, "preview": true},
		"effect_progress": 1.0
	}

func _settled_blink_presentation(before_state: Dictionary, after_state: Dictionary) -> Dictionary:
	var before_player: Dictionary = before_state.get("player", {})
	var after_player: Dictionary = after_state.get("player", {})
	var before_tile: Vector2i = before_player.get("pos", Vector2i.ZERO)
	var after_tile: Vector2i = after_player.get("pos", before_tile)
	return {
		"focus_actor_keys": ["player"],
		"focus_actor_color": Color(0.53, 0.48, 0.92, 0.90),
		"focus_tiles": [after_tile],
		"focus_color": Color(0.53, 0.48, 0.92, 0.24),
		"effect": {"kind": "blink", "from": before_tile, "to": after_tile},
		"effect_progress": 1.0
	}

func _blink_probe_target(combat_state: Dictionary, valid_targets: Array[Vector2i], min_distance: int) -> Vector2i:
	var player: Dictionary = combat_state.get("player", {})
	var player_tile: Vector2i = player.get("pos", Vector2i.ZERO)
	var best_target := Vector2i(-1, -1)
	var best_distance: int = -1
	for target_tile: Vector2i in valid_targets:
		var distance: int = absi(target_tile.x - player_tile.x) + absi(target_tile.y - player_tile.y)
		if distance < min_distance:
			continue
		if distance > best_distance:
			best_target = target_tile
			best_distance = distance
	if best_target.x >= 0:
		return best_target
	for target_tile: Vector2i in valid_targets:
		var distance: int = absi(target_tile.x - player_tile.x) + absi(target_tile.y - player_tile.y)
		if distance > best_distance:
			best_target = target_tile
			best_distance = distance
	return best_target

func _save_root_screenshot(output_path: String) -> void:
	if DisplayServer.get_name() == "headless":
		print("blink rift probe: headless renderer, screenshot skipped")
		return
	var texture: ViewportTexture = root.get_viewport().get_texture()
	if texture == null:
		print("blink rift probe: headless renderer, screenshot skipped")
		return
	var image: Image = texture.get_image()
	if image == null:
		print("blink rift probe: headless renderer, screenshot skipped")
		return
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
