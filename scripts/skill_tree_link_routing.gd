extends RefCounted

# Director-approved gutter elbows: reserve separate 6px rails in native viewport
# pixels. Tier-skipping links use two gutters and a clear vertical channel;
# nodes, ports and skill topology stay owned by SkillTreeView/SkillTreeLibrary.
const Library = preload("res://scripts/skill_tree_library.gd")
const GUTTER_SPACING_PX: float = 6.0
const NODE_CLEARANCE: float = 8.0
const NUMERIC_EPSILON: float = 0.001

var view: Control
var fit_scale: float
var _horizontal_rails: Array[Dictionary]
var _vertical_rails: Array[Dictionary]
var _endpoint_rails: Array[Dictionary]

func _init(next_view: Control, next_scale: float) -> void:
	view = next_view
	fit_scale = maxf(next_scale, NUMERIC_EPSILON)

func gutter_routes() -> Dictionary:
	_horizontal_rails.clear()
	_vertical_rails.clear()
	_endpoint_rails.clear()
	var result: Dictionary = {}
	var edges: Array[Dictionary]
	for target: String in Library.visible_ids():
		for source: String in Library.prerequisites(target):
			edges.append({"source": source, "target": target, "key": source + ">" + target,
				"span": view._node_center(target).y - view._node_center(source).y})
	# Reserve long routes first, then reuse lanes for disjoint local branches.
	edges.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return float(left.span) > float(right.span) if left.span != right.span else str(left.key) < str(right.key)
	)
	for edge: Dictionary in edges:
		var start: Vector2 = view._output_port(edge.source, edge.target)
		var finish: Vector2 = view._input_port(edge.target, edge.source)
		var source_row: float = view._node_center(edge.source).y
		var target_row: float = view._node_center(edge.target).y
		var next_row: float = _next_row(source_row)
		if is_equal_approx(next_row, target_row):
			var y: float = _gutter_lane(source_row, target_row, start.x, finish.x, start.y, finish.y)
			result[edge.key] = view._simplified_points(PackedVector2Array([start, Vector2(start.x, y), Vector2(finish.x, y), finish]))
		else:
			var x: float = _vertical_lane(edge.source, edge.target, start, finish)
			var source_y: float = _gutter_lane(source_row, next_row, start.x, x, start.y)
			var target_y: float = _gutter_lane(_previous_row(target_row), target_row, x, finish.x, NAN, finish.y)
			_vertical_rails.append({"x": x, "low": source_y, "high": target_y})
			result[edge.key] = view._simplified_points(PackedVector2Array([start, Vector2(start.x, source_y), Vector2(x, source_y), Vector2(x, target_y), Vector2(finish.x, target_y), finish]))
	return result

func _gutter_lane(source_row: float, target_row: float, left: float, right: float, source_y: float = NAN, target_y: float = NAN) -> float:
	var low: float = -INF
	var high: float = INF
	for id: String in Library.visible_ids():
		var rect: Rect2 = view._node_visual_rect(id)
		if is_equal_approx(view._node_center(id).y, source_row): low = maxf(low, rect.end.y)
		if is_equal_approx(view._node_center(id).y, target_row): high = minf(high, rect.position.y)
	low += NODE_CLEARANCE
	high -= NODE_CLEARANCE
	var spacing: float = GUTTER_SPACING_PX / fit_scale
	var midpoint: float = (low + high) * 0.5
	var lane: float = midpoint
	var found: bool = false
	for index: int in range(ceili((high - low) / spacing) + 1):
		for sign_value: float in [-1.0, 1.0]:
			var candidate: float = midpoint + float(index) * spacing * sign_value
			if candidate < low or candidate > high: continue
			var clear: bool = true
			if not is_nan(source_y) and not _endpoint_lane_clear(left, source_y, candidate): clear = false
			if not is_nan(target_y) and not _endpoint_lane_clear(right, candidate, target_y): clear = false
			for rail: Dictionary in _horizontal_rails:
				if rail.row == source_row and maxf(minf(left, right), rail.left) <= minf(maxf(left, right), rail.right) and absf(candidate - float(rail.y)) < spacing - NUMERIC_EPSILON:
					clear = false
			if clear:
				lane = candidate
				found = true
				break
		if found: break
	_horizontal_rails.append({"row": source_row, "y": lane, "left": minf(left, right), "right": maxf(left, right)})
	if not is_nan(source_y): _endpoint_rails.append({"x": left, "low": minf(source_y, lane), "high": maxf(source_y, lane)})
	if not is_nan(target_y): _endpoint_rails.append({"x": right, "low": minf(target_y, lane), "high": maxf(target_y, lane)})
	return lane

func _endpoint_lane_clear(x: float, low: float, high: float) -> bool:
	for rails: Array[Dictionary] in [_endpoint_rails, _vertical_rails]:
		for rail: Dictionary in rails:
			if minf(maxf(low, high), rail.high) - maxf(minf(low, high), rail.low) > NUMERIC_EPSILON and absf(x - float(rail.x)) < GUTTER_SPACING_PX / fit_scale - NUMERIC_EPSILON:
				return false
	return true

func _vertical_lane(source: String, target: String, start: Vector2, finish: Vector2) -> float:
	var spacing: float = GUTTER_SPACING_PX / fit_scale
	var preferred: float = (start.x + finish.x) * 0.5
	var candidates: Array[float]
	candidates.append(preferred)
	var low: float = view._row_visual_edge(source, true) + NODE_CLEARANCE
	var high: float = view._row_visual_edge(target, false) - NODE_CLEARANCE
	var obstacles: Array[Rect2]
	for id: String in Library.visible_ids():
		if id in [source, target]: continue
		var rect: Rect2 = view._node_visual_rect(id).grow(NODE_CLEARANCE)
		obstacles.append(rect)
		candidates.append(rect.position.x - NUMERIC_EPSILON)
		candidates.append(rect.end.x + NUMERIC_EPSILON)
	for rail: Dictionary in _vertical_rails:
		candidates.append(float(rail.x) - spacing)
		candidates.append(float(rail.x) + spacing)
	candidates.sort_custom(func(left: float, right: float) -> bool:
		return absf(left - preferred) < absf(right - preferred) if not is_equal_approx(absf(left - preferred), absf(right - preferred)) else left < right
	)
	for x: float in candidates:
		if x < 0.0 or x > view.GRAPH_SIZE.x: continue
		if not _segment_clear(Vector2(x, low), Vector2(x, high), obstacles): continue
		var clear: bool = true
		for rail: Dictionary in _vertical_rails:
			if maxf(low, rail.low) <= minf(high, rail.high) and absf(x - float(rail.x)) < spacing - NUMERIC_EPSILON: clear = false
		if clear: return x
	return preferred

func _next_row(y: float) -> float:
	var result: float = INF
	for id: String in Library.visible_ids():
		var row: float = view._node_center(id).y
		if row > y: result = minf(result, row)
	return result

func _previous_row(y: float) -> float:
	var result: float = -INF
	for id: String in Library.visible_ids():
		var row: float = view._node_center(id).y
		if row < y: result = maxf(result, row)
	return result

func _segment_clear(start: Vector2, finish: Vector2, obstacles: Array[Rect2]) -> bool:
	for rect: Rect2 in obstacles:
		if view._axis_segment_intersects_rect(start, finish, rect.grow(-NUMERIC_EPSILON)): return false
	return true
