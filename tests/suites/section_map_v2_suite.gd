extends RefCounted
const Graph = preload("res://scripts/section_map_graph.gd")
const RunEngineScript = preload("res://scripts/run_engine.gd")
const Progression = preload("res://scripts/progression_store.gd")
const Guardians = preload("res://scripts/guardian_library.gd")
const FIXTURE_SEED: int = 83
const PRESENTATION_FIXTURE_COORD_RADIUS: int = 24
# Capture pristine production outputs for the revision-5 compatibility checks.
# Reusing hashes avoids regenerating the same legacy seeds in the timed suite.
static var revision4_graph_hashes: Dictionary = {}

static func run(expect: Callable) -> void:
	revision4_graph_hashes.clear()
	expect.call(Graph._walk_moves(0, Graph._coords([])) == [0, 0, 1] and Graph._walk_moves(3, Graph._coords([])) == [2, 3, 3], "Uniform clamped deltas retain both outer-lane stay rolls")
	expect.call(Graph._walk_moves(1, Graph._coords([Vector2i(2, 1)])) == [0, 1], "Walk choices exclude only crossing moves")
	for seed: int in range(64):
		var state: Dictionary = {"seed": seed, "current_room": Vector2i.ZERO, "mode": "room"}
		Graph._initialize_revision_4(state)
		revision4_graph_hashes[str(seed)] = var_to_str(state).sha256_text()
		var again: Dictionary = {"seed": seed, "current_room": Vector2i.ZERO, "mode": "room"}
		Graph._initialize_revision_4(again)
		expect.call(state == again, "Revision 4 generation is deterministic: seed %d" % seed)
		expect.call(int(state.get("section_map_layout_revision")) == 4, "Legacy generator records layout revision 4")
		var ids: Dictionary = {}
		for node: Dictionary in state["rooms"].values():
			expect.call(not ids.has(node["coord"]), "Every persistent coordinate is unique")
			ids[node["coord"]] = true
		for index: int in range(6): _test_section(state, index, expect)
	_test_mysteries(expect)
	_test_knowledge(expect)
	_test_older_layouts(expect)
	_test_fallback(expect)
	_test_probe_fixture(expect)

static func _test_section(state: Dictionary, index: int, expect: Callable) -> void:
	var info: Dictionary = Graph.section(state, index)
	var count: int = Graph.ROOM_COUNTS[index]
	var walks: Array = info["walks"]
	expect.call(walks.size() == 5 and walks[0][0] != walks[1][0], "Exactly five walks with distinct first two starts")
	var cells: Dictionary = {}
	var edges: Dictionary = {}
	var rows: Dictionary = {}
	for walk: Array in walks:
		expect.call(walk.size() == count - 1, "Each lane walk spans every non-boss step")
		for offset: int in range(walk.size()):
			var cell := Vector2i(offset + 1, walk[offset])
			cells[cell] = true
			if not rows.has(cell.x): rows[cell.x] = {}
			rows[cell.x][cell.y] = true
			if offset + 1 < walk.size(): edges[Vector3i(cell.x, cell.y, walk[offset + 1])] = true
	for row: Dictionary in rows.values(): expect.call(row.size() >= 2, "Every room step has at least two lanes")
	expect.call(Graph.room(state, info["entry"])["connections"].size() == 3, "Three opening combats satisfy sibling uniqueness and the retained door mapping")
	var reachable: Dictionary = Graph.descendants(state, info["entry"])
	expect.call(reachable.size() == cells.size() + 2, "Every generated room is reachable; nodes are exactly the walk union")
	var actual_edges: Dictionary = {}
	var guardians: Array[Vector2i] = []
	var scavengers: int = 0
	var depth_counts: Dictionary = {}
	for coord: Vector2i in reachable:
		var node: Dictionary = Graph.room(state, coord)
		var step: int = int(node["map_step"])
		var lane: int = int(node["map_lane"])
		var type: String = node["type"]
		expect.call(maxi(absi(coord.x), absi(coord.y)) == int(node["depth"]), "Coordinates preserve Chebyshev encounter depth")
		var directions: Dictionary = {}
		for link: Dictionary in node["connections"]:
			var direction: Vector2i = link["door_dir"]
			expect.call(not directions.has(direction), "Each onward edge has a distinct physical door")
			directions[direction] = true
			for onward: Dictionary in Graph.room(state, link["coord"])["connections"]:
				expect.call(onward["door_dir"] != -direction, "Onward exits never occupy the incoming threshold")
		if step == 0 or step == count: continue
		expect.call(lane >= 0 and lane <= 3 and cells.has(Vector2i(step, lane)), "Room lanes are 0 through 3 and belong to a walk")
		var band: int = int(info["depth_bands"][step])
		expect.call(int(node["depth"]) == index * 4 + band, "Room coordinate lies on its capacity-adjusted depth band")
		depth_counts[node["depth"]] = int(depth_counts.get(node["depth"], 0)) + 1
		if step == 1: expect.call(type == "combat", "Step 1 is all combat")
		if step == ceili(count / 2.0): expect.call(type == "treasure", "Middle row is all treasure")
		if step == count - 1: expect.call(type == "campfire", "Pre-boss row is all Ember Hearth")
		if type == "guardian":
			guardians.append(coord)
			expect.call(step >= 3 and step <= count - 3, "Guardians occupy only eligible middle steps")
			var guardian: Dictionary = Guardians.for_boss(info["boss_id"])
			expect.call(node["guardian_id"] == guardian["id"] and node["guardian_relic"] == guardian["relic"] and node["element"] == guardian["element"] and node["boss_id"] == info["boss_id"], "Every Guardian has its section's exact identity and reward")
		if type == "scavenger":
			scavengers += 1
			expect.call(step >= 3, "Scavengers start at step 3")
		if type == "mystery":
			expect.call(node["mystery_type"] in ["event", "combat", "treasure", "scavenger"] and node["element"] == "none" and Graph.display_type(node) == "mystery", "Unentered mystery stores but never displays its hidden seeded identity")
		var links: Array = node["connections"]
		expect.call(links.size() >= 1 and links.size() <= 3, "Every room has one to three onward doors")
		var child_types: Dictionary = {}
		for link: Dictionary in links:
			var child: Dictionary = Graph.room(state, link["coord"])
			expect.call(int(child["map_step"]) == step + 1, "Edges advance exactly one step")
			var child_type: String = child["type"]
			if type in ["guardian", "scavenger", "graftwright", "campfire", "treasure"]: expect.call(type != child_type, "Special rooms never connect to the same special type")
			if links.size() >= 2:
				expect.call(not child_types.has(child_type) or (child_type == "combat" and links.size() == 3), "Sibling types are distinct except combat at a three-way split")
			child_types[child_type] = true
			if int(child["map_step"]) == count: continue
			var edge := Vector3i(step, lane, int(child["map_lane"]))
			actual_edges[edge] = true
			expect.call(absi(edge.y - edge.z) <= 1, "Walk moves are adjacent or stay in their lane")
			for other: Vector3i in actual_edges:
				if edge.x == other.x: expect.call((edge.y - other.y) * (edge.z - other.z) >= 0, "Every step's edges are crossing-free")
	expect.call(actual_edges == edges, "Stored connections are exactly the union of the five walks")
	for depth: int in depth_counts: expect.call(int(depth_counts[depth]) <= 8 * depth, "Every depth band fits its ring capacity")
	var expected_bands: Dictionary = {}
	var sizes: Dictionary = {1: 0, 2: 0, 3: 0}
	var step_counts: Array[int] = []
	step_counts.assign([3, 3, 3])
	if count >= 11: step_counts[2] = 4
	if count == 12: step_counts[1] = 4
	for step: int in range(1, count):
		var band: int = 1 if step <= step_counts[0] else (2 if step <= step_counts[0] + step_counts[1] else 3)
		expected_bands[step] = band
		sizes[band] += rows[step].size()
	for band: int in range(1, 4):
		while sizes[band] > 8 * (index * 4 + band):
			var last: int = 0
			for step: int in expected_bands:
				if expected_bands[step] == band: last = maxi(last, step)
			expected_bands[last] += 1
			sizes[band] -= rows[last].size()
			sizes[band + 1] += rows[last].size()
	expect.call(info["depth_bands"] == expected_bands, "Capacity repair moves only the last overflowing step into the next band")
	expect.call(guardians.size() >= 2 and info["guardians"] == guardians and info["guardian"] == guardians[0], "Section stores all Guardians and its compatibility alias")
	expect.call(scavengers >= 1, "Every section includes a Scavenger")
	var outcomes: Dictionary = {}
	_walk_routes(state, info["entry"], index, 0, 0, 0, 0, outcomes, expect)
	expect.call(outcomes.has(0) and outcomes.has(1), "Guardian approach and bypass routes both exist")

# Independent exhaustive route traversal checks merges as well as original walks.
static func _walk_routes(state: Dictionary, coord: Vector2i, index: int, fights: int, guardians: int, services: int, visits: int, outcomes: Dictionary, expect: Callable) -> void:
	var node: Dictionary = Graph.room(state, coord)
	var type: String = node["type"]
	if type == "graftwright": expect.call(fights >= 3, "Every incoming Graftwright route has at least three fights")
	if type == "boss":
		var target: int = Graph.FIGHT_COUNTS[index] - 1
		expect.call(fights >= target - 1 and fights <= target + 1, "Every complete route obeys its fight range")
		expect.call(guardians <= 1 and services >= 1, "Every complete route has at most one Guardian and at least one extra service")
		expect.call(visits + 1 == Graph.ROOM_COUNTS[index], "Every complete route obeys the visit budget")
		outcomes[guardians] = true
		return
	visits += int(type != "start")
	fights += int(type in ["combat", "special", "guardian"] or (type == "mystery" and node["mystery_type"] == "combat"))
	guardians += int(type == "guardian")
	services += int(type in ["event", "scavenger", "graftwright"] or (type == "mystery" and node["mystery_type"] != "combat"))
	for link: Dictionary in node["connections"]: _walk_routes(state, link["coord"], index, fights, guardians, services, visits, outcomes, expect)

static func _test_mysteries(expect: Callable) -> void:
	var engine := RunEngineScript.new()
	var initial: Dictionary = _revision4_run(engine, FIXTURE_SEED, Progression.default_data())
	for hidden: String in ["event", "combat", "treasure", "scavenger"]:
		var state: Dictionary = initial.duplicate(true)
		var entry: Vector2i = Graph.section(state, 0)["entry"]
		var target: Vector2i = Graph.room(state, entry)["connections"][0]["coord"]
		var node: Dictionary = Graph.room(state, target)
		node.merge({"type": "mystery", "mystery_type": hidden, "mystery_element": "ice", "element": "none"}, true)
		var topology: Array = node["connections"].duplicate(true)
		var event_count: int = state["map_events"].size()
		var after: Dictionary = engine.move_to_pre_battle(state, target)
		var resolved: Dictionary = Graph.room(after, target)
		expect.call(node["type"] == "mystery" and not node.get("was_mystery", false), "Entry resolution does not mutate the source state")
		expect.call(resolved["type"] == hidden and resolved.get("was_mystery", false) and resolved["connections"] == topology, "Mystery resolves on entry without changing its topology")
		expect.call((resolved["element"] == "ice") == (hidden == "combat"), "Mystery combat receives its saved seeded element")
		expect.call((resolved["merchant_kind"] == "scavenger" and not resolved["npcs"].is_empty()) == (hidden == "scavenger"), "Mystery Scavenger receives the ordinary service fields")
		var expected_mode: String = {"event": "event", "combat": "pre_battle", "treasure": "treasure", "scavenger": "room"}[hidden]
		expect.call(after["mode"] == expected_mode, "Mystery dispatch uses the normal resolved room transaction")
		var resolution_count: int = 0
		for event: Dictionary in after["map_events"].slice(event_count):
			if event["type"] == "mystery_resolved":
				resolution_count += 1
				expect.call(event["payload"] == {"room": target, "type": hidden}, "Mystery analytics record exact room and resolved type")
		expect.call(resolution_count == 1, "Entering a mystery appends exactly one resolution event")
		var copy: Dictionary = after.duplicate(true)
		Graph.resolve_mystery(copy, Graph.room(copy, target))
		expect.call(copy == after, "Mystery resolution is idempotent")
		var direct: Dictionary = engine.move_to_room(state, target)
		expect.call(Graph.room(direct, target)["type"] == hidden and direct["mode"] == ("combat" if hidden == "combat" else expected_mode), "Direct room entry also uses the resolved mystery transaction")
		var scouted: Dictionary = engine.scout_map(state, target)
		var known: Dictionary = Graph.room(scouted, target)
		expect.call(known["type"] == "mystery" and known["scouted"] and Graph.display_type(known) == hidden, "Scout reveals a hidden type without converting the room")
		expect.call(Graph.section(scouted, 0)["scouts"] == 1 and engine.scout_map(scouted, target) == scouted, "Scout spends one use and cannot repeat its target")
		expect.call(scouted["map_events"].back()["payload"]["scope"] == "mystery", "Revision 4 Scout analytics use mystery scope")
		Graph.record_choice(scouted, target)
		for mode: String in ["event", "reward", "treasure", "campfire", "graftwright", "victory", "defeat"]:
			var blocked: Dictionary = state.duplicate(true)
			blocked["mode"] = mode
			expect.call(engine.scout_map(blocked, target) == blocked, "Mystery Scout respects unresolved transaction modes")
		for mode: String in ["room", "combat", "pre_battle"]:
			var permitted: Dictionary = state.duplicate(true)
			permitted["mode"] = mode
			expect.call(Graph.section(engine.scout_map(permitted, target), 0)["scouts"] == 1, "Mystery Scout remains available during inspection modes")
		var unreachable: Dictionary = state.duplicate(true)
		unreachable["current_room"] = Graph.section(state, 0)["boss"]
		expect.call(engine.scout_map(unreachable, target) == unreachable, "Mysteries on abandoned routes cannot be Scouted")
		expect.call(engine.scout_map(state, Graph.INVALID) == state, "Invalid mystery Scout requests are no-ops")
		var found: bool = false
		for metadata: Dictionary in scouted["map_events"].back()["payload"]["known_room_metadata"]:
			if metadata["room"] == target: found = metadata["type"] == hidden
		expect.call(found, "Route analytics record the scouted identity the player knows")

static func _test_knowledge(expect: Callable, revision: int = 4) -> void:
	var state: Dictionary = {"seed": FIXTURE_SEED, "current_room": Vector2i.ZERO, "mode": "room"}
	if revision == 4: Graph._initialize_revision_4(state)
	else: Graph.initialize(state)
	for index: int in range(6):
		state["current_room"] = Graph.section(state, index)["entry"]
		Graph.refresh_knowledge(state)
		var distances: Dictionary = Graph.descendants(state, state["current_room"])
		for coord: Vector2i in distances:
			var node: Dictionary = Graph.room(state, coord)
			var landmark: bool = node.get("map_landmark", false) or node["type"] == "boss"
			if index == 5 and node["type"] in ["treasure", "campfire", "guardian", "boss"]:
				expect.call(landmark and node["revealed"] and node["map_outline"], "All VI treasure, Hearth, Guardian and boss nodes are visible landmarks")
			expect.call(node["revealed"] == (index < 5 or distances[coord] <= 2 or landmark), "I–V reveal the complete section; VI preserves the two-transition horizon")
			expect.call(node["map_outline"] == (index < 5 or distances[coord] <= 3 or landmark), "VI retains the third-transition outline and landmarks")
		var targets: Array[Vector2i] = Graph.scout_options(state)
		for coord: Vector2i in distances:
			var candidate: Dictionary = Graph.room(state, coord)
			var eligible: bool = not candidate.get("sealed", false) and (candidate["map_outline"] and not candidate["revealed"] if index == 5 else candidate["type"] == "mystery" and not candidate.get("scouted", false) and not candidate["visited"])
			expect.call(targets.has(coord) == eligible, "Scout includes exactly the revision and section's eligible reachable rooms")
		for target: Vector2i in targets:
			var node: Dictionary = Graph.room(state, target)
			expect.call(distances.has(target) and (node["map_outline"] and not node["revealed"] if index == 5 else node["type"] == "mystery" and not node["visited"]), "VI Scout retains outlined unknown targets; I–V Scout targets mysteries")
		if index == 5:
			expect.call(not targets.is_empty(), "VI has outlined unknown Scout targets at entry")
			for hidden: String in ["event", "combat", "treasure", "scavenger"]:
				var fixture: Dictionary = state.duplicate(true)
				var target: Vector2i = targets[0]
				Graph.room(fixture, target).merge({"type": "mystery", "mystery_type": hidden}, true)
				var scouted: Dictionary = Graph.scout(fixture, target)
				var known: Dictionary = Graph.room(scouted, target)
				expect.call(known["type"] == "mystery" and known["scouted"] and known["revealed"] and Graph.display_type(known) == hidden, "VI scouting a mystery reveals its hidden identity without conversion")
				expect.call(scouted["map_events"].back()["payload"]["scope"] == "mystery", "VI mystery scouting has additive mystery analytics scope")
			var ordinary: Dictionary = state.duplicate(true)
			Graph.room(ordinary, targets[0])["type"] = "event"
			var surveyed: Dictionary = Graph.scout(ordinary, targets[0])
			expect.call(Graph.room(surveyed, targets[0])["revealed"] and surveyed["map_events"].back()["payload"]["scope"] == "room", "VI ordinary unknown-room scouting retains room scope")
		if index < 5:
			for node: Dictionary in state["rooms"].values():
				if int(node["section_index"]) > index: expect.call(not node["revealed"] and not node["map_outline"], "Future sections stay hidden")

static func _test_older_layouts(expect: Callable) -> void:
	var engine := RunEngineScript.new()
	var state: Dictionary = _revision4_run(engine, FIXTURE_SEED, Progression.default_data())
	var start_npcs: Array = Graph.room(state, Vector2i.ZERO).get("npcs", []).duplicate(true)
	state.erase("map_events")
	state.erase("map_event_revision")
	Graph._initialize_revision_3(state)
	Graph.room(state, Vector2i.ZERO)["npcs"] = start_npcs
	state["current_room_layout"] = engine._display_layout_for_room(FIXTURE_SEED, Graph.room(state, Vector2i.ZERO), Vector2i.ZERO)
	var original: Dictionary = state.duplicate(true)
	Progression.set_run_storage_path("user://section_map_v2_legacy.save")
	expect.call(Progression.save_run_state(state), "Revision 3 layout saves through production serialization")
	var loaded: Dictionary = engine.repair_loaded_run_state(Progression.load_saved_run())
	expect.call(loaded["rooms"] == original["rooms"] and loaded["map_sections"] == original["map_sections"] and loaded["section_map_layout_revision"] == 3, "Loading revision 3 keeps stored topology and all knowledge")
	var target: Vector2i = Graph.scout_options(loaded)[0]
	var after: Dictionary = engine.scout_map(loaded, target)
	expect.call(Graph.room(after, target)["revealed"] and after["map_events"].back()["payload"]["scope"] == "room", "Revision 3 keeps ordinary room Scout behavior")
	var moved: Dictionary = engine.move_to_pre_battle(loaded, engine.available_moves(loaded)[0])
	expect.call(moved["current_room"] != loaded["current_room"] and moved["section_map_layout_revision"] == 3, "A saved revision 3 run remains playable")
	for revision: int in [1, 2]:
		var older: Dictionary = original.duplicate(true)
		older["section_map_layout_revision"] = revision
		var repaired: Dictionary = engine.repair_loaded_run_state(older)
		expect.call(repaired["rooms"] == older["rooms"] and repaired["map_sections"] == older["map_sections"] and not Graph.modern(repaired), "Earlier stored revisions retain topology and fog behavior")
	Progression.clear_saved_run()
	Progression.set_run_storage_path(Progression.DEFAULT_RUN_STORAGE_PATH)

static func _test_fallback(expect: Callable) -> void:
	for index: int in range(6):
		var count: int = Graph.ROOM_COUNTS[index]
		var layout: Dictionary = Graph._fallback_layout(count, Graph.FIGHT_COUNTS[index] - 1)
		expect.call(Graph._complete_types_legal(layout, count, Graph.FIGHT_COUNTS[index] - 1), "Deterministic fallback obeys every route budget")
		for cell: Vector2i in layout["order"]: expect.call(Graph._prefix_type_legal(layout, cell, count, Graph.FIGHT_COUNTS[index] - 1), "Deterministic fallback obeys placement and sibling constraints")

static func _test_probe_fixture(expect: Callable) -> void:
	# Match the existing windowed probe's fixture prerequisites headlessly.
	var engine := RunEngineScript.new()
	var state: Dictionary = _revision4_run(engine, 90429, Progression.default_data())
	for step: int in range(3):
		var current: Dictionary = Graph.room(state, state["current_room"])
		current["cleared"] = true
		current["sealed"] = true
		state["current_room"] = current["connections"][0]["coord"]
		Graph.resolve_mystery(state, Graph.room(state, state["current_room"]))
		Graph.room(state, state["current_room"])["visited"] = true
		Graph.room(state, state["current_room"])["cleared"] = true
		Graph.refresh_knowledge(state)
	var targets: Array[Vector2i] = Graph.scout_options(state)
	expect.call(not targets.is_empty(), "Existing visual probe has a reachable mystery after its three-room advance")
	var choices: Array = Graph.room(state, state["current_room"])["connections"]
	var choice: Vector2i = choices[0]["coord"]
	expect.call(targets.has(choice) == (str(Graph.room(state, choice)["type"]) == "mystery"), "Immediate unentered mysteries remain valid Scout targets alongside travel")
	var panel := preload("res://scripts/section_map_panel.gd").new()
	panel.set_run_state(state)
	expect.call(Graph.modern(panel.run_state), "Panel's compact snapshot retains revision 4 behavior via saved lane metadata")
	for target: Vector2i in targets:
		expect.call(panel.room_description(target) == "Unknown room\nNot yet visited", "Mystery tooltip uses the approved name and normal state line")
		expect.call(not panel.room_description(target).contains(str(Graph.room(state, target)["mystery_type"]).capitalize()), "Panel tooltips never expose an unscouted hidden type")
		var scouted: Dictionary = Graph.scout(state, target)
		panel.set_run_state(scouted)
		expect.call(panel.room_description(target) == "Unknown room · " + panel._type_label(Graph.room(state, target)["mystery_type"]) + "\nNot yet visited", "Scouted mystery tooltip names its revealed type with the normal state line")
		panel.set_run_state(state)
	_test_presentation_adapters(panel, expect)
	panel.free()

static func _test_presentation_adapters(panel: Control, expect: Callable) -> void:
	var icons = preload("res://scripts/room_icon_library.gd")
	for hidden: String in ["event", "combat", "treasure", "scavenger"]:
		var node: Dictionary = {"type": "mystery", "mystery_type": hidden, "section_index": 0}
		expect.call(icons.icon_id_for_room(node) == icons.ICON_UNKNOWN and icons.icon_texture(icons.ICON_UNKNOWN) == null, "Unscouted mystery door uses the existing procedural Unknown emblem")
		node["scouted"] = true
		expect.call(icons.icon_id_for_room(node) == hidden, "Scouted mystery door uses its resolved type's approved emblem")
	for x: int in range(-PRESENTATION_FIXTURE_COORD_RADIUS, PRESENTATION_FIXTURE_COORD_RADIUS + 1):
		for y: int in range(-PRESENTATION_FIXTURE_COORD_RADIUS, PRESENTATION_FIXTURE_COORD_RADIUS + 1):
			var coord := Vector2i(x, y)
			var jitter: Vector2 = panel._node_jitter(coord)
			expect.call(absf(jitter.x) <= 16 and absf(jitter.y) <= 12 and jitter == panel._node_jitter(coord), "Coordinate jitter is deterministic within the approved pixel limits")
	var button := preload("res://scripts/section_map_node.gd").new()
	for type: String in ["combat", "guardian", "boss", "mystery"]:
		button.room_data = {"type": type, "revealed": true, "scouted": type == "mystery"}
		button.route_state = "ahead"
		button.modern_layout = true
		expect.call(button.medallion_icon_tint() == Color(1.0, 1.0, 1.0, 0.85), "Revealed future medallion icons use 85 percent opacity, including scouted mysteries")
		for state: String in ["current", "visited", "reachable", "bypassed"]:
			button.route_state = state
			button.actionable = state == "reachable"
			button.modern_layout = false
			var legacy_tint: Color = button.medallion_icon_tint()
			button.modern_layout = true
			expect.call(button.medallion_icon_tint() == legacy_tint, "Available, current, visited and bypassed icon styles remain unchanged")
		button.route_state = "ahead"
		button.scout_target = true
		button.actionable = true
		expect.call(button.medallion_icon_tint() == Color.WHITE, "An available Scout target retains its full-opacity icon")
		button.scout_target = false
		button.actionable = false
	button.free()

static func _revision4_run(engine: RunEngineScript, seed_value: int, progression: Dictionary) -> Dictionary:
	var state: Dictionary = engine.create_new_run(seed_value, progression)
	var start_npcs: Array = Graph.room(state, Vector2i.ZERO).get("npcs", []).duplicate(true)
	state.erase("map_events")
	state.erase("map_event_revision")
	Graph._initialize_revision_4(state)
	Graph.room(state, Vector2i.ZERO)["npcs"] = start_npcs
	state["current_room_layout"] = engine._display_layout_for_room(seed_value, Graph.room(state, Vector2i.ZERO), Vector2i.ZERO)
	return state
