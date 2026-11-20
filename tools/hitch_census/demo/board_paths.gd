extends RefCounted
## Models production D-pad steps and the left stick's reachable viewport.
const Nav = preload("res://scripts/controller_navigation.gd")
const CURSOR_INSET: float = 18.0

static func first_buttons(start: Dictionary, free_origin: Vector2, room: bool, candidates: Array[Dictionary], edges: Array) -> Dictionary:
	var queue: Array[Dictionary]
	var first: Dictionary
	if not start.is_empty():
		first[str(start["key"])] = -1
		queue.append(start)
	elif room:
		for edge: Array in edges:
			_enqueue(Nav.first_room_candidate(free_origin, edge[2], candidates), int(edge[1]), first, queue)
	var index: int = 0
	while index < queue.size():
		var current: Dictionary = queue[index]
		index += 1
		var key: String = str(current["key"])
		for edge: Array in edges:
			var button: int = int(first[key])
			if button == -1: button = int(edge[1])
			var next: Dictionary = Nav.best_candidate_in_direction(current["point"], edge[2], candidates, key)
			_enqueue(next, button, first, queue)
	return first

static func _enqueue(candidate: Dictionary, button: int, first: Dictionary, queue: Array[Dictionary]) -> void:
	if candidate.is_empty() or first.has(str(candidate["key"])): return
	first[str(candidate["key"])] = button
	queue.append(candidate)

static func stick_point(point: Vector2, viewport_size: Vector2) -> Vector2:
	var inset := Vector2.ONE * CURSOR_INSET
	return point.clamp(inset, (viewport_size - inset).max(inset))

static func audit(scene: Node, candidates: Array[Dictionary], dpad: Dictionary, viewport_size: Vector2) -> Dictionary:
	var by_key: Dictionary
	for candidate: Dictionary in candidates:
		by_key[str(candidate["key"])] = candidate
	var legal: Array[Vector2i] = scene.call("_controller_board_tiles")
	var dpad_tiles: Array[String]
	var stick_tiles: Array[String]
	var unreachable: Array[String]
	for tile: Vector2i in legal:
		var key: String = scene.call("_controller_tile_key", tile)
		var target: Dictionary = by_key.get(key, {})
		if target.is_empty():
			unreachable.append(key)
			continue
		var point: Vector2 = stick_point(target["point"], viewport_size)
		var stick_candidate: Dictionary = Nav.nearest_candidate_within_radius(point, candidates, 0.0)
		var by_dpad: bool = dpad.has(key)
		var by_stick: bool = str(stick_candidate.get("key")) == key
		if by_dpad: dpad_tiles.append(key)
		if by_stick: stick_tiles.append(key)
		if not by_dpad and not by_stick: unreachable.append(key)
	return {"legal": legal, "dpad": dpad_tiles, "stick": stick_tiles, "unreachable": unreachable}
