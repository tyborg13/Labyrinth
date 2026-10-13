extends RefCounted
## Route planning for inspection only; room resolution still uses live actions.

const Graph = preload("res://scripts/section_map_graph.gd")

static func reaches_choice(state: Dictionary, origin: Vector2i, target_depth: int) -> bool:
	if not Graph.enabled(state):
		return false
	var pending: Array[Vector2i]
	pending.append(origin)
	var seen: Dictionary = {}
	while not pending.is_empty():
		var coord: Vector2i = pending.pop_back()
		if seen.has(coord):
			continue
		seen[coord] = true
		var room: Dictionary = Graph.room(state, coord)
		var depth: int = int(room.get("depth", 0))
		if room.is_empty() or depth > target_depth or bool(room.get("sealed", false)):
			continue
		var destinations: Array[Vector2i]
		for connection: Dictionary in room.get("connections", []):
			var destination: Vector2i = connection.get("coord", Graph.INVALID)
			var next_room: Dictionary = Graph.room(state, destination)
			if not next_room.is_empty() and int(next_room.get("depth", 0)) >= depth and not bool(next_room.get("sealed", false)) and not destinations.has(destination):
				destinations.append(destination)
		var required_moves: int = 1 if str(room.get("type", "")) == "boss" else 2
		if depth == target_depth and destinations.size() >= required_moves:
			return true
		pending.append_array(destinations)
	return false
