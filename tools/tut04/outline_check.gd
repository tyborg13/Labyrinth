extends "res://tests/pre_battle_fixture.gd"

const Combat = preload("res://scripts/combat_engine.gd")
const Fixture = preload("res://tools/tut02/run_fixture.gd")
const Hover = preload("res://tools/gfix54/native_hover.gd")
const Path = preload("res://scripts/path_utils.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const ROOM := Vector2i(2, 1)
const RULE: String = "Enemies on dark tiles are hidden: you can't target them or see their intents."
const NON_FLOOR: Array = ["wall", "pillar", "void", "empty", ""]
const MAX_HOLE_AREA_RATIO: float = 1.03
const MAX_HOLE_GROWTH_PX: float = 3.5
const SILHOUETTE_SAMPLE_STEP_PX: float = 4.0
const MAX_FLOOR_DISTANCE_PX: float = 4.0
const SLAB_RING_SIZE: int = 3
const SLAB_GAP := Vector2i(1, 1)
const ISOLATED_SLAB := Vector2i(5, 5)
const PROOF_LAYOUT_FRAME_LIMIT: int = 900
const FALLBACK_TILE_WIDTH_PX: float = 1.0

var _scene: Node
var _board: CombatBoardView
var _floor_layer: Control
var _prompt: Control
var _checked_close: bool = false

func _initialize() -> void:
	_check.call_deferred()

func _check() -> void:
	_setup()
	Hover.prepare(_viewport)
	var profile: Dictionary = Tutorial.complete_tutorial(ProgressionStore.default_data())
	var fixture: Dictionary = Fixture.first_umbra(ProgressionStore.prepare_for_new_run(profile))
	_expect(fixture.get("seed") == Fixture.SEED and fixture.get("current_room") == ROOM, "Generated outline fixture is seed 90212 room (2, 1)")
	if not _failed:
		_expect(ProgressionStore.save_data(fixture["progression"]) and ProgressionStore.save_run_state(fixture), "Write isolated profile and checkpoint")
	if not _failed:
		root.set_meta("labyrinth_resume_saved_run", true)
		_scene = load("res://scenes/run_scene.tscn").instantiate()
		_viewport.add_child(_scene)
		await _settle()
		_board = _scene.get("board_view")
		_floor_layer = _board.get("_dynamic_render_layer")
		_prompt = _scene.get("_contextual_combat_prompt")
		await _wait_for_floor_framing()
		_expect(_prompt.is_visible_in_tree() and _prompt.call("active_prompt_id") == Tutorial.PHASE_UMBRA, "Umbra card opens the fixture")
	if not _failed:
		var dark: Dictionary = _check_outline("OPEN")
		_check_tooltips()
		_check_holes()
		_check_interior_gap()
		if not _failed:
			await _check_refresh(dark)
			await _check_suppression()
			await _check_continue()
	if is_instance_valid(_scene):
		_scene.queue_free()
		await process_frame
	print("TUT-04 OUTLINE CHECK: %s" % ("FAIL" if _failed else "PASS"))
	quit(int(_failed))

func _wait_for_floor_framing() -> void:
	# The saved encounter can appear before its hand layout supplies a board
	# fit. Sample after that fit has replaced the one-pixel startup fallback.
	for _frame: int in PROOF_LAYOUT_FRAME_LIMIT:
		if _scene.get("_hand_layout_pending_revision") < 0 and _board.call("_tile_width") > FALLBACK_TILE_WIDTH_PX:
			await process_frame
			return
		await process_frame
	_fail("The combat hand and board framing must settle before sampling")

func _check_outline(label: String) -> Dictionary:
	var shown: Dictionary = _floor_layer.get("presentation")
	var visible: Array = shown["umbra_visible_tiles"]
	var grid: Array = _floor_layer.get("combat_state")["grid"]
	var expected: Dictionary = {}
	var doors: Array[Vector2i]
	for tile: Vector2i in _floor_layer.call("_rendered_tiles_in_draw_order"):
		var tile_id: String = Path.tile_id(grid, tile)
		if visible.has(tile) or tile_id in NON_FLOOR:
			continue
		if tile_id == "door":
			if not _floor_layer.call("_door_is_visible", tile):
				continue
			doors.append(tile)
		expected[tile] = true
	if label == "OPEN":
		_expect(not doors.is_empty(), "The fixture includes a rendered door in the darkening pass")
		for door: Vector2i in doors:
			var stage_alpha: float = _floor_layer.call("_umbra_stage_fill_alpha", shown["umbra_stage"])
			var darkening: float = _floor_layer.call("_umbra_return_progress", door, _floor_layer.call("_umbra_visual_time_seconds"))
			_expect(stage_alpha * darkening > 0.0, "The outlined door is drawn with a nonzero Umbra fill")
	_expect(not expected.is_empty() and expected == _floor_layer.get("_umbra_tutorial_dark_floor"),
		"The outline uses every darkened floor tile in the retained world pass")
	var expected_edges: int = 0
	for tile: Vector2i in expected:
		for direction: Vector2i in Path.DIRS_4:
			if not expected.has(tile + direction): expected_edges += 1
	var contours: Array = _floor_layer.get("_umbra_tutorial_contours")
	var drawn: Dictionary = {}
	for contour: Array in contours:
		for index: int in contour.size():
			var edge: Vector3i = contour[index]
			var tile := Vector2i(edge.x, edge.y)
			var neighbor: Vector2i = tile + Path.DIRS_4[edge.z]
			_expect(expected.has(tile) and not expected.has(neighbor) and not drawn.has(edge),
				"Each drawn edge is unique and borders exactly one dark floor tile")
			drawn[edge] = true
			var next: Vector3i = contour[(index + 1) % contour.size()]
			var polygon: PackedVector2Array = _board.call("_tile_polygon", tile)
			var next_polygon: PackedVector2Array = _board.call("_tile_polygon", Vector2i(next.x, next.y))
			_expect(polygon[edge.z + 1].is_equal_approx(next_polygon[next.z]), "Every outline contour closes without a gap")
	_expect(drawn.size() == expected_edges, "All exterior edges are drawn and no shared dark edges are drawn")
	print("TUT-04 %s: dark_tiles=%d outline_parts=%d drawn_edges=%d door_tiles_added=%s" % [
		label, expected.size(), contours.size(), drawn.size(), doors,
	])
	return expected

func _check_tooltips() -> void:
	var subtitle: Label = _scene.get("umbra_subtitle")
	var state: Dictionary = _scene.get("_combat_state")
	var saved: Dictionary = state["umbra"]
	var stages_checked: int = 0
	for stage: String in Combat.UMBRA_STAGE_ORDER:
		if stage == Combat.UMBRA_STAGE_CLEAR: continue
		state["umbra"] = {"stage": stage}
		_scene.call("_refresh_umbra_subtitle")
		var label: String = "%s Umbra" % Combat.umbra_stage_display_name(stage)
		_expect(subtitle.text == label and subtitle.tooltip_text == "%s\n%s" % [label, RULE], "Exact two-line tooltip for " + label)
		stages_checked += 1
	state["umbra"] = saved
	_scene.call("_refresh_umbra_subtitle")
	print("TUT-04 TOOLTIP: stages=%d text=%s" % [stages_checked, JSON.stringify(subtitle.tooltip_text)])

func _check_holes() -> void:
	var holes: Array = _prompt.get_meta("board_spotlight_holes", [])
	var silhouettes: Array[PackedVector2Array] = _prompt.get("_board_silhouette")
	var spotlights: Array = _prompt.get_meta("spotlight_rects", [])
	var subtitle: Label = _scene.get("umbra_subtitle")
	var label_rect: Rect2 = subtitle.get_global_rect()
	label_rect.size.x = subtitle.get_minimum_size().x
	_expect(holes.size() == 1 and silhouettes.size() == 1 and spotlights == [label_rect]
		and _prompt.get_meta("evidence_rects", []).is_empty()
		and _prompt.get_meta("spotlight_hole_count", -1) == 2 and _prompt.get_meta("spotlight_frame_count", -1) == 0,
		"The dimmer cuts a board silhouette and the existing HUD label hole, both frameless")
	if _failed:
		return
	var hole: PackedVector2Array = holes[0]
	var silhouette: PackedVector2Array = silhouettes[0]
	var surfaces: Array[PackedVector2Array]
	var floor_points := PackedVector2Array()
	var to_viewport: Transform2D = _board.get_global_transform_with_canvas()
	for tile: Vector2i in _board.call("_rendered_tiles_in_draw_order"):
		surfaces.append(to_viewport * (_board.call("_tile_polygon", tile) as PackedVector2Array))
		for face: PackedVector2Array in _board.call("_tile_depth_faces", tile):
			surfaces.append(to_viewport * face)
	for surface: PackedVector2Array in surfaces:
		floor_points.append_array(surface)
	var covered: bool = true
	for point: Vector2 in floor_points:
		covered = covered and Geometry2D.is_point_in_polygon(point, hole)
	_expect(covered, "The grown hole contains all floor diamonds and slab sides")
	var area_ratio: float = _polygon_area(hole) / _polygon_area(silhouette)
	_expect(area_ratio <= MAX_HOLE_AREA_RATIO, "Hole area stays within 1.03 times the ungrown silhouette")
	var max_distance: float = 0.0
	for point: Vector2 in hole:
		max_distance = maxf(max_distance, _edge_distance(point, silhouette))
	_expect(max_distance <= MAX_HOLE_GROWTH_PX, "Hole vertices stay within 3.5 px of the ungrown silhouette")
	print("TUT-04 DIMMER: silhouette_vertices=%d hole_vertices=%d area_ratio=%.4f max_growth_px=%.3f holes=%d frames=%d" % [
		silhouette.size(), hole.size(), area_ratio, max_distance,
		_prompt.get_meta("spotlight_hole_count"), _prompt.get_meta("spotlight_frame_count"),
	])
	_check_scenery_samples(hole, surfaces, floor_points)

func _check_interior_gap() -> void:
	var tiles: Array[Vector2i]
	for y: int in SLAB_RING_SIZE:
		for x: int in SLAB_RING_SIZE:
			var tile := Vector2i(x, y)
			if tile != SLAB_GAP:
				tiles.append(tile)
	tiles.append(ISOLATED_SLAB)
	var silhouettes: Array[PackedVector2Array] = _board.call("_merge_floor_silhouette", tiles)
	var gap_center := Vector2(SLAB_GAP.x - SLAB_GAP.y, SLAB_GAP.x + SLAB_GAP.y)
	var covered: bool = false
	for silhouette: PackedVector2Array in silhouettes:
		covered = covered or Geometry2D.is_point_in_polygon(gap_center, silhouette)
	_expect(silhouettes.size() == 2 and covered, "The slab union fills an interior gap and retains a separate slab")
	print("TUT-04 SLAB UNION: parts=%d interior_gap_filled=%s" % [silhouettes.size(), covered])

func _check_scenery_samples(hole: PackedVector2Array, surfaces: Array[PackedVector2Array], points: PackedVector2Array) -> void:
	var hull: PackedVector2Array = Geometry2D.convex_hull(points)
	hull.remove_at(hull.size() - 1)
	var base: PackedVector2Array = Geometry2D.offset_polygon(hull, ContextualCombatPrompt.SPOTLIGHT_GROW, Geometry2D.JOIN_ROUND)[0]
	var sample_bounds: Rect2 = _polygon_bounds(points)
	print("TUT-04 FLOOR BOUNDS: bounds=%s tile_width=%s viewport=%s transform=%s" % [
		sample_bounds, _board.call("_tile_width"), _viewport.size, _board.get_global_transform_with_canvas(),
	])
	var near_bounds: Array[Rect2]
	for surface: PackedVector2Array in surfaces:
		near_bounds.append(_polygon_bounds(surface).grow(MAX_FLOOR_DISTANCE_PX))
	var samples: int = 0
	var scenery: int = 0
	var base_scenery: int = 0
	for y: int in range(ceili(sample_bounds.size.y / SILHOUETTE_SAMPLE_STEP_PX)):
		for x: int in range(ceili(sample_bounds.size.x / SILHOUETTE_SAMPLE_STEP_PX)):
			var point: Vector2 = sample_bounds.position + Vector2(x, y) * SILHOUETTE_SAMPLE_STEP_PX
			samples += 1
			var in_hole: bool = Geometry2D.is_point_in_polygon(point, hole)
			var in_base: bool = Geometry2D.is_point_in_polygon(point, base)
			if (in_hole or in_base) and not _within_floor_distance(point, surfaces, near_bounds):
				scenery += int(in_hole)
				base_scenery += int(in_base)
	print("TUT-04 SCENERY: sample_step_px=%.0f samples=%d beyond_floor_px=%.0f silhouette=%d round_1_hull=%d" % [
		SILHOUETTE_SAMPLE_STEP_PX, samples, MAX_FLOOR_DISTANCE_PX, scenery, base_scenery,
	])
	_expect(scenery == 0 and base_scenery > 0, "The silhouette removes the scenery exposed by the round-1 hull")

func _within_floor_distance(point: Vector2, surfaces: Array[PackedVector2Array], bounds: Array[Rect2]) -> bool:
	for index: int in surfaces.size():
		if not bounds[index].has_point(point):
			continue
		if Geometry2D.is_point_in_polygon(point, surfaces[index]) or _edge_distance(point, surfaces[index]) <= MAX_FLOOR_DISTANCE_PX:
			return true
	return false

func _polygon_bounds(polygon: PackedVector2Array) -> Rect2:
	var bounds := Rect2(polygon[0], Vector2.ZERO)
	for point: Vector2 in polygon:
		bounds = bounds.expand(point)
	return bounds

func _edge_distance(point: Vector2, polygon: PackedVector2Array) -> float:
	var distance: float = INF
	for index: int in polygon.size():
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(point, polygon[index], polygon[(index + 1) % polygon.size()])
		distance = minf(distance, point.distance_to(closest))
	return distance

func _polygon_area(polygon: PackedVector2Array) -> float:
	var twice_area: float = 0.0
	for index: int in polygon.size():
		twice_area += polygon[index].cross(polygon[(index + 1) % polygon.size()])
	return absf(twice_area) * 0.5

func _check_refresh(original_dark: Dictionary) -> void:
	var original_shown: Dictionary = _board.presentation
	var changed: Dictionary = original_shown.duplicate(false)
	var visible: Array = original_shown["umbra_visible_tiles"].duplicate()
	var tile: Vector2i = original_dark.keys()[0]
	visible.append(tile)
	changed["umbra_visible_tiles"] = visible
	_submit_board(changed)
	await _settle()
	var dark: Dictionary = _check_outline("LIVE UPDATE")
	_expect(dark.size() == original_dark.size() - 1 and not dark.has(tile) and _prompt.is_visible_in_tree(),
		"A visibility-mask change updates the outline while the card stays up")
	_submit_board(original_shown)
	await _settle()

func _submit_board(shown: Dictionary) -> void:
	_board.set_combat_state(_board.combat_state, _board.move_tiles, _board.attack_tiles, _board.selected_tile,
		_board.status_label, _board.status_detail, _board.exit_tiles, _board.exit_icon_ids, shown, true)

func _check_suppression() -> void:
	_scene.set("_animation_lock", true)
	_scene.call("_refresh_contextual_combat_tutorial")
	await process_frame
	_expect(not _prompt.is_visible_in_tree() and _floor_layer.get("_umbra_tutorial_contours").is_empty(),
		"Suppressing the card clears the outline without Continue")
	_scene.set("_animation_lock", false)
	_scene.call("_refresh_contextual_combat_tutorial")
	await _settle()
	_expect(_prompt.is_visible_in_tree() and not _floor_layer.get("_umbra_tutorial_contours").is_empty(),
		"Resuming the card restores the outline")
	print("TUT-04 SUPPRESSION: checked cleared and restored outline")

func _check_continue() -> void:
	_prompt.visibility_changed.connect(_check_closed_frame, CONNECT_ONE_SHOT)
	await _click(_prompt.get("_continue_button"))
	await process_frame
	_expect(_checked_close, "Continue closed the card and reached the following frame")

func _check_closed_frame() -> void:
	await process_frame
	_checked_close = true
	var remaining: Array = _floor_layer.get("_umbra_tutorial_contours")
	_expect(not _prompt.is_visible_in_tree() and remaining.is_empty()
		and _floor_layer.get("_umbra_tutorial_dark_floor").is_empty(),
		"Continue removes the outline on the frame after the card closes")
	print("TUT-04 CONTINUE: card_visible=%s outline_parts=%d" % [_prompt.is_visible_in_tree(), remaining.size()])
