extends SceneTree

const CombatBoardViewScript = preload("res://scripts/combat_board_view.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")

const OUTPUT_DIR: String = "user://movement_path_arrow_probe"
const VIEWPORT_SIZE: Vector2i = Vector2i(1280, 720)

var _errors: Array[String] = []

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_clear_probe_output(OUTPUT_DIR)

	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.disable_3d = true
	root.add_child(viewport)

	var board: Control = CombatBoardViewScript.new()
	board.size = Vector2(VIEWPORT_SIZE)
	viewport.add_child(board)
	board.set_process(false)
	_verify_style_contract(board)
	await process_frame

	await _capture(
		viewport,
		board,
		_vector2i_array([Vector2i(2, 4), Vector2i(3, 4), Vector2i(4, 4), Vector2i(5, 4), Vector2i(6, 4)]),
		"01_straight_path.png"
	)
	await _capture(
		viewport,
		board,
		_vector2i_array([Vector2i(2, 4), Vector2i(3, 4), Vector2i(4, 4), Vector2i(4, 3), Vector2i(5, 3)]),
		"02_turning_path.png"
	)
	await _capture(
		viewport,
		board,
		_vector2i_array([Vector2i(2, 4), Vector2i(3, 4)]),
		"03_one_step_path.png"
	)

	if _errors.is_empty():
		print("MOVEMENT PATH ARROW PROBE: PASS")
		print(ProjectSettings.globalize_path(OUTPUT_DIR))
		quit(0)
	else:
		for error: String in _errors:
			push_error(error)
		print("MOVEMENT PATH ARROW PROBE: FAIL (%d errors)" % _errors.size())
		quit(1)

func _verify_style_contract(board: Control) -> void:
	var board_script: Script = board.get_script()
	var constants: Dictionary = board_script.get_script_constant_map()
	var shaft_ratio: float = float(constants.get("MOVE_PATH_SHAFT_TILE_HEIGHT_RATIO", 0.0))
	var head_width_ratio: float = float(constants.get("MOVE_PATH_HEAD_WIDTH_TILE_RATIO", 0.0))
	var head_length_ratio: float = float(constants.get("MOVE_PATH_HEAD_LENGTH_TILE_RATIO", 0.0))
	var shadow_offset_ratio: float = float(constants.get("MOVE_PATH_SHADOW_OFFSET_TILE_RATIO", 0.0))
	var highlight_width_ratio: float = float(constants.get("MOVE_PATH_HIGHLIGHT_WIDTH_RATIO", 0.0))
	_expect(shaft_ratio > 0.50, "Arrow shaft should occupy more than half of a projected board square's height")
	_expect(head_width_ratio >= 0.80, "Arrow head should span most of its destination tile")
	_expect(head_length_ratio >= 0.80, "Arrow head should be proportionately long instead of a tiny segment marker")
	_expect(shadow_offset_ratio >= 0.04, "Arrow should have enough cast-shadow offset to read above the board")
	_expect(highlight_width_ratio > 0.30 and highlight_width_ratio < 0.75, "Arrow highlight should create a broad blended face without flattening the shaded bevel")

func _capture(viewport: SubViewport, board: Control, path_tiles: Array[Vector2i], file_name: String) -> void:
	var move_tiles: Array[Vector2i] = path_tiles.duplicate()
	move_tiles.pop_front()
	board.call(
		"set_combat_state",
		_probe_state(),
		move_tiles,
		_vector2i_array([]),
		path_tiles[path_tiles.size() - 1],
		"",
		"",
		{},
		{},
		{
			"focus_tiles": move_tiles,
			"path_tiles": path_tiles
		}
	)
	for _frame: int in range(4):
		await process_frame
	var image: Image = viewport.get_texture().get_image()
	var output_path: String = ProjectSettings.globalize_path("%s/%s" % [OUTPUT_DIR, file_name])
	_expect(image != null and image.get_size() == VIEWPORT_SIZE, "%s should capture at the fixed gameplay proof size" % file_name)
	if image != null:
		_expect(image.save_png(output_path) == OK, "%s should save successfully" % file_name)

func _probe_state() -> Dictionary:
	return {
		"name": "Movement Arrow Proof Hall",
		"room_coord": Vector2i(7, -3),
		"room_element": "none",
		"grid": _probe_grid(),
		"moss": {},
		"player": {
			"pos": Vector2i(2, 4),
			"hp": 30,
			"max_hp": 30,
			"block": 0,
			"stoneskin": 0,
			"burn": 0,
			"bleed": 0
		},
		"enemies": [],
		"illusions": [],
		"npcs": [],
		"loot": [],
		"terrain": [],
		"traps": [],
		"player_turn_restrictions": {}
	}

func _probe_grid() -> Array:
	return [
		["wall", "wall", "wall", "wall", "wall", "wall", "wall", "wall", "wall"],
		["wall", "ash", "ash", "ash", "ash", "ash", "ash", "ash", "wall"],
		["wall", "ash", "ash", "ash", "ash", "ash", "ash", "ash", "wall"],
		["wall", "ash", "ash", "ash", "ash", "ash", "ash", "ash", "wall"],
		["wall", "ash", "ash", "ash", "ash", "ash", "ash", "ash", "wall"],
		["wall", "ash", "ash", "ash", "ash", "ash", "ash", "ash", "wall"],
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
