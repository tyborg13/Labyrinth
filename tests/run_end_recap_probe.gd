extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const RUN_SCENE = preload("res://scenes/run_scene.tscn")

const OUTPUT_DIR: String = "user://run_end_recap_probe_v1"

var _failed: bool = false

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_clear_probe_output(OUTPUT_DIR)
	ProgressionStore.set_storage_path("user://run_end_recap_probe_progression.json")
	ProgressionStore.set_run_storage_path("user://run_end_recap_probe_saved_run.save")
	ProgressionStore.clear_saved_run()
	await _capture_states()
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	quit(1 if _failed else 0)

func _capture_states() -> void:
	var instance: Node = RUN_SCENE.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame
	var engine := RunEngine.new()

	var victory_progression: Dictionary = ProgressionStore.default_data()
	var victory_state: Dictionary = _terminal_state(engine, victory_progression, Vector2i(8, 0), "victory", 64, 4)
	await _install_state(instance, victory_progression, victory_state)
	await _capture_at(instance, 0.0, "%s/victory_nonzero_beat_00.png" % OUTPUT_DIR)
	await _capture_at(instance, 0.24, "%s/victory_nonzero_beat_01.png" % OUTPUT_DIR)
	await _capture_at(instance, 0.62, "%s/victory_nonzero_final.png" % OUTPUT_DIR)

	var zero_victory_progression: Dictionary = ProgressionStore.default_data()
	var zero_victory: Dictionary = _terminal_state(engine, zero_victory_progression, Vector2i(8, 0), "victory", 0, 3)
	await _install_state(instance, zero_victory_progression, zero_victory)
	await _capture_at(instance, 0.62, "%s/victory_zero_final.png" % OUTPUT_DIR)

	var active_marker_progression: Dictionary = ProgressionStore.record_lost_embers(
		ProgressionStore.default_data(),
		19,
		Vector2i(3, 0),
		0
	)
	active_marker_progression = ProgressionStore.prepare_for_new_run(active_marker_progression)
	active_marker_progression = ProgressionStore.set_embers(active_marker_progression, 28)
	var marker_victory: Dictionary = _terminal_state(engine, active_marker_progression, Vector2i(8, 0), "victory", 28, 5)
	await _install_state(instance, active_marker_progression, marker_victory)
	await _capture_at(instance, 0.62, "%s/victory_nonzero_active_marker_final.png" % OUTPUT_DIR)

	var defeat_progression: Dictionary = ProgressionStore.default_data()
	var defeat_state: Dictionary = _terminal_state(engine, defeat_progression, Vector2i(3, 0), "defeat", 47, 2)
	await _install_state(instance, defeat_progression, defeat_state)
	await _capture_at(instance, 0.0, "%s/defeat_nonzero_beat_00.png" % OUTPUT_DIR)
	await _capture_at(instance, 0.24, "%s/defeat_nonzero_beat_01.png" % OUTPUT_DIR)
	await _capture_at(instance, 0.62, "%s/defeat_nonzero_recovery_final.png" % OUTPUT_DIR)

	var zero_defeat_progression: Dictionary = ProgressionStore.default_data()
	var zero_defeat: Dictionary = _terminal_state(engine, zero_defeat_progression, Vector2i(2, 0), "defeat", 0, 1)
	await _install_state(instance, zero_defeat_progression, zero_defeat)
	await _capture_at(instance, 0.62, "%s/defeat_zero_no_marker_final.png" % OUTPUT_DIR)

	instance.queue_free()
	await process_frame

func _install_state(instance: Node, progression: Dictionary, state: Dictionary) -> void:
	ProgressionStore.save_data(progression)
	instance.set("_progression", progression.duplicate(true))
	instance.call("_load_run_state", state)
	await process_frame
	await process_frame
	var recap: Control = instance.get("_run_end_recap") as Control
	if recap == null or not recap.visible:
		_fail("Terminal state should display the recap overlay")
	var board: Control = instance.get_node("Backdrop/Margin/MainVBox/StageRoot/CombatBoard") as Control
	if board == null or not board.visible:
		_fail("Terminal state should keep the final board visible")

func _capture_at(instance: Node, seconds: float, output_path: String) -> void:
	var recap: Control = instance.get("_run_end_recap") as Control
	if recap == null:
		_fail("Recap overlay should exist for capture")
		return
	recap.call("seek_presentation", seconds)
	await process_frame
	await process_frame
	await _save_root_screenshot(output_path)

func _terminal_state(engine: RunEngine, progression: Dictionary, coord: Vector2i, outcome: String, held_embers: int, cleared_rooms: int) -> Dictionary:
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
	room["cleared"] = outcome == "victory"
	if outcome == "victory":
		room["type"] = "boss"
	rooms[_room_key(coord)] = room
	state["rooms"] = rooms
	state["current_room"] = coord
	state["current_room_layout"] = engine.call("_display_layout_for_room", int(state.get("seed", 0)), room, Vector2i(1, 0))
	state["mode"] = outcome
	state["victory"] = outcome == "victory"
	state["game_over"] = outcome == "defeat"
	state["player_hp"] = 0 if outcome == "defeat" else int(state.get("player_max_hp", 1))
	state["held_embers"] = held_embers
	state["unbanked_embers"] = held_embers
	state["progression"] = progression.duplicate(true)
	state["relics"] = ["iron_lung", "ember_lens", "pilgrim_boots"]
	return state

func _room_key(coord: Vector2i) -> String:
	return "%d,%d" % [coord.x, coord.y]

func _save_root_screenshot(output_path: String) -> void:
	var image: Image = root.get_viewport().get_texture().get_image()
	image.save_png(output_path)

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
