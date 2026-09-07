extends RefCounted

## Surface floor commands belong to individual depth-sorted tile CanvasItems.
## Invalidating their owners preserves alpha/depth order without rebuilding the
## unrelated HUD, atmosphere, actors and effects for each preview/progress tick.

const EVENT_KEYS: Array = ["surface_preview_events", "surface_feedback_events"]

static func changed_tiles(previous: Dictionary, current: Dictionary, changes: Dictionary) -> Array[Vector2i]:
	var owners: Dictionary = {}
	for key: String in EVENT_KEYS:
		if changes.has(key) or (key == "surface_feedback_events" and changes.has("surface_feedback_progress")):
			_append_event_tiles(owners, previous.get(key, []) as Array)
			_append_event_tiles(owners, current.get(key, []) as Array)
	if changes.has("surface_preview_arcs"):
		_append_arc_tiles(owners, previous.get("surface_preview_arcs", []) as Array, true)
		_append_arc_tiles(owners, current.get("surface_preview_arcs", []) as Array, true)
	if changes.has("effect") or changes.has("effect_progress"):
		for source: Dictionary in [previous, current]:
			var effect: Dictionary = source.get("effect", {}) as Dictionary
			if str(effect.get("kind", "")) != "chain": continue
			var branches: Array = effect.get("branches", []) as Array
			_append_arc_tiles(owners, [effect] if branches.is_empty() else branches, false)
	var result: Array[Vector2i]
	for tile: Vector2i in owners: result.append(tile)
	return result

static func floor_line_steps(from: Vector2i, to: Vector2i) -> int:
	return maxi(6, int(Vector2(from).distance_to(Vector2(to)) * 12.0))

static func floor_line_depth_tile(from: Vector2i, to: Vector2i, index: int, steps: int) -> Vector2i:
	var point: Vector2 = Vector2(from).lerp(Vector2(to), (float(index) + 0.5) / float(steps))
	return Vector2i(roundi(point.x), roundi(point.y))

static func _append_event_tiles(owners: Dictionary, events: Array) -> void:
	for event_var: Variant in events:
		if typeof(event_var) != TYPE_DICTIONARY: continue
		var event: Dictionary = event_var as Dictionary
		_append_tile(owners, event.get("tile"))
		for tile: Variant in event.get("tiles", []): _append_tile(owners, tile)

static func _append_arc_tiles(owners: Dictionary, arcs: Array, endpoint_fallback: bool) -> void:
	for arc_var: Variant in arcs:
		if typeof(arc_var) != TYPE_DICTIONARY: continue
		var arc: Dictionary = arc_var as Dictionary
		var path: Array = arc.get("path", []) as Array
		if path.is_empty() and endpoint_fallback:
			path = [arc.get("from", Vector2i(-1, -1)), arc.get("to", Vector2i(-1, -1))]
		for edge: int in range(1, path.size()):
			if typeof(path[edge - 1]) != TYPE_VECTOR2I or typeof(path[edge]) != TYPE_VECTOR2I: continue
			var from: Vector2i = path[edge - 1]
			var to: Vector2i = path[edge]
			if from.x < 0 or to.x < 0 or from == to: continue
			var steps: int = floor_line_steps(from, to)
			for index: int in range(steps):
				owners[floor_line_depth_tile(from, to, index, steps)] = true

static func _append_tile(owners: Dictionary, tile: Variant) -> void:
	if typeof(tile) == TYPE_VECTOR2I and (tile as Vector2i).x >= 0:
		owners[tile] = true
