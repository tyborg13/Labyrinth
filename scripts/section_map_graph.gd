extends RefCounted
class_name SectionMapGraph

# Coordinates retain the existing four-depth difficulty bands. Screen placement
# and connectivity are authored independently; a coordinate is a persistent id.
const Bosses = preload("res://scripts/dragon_boss_library.gd")
const Elements = preload("res://scripts/element_data.gd")
const VERSION: int = 1
const LAYOUT_REVISION: int = 2
const ROOM_COUNTS: Array[int] = [10, 11, 11, 11, 11, 12]
const FIGHT_COUNTS: Array[int] = [6, 6, 7, 7, 7, 7]
const INVALID: Vector2i = Vector2i(-999, -999)

static func enabled(state: Dictionary) -> bool:
	return int(state.get("section_map_version", 0)) == VERSION

static func key(coord: Vector2i) -> String:
	return "%d,%d" % [coord.x, coord.y]

static func room(state: Dictionary, coord: Vector2i) -> Dictionary:
	return (state.get("rooms", {}) as Dictionary).get(key(coord), {}) as Dictionary

static func active_section(state: Dictionary) -> int:
	return int(room(state, state.get("current_room", Vector2i.ZERO)).get("section_index", 0))

static func section(state: Dictionary, index: int) -> Dictionary:
	var sections: Array = state.get("map_sections", [])
	return sections[index] as Dictionary if index >= 0 and index < sections.size() else {}

static func initialize(state: Dictionary) -> void:
	var seed_value: int = int(state.get("seed", 0))
	var rooms: Dictionary = {}
	var sections: Array[Dictionary] = []
	for index: int in range(6):
		var rng := RandomNumberGenerator.new()
		rng.seed = absi(seed_value * 7919 + index * 104729 + 3491)
		var count: int = ROOM_COUNTS[index]
		var boss_id: String = Bosses.boss_id_for_depth(seed_value, (index + 1) * 4)
		var entry: Vector2i = Vector2i.ZERO if index == 0 else Vector2i(-index * 4, 0)
		var boss: Vector2i = Vector2i((index + 1) * 4, 0)
		var info: Dictionary = {"index": index, "boss_id": boss_id, "title": Bosses.room_name_for_boss(boss_id), "entry": entry, "boss": boss, "room_count": count, "fight_count": FIGHT_COUNTS[index], "scouts": 2, "entered": false}
		sections.append(info)
		rooms[key(entry)] = _node(entry, index, 0, 1, index * 4, "start", "none")
		var previous: Array[Vector2i] = [entry]
		var slots: Dictionary = {}
		var step: int = 1
		var landmark_groups: Dictionary = {}
		var group: int = 0
		var fights_left: int = FIGHT_COUNTS[index] - 1
		while step < count:
			var length: int = mini(3, count - step)
			var width: int = 3 if group == 1 and index < 5 else 2
			var group_fights: int = mini(2, fights_left) if length == 3 else 0
			if index == 1 and group == 1:
				group_fights = 1
			if index == 0 and group == 1:
				group_fights = 1
			fights_left -= group_fights
			var lanes: Array = [0, 2] if width == 2 else [0, 1, 2]
			# Outer branches remain distinct. Short alternating middle branches
			# let the last section vary its route without jumping across lanes.
			if width == 2 and group % 2 == 1:
				lanes = [0, 1] if rng.randi_range(0, 1) == 0 else [1, 2]
			var paths: Array = []
			for branch: int in range(width):
				var types: Array[String] = []
				for offset: int in range(length):
					if offset < group_fights:
						types.append("combat")
					elif step + offset == count - 1:
						types.append("campfire")
					else:
						var services: Array[String] = ["treasure", "scavenger", "event"]
						types.append(services[posmod(index + group + branch + rng.randi_range(0, 2), 3)])
				# Each branch has the same combat burden but a different service/order.
				for offset: int in range(types.size() - 1, 0, -1):
					var swap: int = rng.randi_range(0, offset)
					var held: String = types[offset]
					types[offset] = types[swap]
					types[swap] = held
				if index == 0 and group == 0 and types[0] != "combat":
					var combat_index: int = types.find("combat")
					types[combat_index] = types[0]
					types[0] = "combat"
				var path: Array[Vector2i] = []
				for offset: int in range(length):
					var local_step: int = step + offset
					var depth: int = index * 4 + mini(3, 1 + int((local_step - 1) * 3 / (count - 1)))
					var slot: int = int(slots.get(depth, 0))
					slots[depth] = slot + 1
					var coord: Vector2i = _ring_coord(depth, slot)
					var element: String = Elements.all_elements()[rng.randi_range(0, 4)] if types[offset] == "combat" else "none"
					var node: Dictionary = _node(coord, index, local_step, lanes[branch], depth, types[offset], element)
					if group == 1 and branch == 0 and types[offset] != "combat" and not landmark_groups.has(group):
						landmark_groups[group] = true
						node["map_landmark"] = true
					if group == 2 and branch == width - 1 and types[offset] != "combat" and not landmark_groups.has(group):
						landmark_groups[group] = true
						node["map_landmark"] = true
					rooms[key(coord)] = node
					path.append(coord)
					if offset > 0:
						_link(rooms, path[offset - 1], _coords([coord]))
				paths.append(path)
			var firsts: Array[Vector2i] = []
			var lasts: Array[Vector2i] = []
			for path_value: Array in paths:
				firsts.append(path_value[0])
				lasts.append(path_value[-1])
			if group == 0:
				_link(rooms, entry, firsts)
			else:
				_connect_groups(rooms, previous, firsts, group % 2 == 0)
			previous = lasts
			step += length
			group += 1
		var boss_room: Dictionary = _node(boss, index, count, 1, (index + 1) * 4, "boss", Bosses.element_for_boss(boss_id))
		boss_room["boss_id"] = boss_id
		rooms[key(boss)] = boss_room
		for coord: Vector2i in previous:
			_link(rooms, coord, _coords([boss]))
		if index > 0:
			_link(rooms, Vector2i(index * 4, 0), _coords([entry]))
	state["section_map_version"] = VERSION
	state["section_map_layout_revision"] = LAYOUT_REVISION
	state["map_sections"] = sections
	state["rooms"] = rooms
	var start: Dictionary = rooms[key(Vector2i.ZERO)]
	start["visited"] = true
	start["revealed"] = true
	start["map_outline"] = true
	refresh_knowledge(state)

static func _coords(values: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for value: Vector2i in values:
		result.append(value)
	return result

static func _ring_coord(depth: int, slot: int) -> Vector2i:
	# At most nine ids per band; rotate away from the reserved east-axis boss.
	var perimeter: Array[Vector2i] = []
	for y: int in range(-depth, depth + 1):
		perimeter.append(Vector2i(depth, y))
	for x: int in range(depth - 1, -depth - 1, -1):
		perimeter.append(Vector2i(x, depth))
	for y: int in range(depth - 1, -depth - 1, -1):
		perimeter.append(Vector2i(-depth, y))
	for x: int in range(-depth + 1, depth):
		perimeter.append(Vector2i(x, -depth))
	return perimeter[slot % perimeter.size()]

static func _node(coord: Vector2i, index: int, step: int, lane: int, depth: int, type: String, element: String) -> Dictionary:
	return {"coord": coord, "section_index": index, "map_step": step, "map_lane": lane, "depth": depth, "type": type, "element": element, "connections": [], "npcs": [{"id": "scavenger", "pos": Vector2i(3, 4)}] if type == "scavenger" else [], "merchant_kind": "scavenger" if type == "scavenger" else "", "revealed": false, "map_outline": false, "visited": false, "cleared": type == "start", "sealed": false}

static func _link(rooms: Dictionary, source: Vector2i, destinations: Array[Vector2i]) -> void:
	var directions: Array[Vector2i] = _coords([Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN]) if destinations.size() == 3 else (_coords([Vector2i.UP, Vector2i.DOWN]) if destinations.size() == 2 else _coords([Vector2i.RIGHT]))
	var links: Array[Dictionary] = []
	for index: int in range(destinations.size()):
		links.append({"coord": destinations[index], "door_dir": directions[index], "kind": "outward"})
	(rooms[key(source)] as Dictionary)["connections"] = links

# Keep group boundaries planar: each edge spans at most one lane, every room
# has a continuation, and every generated destination can be reached. Nearby
# splits/merges preserve options without resetting every route at each fork.
static func _connect_groups(rooms: Dictionary, sources: Array[Vector2i], targets: Array[Vector2i], reverse: bool) -> void:
	var candidates: Array[Vector2i]
	for i: int in range(sources.size()):
		for j: int in range(targets.size()):
			var distance: int = absi(int(rooms[key(sources[i])]["map_lane"]) - int(rooms[key(targets[j])]["map_lane"]))
			if distance <= 1: candidates.append(Vector2i(i, j))
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da: int = absi(int(rooms[key(sources[a.x])]["map_lane"]) - int(rooms[key(targets[a.y])]["map_lane"]))
		var db: int = absi(int(rooms[key(sources[b.x])]["map_lane"]) - int(rooms[key(targets[b.y])]["map_lane"]))
		if da != db: return da < db
		return a.x > b.x if reverse else a.x < b.x)
	var chosen: Array[Vector2i]
	for candidate: Vector2i in candidates:
		var crosses: bool = false
		for edge: Vector2i in chosen:
			crosses = crosses or (candidate.x - edge.x) * (candidate.y - edge.y) < 0
		if not crosses: chosen.append(candidate)
	for i: int in range(sources.size()):
		var destinations: Array[Vector2i]
		for j: int in range(targets.size()):
			if chosen.has(Vector2i(i, j)): destinations.append(targets[j])
		_link(rooms, sources[i], destinations)

static func descendants(state: Dictionary, start: Vector2i, max_hops: int = 99) -> Dictionary:
	var result: Dictionary = {}
	var queue: Array[Vector2i] = [start]
	var distances: Array[int] = [0]
	var source_section: int = int(room(state, start).get("section_index", -1))
	while not queue.is_empty():
		var coord: Vector2i = queue.pop_front()
		var hops: int = distances.pop_front()
		if result.has(coord) or hops > max_hops:
			continue
		var node: Dictionary = room(state, coord)
		if node.is_empty() or int(node.get("section_index", -2)) != source_section:
			continue
		result[coord] = hops
		for link: Dictionary in node.get("connections", []):
			queue.append(link.get("coord", INVALID))
			distances.append(hops + 1)
	return result

static func refresh_knowledge(state: Dictionary) -> void:
	if not enabled(state):
		return
	var current: Vector2i = state.get("current_room", Vector2i.ZERO)
	var index: int = active_section(state)
	var info: Dictionary = section(state, index)
	if not bool(info.get("entered", false)):
		info["entered"] = true
		record_event(state, "section_entered", {"section": index, "boss_id": info.get("boss_id", ""), "scouts": info.get("scouts", 2)})
	var discoveries: Array[String] = []
	var nearby: Dictionary = descendants(state, current, 3)
	for coord: Vector2i in nearby:
		var node: Dictionary = room(state, coord)
		node["map_outline"] = true
		if int(nearby[coord]) <= 2 and not bool(node.get("revealed", false)):
			node["revealed"] = true
			discoveries.append(key(coord))
	for node: Dictionary in (state.get("rooms", {}) as Dictionary).values():
		if int(node.get("section_index", -1)) == index and (bool(node.get("map_landmark", false)) or str(node.get("type", "")) == "boss"):
			if not bool(node.get("revealed", false)):
				discoveries.append(key(node.get("coord", INVALID)))
			node["revealed"] = true
			node["map_outline"] = true
	# Crossing a defeated boss opens only the next threshold, never its rooms.
	var current_node: Dictionary = room(state, current)
	if str(current_node.get("type", "")) == "boss" and bool(current_node.get("cleared", false)):
		for link: Dictionary in current_node.get("connections", []):
			room(state, link.get("coord", INVALID))["revealed"] = true
	if not discoveries.is_empty():
		record_event(state, "route_revealed", {"source": "proximity", "section": index, "rooms": discoveries})

static func scout_options(state: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i]
	if not enabled(state) or int(section(state, active_section(state)).get("scouts", 0)) <= 0:
		return result
	if str(state.get("mode", "")) not in ["room", "combat", "pre_battle"]:
		return result
	for coord: Vector2i in descendants(state, state.get("current_room", Vector2i.ZERO)):
		var node: Dictionary = room(state, coord)
		var visible: bool = bool(node.get("map_outline", false)) or (bool(node.get("recovery_marker", false)) and int(node.get("recovery_amount", 0)) > 0)
		if visible and not bool(node.get("revealed", false)) and not bool(node.get("sealed", false)):
			result.append(coord)
	return result

static func scout_targets(state: Dictionary, target: Vector2i) -> Array[Vector2i]:
	return _coords([target]) if scout_options(state).has(target) else _coords([])

static func scout(state: Dictionary, target: Vector2i) -> Dictionary:
	var targets: Array[Vector2i] = scout_targets(state, target)
	if targets.is_empty():
		return state.duplicate(true)
	var next: Dictionary = state.duplicate(true)
	var info: Dictionary = section(next, active_section(next))
	info["scouts"] = int(info.get("scouts", 2)) - 1
	var node: Dictionary = room(next, target)
	node["revealed"] = true
	node["map_outline"] = true
	var outlined: Array[Vector2i]
	for link: Dictionary in node.get("connections", []):
		var neighbor: Vector2i = link.get("coord", INVALID)
		var destination: Dictionary = room(next, neighbor)
		if int(destination.get("section_index", -1)) != active_section(next): continue
		if not bool(destination.get("map_outline", false)): outlined.append(neighbor)
		destination["map_outline"] = true
	# Keep branch as a legacy payload alias; scope/target distinguish direct
	# room scouting from the older multi-room branch reveal in saved logs.
	record_event(next, "map_scout_used", {"section": active_section(next), "scope": "room", "target": target, "branch": target, "rooms": targets, "outlined_rooms": outlined, "remaining": info["scouts"]})
	return next

static func record_choice(state: Dictionary, destination: Vector2i) -> void:
	if not enabled(state):
		return
	var known: Array[String] = []
	var known_metadata: Array[Dictionary] = []
	for node: Dictionary in (state.get("rooms", {}) as Dictionary).values():
		if int(node.get("section_index", -1)) == active_section(state) and bool(node.get("revealed", false)):
			known.append(key(node.get("coord", INVALID)))
			known_metadata.append({"room": node.get("coord", INVALID), "type": node.get("type", ""), "element": node.get("element", ""), "step": node.get("map_step", 0), "landmark": node.get("map_landmark", false)})
	record_event(state, "route_choice_committed", {"section": active_section(state), "origin": state.get("current_room", Vector2i.ZERO), "destination": destination, "known_rooms": known, "known_room_metadata": known_metadata, "scouts": section(state, active_section(state)).get("scouts", 0)})

static func record_event(state: Dictionary, event_type: String, payload: Dictionary) -> void:
	var events: Array = state.get("map_events", [])
	var revision: int = int(state.get("map_event_revision", 0)) + 1
	events.append({"revision": revision, "type": event_type, "payload": payload})
	state["map_events"] = events
	state["map_event_revision"] = revision
