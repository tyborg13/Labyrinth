extends RefCounted

## Keep the established shoulder layout when clear. Crowded scenes search exact
## obstacle edges using the intent solver's existing 8 px clearance, considering
## the actual crest as well as every independent text line.
const CLEARANCE: float = 8.0

static func finish(view: Control, unit: Dictionary, lines: Array[Rect2], obstacles: Array[Rect2], viewport: Rect2, preferred: Dictionary) -> Dictionary:
	var anchor: Rect2 = view._unit_health_bar_rect(unit, view._unit_center(unit))
	var own: Dictionary = view._status_plate_layout.resolve(view, unit, anchor)
	var health: Rect2 = own["frame"]
	var crest_obstacles: Array[Rect2]
	for rect: Rect2 in obstacles:
		if not (own["group_rects"] as Array).has(rect): crest_obstacles.append(rect)
	if _clear(view, unit, preferred.get("line_rects", []), obstacles, crest_obstacles, viewport, health): return preferred
	var bounds: Rect2 = view._rects_bounds(lines)
	var xs: Array[float]
	var ys: Array[float]
	_add(xs, clampf(0.0, viewport.position.x - bounds.position.x, viewport.end.x - bounds.end.x))
	_add(ys, clampf(0.0, viewport.position.y - bounds.position.y, viewport.end.y - bounds.end.y))
	for rect: Rect2 in obstacles:
		_add(xs, rect.end.x + CLEARANCE - bounds.position.x)
		_add(xs, rect.position.x - CLEARANCE - bounds.end.x)
		_add(ys, rect.end.y + CLEARANCE - bounds.position.y)
		_add(ys, rect.position.y - CLEARANCE - bounds.end.y)
		# If a leader's intent rises above its bar, the crest follows its top.
		if bool(unit.get("is_leader", false)):
			_add(ys, rect.end.y + CLEARANCE + view.LEADER_CREST_SIZE - view.LEADER_CREST_SEAT - bounds.position.y)
	_add(xs, viewport.position.x - bounds.position.x)
	_add(xs, viewport.end.x - bounds.end.x)
	_add(ys, viewport.position.y - bounds.position.y)
	_add(ys, viewport.end.y - bounds.end.y)
	xs.sort_custom(_nearer)
	ys.sort_custom(_nearer)
	for x: float in xs:
		for y: float in ys:
			var offset := Vector2(x, y)
			var shifted: Array[Rect2] = view._offset_rects(lines, offset)
			if _clear(view, unit, shifted, obstacles, crest_obstacles, viewport, health):
				return {"side": "right", "line_rects": shifted, "bounds": view._rects_bounds(shifted), "offset": offset}
	return preferred

static func _clear(view: Control, unit: Dictionary, lines: Array, obstacles: Array[Rect2], crest_obstacles: Array[Rect2], viewport: Rect2, health: Rect2) -> bool:
	if lines.is_empty(): return false
	for line: Rect2 in lines:
		if not viewport.encloses(line): return false
		for obstacle: Rect2 in obstacles:
			if line.intersects(obstacle, false): return false
	var crest: Rect2 = view._leader_marker_rect(unit, health, view._rects_bounds(lines))
	if crest.has_area():
		for obstacle: Rect2 in crest_obstacles:
			if crest.intersects(obstacle, false): return false
	return true

static func _add(values: Array[float], value: float) -> void:
	if not values.has(value): values.append(value)

static func _nearer(a: float, b: float) -> bool:
	return a < b if is_equal_approx(absf(a), absf(b)) else absf(a) < absf(b)
