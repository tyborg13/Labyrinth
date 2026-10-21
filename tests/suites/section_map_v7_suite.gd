extends RefCounted

# map-03: revision 7 section maps (branching web, lane-facing doors, sideways scrolling).
const Graph = preload("res://scripts/section_map_graph.gd")
const MapPanel = preload("res://scripts/section_map_panel.gd")
const NodeButton = preload("res://scripts/section_map_node.gd")
const SEEDS: int = 40
const FIELD_SIZE: Vector2 = Vector2(1864, 823)
const GAP_TOLERANCE: float = 0.001

static func run(expect: Callable) -> void:
	test_new_runs_use_revision_7(expect)
	test_saved_revisions_regenerate(expect)
	var checked: int = 0
	for seed_value: int in range(1, SEEDS + 1):
		var state: Dictionary = {"seed": seed_value, "current_room": Vector2i.ZERO, "mode": "room"}
		Graph.initialize(state)
		for index: int in range(6):
			test_section_rules(state, index, expect)
			test_doors(state, index, expect)
			test_layout(state, index, expect)
			checked += 1
	print("Section map revision 7: %d sections checked" % checked)

static func test_new_runs_use_revision_7(expect: Callable) -> void:
	var state: Dictionary = {"seed": 83, "current_room": Vector2i.ZERO, "mode": "room"}
	Graph.initialize(state)
	expect.call(int(state["section_map_layout_revision"]) == 7, "New runs use layout revision 7")
	for index: int in range(6):
		var info: Dictionary = Graph.section(state, index)
		expect.call(int(info["lane_count"]) == Graph.V7_LANE_COUNT and bool(info.get("scroll", false)), "Revision 7 sections have seven lanes and scroll")

static func test_saved_revisions_regenerate(expect: Callable) -> void:
	# Saved runs keep their revision; regenerating one is byte-identical.
	for revision: int in [5, 6]:
		var first: Dictionary = {"seed": 83, "current_room": Vector2i.ZERO, "mode": "room", "section_map_layout_revision": revision}
		Graph.initialize(first)
		var second: Dictionary = {"seed": 83, "current_room": Vector2i.ZERO, "mode": "room", "section_map_layout_revision": revision}
		Graph.initialize(second)
		expect.call(int(first["section_map_layout_revision"]) == revision and var_to_str(first["rooms"]) == var_to_str(second["rooms"]), "Revision %d regenerates byte-identically" % revision)
		expect.call(not bool(Graph.section(first, 0).get("scroll", false)), "Revision %d keeps the fixed-width map" % revision)

static func _section_rooms(state: Dictionary, index: int) -> Array:
	var rooms: Array = []
	for node: Dictionary in state["rooms"].values():
		if int(node["section_index"]) == index and str(node["type"]) not in ["start", "boss"]: rooms.append(node)
	return rooms

static func test_section_rules(state: Dictionary, index: int, expect: Callable) -> void:
	var info: Dictionary = Graph.section(state, index)
	var count: int = int(info["room_count"])
	var gather: Array[int] = []
	gather.assign([ceili(count / 2.0), count - 1])
	var rows: Dictionary = {}
	for node: Dictionary in _section_rooms(state, index):
		var step: int = int(node["map_step"])
		var lane: int = int(node["map_lane"])
		expect.call(lane >= 0 and lane < Graph.V7_LANE_COUNT, "Rooms sit in the seven lanes")
		if not rows.has(step): rows[step] = []
		rows[step].append(node)
		var exits: Array = node["connections"]
		if step == count - 1:
			expect.call(exits.size() == 1 and Graph.room(state, exits[0]["coord"])["type"] == "boss", "The Ember Hearth row leads to the boss")
			continue
		expect.call(exits.size() >= 1 and exits.size() <= 3, "Every room has one to three exits")
		if step + 1 in gather: expect.call(exits.size() == 1, "Rooms that gather into the Relic and Ember Hearth rows have one door")
		for link: Dictionary in exits:
			var target: Dictionary = Graph.room(state, link["coord"])
			expect.call(int(target["map_step"]) == step + 1 and absi(int(target["map_lane"]) - lane) <= 1, "Exits lead one column on, at most one lane away")
	for step: int in rows:
		var width: int = (rows[step] as Array).size()
		expect.call(width >= 2 and width <= (Graph.V7_FORCED_MAX_WIDTH if step in gather else Graph.V7_MAX_WIDTH), "Row widths stay readable (step %d: %d)" % [step, width])
	# Non-crossing: rooms in lane order lead to non-decreasing lanes.
	for step: int in rows:
		var ordered: Array = rows[step]
		ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["map_lane"]) < int(b["map_lane"]))
		var highest: int = -1
		for node: Dictionary in ordered:
			var lanes: Array[int] = []
			for link: Dictionary in node["connections"]: lanes.append(int(Graph.room(state, link["coord"])["map_lane"]))
			lanes.sort()
			if step < count - 1:
				expect.call(lanes[0] >= highest, "Trails never cross")
				highest = lanes[-1]
	# Routes: at least three real choices; gaps without one stay short.
	var worst: Dictionary = {"choices": 999, "gap": 0, "open_gap": 0}
	for first: Dictionary in Graph.room(state, info["entry"])["connections"]:
		_walk(state, first["coord"], count, gather, 0, 0, 0, worst)
	expect.call(int(worst["choices"]) >= Graph.V7_MIN_CHOICES, "Every route meets at least %d choices (seed %d section %d: %d)" % [Graph.V7_MIN_CHOICES, int(state["seed"]), index + 1, int(worst["choices"])])
	expect.call(int(worst["open_gap"]) <= Graph.V7_MAX_RUN, "Choices are never more than %d rooms apart away from the gathering rows" % Graph.V7_MAX_RUN)
	expect.call(int(worst["gap"]) <= Graph.V7_MAX_RUN + 1, "Even through a gathering row, no more than %d rooms pass without a choice" % (Graph.V7_MAX_RUN + 1))

static func _walk(state: Dictionary, coord: Vector2i, count: int, gather: Array[int], choices: int, gap: int, open_gap: int, worst: Dictionary) -> void:
	var node: Dictionary = Graph.room(state, coord)
	var step: int = int(node["map_step"])
	if step >= count - 1:
		worst["choices"] = mini(int(worst["choices"]), choices)
		return
	var exits: Array = node["connections"]
	var fork: bool = exits.size() >= 2
	var next_gap: int = 0 if fork else gap + 1
	var next_open: int = 0 if fork or step + 1 in gather else open_gap + 1
	worst["gap"] = maxi(int(worst["gap"]), next_gap)
	worst["open_gap"] = maxi(int(worst["open_gap"]), next_open)
	for link: Dictionary in exits:
		_walk(state, link["coord"], count, gather, choices + int(fork), next_gap, next_open, worst)

static func test_doors(state: Dictionary, index: int, expect: Callable) -> void:
	var entered: Dictionary = {}
	var nodes: Array = _section_rooms(state, index)
	nodes.append(Graph.room(state, Graph.section(state, index)["entry"]))
	for node: Dictionary in nodes:
		var directions: Dictionary = {}
		for link: Dictionary in node["connections"]:
			var target: Dictionary = Graph.room(state, link["coord"])
			var direction: Vector2i = link["door_dir"]
			expect.call(not directions.has(direction), "A room's doors face different walls")
			directions[direction] = true
			var expected: Vector2i = Vector2i.RIGHT
			if str(target["type"]) != "boss":
				var delta: float = float(target["map_lane"]) - float(node["map_lane"])
				expected = Vector2i.UP if delta < 0.0 else (Vector2i.DOWN if delta > 0.0 else Vector2i.RIGHT)
			expect.call(direction == expected, "Doors face the lane they lead to")
			if not entered.has(target["coord"]): entered[target["coord"]] = {}
			entered[target["coord"]][-direction] = true
	for node: Dictionary in nodes:
		for link: Dictionary in node["connections"]:
			expect.call(not (entered.get(node["coord"], {}) as Dictionary).has(link["door_dir"]), "No exit opens through a wall the room is entered by")

static func test_layout(state: Dictionary, index: int, expect: Callable) -> void:
	var info: Dictionary = Graph.section(state, index)
	var positions: Dictionary = MapPanel.section_positions(state["rooms"], info, FIELD_SIZE)
	var width: float = MapPanel.scroll_world_width(info, FIELD_SIZE)
	expect.call(width > FIELD_SIZE.x, "A revision 7 section is wider than the field")
	var coords: Array = positions.keys()
	var violations: int = 0
	for a: int in range(coords.size()):
		var first: Dictionary = Graph.room(state, coords[a])
		var point_a: Vector2 = positions[coords[a]]
		expect.call(point_a.x > 0.0 and point_a.x < width and point_a.y > 0.0 and point_a.y < FIELD_SIZE.y, "Rooms lie inside the scrolling world")
		for b: int in range(a + 1, coords.size()):
			var second: Dictionary = Graph.room(state, coords[b])
			var need: float = NodeButton.max_visual_radius(first) + NodeButton.max_visual_radius(second) + MapPanel.SCROLL_NODE_GAP
			if point_a.distance_to(positions[coords[b]]) + GAP_TOLERANCE < need: violations += 1
	expect.call(violations == 0, "Rooms never touch at their largest size (seed %d section %d: %d pairs)" % [int(state["seed"]), index + 1, violations])
