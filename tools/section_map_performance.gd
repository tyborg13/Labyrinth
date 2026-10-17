extends SceneTree

const Graph = preload("res://scripts/section_map_graph.gd")
const SEED_PATH: String = "res://tests/fixtures/fix_05_performance_seeds.json"
const FAST_SEED_PATH: String = "res://tests/fixtures/fix_05_slow_seeds.json"
const REGRESSION_SEED: int = 1792271957
const SLOW_SEED_COUNT: int = 20
const SECTION_LIMIT_MS: float = 250.0
const ATTEMPT_TARGET_MS: float = 50.0
const RUN_LIMIT_MS: float = 1000.0
const FALLBACK_LIMIT: float = 0.01
const PROGRESS_INTERVAL: int = 100
const DEFAULT_OUTPUT: String = "user://fix_05_performance.json"

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var seed_path: String = FAST_SEED_PATH if args.has("--fast") else SEED_PATH
	var seeds: Array = JSON.parse_string(FileAccess.get_file_as_string(seed_path))
	var output: String = DEFAULT_OUTPUT
	for offset: int in range(args.size() - 1):
		if args[offset] == "--output": output = args[offset + 1]
	var report: Dictionary = measure(seeds)
	if report["max_attempt_usec"] >= ATTEMPT_TARGET_MS * 1000.0:
		report["failures"].append("Type-assignment attempt exceeded the 50ms calibration target")
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write section-map performance report: " + output)
		quit(1)
		return
	file.store_string(JSON.stringify(report, "\t") + "\n")
	if args.has("--record-fast"):
		var slow: Array = report["slowest_runs"].slice(0, SLOW_SEED_COUNT)
		var fast: Array[int]
		fast.append(REGRESSION_SEED)
		for sample: Dictionary in slow:
			if not fast.has(int(sample["seed"])): fast.append(int(sample["seed"]))
		var fixture := FileAccess.open(FAST_SEED_PATH, FileAccess.WRITE)
		fixture.store_string(JSON.stringify(fast, "\t") + "\n")
	print("| Section | Max ms | p99 ms | Mean ms | Fallback |")
	print("| --- | ---: | ---: | ---: | ---: |")
	for index: int in range(6):
		var summary: Dictionary = report["sections"][index]
		print("| %d | %.3f | %.3f | %.3f | %d/%d |" % [index + 1, summary["max_ms"], summary["p99_ms"], summary["mean_ms"], summary["fallback"], seeds.size()])
	print("SECTION MAP PERFORMANCE: %s (%d seeds x 6 sections; max section %.3fms; max run %.3fms; fallback %d/%d; max attempt %.3fms / %d nodes)" % ["PASS" if report["failures"].is_empty() else "FAIL", seeds.size(), report["all_sections"]["max_ms"], report["runs"]["max_ms"], report["fallback"], seeds.size() * 6, report["max_attempt_usec"] / 1000.0, report["max_attempt_nodes"]])
	for failure: String in report["failures"]: print("PERFORMANCE FAIL: " + failure)
	print("Section map performance report: " + ProjectSettings.globalize_path(output))
	quit(0 if report["failures"].is_empty() else 1)

static func measure(seeds: Array, verbose: bool = true) -> Dictionary:
	var times: Array = []
	var fallbacks: Array[int]
	for index: int in range(6):
		times.append([])
		fallbacks.append(0)
	var all_times: Array = []
	var run_times: Array = []
	var samples: Array = []
	var failures: Array[String]
	var max_attempt_usec: int = 0
	var max_attempt_nodes: int = 0
	var completed: int = 0
	var total_fallback: int = 0
	for value: Variant in seeds:
		var seed_value: int = int(value)
		var state: Dictionary = {"seed": seed_value, "current_room": Vector2i.ZERO, "mode": "room"}
		var diagnostics: Dictionary = {"enabled": true}
		var started: int = Time.get_ticks_usec()
		Graph.initialize(state, diagnostics)
		var elapsed_ms: float = (Time.get_ticks_usec() - started) / 1000.0
		run_times.append(elapsed_ms)
		var section_times: Array = []
		for index: int in range(6):
			var stats: Dictionary = diagnostics["sections"][index]
			var section_ms: float = stats["generation_usec"] / 1000.0
			times[index].append(section_ms)
			all_times.append(section_ms)
			section_times.append(section_ms)
			fallbacks[index] += int(stats.get("fallback", 0))
			max_attempt_usec = maxi(max_attempt_usec, int(stats.get("max_attempt_usec", 0)))
			max_attempt_nodes = maxi(max_attempt_nodes, int(stats.get("max_attempt_nodes", 0)))
			if section_ms > SECTION_LIMIT_MS: failures.append("seed=%d section=%d %.3fms > %.0fms" % [seed_value, index + 1, section_ms, SECTION_LIMIT_MS])
		if elapsed_ms > RUN_LIMIT_MS: failures.append("seed=%d full run %.3fms > %.0fms" % [seed_value, elapsed_ms, RUN_LIMIT_MS])
		samples.append({"seed": seed_value, "run_ms": elapsed_ms, "section_ms": section_times, "diagnostics": diagnostics["sections"]})
		completed += 1
		if verbose and completed % PROGRESS_INTERVAL == 0: print("Section map performance: %d/%d seeds" % [completed, seeds.size()])
	var summaries: Array = []
	for index: int in range(6):
		var summary: Dictionary = _summary(times[index])
		summary["fallback"] = fallbacks[index]
		total_fallback += fallbacks[index]
		summaries.append(summary)
	if total_fallback > seeds.size() * 6 * FALLBACK_LIMIT: failures.append("Fallback rate exceeds 1%")
	var slow: Array = samples.duplicate()
	slow.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["run_ms"]) > float(b["run_ms"]) if a["run_ms"] != b["run_ms"] else int(a["seed"]) < int(b["seed"]))
	return {"seed_count": seeds.size(), "engine": Engine.get_version_info()["string"], "machine": OS.get_processor_name(), "sections": summaries, "all_sections": _summary(all_times), "runs": _summary(run_times), "fallback": total_fallback, "max_attempt_usec": max_attempt_usec, "max_attempt_nodes": max_attempt_nodes, "slowest_runs": slow.slice(0, SLOW_SEED_COUNT), "samples": samples, "failures": failures}

static func _summary(values: Array) -> Dictionary:
	var sorted: Array = values.duplicate()
	sorted.sort()
	var total: float = 0
	for value: float in sorted: total += value
	# Nearest-rank p99; samples are measured in microseconds, reported in ms.
	return {"max_ms": sorted[-1], "p99_ms": sorted[ceili(sorted.size() * 0.99) - 1], "mean_ms": total / sorted.size()}
