extends RefCounted

const Graph = preload("res://scripts/section_map_graph.gd")
const MapPanel = preload("res://scripts/section_map_panel.gd")
const LAYOUT_SEEDS: PackedInt32Array = [1, 2, 5]
const PUBLIC_DISPATCH_SEED: int = 83
const STRUCTURAL_TIMEOUT_SECONDS: int = 10
const PROBE_SETUP_TIMEOUT_SECONDS: int = 10
const FIELD_SIZE: Vector2 = Vector2(1864, 823)
const ORDINARY_EXTENT: float = 61.0
const BOSS_EXTENT: float = 106.0
const MINIMUM_GAP: float = 8.0
const GAP_TOLERANCE: float = 0.001

static func run(expect: Callable) -> void:
	test_public_dispatch(expect)
	test_bounded_structures(expect)
	test_probe_ready(expect)
	for seed_value: int in LAYOUT_SEEDS:
		var state: Dictionary = {"seed": seed_value, "current_room": Vector2i.ZERO, "mode": "room"}
		Graph.initialize(state)
		test_layout_gaps(state, expect)

static func test_public_dispatch(expect: Callable) -> void:
	for revision: int in [3, 4]:
		var recorded: Dictionary = {"seed": PUBLIC_DISPATCH_SEED, "current_room": Vector2i.ZERO, "mode": "room"}
		if revision == 3: Graph._initialize_revision_3(recorded)
		else: Graph._initialize_revision_4(recorded)
		var serialized: String = var_to_str(recorded)
		var loaded: Dictionary = str_to_var(serialized)
		var expected_map: String = _map_snapshot(loaded)
		Graph.initialize(loaded)
		# Initialization appends its existing analytics events; compare every map
		# value and the saved revision without changing that established behavior.
		expect.call(_map_snapshot(loaded) == expected_map, "Public initialize dispatch preserves the complete recorded revision-%d map byte-for-byte" % revision)
	print("Map 02 recorded revision dispatch: checked revisions 3 and 4 through initialize")

static func _map_snapshot(state: Dictionary) -> String:
	return var_to_str({"rooms": state["rooms"], "map_sections": state["map_sections"], "section_map_layout_revision": state["section_map_layout_revision"]})

static func test_bounded_structures(expect: Callable) -> void:
	# A broken bound must fail in seconds, even when invoked by the full suite.
	var result: Dictionary = _run_child("section_map_structural_rejection_test.gd", STRUCTURAL_TIMEOUT_SECONDS)
	var log_text: String = result["log"]
	expect.call(result["code"] == 0 and log_text.contains("Section map structural rejection: PASS"), "Forced structural rejection finishes within %ds and exhausts all bounded attempts" % STRUCTURAL_TIMEOUT_SECONDS)
	expect.call(log_text.count("SECTION MAP V5 FALLBACK ") == 1, "Forced structural rejection logs exactly one fallback")
	print(log_text)

static func test_probe_ready(expect: Callable) -> void:
	var result: Dictionary = _run_child("section_map_variety_probe.gd", PROBE_SETUP_TIMEOUT_SECONDS, PackedStringArray(["--debug-reveal-section", "--setup-only"]))
	expect.call(result["code"] == 0 and str(result["log"]).contains("Map 02 probe setup: PASS"), "Map proof defers startup and awaits panel ready before layout frame waits")
	print(result["log"])

static func _run_child(script_name: String, timeout_seconds: int, user_args: PackedStringArray = PackedStringArray()) -> Dictionary:
	var output: Array = []
	var args: PackedStringArray = [
		ProjectSettings.globalize_path("res://tools/godot_task_runner.py"),
		"--project", ProjectSettings.globalize_path("res://"), "--task-id", "map-02",
		"--timeout", str(timeout_seconds), "--stream", "--",
		OS.get_executable_path(), "--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://tests/" + script_name
	]
	if not user_args.is_empty():
		args.append("--")
		args.append_array(user_args)
	var code: int = OS.execute("python3", args, output, true)
	var log_text: String = ""
	for chunk: String in output: log_text += chunk
	return {"code": code, "log": log_text}

static func test_layout_gaps(state: Dictionary, expect: Callable) -> void:
	var violations: int = 0
	var first_failure: String = ""
	for index: int in range(6):
		var info: Dictionary = Graph.section(state, index)
		var rectangles: Array = []
		for node: Dictionary in state["rooms"].values():
			if int(node["section_index"]) != index: continue
			var extent: float = BOSS_EXTENT if node["type"] == "boss" else ORDINARY_EXTENT
			var point: Vector2 = MapPanel._node_position(node, info, FIELD_SIZE, true)
			rectangles.append(Rect2(point - Vector2.ONE * extent, Vector2.ONE * extent * 2.0))
		for a: int in range(rectangles.size()):
			for b: int in range(a + 1, rectangles.size()):
				var first: Rect2 = rectangles[a]
				var second: Rect2 = rectangles[b]
				var dx: float = maxf(0, maxf(first.position.x - second.end.x, second.position.x - first.end.x))
				var dy: float = maxf(0, maxf(first.position.y - second.end.y, second.position.y - first.end.y))
				var gap: float = Vector2(dx, dy).length()
				if gap + GAP_TOLERANCE >= MINIMUM_GAP: continue
				violations += 1
				if first_failure.is_empty(): first_failure = "section=%d gap=%.3fpx" % [index + 1, gap]
	expect.call(violations == 0, "Focused jitter-clamp gaps seed=%d: %d violations %s" % [int(state["seed"]), violations, first_failure])
	print("Map 02 focused jitter-clamp gaps: %d violations (seed %d)" % [violations, int(state["seed"])])
