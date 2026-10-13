extends RefCounted
class_name SectionMapGraph

# Coordinates retain the existing four-depth difficulty bands. Screen placement
# and connectivity are authored independently; a coordinate is a persistent id.
const DepthRules = preload("res://scripts/depth_rules.gd")
const Bosses = preload("res://scripts/dragon_boss_library.gd")
const Elements = preload("res://scripts/element_data.gd")
const VERSION: int = 1
const LAYOUT_REVISION: int = 4
const Guardians = preload("res://scripts/guardian_library.gd")
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

# Search limits affect implementation work only; accepted sections always satisfy
# the same contract. The old generator is retained solely for compatibility proof.
const WALK_COUNT: int = 5
const TOPOLOGY_ATTEMPTS: int = 50
const SECTION_ATTEMPTS: int = 50
const TYPE_REPAIR_LIMIT: int = 12000
const NODE_SEED_RUN_MULTIPLIER: int = 15485863
const NODE_SEED_SECTION_MULTIPLIER: int = 32452843
const NODE_SEED_STEP_MULTIPLIER: int = 49979687
const NODE_SEED_LANE_MULTIPLIER: int = 67867967
const TYPE_WEIGHTS: Dictionary = {"combat": 46, "mystery": 22, "guardian": 10, "scavenger": 10, "graftwright": 6, "event": 6}
const MYSTERY_WEIGHTS: Dictionary = {"event": 70, "combat": 20, "treasure": 5, "scavenger": 5}
# Three opening combats are the only legal threshold fan-out: combat may
# repeat only with three children, and the physical mapping has three doors.
const OPENING_CHILD_COUNT: int = 3

static func modern(state: Dictionary) -> bool:
	# The panel's compact snapshot retains section metadata but historically
	# omits the top-level revision. An explicit older revision always wins.
	var revision: int = int(state.get("section_map_layout_revision", section(state, 0).get("lane_count", 0)))
	return enabled(state) and revision >= 4

static func full_visibility(state: Dictionary, index: int) -> bool:
	return modern(state) and index < 5

static func display_type(node: Dictionary) -> String:
	if str(node.get("type", "")) == "mystery":
		return str(node.get("mystery_type", "mystery")) if bool(node.get("scouted", false)) else "mystery"
	return str(node.get("type", ""))

static func initialize(state: Dictionary) -> void:
	var seed_value: int = int(state.get("seed", 0))
	var rooms: Dictionary = {}
	var sections: Array[Dictionary] = []
	for index: int in range(6):
		var rng := RandomNumberGenerator.new()
		rng.seed = absi(seed_value * 7919 + index * 104729 + 3491)
		var count: int = ROOM_COUNTS[index]
		var boss_id: String = Bosses.boss_id_for_depth(seed_value, (index + 1) * 4)
		var layout: Dictionary = {}
		for attempt: int in range(SECTION_ATTEMPTS):
			layout = _walk_layout(rng, count)
			_prepare_types(layout, seed_value, index, count)
			var repair: Dictionary = {"remaining": TYPE_REPAIR_LIMIT}
			if _repair_types(layout, rng, count, FIGHT_COUNTS[index] - 1, 0, repair, state): break
			layout = {}
		if layout.is_empty():
			layout = _fallback_layout(count, FIGHT_COUNTS[index] - 1)
		var entry: Vector2i = Vector2i.ZERO if index == 0 else Vector2i(-index * 4, 0)
		var boss := Vector2i((index + 1) * 4, 0)
		var info: Dictionary = {"index": index, "boss_id": boss_id, "title": Bosses.room_name_for_boss(boss_id), "entry": entry, "boss": boss, "room_count": count, "fight_count": FIGHT_COUNTS[index], "scouts": 2, "entered": false, "lane_count": 4, "walks": layout["walks"]}
		sections.append(info)
		rooms[key(entry)] = _node(entry, index, 0, 1, index * 4, "start", "none")
		rooms[key(entry)]["map_lane"] = 1.5
		var bands: Dictionary = _depth_bands(layout["rows"], index, count)
		info["depth_bands"] = bands
		var slots: Dictionary = {}
		var ids: Dictionary = {}
		var guardians: Array[Vector2i] = []
		for cell: Vector2i in layout["order"]:
			var depth: int = index * 4 + int(bands[cell.x])
			var slot: int = int(slots.get(depth, 0))
			assert(slot < 8 * depth, "Section map depth ring capacity exceeded")
			slots[depth] = slot + 1
			var coord: Vector2i = _ring_coord(depth, slot)
			ids[cell] = coord
			var data: Dictionary = layout["nodes"][cell]
			var type: String = data["type"]
			var node: Dictionary = _node(coord, index, cell.x, cell.y, depth, type, "none")
			_apply_type_fields(node, type, data.get("combat_element", "fire"))
			if type == "mystery":
				node["mystery_type"] = data["mystery_type"]
				node["mystery_element"] = data["combat_element"]
			if type == "guardian":
				var guardian: Dictionary = Guardians.for_boss(boss_id)
				node.merge({"element": guardian["element"], "boss_id": boss_id, "guardian_id": guardian["id"], "guardian_relic": guardian["relic"], "map_landmark": true}, true)
				guardians.append(coord)
			if index == 5 and cell.x in [ceili(count / 2.0), count - 1]: node["map_landmark"] = true
			rooms[key(coord)] = node
		info["guardians"] = guardians
		info["guardian"] = guardians[0]
		var firsts: Array[Vector2i] = []
		for lane: int in layout["rows"][1]: firsts.append(ids[Vector2i(1, lane)])
		_link(rooms, entry, firsts)
		for cell: Vector2i in layout["order"]:
			var destinations: Array[Vector2i] = []
			for target: Vector2i in layout["children"].get(cell, []): destinations.append(ids[target])
			if cell.x == count - 1: destinations.append(boss)
			_link(rooms, ids[cell], destinations)
		var boss_room: Dictionary = _node(boss, index, count, 1, (index + 1) * 4, "boss", Bosses.element_for_boss(boss_id))
		boss_room["map_lane"] = 1.5
		boss_room["boss_id"] = boss_id
		rooms[key(boss)] = boss_room
		if index > 0: _link(rooms, Vector2i(index * 4, 0), _coords([entry]))
	state["section_map_version"] = VERSION
	state["section_map_layout_revision"] = LAYOUT_REVISION
	state["map_sections"] = sections
	state["rooms"] = rooms
	rooms[key(Vector2i.ZERO)].merge({"visited": true, "revealed": true, "map_outline": true}, true)
	refresh_knowledge(state)

static func _weighted_roll(rng: RandomNumberGenerator, weights: Dictionary) -> String:
	var total: int = 0
	for weight: int in weights.values(): total += weight
	var roll: int = rng.randi_range(1, total)
	for type: String in weights:
		roll -= int(weights[type])
		if roll <= 0: return type
	return str(weights.keys()[0])

static func _walk_layout(rng: RandomNumberGenerator, count: int) -> Dictionary:
	for attempt: int in range(TOPOLOGY_ATTEMPTS):
		var walks: Array = []
		var edges: Dictionary = {}
		for walk_index: int in range(WALK_COUNT):
			var lane: int = rng.randi_range(0, 3)
			if walk_index == 1:
				var alternatives: Array[int] = []
				for candidate: int in range(4):
					if candidate != int(walks[0][0]): alternatives.append(candidate)
				lane = alternatives[rng.randi_range(0, alternatives.size() - 1)]
			var walk: Array[int] = []
			walk.assign([lane])
			for step: int in range(1, count - 1):
				var moves: Array[int] = _walk_moves(lane, _coords(edges.get(step, [])))
				var next_lane: int = lane if moves.is_empty() else moves[rng.randi_range(0, moves.size() - 1)]
				if not edges.has(step): edges[step] = []
				var move := Vector2i(lane, next_lane)
				if not edges[step].has(move): edges[step].append(move)
				walk.append(next_lane)
				lane = next_lane
			walks.append(walk)
		var layout: Dictionary = _layout_from_walks(walks, count)
		var valid: bool = layout["rows"][1].size() == OPENING_CHILD_COUNT
		for row: Array in layout["rows"].values(): valid = valid and row.size() >= 2
		# Fixed rows cannot be repaired by changing their types. Reject a
		# topology that forks into them before spending the type-search budget.
		for children: Array in layout["children"].values():
			if children.size() >= 2 and int(children[0].x) in [ceili(count / 2.0), count - 1]: valid = false
		if valid and _physical_doors_legal(layout): return layout
	return _layout_from_walks(_fallback_walks(count), count)

static func _walk_moves(lane: int, edges: Array[Vector2i]) -> Array[int]:
	var moves: Array[int] = []
	# Roll uniformly among the three deltas, then clamp. At an outer lane,
	# two different deltas stay in that lane; do not deduplicate those rolls.
	for delta: int in range(-1, 2):
		var target: int = clampi(lane + delta, 0, 3)
		var crosses: bool = false
		for edge: Vector2i in edges: crosses = crosses or (lane - edge.x) * (target - edge.y) < 0
		if not crosses: moves.append(target)
	return moves

static func _door_directions(count: int) -> Array[Vector2i]:
	return _coords([Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN]) if count == 3 else (_coords([Vector2i.UP, Vector2i.DOWN]) if count == 2 else _coords([Vector2i.RIGHT]))

static func _physical_doors_legal(layout: Dictionary) -> bool:
	# A branch's physical door must not occupy its destination's incoming
	# threshold. Preserve the established direction/order mapping exactly.
	var firsts: Array = layout["rows"][1]
	var first_directions: Array[Vector2i] = _door_directions(firsts.size())
	for offset: int in range(firsts.size()):
		var cell := Vector2i(1, firsts[offset])
		if _door_directions(layout["children"].get(cell, []).size()).has(-first_directions[offset]): return false
	for source: Vector2i in layout["children"]:
		var children: Array = layout["children"][source]
		var directions: Array[Vector2i] = _door_directions(children.size())
		for offset: int in range(children.size()):
			var target: Vector2i = children[offset]
			if _door_directions(layout["children"].get(target, []).size()).has(-directions[offset]): return false
	return true

static func _layout_from_walks(walks: Array, count: int) -> Dictionary:
	var rows: Dictionary = {}
	var children: Dictionary = {}
	var parents: Dictionary = {}
	for walk: Array in walks:
		for step: int in range(1, count):
			var cell := Vector2i(step, walk[step - 1])
			if not rows.has(step): rows[step] = []
			if not rows[step].has(cell.y): rows[step].append(cell.y)
			if step == count - 1: continue
			var target := Vector2i(step + 1, walk[step])
			if not children.has(cell): children[cell] = []
			if not parents.has(target): parents[target] = []
			if not children[cell].has(target): children[cell].append(target)
			if not parents[target].has(cell): parents[target].append(cell)
	var order: Array[Vector2i] = []
	for step: int in range(1, count):
		rows[step].sort()
		for lane: int in rows[step]: order.append(Vector2i(step, lane))
	for targets: Array in children.values(): targets.sort()
	return {"rows": rows, "children": children, "parents": parents, "order": order, "walks": walks, "nodes": {}}

static func _prepare_types(layout: Dictionary, seed_value: int, index: int, count: int) -> void:
	for cell: Vector2i in layout["order"]:
		var rng := RandomNumberGenerator.new()
		rng.seed = absi(seed_value * NODE_SEED_RUN_MULTIPLIER + index * NODE_SEED_SECTION_MULTIPLIER + cell.x * NODE_SEED_STEP_MULTIPLIER + cell.y * NODE_SEED_LANE_MULTIPLIER)
		var type: String = "combat" if cell.x == 1 else ("campfire" if cell.x == count - 1 else ("treasure" if cell.x == ceili(count / 2.0) else ""))
		layout["nodes"][cell] = {"type": type, "fixed": not type.is_empty(), "mystery_type": _weighted_roll(rng, MYSTERY_WEIGHTS), "combat_element": Elements.all_elements()[rng.randi_range(0, 4)]}

# Weighted first rolls, then weighted re-rolls of offending assignments. Prefix
# bounds summarize EVERY incoming route, including paths created by merges.
static func _repair_types(layout: Dictionary, rng: RandomNumberGenerator, count: int, fights: int, position: int, budget: Dictionary, depth_state: Dictionary = {}) -> bool:
	if int(budget["remaining"]) <= 0: return false
	if position == layout["order"].size(): return _complete_types_legal(layout, count, fights)
	var cell: Vector2i = layout["order"][position]
	var node: Dictionary = layout["nodes"][cell]
	var candidates: Array[String] = []
	if bool(node["fixed"]):
		candidates.append(node["type"])
	else:
		var weights: Dictionary = TYPE_WEIGHTS.duplicate()
		weights["guardian"] = DepthRules.guardian_weight(depth_state, int(weights["guardian"]))
		while not weights.is_empty():
			var type: String = _weighted_roll(rng, weights)
			candidates.append(type)
			weights.erase(type)
	for type: String in candidates:
		budget["remaining"] = int(budget["remaining"]) - 1
		node["type"] = type
		_prefix_bounds(layout, cell)
		if _prefix_type_legal(layout, cell, count, fights) and _repair_types(layout, rng, count, fights, position + 1, budget, depth_state): return true
		if int(budget["remaining"]) <= 0: break
	if not bool(node["fixed"]): node["type"] = ""
	return false

static func _is_fight(node: Dictionary) -> bool:
	return str(node["type"]) in ["combat", "guardian"] or (str(node["type"]) == "mystery" and str(node["mystery_type"]) == "combat")

static func _is_service(node: Dictionary) -> bool:
	return str(node["type"]) in ["scavenger", "graftwright", "event"] or (str(node["type"]) == "mystery" and str(node["mystery_type"]) != "combat")

static func _prefix_bounds(layout: Dictionary, cell: Vector2i) -> void:
	var node: Dictionary = layout["nodes"][cell]
	for metric: String in ["fights", "guardians", "services"]:
		var low: int = 999
		var high: int = 0
		var parents: Array = layout["parents"].get(cell, [])
		for parent: Vector2i in parents:
			low = mini(low, int(layout["nodes"][parent]["min_" + metric]))
			high = maxi(high, int(layout["nodes"][parent]["max_" + metric]))
		if parents.is_empty(): low = 0
		var increment: int = int(_is_fight(node)) if metric == "fights" else (int(str(node["type"]) == "guardian") if metric == "guardians" else int(_is_service(node)))
		node["min_" + metric] = low + increment
		node["max_" + metric] = high + increment

static func _prefix_type_legal(layout: Dictionary, cell: Vector2i, count: int, fights: int) -> bool:
	var node: Dictionary = layout["nodes"][cell]
	var type: String = node["type"]
	if type == "guardian" and (cell.x < 3 or cell.x > count - 3): return false
	if type == "scavenger" and cell.x < 3: return false
	if type == "graftwright" and int(node["min_fights"]) < 3: return false
	if int(node["max_guardians"]) > 1 or int(node["max_fights"]) > fights + 1: return false
	var remaining_fights: int = 0
	for step: int in range(cell.x + 1, count - 1):
		if step != ceili(count / 2.0): remaining_fights += 1
	if int(node["min_fights"]) + remaining_fights < fights - 1: return false
	for parent: Vector2i in layout["parents"].get(cell, []):
		if type in ["guardian", "scavenger", "graftwright", "campfire", "treasure"] and str(layout["nodes"][parent]["type"]) == type: return false
		var siblings: Array = layout["children"][parent]
		if siblings.size() < 2: continue
		for sibling: Vector2i in siblings:
			if sibling == cell or sibling.y > cell.y: continue
			if str(layout["nodes"][sibling]["type"]) == type and not (type == "combat" and siblings.size() == 3): return false
	return true

static func _complete_types_legal(layout: Dictionary, count: int, fights: int) -> bool:
	var guardians: int = 0
	var scavengers: int = 0
	var bypass: bool = false
	for cell: Vector2i in layout["order"]:
		var node: Dictionary = layout["nodes"][cell]
		guardians += int(str(node["type"]) == "guardian")
		scavengers += int(str(node["type"]) == "scavenger")
		if cell.x != count - 1: continue
		if int(node["min_fights"]) < fights - 1 or int(node["max_fights"]) > fights + 1 or int(node["min_services"]) < 1 or int(node["max_guardians"]) > 1: return false
		bypass = bypass or int(node["min_guardians"]) == 0
	return guardians >= 2 and scavengers >= 1 and bypass

static func _fallback_walks(count: int) -> Array:
	# Alternating split/merge diamonds keep all four lanes usable without
	# putting consecutive forks across an incoming physical threshold.
	var walks: Array = []
	for walk_index: int in range(WALK_COUNT):
		var walk: Array[int] = []
		for step: int in range(1, count):
			var lane: int = 0 if walk_index in [0, 4] else (3 if walk_index == 1 else 1)
			if walk_index == 3 and step % 2 == 0 and step not in [ceili(count / 2.0), count - 1]: lane = 2
			walk.append(lane)
		walks.append(walk)
	return walks

static func _straight_fallback_walks(count: int) -> Array:
	var walks: Array = []
	for lane: int in [0, 1, 3, 0, 3]:
		var walk: Array[int] = []
		for step: int in range(count - 1): walk.append(lane)
		walks.append(walk)
	return walks

static func _fallback_layout(count: int, fights: int) -> Dictionary:
	var layout: Dictionary = _layout_from_walks(_straight_fallback_walks(count), count)
	_prepare_types(layout, 0, 0, count)
	var fight_steps: Array[int] = []
	fight_steps.assign([1, 2, 3])
	for step: int in range(5, count - 1):
		if step != ceili(count / 2.0) and fight_steps.size() < fights: fight_steps.append(step)
	for cell: Vector2i in layout["order"]:
		var node: Dictionary = layout["nodes"][cell]
		if not bool(node["fixed"]):
			node["type"] = "combat" if fight_steps.has(cell.x) else "event"
			if cell.x == 3 and cell.y < 3: node["type"] = "guardian"
			if cell.x == 4: node["type"] = "scavenger"
		_prefix_bounds(layout, cell)
		assert(_prefix_type_legal(layout, cell, count, fights))
	assert(_complete_types_legal(layout, count, fights))
	return layout

static func _depth_bands(rows: Dictionary, index: int, count: int) -> Dictionary:
	var result: Dictionary = {}
	var sizes: Dictionary = {1: 0, 2: 0, 3: 0}
	var base: int = (count - 1) / 3
	var remainder: int = (count - 1) % 3
	var first_end: int = base
	var second_end: int = base * 2 + int(remainder == 2)
	for step: int in range(1, count):
		var band: int = 1 if step <= first_end else (2 if step <= second_end else 3)
		result[step] = band
		sizes[band] += rows[step].size()
	for band: int in range(1, 4):
		var capacity: int = 8 * (index * 4 + band)
		while int(sizes[band]) > capacity:
			assert(band < 3, "Final depth ring overflow")
			var last: int = 0
			for step: int in result:
				if int(result[step]) == band: last = maxi(last, step)
			result[last] = band + 1
			sizes[band] -= rows[last].size()
			sizes[band + 1] += rows[last].size()
	return result

static func _apply_type_fields(node: Dictionary, type: String, combat_element: String) -> void:
	node["type"] = type
	node["element"] = combat_element if type == "combat" else "none"
	node["npcs"] = [{"id": "scavenger", "pos": Vector2i(3, 4)}] if type == "scavenger" else []
	node["merchant_kind"] = "scavenger" if type == "scavenger" else ""

static func resolve_mystery(state: Dictionary, node: Dictionary) -> void:
	if not modern(state) or str(node.get("type", "")) != "mystery": return
	var type: String = str(node["mystery_type"])
	_apply_type_fields(node, type, str(node.get("mystery_element", "fire")))
	node["was_mystery"] = true
	record_event(state, "mystery_resolved", {"room": node["coord"], "type": type})

static func _initialize_revision_3(state: Dictionary) -> void:
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
		var previous: Array[Vector2i] = []
		previous.assign([entry])
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
						var services: Array[String] = []
						services.assign(["treasure", "scavenger", "event"])
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
				# Every path through an earlier group has the same fight budget.
				# Gate using that minimum plus this branch's preceding combats,
				# never map depth (service order is shuffled).
				var fights_before: int = FIGHT_COUNTS[index] - 1 - fights_left - group_fights
				for previous_section: int in range(index): fights_before += FIGHT_COUNTS[previous_section]
				for offset: int in range(types.size()):
					if types[offset] == "combat":
						fights_before += 1
					elif types[offset] in ["treasure", "scavenger", "event"] and fights_before >= 3:
						if posmod(seed_value * 13 + index * 37 + group * 19 + branch * 7 + offset * 11, 5) == 0:
							types[offset] = "graftwright"
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
			if group == 1:
				var chosen_path: Array = paths[posmod(seed_value + index, paths.size())]
				for guardian_coord: Vector2i in chosen_path:
					var guardian_room: Dictionary = rooms[key(guardian_coord)]
					if str(guardian_room["type"]) != "combat": continue
					var guardian: Dictionary = Guardians.for_boss(boss_id)
					guardian_room["type"] = "guardian"
					guardian_room["element"] = guardian["element"]
					guardian_room["boss_id"] = boss_id
					guardian_room["guardian_id"] = guardian["id"]
					guardian_room["guardian_relic"] = guardian["relic"]
					guardian_room["map_landmark"] = true
					info["guardian"] = guardian_coord
					break
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
	state["section_map_layout_revision"] = 3
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
	# Allocate unique ids across the full square perimeter of a depth band.
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
	var directions: Array[Vector2i] = _door_directions(destinations.size())
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
	var queue: Array[Vector2i] = []
	queue.assign([start])
	var distances: Array[int] = []
	distances.assign([0])
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
	if full_visibility(state, index):
		for node: Dictionary in (state.get("rooms", {}) as Dictionary).values():
			if int(node.get("section_index", -1)) != index: continue
			if not bool(node.get("revealed", false)): discoveries.append(key(node["coord"]))
			node["revealed"] = true
			node["map_outline"] = true
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
		if full_visibility(state, active_section(state)):
			if str(node.get("type", "")) == "mystery" and not bool(node.get("scouted", false)) and not bool(node.get("visited", false)) and not bool(node.get("sealed", false)):
				result.append(coord)
			continue
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
	var mystery: bool = modern(next) and str(node.get("type", "")) == "mystery"
	if mystery: node["scouted"] = true
	var outlined: Array[Vector2i]
	for link: Dictionary in node.get("connections", []):
		var neighbor: Vector2i = link.get("coord", INVALID)
		var destination: Dictionary = room(next, neighbor)
		if int(destination.get("section_index", -1)) != active_section(next): continue
		if not bool(destination.get("map_outline", false)): outlined.append(neighbor)
		destination["map_outline"] = true
	# Keep branch as a legacy payload alias; scope/target distinguish direct
	# room scouting from the older multi-room branch reveal in saved logs.
	record_event(next, "map_scout_used", {"section": active_section(next), "scope": "mystery" if mystery else "room", "target": target, "branch": target, "rooms": targets, "outlined_rooms": outlined, "remaining": info["scouts"]})
	return next

static func record_choice(state: Dictionary, destination: Vector2i) -> void:
	if not enabled(state):
		return
	var known: Array[String] = []
	var known_metadata: Array[Dictionary] = []
	for node: Dictionary in (state.get("rooms", {}) as Dictionary).values():
		if int(node.get("section_index", -1)) == active_section(state) and bool(node.get("revealed", false)):
			known.append(key(node.get("coord", INVALID)))
			known_metadata.append({"room": node.get("coord", INVALID), "type": display_type(node), "element": node.get("mystery_element", "none") if display_type(node) == "combat" and str(node.get("type", "")) == "mystery" else node.get("element", ""), "step": node.get("map_step", 0), "landmark": node.get("map_landmark", false)})
	record_event(state, "route_choice_committed", {"section": active_section(state), "origin": state.get("current_room", Vector2i.ZERO), "destination": destination, "known_rooms": known, "known_room_metadata": known_metadata, "scouts": section(state, active_section(state)).get("scouts", 0)})

static func record_event(state: Dictionary, event_type: String, payload: Dictionary) -> void:
	var events: Array = state.get("map_events", [])
	var revision: int = int(state.get("map_event_revision", 0)) + 1
	events.append({"revision": revision, "type": event_type, "payload": payload})
	state["map_events"] = events
	state["map_event_revision"] = revision
