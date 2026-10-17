extends RefCounted

const Graph = preload("res://scripts/section_map_graph.gd")
const Metrics = preload("res://tools/section_map_variety.gd")
const Legacy = preload("res://tests/suites/section_map_v2_suite.gd")
const MapPanel = preload("res://scripts/section_map_panel.gd")
const RunEngineScript = preload("res://scripts/run_engine.gd")
const Progression = preload("res://scripts/progression_store.gd")
const Regression = preload("res://tests/suites/section_map_regression_suite.gd")
const METRIC_SEED_COUNT: int = 50
const LEGACY_SEED_COUNT: int = 200
# The dedicated proof checks all 200 seeds. The full runner also executes the
# existing 64-seed revision-4 suite twice; sample here to avoid redundant work
# crowding its unchanged 900-second budget.
const FULL_SUITE_LEGACY_SEED_COUNT: int = 50
const DETERMINISM_SEED_COUNT: int = 5
const FINAL_JITTER_SAMPLE_COUNT: int = 33
const GAP_TOLERANCE: float = 0.001
const PROOF_FIELD_SIZE: Vector2 = Vector2(1864, 823)

static func run(expect: Callable, legacy_seed_count: int = LEGACY_SEED_COUNT) -> void:
	var report: Dictionary = Metrics.measure(METRIC_SEED_COUNT)
	var failures: Array[String] = Metrics.metric_failures(report)
	for failure: String in failures: expect.call(false, failure)
	expect.call(failures.is_empty(), "Revision 5 metric thresholds over seeds 1..50 x 6 sections")
	print("Map 02 metrics: %s (50 seeds x 6 sections)" % ("PASS" if failures.is_empty() else "FAIL"))
	_test_legacy_hashes(expect, legacy_seed_count)
	Regression.test_public_dispatch(expect)
	Regression.test_bounded_structures(expect)
	Regression.test_probe_ready(expect)
	for seed_value: int in range(1, DETERMINISM_SEED_COUNT + 1):
		var state: Dictionary = _state(seed_value)
		Graph.initialize(state)
		var again: Dictionary = _state(seed_value)
		Graph.initialize(again)
		expect.call(state == again and state["section_map_layout_revision"] == 5, "Revision 5 is deterministic and new runs record revision 5")
		if seed_value == 1: _test_panel_before_ready(state, expect)
		if seed_value in Regression.LAYOUT_SEEDS: Regression.test_layout_gaps(state, expect)
		for index: int in range(6): _test_section(state, index, expect)
	_test_saved_revision4(expect)
	_test_layout_contract(expect)
	Legacy._test_knowledge(expect, 5)

static func _state(seed_value: int) -> Dictionary:
	return {"seed": seed_value, "current_room": Vector2i.ZERO, "mode": "room"}

static func _test_legacy_hashes(expect: Callable, seed_count: int) -> void:
	var revision4: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Metrics.BASELINE_PATH))["hashes"]
	var revision3: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/map_02_revision3_hashes.json"))
	var reused: int = 0
	for seed_value: int in range(1, seed_count + 1):
		var seed_key: String = str(seed_value)
		var state: Dictionary = _state(int(seed_key))
		var actual_revision4: String = str(Legacy.revision4_graph_hashes.get(seed_key, ""))
		if actual_revision4.is_empty():
			Graph._initialize_revision_4(state)
			actual_revision4 = var_to_str(state).sha256_text()
		else:
			reused += 1
		expect.call(actual_revision4 == revision4[seed_key], "Revision 4 stays byte-identical to the pre-change graph: seed " + seed_key)
		state = _state(int(seed_key))
		Graph._initialize_revision_3(state)
		expect.call(var_to_str(state).sha256_text() == revision3[seed_key], "Revision 3 stays byte-identical to the pre-change graph: seed " + seed_key)
	print("Map 02 legacy hashes: checked %d seeds each for revisions 3 and 4" % seed_count)
	if reused > 0: print("Map 02 legacy hashes: reused %d pristine revision-4 outputs from the legacy suite" % reused)

static func _test_section(state: Dictionary, index: int, expect: Callable) -> void:
	var info: Dictionary = Graph.section(state, index)
	var count: int = Graph.ROOM_COUNTS[index]
	var walks: Array = info["walks"]
	expect.call(info["lane_count"] == 5 and walks.size() == 6, "Revision 5 uses five lanes and six walks")
	expect.call(walks[0][0] != walks[1][0] and walks[0][0] != walks[2][0] and walks[1][0] != walks[2][0], "First three walks cover three distinct opening fights")
	var expected_edges: Dictionary = {}
	var rows: Dictionary = {}
	for walk: Array in walks:
		expect.call(walk.size() == count - 1, "All six walks span the whole section")
		expect.call(walk[0] in [walks[0][0], walks[1][0], walks[2][0]], "Extra walks start at an existing opening")
		for offset: int in range(walk.size()):
			if not rows.has(offset + 1): rows[offset + 1] = {}
			rows[offset + 1][walk[offset]] = true
			if offset + 1 < walk.size(): expected_edges[Vector3i(offset + 1, walk[offset], walk[offset + 1])] = true
	var actual_edges: Dictionary = {}
	var layout: Dictionary = Graph._layout_from_walks(walks, count)
	var previous: Array = []
	var repetitions: int = 0
	var wide: bool = false
	for step: int in range(1, count):
		var lanes: Array = rows[step].keys()
		lanes.sort()
		expect.call(lanes.size() >= 2 and lanes.size() <= 5, "Interior row sizes are 2..5")
		wide = wide or lanes.size() >= 4
		repetitions = repetitions + 1 if lanes == previous else 1
		expect.call(repetitions <= 3, "No more than three consecutive identical lane sets")
		previous = lanes
	expect.call(wide and Metrics._long_divergence(layout), "Every revision 5 section has a wide row and four-row divergence")
	var reachable: Dictionary = Graph.descendants(state, info["entry"])
	expect.call(reachable.size() == layout["order"].size() + 2, "Every generated cell is reachable")
	for coord: Vector2i in reachable:
		var node: Dictionary = Graph.room(state, coord)
		var step: int = int(node["map_step"])
		if step == 0 or step == count: continue
		var lane: int = int(node["map_lane"])
		expect.call(lane >= 0 and lane <= 4 and rows[step].has(lane), "Room belongs to its five-lane walk union")
		if step == 1: expect.call(node["type"] == "combat", "Opening row contains exactly three Combat nodes")
		if step == ceili(count / 2.0): expect.call(node["type"] == "treasure", "Midpoint remains Treasure")
		if step == count - 1: expect.call(node["type"] == "campfire", "Pre-boss row remains Campfire")
		var types: Dictionary = {}
		var links: Array = node["connections"]
		for link: Dictionary in links:
			var child: Dictionary = Graph.room(state, link["coord"])
			var type: String = child["type"]
			expect.call(not types.has(type) or (type == "combat" and links.size() == 3), "Fork destinations have different types, except three-way Combat forks")
			types[type] = true
			for onward: Dictionary in child["connections"]:
				expect.call(onward["door_dir"] != -link["door_dir"], "Physical onward doors never conflict with incoming thresholds")
			if int(child["map_step"]) == count: continue
			var edge := Vector3i(step, lane, int(child["map_lane"]))
			expect.call(absi(edge.y - edge.z) <= 1, "Each lane step changes by at most one")
			for other: Vector3i in actual_edges:
				if other.x == edge.x: expect.call((edge.y - other.y) * (edge.z - other.z) >= 0, "Edges do not cross")
			actual_edges[edge] = true
	expect.call(actual_edges == expected_edges, "Stored edges equal the union of six walks")
	var outcomes: Dictionary = {}
	Legacy._walk_routes(state, info["entry"], index, 0, 0, 0, 0, outcomes, expect)
	expect.call(outcomes.has(0) and outcomes.has(1), "Every section offers a Guardian-free route")

static func _test_saved_revision4(expect: Callable) -> void:
	var engine := RunEngineScript.new()
	var state: Dictionary = engine.create_new_run(83, Progression.default_data())
	var start_npcs: Array = Graph.room(state, Vector2i.ZERO).get("npcs", []).duplicate(true)
	state.erase("map_events")
	state.erase("map_event_revision")
	Graph._initialize_revision_4(state)
	Graph.room(state, Vector2i.ZERO)["npcs"] = start_npcs
	state["current_room_layout"] = engine._display_layout_for_room(83, Graph.room(state, Vector2i.ZERO), Vector2i.ZERO)
	var original: Dictionary = {"rooms": state["rooms"].duplicate(true), "map_sections": state["map_sections"].duplicate(true), "section_map_layout_revision": state["section_map_layout_revision"]}
	Progression.set_run_storage_path("user://map_02_revision4.save")
	expect.call(Progression.save_run_state(state), "Revision 4 saves with production serialization")
	var loaded: Dictionary = engine.repair_loaded_run_state(Progression.load_saved_run())
	expect.call(loaded["rooms"] == original["rooms"] and loaded["map_sections"] == original["map_sections"] and loaded["section_map_layout_revision"] == original["section_map_layout_revision"], "Saved revision 4 retains every map value and its recorded revision through load and repair")
	Progression.clear_saved_run()
	Progression.set_run_storage_path(Progression.DEFAULT_RUN_STORAGE_PATH)

static func _test_layout_contract(expect: Callable) -> void:
	var node: Dictionary = {"coord": Vector2i(3, 4), "type": "combat", "map_step": 2, "map_lane": 4}
	var point: Vector2 = MapPanel._node_position(node, {"room_count": 12, "lane_count": 5}, PROOF_FIELD_SIZE, true)
	var base_y: float = 116 + (PROOF_FIELD_SIZE.y - 232) * 4.0 / 4.0
	expect.call(absf(point.y - base_y) <= 12, "Revision 5 uses lane / 4 and clamps existing jitter")
	var info5: Dictionary = {"room_count": 12, "lane_count": 5}
	var boss_x: float = 80 + (PROOF_FIELD_SIZE.x - 204)
	var column_step: float = (boss_x - 175 - 80) / 11.0
	for step: int in range(13):
		var column: Dictionary = {"type": "boss" if step == 12 else "start", "map_step": step, "map_lane": 2}
		var expected_x: float = boss_x if step == 12 else 80 + column_step * float(step)
		expect.call(is_equal_approx(MapPanel._node_position(column, info5, PROOF_FIELD_SIZE, true).x, expected_x), "Revision 5 evenly spaces entry through last interior column and retains boss centre")
	for offset: int in range(FINAL_JITTER_SAMPLE_COUNT):
		var hearth: Dictionary = {"coord": Vector2i(offset, 0), "type": "campfire", "map_step": 11, "map_lane": 2}
		expect.call(boss_x - MapPanel._node_position(hearth, info5, PROOF_FIELD_SIZE, true).x >= 175 - GAP_TOLERANCE, "Final interior jitter preserves the approved boss gap")
	for lanes: int in [3, 4]:
		var info: Dictionary = {"room_count": 11, "lane_count": lanes}
		var old: Vector2 = Vector2(80 + (PROOF_FIELD_SIZE.x - 204) * 2.0 / 11.0, 116 + (PROOF_FIELD_SIZE.y - 232) * 4.0 / float(lanes - 1))
		if lanes == 4: old += MapPanel._node_jitter(node["coord"])
		expect.call(MapPanel._node_position(node, info, PROOF_FIELD_SIZE, lanes == 4).is_equal_approx(old), "Legacy layout divisors and jitter remain unchanged")

static func _test_panel_before_ready(state: Dictionary, expect: Callable) -> void:
	var history: Dictionary = state.duplicate()
	history["current_room"] = Graph.section(state, 2)["entry"]
	var panel := MapPanel.new()
	panel.set_run_state(history)
	panel.select_section(0)
	expect.call(not panel._built and panel._tabs == null and panel.viewed_section == 0, "Selecting reached history before ready retains the section without touching unbuilt tabs")
	panel.select_section(3)
	panel.select_section(-1)
	expect.call(panel.viewed_section == 0, "Pre-ready history selection still rejects unreached or invalid sections")
	panel.free()
