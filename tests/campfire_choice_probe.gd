extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")

const OUTPUT_DIR: String = "user://campfire_choice_probe"

var _failed: bool = false

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_clear_probe_output(OUTPUT_DIR)
	ProgressionStore.set_storage_path("user://labyrinth_progression_campfire_choice_probe.json")
	ProgressionStore.set_run_storage_path("user://labyrinth_run_campfire_choice_probe.save")
	ProgressionStore.clear_saved_run()
	await _capture_campfire_choice_states()
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	quit(1 if _failed else 0)

func _capture_campfire_choice_states() -> void:
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	if packed == null:
		_fail("Run scene should load for campfire choice probe")
		return
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame

	var probe_run_engine := RunEngine.new()
	await _capture_choice_state(
		instance,
		probe_run_engine,
		0,
		120,
		"%s/campfire_strength_unaffordable.png" % OUTPUT_DIR
	)
	await _capture_choice_state(
		instance,
		probe_run_engine,
		180,
		120,
		"%s/campfire_strength_affordable.png" % OUTPUT_DIR
	)
	await _capture_affordable_hover_state(instance, "%s/campfire_strength_affordable_hover.png" % OUTPUT_DIR)
	await _capture_linger_feedback_state(instance, "%s/campfire_linger_feedback_pulse.png" % OUTPUT_DIR)
	await _capture_choice_state(
		instance,
		probe_run_engine,
		180,
		36,
		"%s/campfire_low_hp.png" % OUTPUT_DIR
	)

	instance.queue_free()
	await process_frame

func _capture_choice_state(instance: Node, probe_run_engine: RunEngine, held_embers: int, player_hp: int, output_path: String) -> void:
	var progression: Dictionary = ProgressionStore.set_embers(ProgressionStore.default_data(), held_embers)
	var base_state: Dictionary = probe_run_engine.create_new_run(721, progression)
	var campfire_coord: Vector2i = _first_room_coord_of_type(probe_run_engine, base_state, "campfire")
	if campfire_coord == Vector2i.ZERO:
		_fail("Probe run should include a campfire room")
		return
	var campfire_state: Dictionary = _run_state_for_room(probe_run_engine, base_state, campfire_coord, "campfire", Vector2i(1, 0))
	campfire_state["player_hp"] = player_hp
	campfire_state["player_max_hp"] = 360
	campfire_state["held_embers"] = held_embers
	campfire_state["unbanked_embers"] = held_embers
	campfire_state["progression"] = progression
	instance.call("_load_run_state", campfire_state)
	await process_frame
	await process_frame
	await _save_root_screenshot(output_path)

func _capture_affordable_hover_state(instance: Node, output_path: String) -> void:
	var before_rects: Array = _choice_panel_rects(instance)
	var strength_panel: PanelContainer = _strength_choice_panel(instance)
	if strength_panel == null:
		_fail("Affordable campfire choices should expose a strength panel")
		return
	instance.call("_set_campfire_choice_hovered", strength_panel, Color("d79a4d"), true)
	await process_frame
	await process_frame
	var after_rects: Array = _choice_panel_rects(instance)
	if not _rect_lists_match(before_rects, after_rects):
		_fail("Campfire choice hover should not move or resize the choice panels")
	await _save_root_screenshot(output_path)
	instance.call("_set_campfire_choice_hovered", strength_panel, Color("d79a4d"), false)
	await process_frame

func _capture_linger_feedback_state(instance: Node, output_path: String) -> void:
	var linger_panel: PanelContainer = _choice_panel(instance, 0)
	if linger_panel == null:
		_fail("Affordable campfire choices should expose a linger panel")
		return
	instance.call("_show_campfire_choice_feedback_pulse", linger_panel, Color("efb35f"))
	await process_frame
	await process_frame
	await _save_root_screenshot(output_path)

func _choice_panel_rects(instance: Node) -> Array:
	var rects: Array = []
	var relic_bar: HBoxContainer = instance.get("_relic_choice_bar") as HBoxContainer
	if relic_bar == null:
		return rects
	for child: Node in relic_bar.get_children():
		var control: Control = child as Control
		if control != null:
			rects.append(control.get_global_rect())
	return rects

func _strength_choice_panel(instance: Node) -> PanelContainer:
	return _choice_panel(instance, 2)

func _choice_panel(instance: Node, index: int) -> PanelContainer:
	var relic_bar: HBoxContainer = instance.get("_relic_choice_bar") as HBoxContainer
	if relic_bar == null or relic_bar.get_child_count() <= index:
		return null
	return relic_bar.get_child(index) as PanelContainer

func _rect_lists_match(before_rects: Array, after_rects: Array) -> bool:
	if before_rects.size() != after_rects.size():
		return false
	for index: int in range(before_rects.size()):
		var before_rect: Rect2 = before_rects[index]
		var after_rect: Rect2 = after_rects[index]
		if before_rect.position.distance_to(after_rect.position) > 0.5:
			return false
		if before_rect.size.distance_to(after_rect.size) > 0.5:
			return false
	return true

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

func _fail(message: String) -> void:
	_failed = true
	push_error(message)
	print("TEST RESULT: FAIL %s" % message)
