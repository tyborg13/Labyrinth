extends RefCounted

const Graph = preload("res://scripts/section_map_graph.gd")
const Benchmark = preload("res://tools/section_map_performance.gd")
const Regression = preload("res://tests/suites/section_map_regression_suite.gd")
const REJECTION_TIMEOUT_SECONDS: int = 10

static func run(expect: Callable) -> void:
	_test_seed_fixtures(expect)
	_test_forward_checks(expect)
	_test_memo_and_cutoff(expect)
	var rejection: Dictionary = Regression._run_child("section_map_type_rejection_test.gd", REJECTION_TIMEOUT_SECONDS)
	expect.call(rejection["code"] == 0 and str(rejection["log"]).contains("Section map type rejection: PASS"), "Type-budget exhaustion consumes the bounded topology attempts")
	expect.call(str(rejection["log"]).count("SECTION MAP V5 FALLBACK ") == 1, "Type-budget exhaustion logs exactly one fallback")
	print(rejection["log"])
	var seeds: Array = JSON.parse_string(FileAccess.get_file_as_string(Benchmark.FAST_SEED_PATH))
	var report: Dictionary = Benchmark.measure(seeds, false)
	# Wall-clock thresholds belong to the standalone sweep, where load is
	# controlled. The committed regression bounds deterministic search work.
	var fallback_within_limit: bool = report["fallback"] <= seeds.size() * Graph.ROOM_COUNTS.size() * Benchmark.FALLBACK_LIMIT
	expect.call(fallback_within_limit, "Fallback rate stays within the sweep's limit")
	expect.call(report["max_attempt_nodes"] <= Graph.V5_TYPE_NODE_BUDGET, "Every type assignment respects its deterministic node budget")
	# Exercise the ordinary public call too: diagnostics must not enter saves or
	# influence the generated graph, and all 21 cases retain complete map rules.
	for sample: Dictionary in report["samples"]:
		var max_nodes: int = 0
		for stats: Dictionary in sample["diagnostics"]:
			max_nodes = maxi(max_nodes, int(stats.get("max_attempt_nodes", 0)))
		print("SECTION MAP NODE BUDGET: seed=%d max_attempt_nodes=%d" % [int(sample["seed"]), max_nodes])
		var first: Dictionary = {"seed": int(sample["seed"]), "current_room": Vector2i.ZERO, "mode": "room"}
		var diagnostics: Dictionary = {"enabled": true}
		Graph.initialize(first, diagnostics)
		var second: Dictionary = {"seed": int(sample["seed"]), "current_room": Vector2i.ZERO, "mode": "room"}
		Graph.initialize(second)
		expect.call(var_to_str(first) == var_to_str(second), "Same 32-bit seed gives a byte-identical graph with or without diagnostics: %d" % int(sample["seed"]))
		for index: int in range(6): _test_rules(first, index, expect)
	print("Section map fast performance: %s (%d seeds x 6 sections; max attempt %d/%d nodes; fallback %d; max section %.3fms; max run %.3fms)" % ["PASS" if fallback_within_limit and report["max_attempt_nodes"] <= Graph.V5_TYPE_NODE_BUDGET else "FAIL", seeds.size(), report["max_attempt_nodes"], Graph.V5_TYPE_NODE_BUDGET, report["fallback"], report["all_sections"]["max_ms"], report["runs"]["max_ms"]])

static func _test_seed_fixtures(expect: Callable) -> void:
	var seeds: Array = JSON.parse_string(FileAccess.get_file_as_string(Benchmark.SEED_PATH))
	var seen: Dictionary = {}
	for value: Variant in seeds:
		var seed_value: int = int(value)
		expect.call(seed_value >= 0 and seed_value <= 0xffffffff, "Sweep seeds span the unsigned 32-bit range")
		seen[seed_value] = true
	expect.call(seeds.size() == 2000 and seen.size() == 2000 and seen.has(Benchmark.REGRESSION_SEED), "Fixed sweep contains 2,000 distinct 32-bit seeds including the New Game hang")
	var fast: Array = JSON.parse_string(FileAccess.get_file_as_string(Benchmark.FAST_SEED_PATH))
	var summary: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/fix_05_performance_summary.json"))
	var expected: Dictionary = {Benchmark.REGRESSION_SEED: true}
	for sample: Dictionary in summary["slowest_runs"]: expected[int(sample["seed"])] = true
	var actual: Dictionary = {}
	for value: Variant in fast:
		actual[int(value)] = true
		expect.call(seen.has(int(value)), "Fast regression seeds come from the fixed sweep")
	expect.call(actual == expected and fast.size() == actual.size() and summary["slowest_runs"].size() == 20, "Fast suite contains the hang seed plus exactly the sweep's 20 slowest full runs")

static func _test_forward_checks(expect: Callable) -> void:
	var parent := Vector2i.ZERO
	var children: Array = [Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2)]
	var layout: Dictionary = {"children": {parent: children}, "positions": {children[0]: 0, children[1]: 1, children[2]: 2}}
	expect.call(not Graph._fork_types_possible_v5(layout, [["mystery", "event"], ["mystery", "event"], ["mystery", "event"]]), "Forward checking rejects three fork children with only two service colours before branching")
	expect.call(Graph._fork_types_possible_v5(layout, [["combat"], ["combat"], ["combat"]]), "Three-way Combat repetition remains legal")
	layout["children"][parent] = children.slice(0, 2)
	expect.call(not Graph._fork_types_possible_v5(layout, [["combat"], ["combat"], ["combat"]]), "Two-way Combat repetition remains illegal")
	expect.call(not Graph._section_counts_v5([["guardian", "scavenger"], ["guardian", "event"]])["possible"], "Overlapping forced section counts reject an impossible partial assignment")
	var counts: Dictionary = Graph._section_counts_v5([["guardian"], ["guardian", "event"], ["scavenger", "event"]])
	expect.call(counts["possible"] and counts["forced"] == {1: "guardian", 2: "scavenger"}, "Section counts force the remaining Guardian and Scavenger witnesses")
	var route: Dictionary = Graph._fallback_layout(10, 5)
	route["positions"] = {}
	var domains: Array = []
	for cell: Vector2i in route["order"]:
		route["positions"][cell] = domains.size()
		domains.append([route["nodes"][cell]["type"]])
	expect.call(Graph._propagate_types_v5(route, domains.duplicate(true), 10, 5), "Forward checks accept a complete legal route assignment")
	for offset: int in range(domains.size()):
		var cell: Vector2i = route["order"][offset]
		if cell.x in [3, 5] and cell.y == 0: domains[offset] = ["guardian"]
	expect.call(not Graph._propagate_types_v5(route, domains, 10, 5), "Per-route forward checking rejects two Guardians on a route")

static func _test_memo_and_cutoff(expect: Callable) -> void:
	var layout: Dictionary = {"solver_nodes": 0}
	var search: Dictionary = {"remaining": 0, "failed": {}}
	expect.call(not Graph._solve_types_v5(layout, [], 10, 5, search) and search.get("exhausted", false), "Zero remaining nodes cuts off before propagation")
	expect.call(layout["solver_nodes"] == 0 and search["failed"].is_empty(), "A budget cutoff spends no extra node and is never memoised as unsatisfiable")
	# The empty layout fails the required section counts after propagation.
	layout = {"order": [], "parents": {}, "children": {}, "nodes": {}, "positions": {}}
	search = {"remaining": 2, "failed": {}}
	expect.call(not Graph._solve_types_v5(layout, [], 10, 5, search), "Impossible partial assignment fails")
	expect.call(search["failed"].has(Graph._type_signature_v5([])), "Proved failed partial assignment enters the canonical memo")
	expect.call(not Graph._solve_types_v5(layout, [], 10, 5, search) and int(search.get("memo_hits", 0)) == 1, "Repeated failed state uses the memo")
	expect.call(Graph._type_signature_v5([["event", "mystery"]]) == Graph._type_signature_v5([["mystery", "event"]]), "Memo keys ignore candidate preference order")

static func _test_rules(state: Dictionary, index: int, expect: Callable) -> void:
	var info: Dictionary = Graph.section(state, index)
	var count: int = Graph.ROOM_COUNTS[index]
	var layout: Dictionary = Graph._layout_from_walks(info["walks"], count)
	for node: Dictionary in state["rooms"].values():
		if int(node["section_index"]) != index or int(node["map_step"]) in [0, count]: continue
		var solver_node: Dictionary = node.duplicate(true)
		# Specials substitute ordinary combat only after this solver runs.
		# Check the solver's original domains here; the special suite checks
		# distinct special identities and all post-substitution route limits.
		if str(solver_node["type"]) == "special": solver_node["type"] = "combat"
		layout["nodes"][Vector2i(node["map_step"], node["map_lane"])] = solver_node
	for cell: Vector2i in layout["order"]:
		Graph._prefix_bounds(layout, cell)
		expect.call(Graph._prefix_type_legal(layout, cell, count, Graph.FIGHT_COUNTS[index] - 1), "Slow-seed regression preserves all prefix, fork and eligibility rules")
	expect.call(Graph._complete_types_legal(layout, count, Graph.FIGHT_COUNTS[index] - 1), "Slow-seed regression preserves all route and section counts")
