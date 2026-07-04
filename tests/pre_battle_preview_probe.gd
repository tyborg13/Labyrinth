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
