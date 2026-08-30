extends SceneTree

const CombatBoardViewScript = preload("res://scripts/combat_board_view.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")

const OUTPUT_DIR: String = "user://movement_path_arrow_probe"
const VIEWPORT_SIZE: Vector2i = Vector2i(1920, 1080)

var _errors: Array[String] = []

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_clear_probe_output(OUTPUT_DIR)
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.msaa_2d = int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_2d", Viewport.MSAA_DISABLED))
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.disable_3d = true
	root.add_child(viewport)
	var board: Control = CombatBoardViewScript.new()
	board.size = Vector2(VIEWPORT_SIZE)
	viewport.add_child(board)
	board.set_process(false)
	_verify_style_contract(board, viewport)
	await process_frame

	await _capture(
		viewport,
		board,
		_vector2i_array([Vector2i(2, 4), Vector2i(3, 4), Vector2i(4, 4), Vector2i(5, 4), Vector2i(6, 4)]),
		"crumble_v5_01_southeast_straight.png",
		1
	)
	await _capture(
		viewport,
		board,
		_vector2i_array([Vector2i(2, 4), Vector2i(3, 4), Vector2i(4, 4), Vector2i(4, 3), Vector2i(4, 2)]),
		"crumble_v5_02_turning_path.png",
		2
	)
	await _capture(
		viewport,
		board,
		_vector2i_array([Vector2i(2, 4), Vector2i(3, 4)]),
		"crumble_v5_03_one_step_path.png",
		3
	)
	await _capture(
		viewport,
		board,
		_vector2i_array([Vector2i(2, 4), Vector2i(3, 4), Vector2i(4, 4), Vector2i(5, 4), Vector2i(6, 4)]),
		"crumble_v5_04_ground_item_layering.png",
		4,
		true
	)
	await _capture(
		viewport,
		board,
		_vector2i_array([Vector2i(6, 2), Vector2i(5, 2), Vector2i(4, 2), Vector2i(3, 2), Vector2i(2, 2)]),
		"crumble_v5_05_northwest_straight.png",
		5
	)
	await _capture(
		viewport,
		board,
		_vector2i_array([Vector2i(4, 2), Vector2i(4, 3), Vector2i(4, 4), Vector2i(4, 5)]),
		"crumble_v5_06_southwest_straight.png",
		6
	)
	await _capture(
		viewport,
		board,
		_vector2i_array([Vector2i(6, 5), Vector2i(6, 4), Vector2i(6, 3), Vector2i(6, 2), Vector2i(6, 1)]),
		"crumble_v5_07_northeast_straight.png",
		7
	)
	await _capture(
		viewport,
		board,
		_vector2i_array([Vector2i(2, 4), Vector2i(3, 4), Vector2i(4, 4), Vector2i(4, 3), Vector2i(3, 3), Vector2i(3, 2), Vector2i(4, 2)]),
		"crumble_v5_08_double_bend.png",
		8
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

func _verify_style_contract(board: Control, viewport: SubViewport) -> void:
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
	var damage_spacing_ratio: float = float(constants.get("MOVE_PATH_CRUMBLE_DAMAGE_SPACING_RATIO", 0.0))
	var micro_depth_ratio: float = float(constants.get("MOVE_PATH_CRUMBLE_MICRO_DEPTH_RATIO", 0.0))
	var chip_depth_ratio: float = float(constants.get("MOVE_PATH_CRUMBLE_CHIP_DEPTH_RATIO", 0.0))
	var chunk_depth_ratio: float = float(constants.get("MOVE_PATH_CRUMBLE_CHUNK_DEPTH_RATIO", 0.0))
	var surface_spacing_ratio: float = float(constants.get("MOVE_PATH_CRUMBLE_SURFACE_SPACING_RATIO", 0.0))
	var spall_size_ratio: float = float(constants.get("MOVE_PATH_CRUMBLE_SPALL_SIZE_RATIO", 0.0))
	var crack_dark_width_ratio: float = float(constants.get("MOVE_PATH_CRACK_DARK_WIDTH_RATIO", 0.0))
	var projected_tile_edge_ratio: float = Vector2(0.5, 0.25).length() * 0.5
	_expect(int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_2d", 0)) >= Viewport.MSAA_4X, "Real display renderers should use at least 4x project-wide 2D MSAA")
	_expect(viewport.msaa_2d >= Viewport.MSAA_4X, "Focused arrow captures should render their offscreen viewport with at least 4x 2D MSAA")
	_expect(shaft_ratio >= 0.32 and shaft_ratio <= 0.345, "Arrow shaft should be about ten percent narrower than the 0.37-tile pass")
	_expect(head_width_ratio >= 0.39 and head_width_ratio <= 0.42, "Arrow head should scale down about ten percent with the narrower shaft")
	_expect(head_tip_reach_ratio + head_tail_reach_ratio >= 0.41 and head_tip_reach_ratio + head_tail_reach_ratio <= 0.435, "Arrow head should be about ten percent shorter than the 0.47-tile pass")
	_expect(projected_tile_edge_ratio - head_tip_reach_ratio >= 0.13 and projected_tile_edge_ratio - head_tip_reach_ratio <= 0.15, "Arrow tip should land clearly inside the destination tile instead of near the next tile")
	_expect(head_tail_reach_ratio - projected_tile_edge_ratio >= 0.0 and head_tail_reach_ratio - projected_tile_edge_ratio <= 0.035, "Arrow head base should just cross the destination tile's near edge")
	_expect(absf((head_tip_reach_ratio - head_tail_reach_ratio) * 0.5) <= 0.075, "Arrow head bounds should remain centered near the destination tile")
	_expect(shadow_offset_ratio >= 0.025 and shadow_offset_ratio <= 0.05, "Arrow should retain a restrained cast shadow without inflating its silhouette")
	_expect(outline_width_ratio >= 1.08 and outline_width_ratio <= 1.16, "Arrow outline should define the ribbon without making it substantially wider")
	_expect(glow_width_ratio >= 1.16 and glow_width_ratio <= 1.30, "Arrow bloom should stay soft and close to the ribbon")
	_expect(gradient_layers >= 12, "Arrow shaft should blend its face through enough narrow gradient layers to avoid crude bands")
	_expect(body_alpha >= 0.80 and body_alpha <= 0.90, "Single-tile path marker should be subtly translucent without losing tactical readability")
	_expect(gradient_base_alpha >= 0.64 and gradient_base_alpha <= 0.76, "Arrow shaft base should leave board texture visible through its shaded edge")
	_expect(gradient_layer_alpha >= 0.035 and gradient_layer_alpha <= 0.075, "Arrow shaft highlight layers should build translucency gradually instead of becoming opaque through overdraw")
	_expect(gradient_segments >= 20, "Single-tile path markers should use enough interpolated gradient segments to avoid visible color bands")
	_expect(damage_spacing_ratio >= 0.72 and damage_spacing_ratio <= 0.95, "Discrete edge losses should leave straight material between damage sites instead of deforming the outline continuously")
	_expect(micro_depth_ratio >= 0.035 and micro_depth_ratio <= 0.075, "Micro-imperfections should nick the edge without turning it into a squiggle")
	_expect(chip_depth_ratio >= 0.095 and chip_depth_ratio <= 0.17, "Medium chips should visibly break the edge while retaining the route")
	_expect(chunk_depth_ratio >= 0.18 and chunk_depth_ratio <= 0.28, "Large missing chunks should be substantial without severing the arrow")
	_expect(surface_spacing_ratio >= 2.10 and surface_spacing_ratio <= 2.80, "Internal damage should recur along the route without becoming a dotted pattern")
	_expect(spall_size_ratio >= 0.14 and spall_size_ratio <= 0.22, "Internal spalls should read at board scale without hollowing the route")
	_expect(crack_dark_width_ratio >= 0.032 and crack_dark_width_ratio <= 0.055, "Cracks should be legible bevels without becoming route-dividing seams")
	_verify_unified_arrow_geometry(board)
	_verify_crumble_geometry(board)
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

func _verify_crumble_geometry(board: Control) -> void:
	var routes: Array = [
		[Vector2i(2, 4), Vector2i(3, 4)],
		[Vector2i(2, 4), Vector2i(3, 4), Vector2i(4, 4), Vector2i(5, 4), Vector2i(6, 4)],
		[Vector2i(6, 2), Vector2i(5, 2), Vector2i(4, 2), Vector2i(3, 2), Vector2i(2, 2)],
		[Vector2i(2, 1), Vector2i(2, 2), Vector2i(2, 3), Vector2i(2, 4), Vector2i(2, 5)],
		[Vector2i(6, 5), Vector2i(6, 4), Vector2i(6, 3), Vector2i(6, 2), Vector2i(6, 1)],
		[Vector2i(2, 4), Vector2i(3, 4), Vector2i(4, 4), Vector2i(4, 3), Vector2i(4, 2)],
	]
	for route_index: int in range(routes.size()):
		var path_tiles: Array[Vector2i] = _vector2i_array(routes[route_index] as Array)
		var path_points: PackedVector2Array = _projected_path_points(path_tiles, 100.0)
		var shaft_width: float = 100.0 * 0.5 * 0.333
		var arrow_geometry: Dictionary = board.call(
			"_path_arrow_geometry",
			path_points[path_points.size() - 2],
			path_points[path_points.size() - 1],
			100.0,
			shaft_width
		) as Dictionary
		var direction: Vector2 = arrow_geometry.get("direction", Vector2.ZERO)
		var shaft_points: PackedVector2Array = path_points.duplicate()
		shaft_points[shaft_points.size() - 1] = (
			arrow_geometry.get("tail_center", path_points[path_points.size() - 1])
			+ direction * shaft_width * 0.18
		)
		var unified: PackedVector2Array = board.call(
			"_unified_path_arrow_polygon",
			shaft_points,
			arrow_geometry.get("polygon", PackedVector2Array()),
			shaft_width
		) as PackedVector2Array
		var crumble: Dictionary = board.call(
			"_path_crumble_geometry",
			path_tiles,
			path_points,
			unified,
			shaft_width
		) as Dictionary
		var repeated: Dictionary = board.call(
			"_path_crumble_geometry",
			path_tiles,
			path_points,
			unified,
			shaft_width
		) as Dictionary
		var body_polygons: Array[PackedVector2Array] = board.call(
			"_path_polygon_array",
			crumble.get("body_polygons", [])
		) as Array[PackedVector2Array]
		var notches: Array = crumble.get("notches", []) as Array
		var surface_spalls: Array = crumble.get("surface_spalls", []) as Array
		var cracks: Array = crumble.get("cracks", []) as Array
		var damage_counts: Dictionary = crumble.get("damage_counts", {}) as Dictionary
		var micro_count: int = int(damage_counts.get("micro", 0))
		var chip_count: int = int(damage_counts.get("chip", 0))
		var chunk_count: int = int(damage_counts.get("chunk", 0))
		var total_damage_count: int = micro_count + chip_count + chunk_count
		var boundary_sample_count: int = int(crumble.get("boundary_sample_count", 0))
		var unified_area: float = absf(float(board.call("_path_polygon_signed_area", unified)))
		var body_area: float = float(board.call("_path_polygon_array_area", body_polygons))
		var label: String = "route %d" % route_index
		var edge_crack_count: int = 0
		var surface_crack_count: int = 0
		for crack_var: Variant in cracks:
			var source_kind: String = str((crack_var as Dictionary).get("source_kind", ""))
			if source_kind == "edge_notch":
				edge_crack_count += 1
			elif source_kind == "surface_spall":
				surface_crack_count += 1
		_expect(not body_polygons.is_empty(), "%s should retain drawable arrow body polygons after distressing" % label)
		_expect(total_damage_count == notches.size(), "%s should account for every accepted discrete edge loss" % label)
		_expect(micro_count >= 1, "%s should include small edge nicks between larger breaks" % label)
		_expect(chip_count >= 1, "%s should include asymmetric medium chips" % label)
		_expect(chunk_count >= 1, "%s should include at least one substantial missing chunk" % label)
		_expect(total_damage_count < boundary_sample_count, "%s should retain straight baseline spans rather than damaging every perimeter sample" % label)
		_expect(not crumble.has("loose_polygons"), "%s should keep damage in the arrow material instead of scattering detached rubble" % label)
		_expect(surface_spalls.size() >= 2, "%s should carry internal material damage along the arrow face" % label)
		_expect(edge_crack_count >= chunk_count and edge_crack_count <= chip_count + chunk_count, "%s edge cracks should grow only from accepted medium and large breaks" % label)
		_expect(surface_crack_count >= 1 and surface_crack_count <= surface_spalls.size(), "%s should branch at least one internal fracture from a face spall" % label)
		_expect(cracks.size() == edge_crack_count + surface_crack_count, "%s should classify every fracture by its material origin" % label)
		_expect(body_area >= unified_area * 0.78 and body_area < unified_area * 0.995, "%s should lose discrete material without compromising route readability (ratio %.4f)" % [label, body_area / unified_area])
		_expect(str(crumble) == str(repeated), "%s crumble geometry should be stable across redraws" % label)
		for spall_var: Variant in surface_spalls:
			var spall: Dictionary = spall_var as Dictionary
			var spall_polygon: PackedVector2Array = spall.get("polygon", PackedVector2Array())
			var segment_direction: Vector2 = spall.get("segment_direction", Vector2.ZERO)
			var board_cross: Vector2 = spall.get("board_cross_direction", Vector2.ZERO)
			var expected_cross: Vector2 = Vector2(-segment_direction.x, segment_direction.y).normalized()
			_expect(spall_polygon.size() == 7, "%s face damage should use irregular seven-sided spalls rather than primitive decals" % label)
			_expect(bool(board.call("_path_polygon_inside_any_path_polygon", spall_polygon, body_polygons)), "%s face spalls should stay inside retained arrow material" % label)
			_expect(board_cross.normalized().distance_to(expected_cross) <= 0.001, "%s face spalls should carry the route's projected board frame" % label)
		for crack_index: int in range(cracks.size()):
			var crack_var: Variant = cracks[crack_index]
			var crack: Dictionary = crack_var as Dictionary
			var crack_points: PackedVector2Array = crack.get("points", PackedVector2Array())
			var board_cross: Vector2 = crack.get("board_cross_direction", Vector2.ZERO)
			var branch_points: PackedVector2Array = crack.get("branch", PackedVector2Array())
			var source: Vector2 = crack.get("source", Vector2.INF)
			var source_kind: String = str(crack.get("source_kind", ""))
			_expect(crack_points.size() == 4, "%s cracks should use compact four-point fracture marks" % label)
			_expect(branch_points.size() == 2, "%s cracks should include one short fork" % label)
			_expect(source == crack_points[0], "%s cracks should expose their material-damage origin" % label)
			if source_kind == "edge_notch":
				var source_damage_index: int = int(crack.get("source_damage_index", -1))
				_expect(source_damage_index >= 0 and source_damage_index < notches.size(), "%s edge cracks should identify their originating loss" % label)
				if source_damage_index >= 0 and source_damage_index < notches.size():
					var source_notch: PackedVector2Array = notches[source_damage_index] as PackedVector2Array
					_expect(source_notch.size() >= 5 and source.distance_to(source_notch[4]) <= 0.001, "%s edge crack origins should remain attached to missing chunks" % label)
			elif source_kind == "surface_spall":
				var source_spall_index: int = int(crack.get("source_spall_index", -1))
				_expect(source_spall_index >= 0 and source_spall_index < surface_spalls.size(), "%s internal cracks should identify their originating spall" % label)
				if source_spall_index >= 0 and source_spall_index < surface_spalls.size():
					var source_spall: Dictionary = surface_spalls[source_spall_index] as Dictionary
					var source_polygon: PackedVector2Array = source_spall.get("polygon", PackedVector2Array())
					_expect(_polygon_has_point(source_polygon, source), "%s internal fracture origins should touch their face spalls" % label)
					_expect(bool(board.call("_path_crack_fits_polygon_array", crack, body_polygons)), "%s internal fractures should stay inside retained arrow material" % label)
			else:
				_expect(false, "%s cracks should have an edge-notch or surface-spall origin" % label)
			if crack_points.size() == 4 and board_cross.length_squared() > 0.0:
				var opening_direction: Vector2 = (crack_points[1] - crack_points[0]).normalized()
				_expect(absf(opening_direction.cross(board_cross.normalized())) <= 0.001, "%s crack openings should follow the projected board cross-axis" % label)
				for crack_point: Vector2 in crack_points:
					_expect(Geometry2D.is_point_in_polygon(crack_point, unified), "%s cracks should stay clipped conceptually inside the 3D arrow face" % label)
				for branch_point: Vector2 in branch_points:
					_expect(Geometry2D.is_point_in_polygon(branch_point, unified), "%s crack forks should stay inside the 3D arrow face" % label)

func _polygon_has_point(polygon: PackedVector2Array, expected: Vector2) -> bool:
	for point: Vector2 in polygon:
		if point.distance_to(expected) <= 0.001:
			return true
	return false

func _projected_path_points(path_tiles: Array[Vector2i], tile_width: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for tile: Vector2i in path_tiles:
		points.append(Vector2(
			float(tile.x - tile.y) * tile_width * 0.5,
			float(tile.x + tile.y) * tile_width * 0.25
		))
	return points

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
	_expect(absf((bounds_midpoint - to_point).dot(direction)) <= tile_width * 0.075, "Arrow head longitudinal bounds should center near the destination tile")
	_expect(from_point.distance_to(to_point) > 0.0, "Perspective fixture should use a nonzero isometric step")

func _verify_layering_contract(board: Control) -> void:
	_expect(not bool(board.call("_loot_renders_below_path", {"kind": "item", "card_id": "crimson_draught"})), "Floating item potions should render above the movement path")
	_expect(not bool(board.call("_loot_renders_below_path", {"kind": "item", "card_id": "bone_ward_charm"})), "Floating item charms should render above the movement path")
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
		_probe_state(Vector2i(7 + capture_index, -3), path_tiles[0], include_layering_fixture),
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

func _probe_state(room_coord: Vector2i, player_pos: Vector2i, include_layering_fixture: bool = false) -> Dictionary:
	var state: Dictionary = {
		"name": "Movement Arrow Proof Hall",
		"room_coord": room_coord,
		"room_element": "none",
		"grid": _probe_grid(),
		"moss": {},
		"player": {
			"pos": player_pos,
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
			{"id": "probe_potion", "kind": "item", "card_id": "crimson_draught", "pos": Vector2i(3, 4)},
			{"id": "probe_shield", "kind": "item", "card_id": "bone_ward_charm", "pos": Vector2i(5, 4)},
			{"id": "probe_equipment", "kind": "equipment", "equipment_id": "iron_cleaver", "pos": Vector2i(6, 4)}
		]
		state["traps"] = [
			{"id": "probe_trap", "pos": Vector2i(4, 4), "element": "fire", "damage": 40}
		]
	return state

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
