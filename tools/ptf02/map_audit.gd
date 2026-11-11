extends SceneTree

# Run before and after the implementation with the same seed inventory. Counts
# are physical rooms (fights also includes hidden fights, Guardians and specials).
const Graph = preload("res://scripts/section_map_graph.gd")
const Rules = preload("res://tools/ptf02/map_rules.gd")
const SEED_COUNT: int = 500
const OUTPUT_DIR: String = "/private/tmp/labyrinth_codex/ptf-02"
const ROOM_TYPES: Array = ["combat", "event", "scavenger", "treasure", "graftwright", "guardian", "special", "mystery", "campfire"]
var _violations: Dictionary = {}
var _graph: Script = Graph

func _initialize() -> void:
	var phase: String = "after"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--phase="): phase = argument.trim_prefix("--phase=")
		if argument.begins_with("--baseline-source="): _graph = load(argument.trim_prefix("--baseline-source="))
	var report: Dictionary = {"phase": phase, "seeds": SEED_COUNT, "sections": [], "routes_without_mid_hearth": 0, "routes_with_multiple_mid_hearths": 0, "routes": 0, "generation_failures": 0, "fallback_sections": 0}
	report["source_sha256"] = _graph.get_source_code().sha256_text()
	var times: Array[int]
	var run_times: Array[int]
	for index: int in range(6):
		var counts: Dictionary = {"fights": 0}
		for type: String in ROOM_TYPES: counts[type] = 0
		report["sections"].append({"section": index + 1, "counts": counts, "fallbacks": 0, "generation_usec": [], "routes": 0, "fights_per_route_histogram": {}, "total_route_fights": 0})
	for seed_value: int in range(1, SEED_COUNT + 1):
		var state: Dictionary = {"seed": seed_value, "current_room": Vector2i.ZERO, "mode": "room"}
		var diagnostics: Dictionary = {"enabled": true}
		var started: int = Time.get_ticks_usec()
		_graph.initialize(state, diagnostics)
		run_times.append(Time.get_ticks_usec() - started)
		if (state.get("map_sections", []) as Array).size() != 6:
			report["generation_failures"] += 1
			continue
		for index: int in range(6):
			var summary: Dictionary = report["sections"][index]
			var detail: Dictionary = diagnostics["sections"][index]
			var elapsed: int = int(detail["generation_usec"])
			times.append(elapsed)
			summary["generation_usec"].append(elapsed)
			summary["fallbacks"] += int(int(detail.get("fallback", 0)) > 0)
			report["fallback_sections"] += int(int(detail.get("fallback", 0)) > 0)
			for node: Dictionary in state["rooms"].values():
				if int(node["section_index"]) != index or not ROOM_TYPES.has(node["type"]): continue
				summary["counts"][node["type"]] += 1
				if Graph._is_fight(node): summary["counts"]["fights"] += 1
			var routes: Dictionary = _routes(state, Graph.section(state, index)["entry"], index, {})
			if phase == "after": Rules.validate(state, index, Callable(self, "_expect"))
			for outcome: Vector2i in routes:
				var route_count: int = int(routes[outcome])
				report["routes"] += route_count
				if outcome.x == 0: report["routes_without_mid_hearth"] += route_count
				if outcome.x > 1: report["routes_with_multiple_mid_hearths"] += route_count
				var histogram: Dictionary = summary["fights_per_route_histogram"]
				histogram[outcome.y] = int(histogram.get(outcome.y, 0)) + route_count
				summary["routes"] += route_count
				summary["total_route_fights"] += outcome.y * route_count
		if seed_value % 100 == 0: print("PTF02 audit %s: %d/%d seeds" % [phase, seed_value, SEED_COUNT])
	for summary: Dictionary in report["sections"]:
		var samples: Array = summary["generation_usec"]
		samples.sort()
		summary["generation_usec"] = _percentiles(samples)
		summary["fallback_rate"] = float(summary["fallbacks"]) / SEED_COUNT
		# Pool all distinct routes over the seed inventory: each route has equal
		# weight, including recombinations at merges, rather than each seed.
		summary["mean_fights_per_route"] = float(summary["total_route_fights"]) / int(summary["routes"])
	times.sort()
	run_times.sort()
	report["generation_usec"] = _percentiles(times)
	report["run_generation_usec"] = _percentiles(run_times)
	report["generation_failure_rate"] = float(report["generation_failures"]) / SEED_COUNT
	report["fallback_rate"] = float(report["fallback_sections"]) / (SEED_COUNT * 6)
	report["rule_violations"] = _violations
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	var path: String = OUTPUT_DIR.path_join("map_audit_" + phase + ".json")
	FileAccess.open(path, FileAccess.WRITE).store_string(JSON.stringify(report, "\t") + "\n")
	print("PTF02 AUDIT %s: routes_without_mid_hearth=%d multiple=%d failures=%d fallbacks=%d p50_usec=%d p99_usec=%d" % [phase, report["routes_without_mid_hearth"], report["routes_with_multiple_mid_hearths"], report["generation_failures"], report["fallback_sections"], report["generation_usec"]["p50"], report["generation_usec"]["p99"]])
	print("PTF02 audit report: " + path)
	print("PTF02 AUDIT RULES: %d violations" % _violations.size())
	quit(1 if not _violations.is_empty() or int(report["generation_failures"]) > 0 or (phase == "after" and int(report["routes_without_mid_hearth"]) + int(report["routes_with_multiple_mid_hearths"]) > 0) else 0)

func _expect(ok: bool, message: String) -> void:
	if not ok: _violations[message] = int(_violations.get(message, 0)) + 1

func _percentiles(samples: Array) -> Dictionary:
	return {"p50": samples[ceili(samples.size() * 0.50) - 1], "p99": samples[ceili(samples.size() * 0.99) - 1]}

func _routes(state: Dictionary, coord: Vector2i, index: int, memo: Dictionary) -> Dictionary:
	if memo.has(coord): return memo[coord]
	var node: Dictionary = Graph.room(state, coord)
	# Joint suffix histogram: x counts midpoint Hearths, y counts non-boss
	# fights. Terminating at the boss excludes it and the next section.
	if str(node["type"]) == "boss": return {Vector2i.ZERO: 1}
	var increment := Vector2i(int(str(node["type"]) == "campfire" and int(node["depth"]) - index * 4 == 2), int(Graph._is_fight(node)))
	var result: Dictionary = {}
	for link: Dictionary in node["connections"]:
		var suffixes: Dictionary = _routes(state, link["coord"], index, memo)
		for outcome: Vector2i in suffixes:
			result[outcome + increment] = int(result.get(outcome + increment, 0)) + int(suffixes[outcome])
	memo[coord] = result
	return result
