extends SceneTree

const CombatEngine = preload("res://scripts/combat_engine.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const RUN_SCENE = preload("res://scenes/run_scene.tscn")

const OUTPUT_ROOT: String = "user://run_end_recap_probe_v2"

var _failed: bool = false
var _resolution: Vector2i = Vector2i(1920, 1080)
var _output_dir: String = ""

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	_resolution = _requested_resolution()
	_output_dir = "%s/%dx%d" % [OUTPUT_ROOT, _resolution.x, _resolution.y]
	_configure_window(_resolution)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output_dir))
	_clear_probe_output(_output_dir)
	ProgressionStore.set_storage_path("user://run_end_recap_probe_progression.json")
	ProgressionStore.set_run_storage_path("user://run_end_recap_probe_saved_run.save")
	ProgressionStore.clear_saved_run()
	call_deferred("_capture_states")

func _capture_states() -> void:
	await process_frame
	await process_frame
	var instance: Node = RUN_SCENE.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame
	var engine := RunEngine.new()

	var baseline_stats: Dictionary = {
		"enemies_killed": 3,
		"damage_dealt": 300,
		"damage_received": 150,
		"depth": 1,
		"rooms_cleared": 1,
		"bosses_defeated": 0
	}
	var baseline_record: Dictionary = ProgressionStore.record_run_result(ProgressionStore.default_data(), "probe:baseline", baseline_stats)
	var defeat_progression: Dictionary = baseline_record.get("data", {}) as Dictionary
	var defeat_state: Dictionary = _terminal_state(engine, defeat_progression, Vector2i(4, 0), "defeat", 47, 3, {
		"enemies_killed": 9,
		"damage_dealt": 780,
		"damage_received": 260
	})
	await _install_state(instance, defeat_progression, defeat_state)
	var recap: Control = instance.get("_run_end_recap") as Control
	if recap != null:
		recap.call("seek_presentation", 0.0)
	await _capture("defeat_pre_engulf.png")
	if recap != null:
		recap.call("seek_presentation", 0.78)
	await _capture("defeat_mid_engulf.png")
	if recap != null:
		recap.call("seek_presentation", float(recap.call("presentation_duration")))
	await _capture("defeat_final.png")
	if recap != null:
		recap.call("reset")
		recap.call("set_motion_enabled", false)
		instance.call("_show_run_end_recap", "defeat")
	await create_timer(0.08).timeout
	await _capture("defeat_reduced_motion_final.png")

	var victory_progression: Dictionary = ProgressionStore.load_data()
	var victory_state: Dictionary = _terminal_state(engine, victory_progression, Vector2i(8, 0), "victory", 64, 6, {
		"enemies_killed": 14,
		"damage_dealt": 1240,
		"damage_received": 310
	})
	await _install_state(instance, victory_progression, victory_state)
	recap = instance.get("_run_end_recap") as Control
	if recap != null:
		recap.call("set_motion_enabled", true)
		recap.call("seek_presentation", float(recap.call("presentation_duration")))
	await _capture("victory_final.png")

	instance.queue_free()
	await process_frame
	print(ProjectSettings.globalize_path(_output_dir))
	quit(1 if _failed else 0)

func _install_state(instance: Node, progression: Dictionary, state: Dictionary) -> void:
	ProgressionStore.save_data(progression)
	instance.set("_progression", progression.duplicate(true))
	instance.call("_load_run_state", state)
	await process_frame
	await process_frame
	var recap: Control = instance.get("_run_end_recap") as Control
	if recap == null or not recap.visible:
		_fail("Terminal state should display the recap overlay")
	var board: Control = instance.get_node("BoardUnderlay/CombatBoard") as Control
	if board == null or not board.visible:
		_fail("Terminal state should keep the final tactical room visible")

func _terminal_state(engine: RunEngine, progression: Dictionary, coord: Vector2i, outcome: String, held_embers: int, cleared_rooms: int, run_stats: Dictionary) -> Dictionary:
	var state: Dictionary = engine.create_new_run(8841 + held_embers * 3 + coord.x, progression)
	var rooms: Dictionary = (state.get("rooms", {}) as Dictionary).duplicate(true)
	var marked: int = 0
	for room_key_var: Variant in rooms.keys():
		if marked >= cleared_rooms:
			break
		var room_var: Variant = rooms[room_key_var]
		if typeof(room_var) != TYPE_DICTIONARY:
			continue
		var candidate: Dictionary = (room_var as Dictionary).duplicate(true)
		if int(candidate.get("depth", 0)) <= 0 or str(room_key_var) == _room_key(coord):
			continue
		candidate["visited"] = true
		candidate["cleared"] = true
		rooms[room_key_var] = candidate
		marked += 1
	var room: Dictionary = engine.room_metadata(state, coord).duplicate(true)
	room["revealed"] = true
	room["visited"] = true
	room["cleared"] = false
	if outcome == "victory":
		room["type"] = "boss"
	rooms[_room_key(coord)] = room
	state["rooms"] = rooms
	state["current_room"] = coord
	state["run_stats"] = CombatEngine.normalized_run_stats(run_stats)
	var layout: Dictionary = engine.call("_combat_layout_for_room", room, Vector2i(1, 0), state)
	var combat := CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(int(state.get("seed", 0)), layout, engine.call("_player_snapshot", state) as Dictionary)
	combat_state["run_stats"] = CombatEngine.normalized_run_stats(run_stats)
	if outcome == "defeat":
		var player: Dictionary = (combat_state.get("player", {}) as Dictionary).duplicate(true)
		player["hp"] = 0
		combat_state["player"] = player
	else:
		var enemies: Array = (combat_state.get("enemies", []) as Array).duplicate(true)
		for index: int in range(enemies.size()):
			var enemy: Dictionary = (enemies[index] as Dictionary).duplicate(true)
			enemy["hp"] = 0
			enemies[index] = enemy
		combat_state["enemies"] = enemies
	state["mode"] = "combat"
	state["combat_state"] = combat_state
	state["held_embers"] = held_embers
	state["unbanked_embers"] = held_embers
	state = engine.finish_combat(state, combat_state)
	state["mode"] = outcome
	state["victory"] = outcome == "victory"
	state["game_over"] = outcome == "defeat"
	state["held_embers"] = held_embers
	state["unbanked_embers"] = held_embers
	state["run_stats"] = CombatEngine.normalized_run_stats(run_stats)
	state["progression"] = progression.duplicate(true)
	return state

func _requested_resolution() -> Vector2i:
	for argument: String in OS.get_cmdline_user_args():
		if not argument.begins_with("--resolution="):
			continue
		var value: String = argument.trim_prefix("--resolution=").to_lower()
		var parts: PackedStringArray = value.split("x", false)
		if parts.size() == 2:
			var width: int = int(parts[0])
			var height: int = int(parts[1])
			if width >= 640 and height >= 360:
				return Vector2i(width, height)
	return Vector2i(1920, 1080)

func _configure_window(resolution: Vector2i) -> void:
	root.content_scale_size = resolution
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.size = resolution
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(resolution)

func _capture(filename: String) -> void:
	await process_frame
	await process_frame
	var image: Image = root.get_viewport().get_texture().get_image()
	if image.get_width() != _resolution.x or image.get_height() != _resolution.y:
		# macOS exposes the Retina backing texture even though content_scale_size is
		# the requested logical proof viewport. Preserve that Metal render and
		# downsample it to the exact review resolution.
		image.resize(_resolution.x, _resolution.y, Image.INTERPOLATE_LANCZOS)
	var error: Error = image.save_png("%s/%s" % [_output_dir, filename])
	if error != OK:
		_fail("Could not save %s" % filename)

func _room_key(coord: Vector2i) -> String:
	return "%d,%d" % [coord.x, coord.y]

func _clear_probe_output(output_dir: String) -> void:
	_clear_probe_output_absolute(ProjectSettings.globalize_path(output_dir))

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

func _fail(message: String) -> void:
	_failed = true
	push_error(message)
	print("TEST RESULT: FAIL %s" % message)
