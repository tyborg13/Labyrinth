extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")

const OUTPUT_DIR: String = "user://pre_battle_preview_probe"
const INVALID_COORD: Vector2i = Vector2i(999, 999)

var _failed: bool = false

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_clear_probe_output(OUTPUT_DIR)
	ProgressionStore.set_storage_path("user://labyrinth_progression_pre_battle_preview_probe.json")
	ProgressionStore.set_run_storage_path("user://labyrinth_run_pre_battle_preview_probe.save")
	ProgressionStore.clear_saved_run()
	await _capture_pre_battle_preview()
	await _capture_five_enemy_pre_battle_preview()
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	quit(1 if _failed else 0)

func _capture_pre_battle_preview() -> void:
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	if packed == null:
		_fail("Run scene should load for pre-battle preview probe")
		return
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame

	var probe_run_engine := RunEngine.new()
	var run_state: Dictionary = _run_with_available_combat(probe_run_engine)
	var combat_coord: Vector2i = _first_available_combat_coord(probe_run_engine, run_state)
	if combat_coord == INVALID_COORD:
		_fail("Probe run should include an available combat room")
		instance.queue_free()
		await process_frame
		return

	instance.call("_load_run_state", run_state)
	await process_frame
	await process_frame
	instance.call("_close_dialogue")
	await instance.call("_on_map_view_room_selected", combat_coord)
	await process_frame
	await create_timer(0.30).timeout
	await process_frame

	var scrim: Control = instance.get("_pre_battle_scrim") as Control
	var panel: Control = instance.get("_pre_battle_panel") as Control
	if scrim == null or not scrim.visible:
		_fail("Pre-battle preview should be visible")
	elif panel == null:
		_fail("Pre-battle preview panel should exist")
	else:
		if panel.find_child("PreBattleEnemyCard", true, false) == null:
			_fail("Pre-battle preview should render enemy cards")
		if panel.find_child("PreBattleDeckBadge", true, false) == null:
			_fail("Pre-battle preview should render deck badges")
		if panel.find_child("PreBattleEquipmentRow", true, false) == null:
			_fail("Pre-battle preview should render equipment icons")
		if panel.find_child("PreBattleEnemyHealth", true, false) == null:
			_fail("Pre-battle preview should render enemy health")
		if panel.find_child("PreBattleIntentRow", true, false) != null:
			_fail("Pre-battle preview should not render enemy intent icons")
		if panel.find_child("PreBattleCloseButton", true, false) != null:
			_fail("Pre-battle preview should not offer a back-out button")

	var paused_state: Dictionary = instance.get("_run_state")
	if str(paused_state.get("mode", "")) != RunEngine.MODE_PRE_BATTLE:
		_fail("Pre-battle preview should commit to pre-battle mode before Start")
	if paused_state.get("current_room", INVALID_COORD) != combat_coord:
		_fail("Pre-battle preview should already be in the selected room")
	if not (paused_state.get("combat_state", {}) as Dictionary).is_empty():
		_fail("Pre-battle preview should not create the real combat state before Start")
	await _save_root_screenshot("%s/pre_battle_preview.png" % OUTPUT_DIR)
	instance.queue_free()
	await process_frame

func _capture_five_enemy_pre_battle_preview() -> void:
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	if packed == null:
		_fail("Run scene should load for five-enemy pre-battle preview probe")
		return
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame

	var probe_run_engine := RunEngine.new()
	var progression: Dictionary = ProgressionStore.default_data()
	var run_state: Dictionary = probe_run_engine.create_new_run(7262026, progression)
	var combat_coord: Vector2i = _first_room_coord_with_min_enemies(probe_run_engine, run_state, 5)
	if combat_coord == INVALID_COORD:
		_fail("Probe should find a generated room with at least five enemies")
		instance.queue_free()
		await process_frame
		return
	run_state = _pre_battle_state_for_room(probe_run_engine, run_state, combat_coord)
	instance.call("_load_run_state", run_state)
	await process_frame
	await process_frame
	instance.call("_close_dialogue")
	await process_frame
	await create_timer(0.30).timeout
	await process_frame

	var scrim: Control = instance.get("_pre_battle_scrim") as Control
	var panel: Control = instance.get("_pre_battle_panel") as Control
	if scrim == null or not scrim.visible:
		_fail("Five-enemy pre-battle preview should be visible")
	elif panel == null:
		_fail("Five-enemy pre-battle preview panel should exist")
	else:
		var flow: HFlowContainer = panel.find_child("PreBattleEnemyFlow", true, false) as HFlowContainer
		if flow == null:
			_fail("Five-enemy pre-battle preview should render the enemy flow")
		elif flow.get_child_count() < 5:
			_fail("Five-enemy pre-battle preview should render at least five enemy cards")
		else:
			for index: int in range(flow.get_child_count()):
				var card: Control = flow.get_child(index) as Control
				if card == null:
					continue
				if card.custom_minimum_size.x > 200.0 or card.custom_minimum_size.y > 154.0:
					_fail("Five-enemy pre-battle preview should use compact enemy cards")
					break
	await _save_root_screenshot("%s/pre_battle_preview_five_enemies.png" % OUTPUT_DIR)
	instance.queue_free()
	await process_frame

func _run_with_available_combat(probe_run_engine: RunEngine) -> Dictionary:
	var progression: Dictionary = ProgressionStore.default_data()
	for seed: int in range(1, 120):
		var state: Dictionary = probe_run_engine.create_new_run(seed, progression)
		if _first_available_combat_coord(probe_run_engine, state) != INVALID_COORD:
			return state
	return {}

func _first_available_combat_coord(probe_run_engine: RunEngine, run_state: Dictionary) -> Vector2i:
	if run_state.is_empty():
		return INVALID_COORD
	for coord_var: Variant in probe_run_engine.available_moves(run_state):
		if typeof(coord_var) != TYPE_VECTOR2I:
			continue
		var coord: Vector2i = coord_var
		var preview_state: Dictionary = probe_run_engine.move_to_room(run_state.duplicate(true), coord)
		if str(preview_state.get("mode", "")) == "combat" and not (preview_state.get("combat_state", {}) as Dictionary).is_empty():
			return coord
	return INVALID_COORD

func _first_room_coord_with_min_enemies(probe_run_engine: RunEngine, run_state: Dictionary, min_enemies: int) -> Vector2i:
	for radius: int in range(1, 9):
		for x: int in range(-radius, radius + 1):
			for y: int in range(-radius, radius + 1):
				var coord := Vector2i(x, y)
				if maxi(absi(x), absi(y)) != radius:
					continue
				var room: Dictionary = probe_run_engine.room_metadata(run_state, coord)
				if str(room.get("type", "")) not in ["combat", "boss"]:
					continue
				var layout: Dictionary = probe_run_engine.call("_combat_layout_for_room", room, _travel_dir_for_coord(coord), run_state)
				var enemies: Array = layout.get("enemies", [])
				if enemies.size() >= min_enemies:
					return coord
	return INVALID_COORD

func _pre_battle_state_for_room(probe_run_engine: RunEngine, run_state: Dictionary, coord: Vector2i) -> Dictionary:
	var state: Dictionary = run_state.duplicate(true)
	var travel_dir: Vector2i = _travel_dir_for_coord(coord)
	var room: Dictionary = probe_run_engine.room_metadata(state, coord).duplicate(true)
	room["revealed"] = true
	room["visited"] = true
	room["cleared"] = false
	room["sealed"] = false
	var rooms: Dictionary = (state.get("rooms", {}) as Dictionary).duplicate(true)
	rooms[_room_key(coord)] = room
	state["rooms"] = rooms
	state["current_room"] = coord
	state["current_room_layout"] = probe_run_engine.call("_display_layout_for_room", int(state.get("seed", 0)), room, travel_dir)
	state["mode"] = RunEngine.MODE_PRE_BATTLE
	state["combat_state"] = {}
	state["pre_battle_pending"] = true
	state["pre_battle_travel_dir"] = travel_dir
	return state

func _travel_dir_for_coord(coord: Vector2i) -> Vector2i:
	if coord == Vector2i.ZERO:
		return Vector2i(1, 0)
	if absi(coord.x) >= absi(coord.y) and coord.x != 0:
		return Vector2i(1, 0) if coord.x > 0 else Vector2i(-1, 0)
	return Vector2i(0, 1) if coord.y > 0 else Vector2i(0, -1)

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
