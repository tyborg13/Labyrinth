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
		"01_straight_path.png",
		1
	)
	await _capture(
		viewport,
		board,
		_vector2i_array([Vector2i(2, 4), Vector2i(3, 4), Vector2i(4, 4), Vector2i(4, 3), Vector2i(5, 3)]),
		"02_turning_path.png",
		2
	)
	await _capture(
		viewport,
		board,
		_vector2i_array([Vector2i(2, 4), Vector2i(3, 4)]),
		"03_one_step_path.png",
		3
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
	var head_tip_reach_ratio: float = float(constants.get("MOVE_PATH_HEAD_TIP_REACH_TILE_RATIO", 0.0))
	var head_tail_reach_ratio: float = float(constants.get("MOVE_PATH_HEAD_TAIL_REACH_TILE_RATIO", 0.0))
	var shadow_offset_ratio: float = float(constants.get("MOVE_PATH_SHADOW_OFFSET_TILE_RATIO", 0.0))
	var outline_width_ratio: float = float(constants.get("MOVE_PATH_OUTLINE_WIDTH_RATIO", 0.0))
	var glow_width_ratio: float = float(constants.get("MOVE_PATH_GLOW_WIDTH_RATIO", 0.0))
	var gradient_layers: int = int(constants.get("MOVE_PATH_GRADIENT_LAYER_COUNT", 0))
	var body_alpha: float = float(constants.get("MOVE_PATH_BODY_ALPHA", 1.0))
	var gradient_base_alpha: float = float(constants.get("MOVE_PATH_GRADIENT_BASE_ALPHA", 1.0))
	var gradient_layer_alpha: float = float(constants.get("MOVE_PATH_GRADIENT_LAYER_ALPHA", 1.0))
	var gradient_segments: int = int(constants.get("MOVE_PATH_GRADIENT_DISC_SEGMENTS", 0))
	var projected_tile_edge_ratio: float = Vector2(0.5, 0.25).length() * 0.5
	_expect(shaft_ratio >= 0.38 and shaft_ratio <= 0.43, "Arrow shaft should be about fifteen percent narrower than the prior half-tile pass")
	_expect(head_width_ratio >= 0.47 and head_width_ratio <= 0.53, "Arrow head should scale down proportionately with the narrower shaft")
	_expect(head_tip_reach_ratio + head_tail_reach_ratio >= 0.49 and head_tip_reach_ratio + head_tail_reach_ratio <= 0.56, "Arrow head length should scale down while its tip remains on the destination edge")
	_expect(absf(head_tip_reach_ratio - projected_tile_edge_ratio) <= 0.02, "Arrow tip should stop at the destination tile's far edge instead of pointing toward the next tile")
	_expect(shadow_offset_ratio >= 0.025 and shadow_offset_ratio <= 0.05, "Arrow should retain a restrained cast shadow without inflating its silhouette")
	_expect(outline_width_ratio >= 1.08 and outline_width_ratio <= 1.16, "Arrow outline should define the ribbon without making it substantially wider")
	_expect(glow_width_ratio >= 1.16 and glow_width_ratio <= 1.30, "Arrow bloom should stay soft and close to the ribbon")
	_expect(gradient_layers >= 12, "Arrow shaft should blend its face through enough narrow gradient layers to avoid crude bands")
	_expect(body_alpha >= 0.80 and body_alpha <= 0.90, "Arrow head should be subtly translucent without losing tactical readability")
	_expect(gradient_base_alpha >= 0.64 and gradient_base_alpha <= 0.76, "Arrow shaft base should leave board texture visible through its shaded edge")
	_expect(gradient_layer_alpha >= 0.035 and gradient_layer_alpha <= 0.075, "Arrow shaft highlight layers should build translucency gradually instead of becoming opaque through overdraw")
	_expect(gradient_segments >= 20, "Single-tile path markers should use enough interpolated gradient segments to avoid visible color bands")
	_verify_unified_arrow_geometry(board)

func _verify_unified_arrow_geometry(board: Control) -> void:
	var from_point := Vector2(120.0, 140.0)
	var to_point := Vector2(220.0, 190.0)
	var tile_width: float = 100.0
	var shaft_width: float = 22.0
	var head_geometry: Dictionary = board.call("_path_arrow_geometry", from_point, to_point, tile_width, shaft_width)
	var head_polygon: PackedVector2Array = head_geometry.get("polygon", PackedVector2Array())
	var direction: Vector2 = head_geometry.get("direction", Vector2.ZERO)
	var tail_center: Vector2 = head_geometry.get("tail_center", to_point)
	var shaft_points := PackedVector2Array([
		from_point,
		tail_center + direction * shaft_width * 0.18
	])
	var unified: PackedVector2Array = board.call("_unified_path_arrow_polygon", shaft_points, head_polygon, shaft_width)
	_expect(not unified.is_empty(), "Arrow renderer should merge shaft and head into one polygon")
	var head_area: float = absf(float(board.call("_path_polygon_signed_area", head_polygon)))
	var unified_area: float = absf(float(board.call("_path_polygon_signed_area", unified)))
	_expect(unified_area > head_area * 1.5, "Unified arrow polygon should contain both the head and a substantial shaft")

func _capture(viewport: SubViewport, board: Control, path_tiles: Array[Vector2i], file_name: String, capture_index: int) -> void:
	var move_tiles: Array[Vector2i] = path_tiles.duplicate()
	move_tiles.pop_front()
	board.call(
		"set_combat_state",
		_probe_state(Vector2i(7 + capture_index, -3)),
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
	board.queue_redraw()
	for _frame: int in range(4):
		await process_frame
	var image: Image = viewport.get_texture().get_image()
	var output_path: String = ProjectSettings.globalize_path("%s/%s" % [OUTPUT_DIR, file_name])
	_expect(image != null and image.get_size() == VIEWPORT_SIZE, "%s should capture at the fixed gameplay proof size" % file_name)
	var instrumentation: Dictionary = board.call("render_instrumentation_snapshot")
	_expect(int(instrumentation.get("static_draw_count", 0)) >= 1, "%s should render the complete static board context" % file_name)
	if image != null:
		_expect(image.save_png(output_path) == OK, "%s should save successfully" % file_name)

func _probe_state(room_coord: Vector2i) -> Dictionary:
	return {
		"name": "Movement Arrow Proof Hall",
		"room_coord": room_coord,
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
