extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")

const PROBE_DIR: String = "user://relic_choice_sparkle_probe"

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PROBE_DIR))
	_clear_probe_output(PROBE_DIR)
	ProgressionStore.set_storage_path("user://labyrinth_progression_relic_choice_sparkle_probe.json")
	ProgressionStore.set_run_storage_path("user://labyrinth_run_relic_choice_sparkle_probe.save")
	ProgressionStore.clear_saved_run()
	await _capture_relic_choice_sparkle()
	print(ProjectSettings.globalize_path(PROBE_DIR))
	quit()

func _capture_relic_choice_sparkle() -> void:
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	if packed == null:
		return
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame

	var probe_run_engine := RunEngine.new()
	var base_state: Dictionary = probe_run_engine.create_new_run(7321, ProgressionStore.default_data())
	var treasure_coord: Vector2i = _first_room_coord_of_type(probe_run_engine, base_state, "treasure")
	var treasure_state: Dictionary = _run_state_for_room(probe_run_engine, base_state, treasure_coord, "treasure", Vector2i(1, 0))
	treasure_state["pending_relics"] = ["iron_lung", "ember_lens", "pilgrim_boots"]
	instance.call("_load_run_state", treasure_state)
	await process_frame
	await process_frame
	await create_timer(0.12).timeout
	await _save_root_screenshot("%s/relic_choice_before.png" % PROBE_DIR)

	var choice_bar: HBoxContainer = instance.get("_relic_choice_bar") as HBoxContainer
	if choice_bar != null and choice_bar.get_child_count() > 0:
		var selected_choice: Control = choice_bar.get_child(0) as Control
		var source_rect: Rect2 = Rect2()
		if selected_choice != null:
			source_rect = selected_choice.get_global_rect()
		create_timer(0.18).timeout.connect(_save_root_screenshot.bind("%s/relic_choice_acquire_mid.png" % PROBE_DIR))
		await instance.call("_on_relic_pressed", "iron_lung", source_rect)
		await process_frame
		await _save_root_screenshot("%s/relic_choice_after.png" % PROBE_DIR)

	instance.queue_free()
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
