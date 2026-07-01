extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const GameData = preload("res://scripts/game_data.gd")

const OUTPUT_DIR: String = "user://merchant_room_probe"

var _failed: bool = false

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_clear_probe_output(OUTPUT_DIR)
	ProgressionStore.set_storage_path("user://labyrinth_progression_merchant_room_probe.json")
	ProgressionStore.set_run_storage_path("user://labyrinth_run_merchant_room_probe.save")
	ProgressionStore.clear_saved_run()
	await _capture_merchant_rooms()
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	quit(1 if _failed else 0)

func _capture_merchant_rooms() -> void:
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	if packed == null:
		_fail("Run scene should load for merchant room probe")
		return
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame

	var probe_run_engine := RunEngine.new()
	var progression: Dictionary = ProgressionStore.set_embers(ProgressionStore.default_data(), 140)
	var base_state: Dictionary = _run_with_room_type(probe_run_engine, progression, "blacksmith")
	var blacksmith_coord: Vector2i = _first_room_coord_of_type(probe_run_engine, base_state, "blacksmith")
	if blacksmith_coord.x >= 900:
		_fail("Probe run should include a blacksmith room")
		return
	var blacksmith_state: Dictionary = _run_state_for_room(probe_run_engine, base_state, blacksmith_coord, Vector2i(1, 0))
	blacksmith_state["held_embers"] = 140
	blacksmith_state["unbanked_embers"] = 140
	blacksmith_state["equipment_inventory"] = ["ward_kite", "iron_cleaver"]
	blacksmith_state["collected_equipment"] = GameData.starter_equipment_ids() + ["ward_kite", "iron_cleaver"]
	instance.call("_load_run_state", blacksmith_state)
	await _settle_visuals()
	await _save_root_screenshot("%s/blacksmith_dialogue.png" % OUTPUT_DIR)
	instance.call("_close_dialogue")
	await _settle_visuals()
	await _save_root_screenshot("%s/blacksmith_trade.png" % OUTPUT_DIR)

	base_state = _run_with_room_type(probe_run_engine, progression, "arcanist")
	var arcanist_coord: Vector2i = _first_room_coord_of_type(probe_run_engine, base_state, "arcanist")
	if arcanist_coord.x >= 900:
		_fail("Probe run should include an arcanist room")
		return
	var arcanist_state: Dictionary = _run_state_for_room(probe_run_engine, base_state, arcanist_coord, Vector2i(1, 0))
	arcanist_state["held_embers"] = 96
	arcanist_state["unbanked_embers"] = 96
	arcanist_state["reward_cards"] = ["spark_dart", "frostbolt"]
	arcanist_state["magic_inventory"] = ["spark_dart", "frostbolt"]
	instance.call("_load_run_state", arcanist_state)
	await _settle_visuals()
	instance.call("_close_dialogue")
	await _settle_visuals()
	await _save_root_screenshot("%s/arcanist_trade.png" % OUTPUT_DIR)

	instance.queue_free()
	await process_frame

func _run_with_room_type(probe_run_engine: RunEngine, progression: Dictionary, room_type: String) -> Dictionary:
	for seed: int in range(1, 90):
		var state: Dictionary = probe_run_engine.create_new_run(seed, progression)
		if _first_room_coord_of_type(probe_run_engine, state, room_type).x < 900:
			return state
	return {}

func _run_state_for_room(probe_run_engine: RunEngine, source_state: Dictionary, coord: Vector2i, travel_dir: Vector2i) -> Dictionary:
	var state: Dictionary = source_state.duplicate(true)
	var room: Dictionary = probe_run_engine.room_metadata(state, coord).duplicate(true)
	room["revealed"] = true
	room["visited"] = true
	room["cleared"] = true
	var rooms: Dictionary = (state.get("rooms", {}) as Dictionary).duplicate(true)
	rooms[_room_key(coord)] = room
	state["rooms"] = rooms
	state["current_room"] = coord
	state["current_room_layout"] = probe_run_engine.call("_display_layout_for_room", int(state.get("seed", 0)), room, travel_dir)
	state["mode"] = "room"
	state["combat_state"] = {}
	state["pending_reward"] = {}
	state["pending_relics"] = []
	return state

func _first_room_coord_of_type(probe_run_engine: RunEngine, state: Dictionary, room_type: String) -> Vector2i:
	if state.is_empty():
		return Vector2i(999, 999)
	for radius: int in range(1, RunEngine.MAX_DEPTH + 1):
		for x: int in range(-radius, radius + 1):
			for y: int in range(-radius, radius + 1):
				var coord := Vector2i(x, y)
				if maxi(absi(x), absi(y)) != radius:
					continue
				if str(probe_run_engine.room_metadata(state, coord).get("type", "")) == room_type:
					return coord
	return Vector2i(999, 999)

func _settle_visuals() -> void:
	await process_frame
	await process_frame
	await create_timer(0.18).timeout
	await process_frame

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

func _fail(message: String) -> void:
	_failed = true
	push_error(message)
