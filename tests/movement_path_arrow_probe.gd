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
		_vector2i_array([Vector2i(2, 4), Vector2i(3, 4), Vector2i(4, 4), Vector2i(4, 3), Vector2i(4, 2)]),
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
	await _capture(
		viewport,
		board,
		_vector2i_array([Vector2i(2, 4), Vector2i(3, 4), Vector2i(4, 4), Vector2i(5, 4), Vector2i(6, 4)]),
		"04_ground_item_layering.png",
		4,
		true
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
	_expect(shaft_ratio >= 0.35 and shaft_ratio <= 0.39, "Arrow shaft should be about ten percent narrower than the 0.41-tile pass")
	_expect(head_width_ratio >= 0.42 and head_width_ratio <= 0.47, "Arrow head should scale down about ten percent with the narrower shaft")
	_expect(head_tip_reach_ratio + head_tail_reach_ratio >= 0.44 and head_tip_reach_ratio + head_tail_reach_ratio <= 0.50, "Arrow head should preserve its approved overall length")
	_expect(projected_tile_edge_ratio - head_tip_reach_ratio >= 0.08 and projected_tile_edge_ratio - head_tip_reach_ratio <= 0.12, "Arrow tip should land clearly inside the destination tile instead of near the next tile")
	_expect(head_tail_reach_ratio - projected_tile_edge_ratio >= 0.0 and head_tail_reach_ratio - projected_tile_edge_ratio <= 0.035, "Arrow head base should just cross the destination tile's near edge")
	_expect(absf((head_tip_reach_ratio - head_tail_reach_ratio) * 0.5) <= 0.065, "Arrow head bounds should remain centered near the destination tile")
	_expect(shadow_offset_ratio >= 0.025 and shadow_offset_ratio <= 0.05, "Arrow should retain a restrained cast shadow without inflating its silhouette")
	_expect(outline_width_ratio >= 1.08 and outline_width_ratio <= 1.16, "Arrow outline should define the ribbon without making it substantially wider")
	_expect(glow_width_ratio >= 1.16 and glow_width_ratio <= 1.30, "Arrow bloom should stay soft and close to the ribbon")
	_expect(gradient_layers >= 12, "Arrow shaft should blend its face through enough narrow gradient layers to avoid crude bands")
	_expect(body_alpha >= 0.80 and body_alpha <= 0.90, "Single-tile path marker should be subtly translucent without losing tactical readability")
	_expect(gradient_base_alpha >= 0.64 and gradient_base_alpha <= 0.76, "Arrow shaft base should leave board texture visible through its shaded edge")
	_expect(gradient_layer_alpha >= 0.035 and gradient_layer_alpha <= 0.075, "Arrow shaft highlight layers should build translucency gradually instead of becoming opaque through overdraw")
	_expect(gradient_segments >= 20, "Single-tile path markers should use enough interpolated gradient segments to avoid visible color bands")
	_verify_unified_arrow_geometry(board)
	_verify_layering_contract(board)

func _verify_unified_arrow_geometry(board: Control) -> void:
	var tile_width: float = 100.0
	var shaft_width: float = 22.0
	var to_point := Vector2(220.0, 190.0)
	var from_point: Vector2 = to_point - Vector2(tile_width * 0.5, tile_width * 0.25)
	var head_geometry: Dictionary = board.call("_path_arrow_geometry", from_point, to_point, tile_width, shaft_width)
	var head_polygon: PackedVector2Array = head_geometry.get("polygon", PackedVector2Array())
	var direction: Vector2 = head_geometry.get("direction", Vector2.ZERO)
	var tail_center: Vector2 = head_geometry.get("tail_center", to_point)
	_expect(head_polygon.size() == 3, "Arrow head should begin as a true triangle before unifying with the shaft")
	_verify_board_perspective_geometry(
		from_point,
		to_point,
		tile_width,
		Vector2(-0.5, 0.25).normalized(),
		head_geometry
	)
	_verify_board_perspective_geometry(
		to_point - Vector2(tile_width * 0.5, -tile_width * 0.25),
		to_point,
		tile_width,
		Vector2(-0.5, -0.25).normalized(),
		board.call(
			"_path_arrow_geometry",
			to_point - Vector2(tile_width * 0.5, -tile_width * 0.25),
			to_point,
			tile_width,
			shaft_width
		) as Dictionary
	)
	var shaft_points := PackedVector2Array([
		from_point,
		tail_center + direction * shaft_width * 0.18
	])
	var unified: PackedVector2Array = board.call("_unified_path_arrow_polygon", shaft_points, head_polygon, shaft_width)
	_expect(not unified.is_empty(), "Arrow renderer should merge shaft and head into one polygon")
	var head_area: float = absf(float(board.call("_path_polygon_signed_area", head_polygon)))
	var unified_area: float = absf(float(board.call("_path_polygon_signed_area", unified)))
	_expect(unified_area > head_area * 1.5, "Unified arrow polygon should contain both the head and a substantial shaft")

func _verify_board_perspective_geometry(
	from_point: Vector2,
	to_point: Vector2,
	tile_width: float,
	expected_cross: Vector2,
	head_geometry: Dictionary
) -> void:
	var direction: Vector2 = head_geometry.get("direction", Vector2.ZERO)
	var board_cross: Vector2 = head_geometry.get("board_cross_direction", Vector2.ZERO)
	var tip: Vector2 = head_geometry.get("tip", Vector2.ZERO)
	var tail_center: Vector2 = head_geometry.get("tail_center", Vector2.ZERO)
	var plus_shoulder: Vector2 = head_geometry.get("plus_shoulder", Vector2.ZERO)
	var minus_shoulder: Vector2 = head_geometry.get("minus_shoulder", Vector2.ZERO)
	var shoulder_midpoint: Vector2 = plus_shoulder.lerp(minus_shoulder, 0.5)
	var rear_direction: Vector2 = (plus_shoulder - minus_shoulder).normalized()
	var tile_height: float = tile_width * 0.5
	var destination_tile := PackedVector2Array([
		to_point + Vector2(0.0, -tile_height * 0.5),
		to_point + Vector2(tile_width * 0.5, 0.0),
		to_point + Vector2(0.0, tile_height * 0.5),
		to_point + Vector2(-tile_width * 0.5, 0.0)
	])
	_expect(absf(rear_direction.cross(expected_cross)) <= 0.001, "Arrow head rear edge should run parallel to the board's cross-grid axis")
	_expect(absf(board_cross.cross(expected_cross)) <= 0.001, "Arrow head should expose the isometric cross-grid direction it used")
	_expect(shoulder_midpoint.distance_to(tail_center) <= 0.001, "Arrow head shoulders should remain symmetric around their board-space center")
	_expect(absf((tip - tail_center).normalized().cross(direction)) <= 0.001, "Arrow tip should stay centered on the movement axis")
	_expect(Geometry2D.is_point_in_polygon(tip, destination_tile), "Arrow tip should finish inside the destination tile")
	_expect(not Geometry2D.is_point_in_polygon(tail_center, destination_tile), "Arrow head base should straddle the destination tile's near edge")
	var bounds_midpoint: Vector2 = tip.lerp(tail_center, 0.5)
	_expect(absf((bounds_midpoint - to_point).dot(direction)) <= tile_width * 0.065, "Arrow head longitudinal bounds should center near the destination tile")
	_expect(from_point.distance_to(to_point) > 0.0, "Perspective fixture should use a nonzero isometric step")

func _verify_layering_contract(board: Control) -> void:
	_expect(bool(board.call("_loot_renders_below_path", {"kind": "healing_vial"})), "Ground potions should render below the movement path")
	_expect(bool(board.call("_loot_renders_below_path", {"kind": "rusty_shield"})), "Ground shields should render below the movement path")
	_expect(not bool(board.call("_loot_renders_below_path", {"kind": "equipment"})), "Floating equipment should render above the movement path")

func _capture(
	viewport: SubViewport,
	board: Control,
	path_tiles: Array[Vector2i],
	file_name: String,
	capture_index: int,
	include_layering_fixture: bool = false
) -> void:
	var move_tiles: Array[Vector2i] = path_tiles.duplicate()
	move_tiles.pop_front()
	board.call(
		"set_combat_state",
		_probe_state(Vector2i(7 + capture_index, -3), include_layering_fixture),
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

func _probe_state(room_coord: Vector2i, include_layering_fixture: bool = false) -> Dictionary:
	var state: Dictionary = {
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
	if include_layering_fixture:
		state["loot"] = [
			{"id": "probe_potion", "kind": "healing_vial", "amount": 40, "pos": Vector2i(3, 4)},
			{"id": "probe_shield", "kind": "rusty_shield", "amount": 40, "pos": Vector2i(5, 4)},
			{"id": "probe_equipment", "kind": "equipment", "equipment_id": "iron_cleaver", "pos": Vector2i(6, 4)}
		]
		state["traps"] = [
			{"id": "probe_trap", "pos": Vector2i(4, 4), "element": "fire", "damage": 40}
		]
	return state

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
