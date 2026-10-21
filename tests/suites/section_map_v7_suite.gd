extends RefCounted

# map-03: revision 7 section maps (branching web, lane-facing doors, sideways scrolling).
const Graph = preload("res://scripts/section_map_graph.gd")
const MapPanel = preload("res://scripts/section_map_panel.gd")
const NodeButton = preload("res://scripts/section_map_node.gd")
const Specials = preload("res://scripts/special_encounter_library.gd")
const SEEDS: int = 40
const FIELD_SIZE: Vector2 = Vector2(1864, 823)
const GAP_TOLERANCE: float = 0.001
# Graph.initialize digests for seeds 1-24, computed at the pre-map-03 base
# (3fad2e65b): saved revision-5 and revision-6 runs regenerate unchanged.
const BASE_DIGEST_SEEDS: int = 24
const BASE_DIGESTS: Dictionary = {
	5: "8f11d783419ad86eccf86c676b3d706018c92d50f70fcfdac78aa1847eb7f1e9",
	6: "a16f2bfec2f02525198b640670520ebf3be6b7807ec6d77fe8f76b0117f4e5a6",
}
const PANEL_POSITION: Vector2 = Vector2(28, 28)
const PANEL_SIZE: Vector2 = Vector2(1864, 1024)
const WALK_WAIT_SECONDS: float = 0.85

static func run(expect: Callable) -> void:
	test_new_runs_use_revision_7(expect)
	test_saved_revisions_regenerate(expect)
	test_fallback_sections(expect)
	await test_panel_pointer(expect)
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
	for revision: int in [5, 6]:
		var text: String = ""
		for seed_value: int in range(1, BASE_DIGEST_SEEDS + 1):
			var state: Dictionary = {"seed": seed_value, "current_room": Vector2i.ZERO, "mode": "room", "section_map_layout_revision": revision}
			Graph.initialize(state)
			text += var_to_str(state)
			if seed_value == 1: expect.call(not bool(Graph.section(state, 0).get("scroll", false)), "Revision %d keeps the fixed-width map" % revision)
		expect.call(text.sha256_text() == BASE_DIGESTS[revision], "Revision %d maps match the pre-map-03 base byte for byte" % revision)

# The stored fallback sections (exhausted generation or special placement) obey
# every revision-7 rule, and special encounters place on each.
static func test_fallback_sections(expect: Callable) -> void:
	var state: Dictionary = {"seed": 83, "current_room": Vector2i.ZERO, "mode": "room"}
	Graph.initialize(state, {"force_v7_fallback": true})
	for index: int in range(6):
		test_section_rules(state, index, expect)
		test_doors(state, index, expect)
		test_layout(state, index, expect)
		var layout: Dictionary = Graph._fallback_layout_v7(83, index)
		for placement_seed: int in range(8):
			var rng := RandomNumberGenerator.new()
			rng.seed = placement_seed
			expect.call(Specials.place(layout.duplicate(true), rng, Graph.ROOM_COUNTS[index], "none"), "Special encounters place on stored fallback section %d" % (index + 1))

static func _section_rooms(state: Dictionary, index: int) -> Array:
	var rooms: Array = []
	for node: Dictionary in state["rooms"].values():
		if int(node["section_index"]) == index and str(node["type"]) not in ["start", "boss"]: rooms.append(node)
	return rooms

static func test_section_rules(state: Dictionary, index: int, expect: Callable) -> void:
	var info: Dictionary = Graph.section(state, index)
	var count: int = int(info["room_count"])
	var gather: Array[int]
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
			var lanes: Array[int]
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

# Pointer and lifecycle checks through real GUI input on the panel.
static func test_panel_pointer(expect: Callable) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	tree.root.add_child(viewport)
	var panel: Control = MapPanel.new()
	panel.position = PANEL_POSITION
	panel.size = PANEL_SIZE
	viewport.add_child(panel)
	var state: Dictionary = {"seed": 83, "current_room": Vector2i.ZERO, "mode": "room"}
	Graph.initialize(state)
	var info: Dictionary = Graph.section(state, 0)
	state["current_room"] = info["entry"]
	Graph.room(state, info["entry"])["visited"] = true
	Graph.refresh_knowledge(state)
	panel.set_run_state(state)
	await tree.process_frame
	await tree.process_frame
	var selected: Array = []
	panel.room_selected.connect(func(coord: Vector2i) -> void: selected.append(coord))
	var target: Vector2i = panel.available_destinations()[0]
	var button: Control = panel.node_buttons[target]
	# A drag that starts on a room scrolls the map and never commits travel.
	var start: Vector2 = button.get_global_rect().get_center()
	_pointer(viewport, start, true)
	_pointer(viewport, start + Vector2(-40.0, 0.0))
	_pointer(viewport, start + Vector2(-40.0, 0.0), false)
	await tree.create_timer(WALK_WAIT_SECONDS).timeout
	expect.call(panel.scroll_offset() > 30.0, "Dragging from a room scrolls the map")
	expect.call(selected.is_empty(), "A drag from a room never commits travel")
	# Keyboard or controller activation right after a drag is not swallowed.
	button.pressed.emit()
	await tree.create_timer(WALK_WAIT_SECONDS).timeout
	expect.call(selected == [target], "Activation after a drag still travels")
	# A small wobble below the drag threshold is still a click.
	panel.set_run_state(state.merged({"mode": "pre_battle"}))
	panel.set_run_state(state)
	panel.scroll_to(0.0)
	await tree.process_frame
	start = button.get_global_rect().get_center()
	_pointer(viewport, start, true)
	_pointer(viewport, start + Vector2(3.0, 0.0))
	_pointer(viewport, start + Vector2(3.0, 0.0), false)
	await tree.create_timer(WALK_WAIT_SECONDS).timeout
	expect.call(selected.size() == 2 and is_zero_approx(panel.scroll_offset()), "A click that wobbles under the drag threshold travels")
	# The wheel scrolls over a room as well as over open floor.
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	wheel.position = button.get_global_rect().get_center()
	wheel.global_position = wheel.position
	viewport.push_input(wheel, true)
	await tree.create_timer(0.5).timeout
	expect.call(panel.scroll_offset() > 0.0, "The wheel scrolls the map over a room")
	# A finished walk leaves the lantern at its room until the run moves there.
	expect.call(is_equal_approx(float(panel._canvas.get("travel_progress")), 1.0), "A finished walk holds the lantern at the chosen room")
	var moved: Dictionary = state.duplicate(true)
	moved["current_room"] = target
	Graph.room(moved, target)["visited"] = true
	Graph.refresh_knowledge(moved)
	panel.set_run_state(moved)
	await tree.process_frame
	expect.call(is_zero_approx(float(panel._canvas.get("travel_progress"))) and bool((panel.node_buttons[target] as Control).get("lantern_marker")), "Arriving resets the walk and the room carries the lantern")
	viewport.queue_free()
	await tree.process_frame

static func _pointer(viewport: SubViewport, point: Vector2, pressed: Variant = null) -> void:
	var event: InputEventMouse
	if pressed == null:
		var motion := InputEventMouseMotion.new()
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		event = motion
	else:
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = bool(pressed)
		event = press
	event.position = point
	event.global_position = point
	viewport.push_input(event, true)
