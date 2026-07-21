extends SceneTree

const CombatBoardViewScript = preload("res://scripts/combat_board_view.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")

const OUTPUT_DIR: String = "user://terrain_destruction_probe"
const VIEWPORT_SIZE: Vector2i = Vector2i(1280, 720)

var _errors: Array[String] = []

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	DisplayServer.window_set_size(VIEWPORT_SIZE)
	root.size = VIEWPORT_SIZE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_clear_probe_output(OUTPUT_DIR)
	await process_frame

	var board: Control = CombatBoardViewScript.new()
	board.size = root.get_visible_rect().size
	root.add_child(board)
	board.set_process(false)
	await process_frame

	var box_frames: Array = board.call("_terrain_destruction_frames_for_kind", "wooden_box")
	var crate_frames: Array = board.call("_terrain_destruction_frames_for_kind", "wooden_crate")
	_expect(box_frames.size() == 16, "Wooden box destruction probe requires all 16 frames")
	_expect(crate_frames.size() == 16, "Wooden crate destruction probe requires all 16 frames")

	await _capture(board, 7, 0.48, "terrain_destruction_mid.png")
	await _capture(board, 14, 0.92, "terrain_destruction_late.png")
	board.queue_free()
	await process_frame

	if _errors.is_empty():
		print("TERRAIN DESTRUCTION PROBE RESULT: PASS")
		print(ProjectSettings.globalize_path(OUTPUT_DIR))
		quit(0)
	else:
		for error: String in _errors:
			push_error(error)
		print("TERRAIN DESTRUCTION PROBE RESULT: FAIL (%d errors)" % _errors.size())
		quit(1)

func _capture(board: Control, frame: int, progress: float, file_name: String) -> void:
	var presentation: Dictionary = {
		"focus_tiles": [Vector2i(3, 3), Vector2i(5, 3)],
		"focus_color": Color(0.98, 0.55, 0.25, 0.18),
		"effect_progress": progress,
		"impact_progress": progress,
		"terrain_destruction_units": [
			{
				"key": "terrain_probe_box",
				"id": "probe_box",
				"kind": "wooden_box",
				"pos": Vector2i(3, 3),
				"destruction_frame": frame,
				"destruction_progress": progress
			},
			{
				"key": "terrain_probe_crate",
				"id": "probe_crate",
				"kind": "wooden_crate",
				"pos": Vector2i(5, 3),
				"destruction_frame": frame,
				"destruction_progress": progress
			}
		]
	}
	board.call(
		"set_combat_state",
		_probe_state(),
		_vector2i_array([]),
		_vector2i_array([]),
		Vector2i(-1, -1),
		"",
		"",
		{},
		{},
		presentation
	)
	await process_frame
	await process_frame
	var image: Image = root.get_texture().get_image()
	var output_path: String = ProjectSettings.globalize_path("%s/%s" % [OUTPUT_DIR, file_name])
	_expect(image.get_size() == VIEWPORT_SIZE, "%s should capture at 1280x720" % file_name)
	_expect(image.save_png(output_path) == OK, "%s could not be saved" % file_name)

func _probe_state() -> Dictionary:
	return {
		"name": "Incidental Blast Destruction",
		"room_coord": Vector2i(2, -1),
		"room_element": "fire",
		"grid": _probe_grid(),
		"moss": {},
		"player": {
			"pos": Vector2i(1, 5),
			"hp": 80,
			"max_hp": 100,
			"block": 0,
			"stoneskin": 0,
			"burn": 0,
			"bleed": 0
		},
		"enemies": [{
			"id": 1,
			"type": "crawler",
			"pos": Vector2i(7, 1),
			"hp": 140,
			"max_hp": 140,
			"block": 0,
			"stoneskin": 0,
			"intent": {"name": "Skitter", "actions": [{"type": "move_toward", "range": 2}]}
		}],
		"illusions": [],
		"npcs": [],
		"loot": [],
		"terrain": [
			{"id": "probe_box", "kind": "wooden_box", "pos": Vector2i(3, 3), "hp": 0, "max_hp": 30},
			{"id": "probe_crate", "kind": "wooden_crate", "pos": Vector2i(5, 3), "hp": 0, "max_hp": 30}
		],
		"traps": [],
		"player_turn_restrictions": {}
	}

func _probe_grid() -> Array:
	return [
		["wall", "wall", "wall", "wall", "wall", "wall", "wall", "wall", "wall"],
		["wall", "stone", "stone", "stone", "stone", "stone", "stone", "stone", "wall"],
		["wall", "stone", "stone", "stone", "stone", "stone", "stone", "stone", "wall"],
		["wall", "stone", "stone", "stone", "stone", "stone", "stone", "stone", "wall"],
		["wall", "stone", "stone", "stone", "stone", "stone", "stone", "stone", "wall"],
		["wall", "stone", "stone", "stone", "stone", "stone", "stone", "stone", "wall"],
		["wall", "wall", "wall", "wall", "wall", "wall", "wall", "wall", "wall"]
	]

func _vector2i_array(values: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for value: Variant in values:
		if typeof(value) == TYPE_VECTOR2I:
			result.append(value)
	return result

func _clear_probe_output(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		dir.remove(file_name)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
