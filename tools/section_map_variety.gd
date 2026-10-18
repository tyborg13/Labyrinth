extends SceneTree

const Graph = preload("res://scripts/section_map_graph.gd")
const Audit = preload("res://tools/section_map_revision4_audit.gd")
const BASELINE_PATH: String = "res://tests/fixtures/map_02_revision4_baseline.json"
const DEFAULT_SEED_COUNT: int = 200
const BEFORE_FIX_PATH: String = "res://tests/fixtures/fix_05_revision5_before_metrics.json"

func _initialize() -> void:
	var seed_count: int = DEFAULT_SEED_COUNT
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for offset: int in range(args.size() - 1):
		if args[offset] == "--seeds": seed_count = int(args[offset + 1])
	if not args.has("--revision4"):
		_measure_revision5(seed_count, args)
		return
	var stats: Dictionary = {}
	var hashes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASELINE_PATH))["hashes"] if args.has("--audit-only") else {}
	var signatures: Array = []
	var routes: Array[int] = []
	var types: Dictionary = {}
	var wide: int = 0
	var long_divergence: int = 0
	for index: int in range(6): signatures.append({})
	for seed_value: int in range(1, seed_count + 1):
		var state: Dictionary = {"seed": seed_value, "current_room": Vector2i.ZERO, "mode": "room"}
		if not args.has("--audit-only"):
			Graph._initialize_revision_4(state)
			hashes[str(seed_value)] = var_to_str(state).sha256_text()
		for index: int in range(6):
			var layout: Dictionary = Audit.generate(seed_value, index, stats)
			if not args.has("--audit-only"): assert(layout["walks"] == Graph.section(state, index)["walks"], "Audit reproduces revision 4 walks")
			for node: Dictionary in state.get("rooms", {}).values():
				if int(node["section_index"]) == index and int(node["map_step"]) > 0 and int(node["map_step"]) < Graph.ROOM_COUNTS[index]:
					assert(layout["nodes"][Vector2i(node["map_step"], node["map_lane"])]["type"] == node["type"], "Audit reproduces revision 4 types")
			var strings: Array[String] = []
			for walk: Array in layout["walks"]:
				var lanes: String = ""
				for lane: int in walk: lanes += str(lane)
				strings.append(lanes)
			signatures[index]["|".join(strings)] = true
			routes.append(_route_count(layout, Graph.ROOM_COUNTS[index]))
			var max_width: int = 0
			for row: Array in layout["rows"].values(): max_width = maxi(max_width, row.size())
			wide += int(max_width >= 4)
			long_divergence += int(_long_divergence(layout))
			for node: Dictionary in layout["nodes"].values(): Audit.bump(types, node["type"])
		if seed_value % 10 == 0: print("Revision 4 audit: %d/%d seeds" % [seed_value, seed_count])
	routes.sort()
	var distinct: Array[int] = []
	for seen: Dictionary in signatures: distinct.append(seen.size())
	var report: Dictionary = {"seed_count": seed_count, "stats": stats, "distinct_signatures": distinct, "median_routes": _median(routes), "wide_sections": wide, "long_divergence_sections": long_divergence, "types": types, "hashes": hashes}
	if args.has("--record-baseline"):
		var file := FileAccess.open(BASELINE_PATH, FileAccess.WRITE)
		file.store_string(JSON.stringify(report, "\t"))
		print("Revision 4 baseline: " + BASELINE_PATH)
	report.erase("hashes")
	print(JSON.stringify(report))
	quit()

static func measure(seed_count: int, verbose: bool = false, first_seed: int = 1) -> Dictionary:
	var stats: Dictionary = {"enabled": true}
	var signatures: Array = []
	var routes: Array[int] = []
	var types: Dictionary = {}
	var wide: int = 0
	var divergence: int = 0
	var valid: int = 0
	for index: int in range(6): signatures.append({})
	for seed_value: int in range(first_seed, first_seed + seed_count):
		for index: int in range(6):
			var rng := RandomNumberGenerator.new()
			rng.seed = absi(seed_value * 7919 + index * 104729 + 3491)
			var count: int = Graph.ROOM_COUNTS[index]
			var started: int = Time.get_ticks_msec()
			if verbose: print("SOLVING seed=%d section=%d" % [seed_value, index + 1])
			var layout: Dictionary = Graph._section_layout_v5(rng, seed_value, index, stats)
			if verbose: print("SOLVED ", stats, " msec=", Time.get_ticks_msec() - started)
			var strings: Array[String] = []
			for walk: Array in layout["walks"]:
				var lanes: String = ""
				for lane: int in walk: lanes += str(lane)
				strings.append(lanes)
			signatures[index]["|".join(strings)] = true
			routes.append(_route_count(layout, count))
			var max_width: int = 0
			for row: Array in layout["rows"].values(): max_width = maxi(max_width, row.size())
			wide += int(max_width >= 4)
			divergence += int(_long_divergence(layout))
			var legal: bool = Graph._complete_types_legal(layout, count, Graph.FIGHT_COUNTS[index] - 1)
			for cell: Vector2i in layout["order"]:
				legal = legal and Graph._prefix_type_legal(layout, cell, count, Graph.FIGHT_COUNTS[index] - 1)
				Audit.bump(types, layout["nodes"][cell]["type"])
			valid += int(legal)
		if seed_value % 10 == 0: print("Revision 5 variety: %d/%d seeds" % [seed_value, seed_count])
	routes.sort()
	var distinct: Array[int] = []
	for seen: Dictionary in signatures: distinct.append(seen.size())
	var report: Dictionary = {"seed_count": seed_count, "stats": stats, "distinct_signatures": distinct, "median_routes": _median(routes), "wide_sections": wide, "long_divergence_sections": divergence, "valid_sections": valid, "types": types}
	return report

func _measure_revision5(seed_count: int, args: PackedStringArray) -> void:
	var first_seed: int = 1
	for offset: int in range(args.size() - 1):
		if args[offset] == "--first-seed": first_seed = int(args[offset + 1])
	var report: Dictionary = measure(seed_count, args.has("--verbose"), first_seed)
	var output: String = "user://map_02_variety.json"
	for offset: int in range(args.size() - 1):
		if args[offset] == "--output": output = args[offset + 1]
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	print("Revision 5 report: " + ProjectSettings.globalize_path(output))
	var failures: Array[String] = metric_failures(report)
	_print_comparison(report)
	for failure: String in failures: print("METRIC FAIL: " + failure)
	print("Section map variety metrics: %s (%d seeds x 6 sections)" % ["PASS" if failures.is_empty() else "FAIL", seed_count])
	quit(0 if failures.is_empty() else 1)

static func metric_failures(report: Dictionary) -> Array[String]:
	var failures: Array[String] = []
	var seeds: int = int(report["seed_count"])
	var sections: int = seeds * 6
	if int(report["stats"].get("fallback", 0)) > sections * 0.01: failures.append("Fallback rate exceeds 1%")
	for distinct: int in report["distinct_signatures"]:
		if distinct < seeds * 0.95: failures.append("Distinct topology signatures below 95%")
	if float(report["median_routes"]) < 12 or float(report["median_routes"]) > 40: failures.append("Median route count outside 12..40")
	if int(report["wide_sections"]) < sections * 0.8: failures.append("Wide rows below 80%")
	if int(report["long_divergence_sections"]) != sections: failures.append("Long divergence below 100%")
	if int(report["valid_sections"]) != sections: failures.append("Existing route/section constraints below 100%")
	var targets: Dictionary = {"combat": 46.0, "mystery": 16.2, "treasure": 9.0, "campfire": 8.9, "guardian": 6.5, "scavenger": 5.7, "event": 5.2, "graftwright": 2.4}
	var total: int = 0
	for value: int in report["types"].values(): total += value
	for type: String in targets:
		var frequency: float = 100.0 * int(report["types"].get(type, 0)) / float(total)
		if absf(frequency - float(targets[type])) > 3.0: failures.append("%s frequency %.2f%% differs from triage by >3pp" % [type, frequency])
	return failures

static func _median(sorted_values: Array[int]) -> float:
	return (float(sorted_values[(sorted_values.size() - 1) / 2]) + float(sorted_values[sorted_values.size() / 2])) * 0.5

static func _print_comparison(after: Dictionary) -> void:
	var revision4: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASELINE_PATH))
	var before: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BEFORE_FIX_PATH))
	print("| Metric | Revision 4 | Revision 5 before fix | Revision 5 after fix |")
	print("| --- | --- | --- | --- |")
	print("| Accepted canned topology | %d/%d | %d/%d | %d/%d |" % [int(revision4["stats"].get("accepted_canned_topology", 0)), int(revision4["seed_count"]) * 6, int(before["stats"].get("fallback", 0)), int(before["seed_count"]) * 6, int(after["stats"].get("fallback", 0)), int(after["seed_count"]) * 6])
	for metric: String in ["distinct_signatures", "median_routes", "wide_sections", "long_divergence_sections"]:
		print("| %s | %s | %s | %s |" % [metric, str(revision4[metric]), str(before[metric]), str(after[metric])])
	var totals: Array[int]
	for report: Dictionary in [revision4, before, after]:
		var total: int = 0
		for value: int in report["types"].values(): total += value
		totals.append(total)
	for type: String in Graph.TYPE_WEIGHTS.keys() + ["treasure", "campfire"]:
		print("| %s | %.2f%% | %.2f%% | %.2f%% |" % [type, 100.0 * int(revision4["types"].get(type, 0)) / float(totals[0]), 100.0 * int(before["types"].get(type, 0)) / float(totals[1]), 100.0 * int(after["types"].get(type, 0)) / float(totals[2])])

static func _route_count(layout: Dictionary, count: int) -> int:
	var paths: Dictionary = {}
	var total: int = 0
	for cell: Vector2i in layout["order"]:
		var incoming: Array = layout["parents"].get(cell, [])
		var value: int = 1 if incoming.is_empty() else 0
		for parent: Vector2i in incoming: value += int(paths[parent])
		paths[cell] = value
		if cell.x == count - 1: total += value
	return total

static func _long_divergence(layout: Dictionary) -> bool:
	# Pair-state dynamic programming includes recombined routes, not just walks.
	var pairs: Dictionary = {}
	for lane_a: int in layout["rows"][1]:
		for lane_b: int in layout["rows"][1]: pairs[Vector2i(lane_a, lane_b)] = int(lane_a != lane_b)
	for step: int in range(1, layout["rows"].size()):
		var next: Dictionary = {}
		for pair: Vector2i in pairs:
			for a: Vector2i in layout["children"].get(Vector2i(step, pair.x), []):
				for b: Vector2i in layout["children"].get(Vector2i(step, pair.y), []):
					var length: int = int(pairs[pair]) + 1 if a != b else 0
					if length >= 4: return true
					var key := Vector2i(a.y, b.y)
					next[key] = maxi(int(next.get(key, 0)), length)
		pairs = next
	return false
