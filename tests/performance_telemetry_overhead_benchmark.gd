extends SceneTree

const PerformanceTelemetryScript = preload("res://scripts/performance_telemetry.gd")
const SteamServiceScript = preload("res://scripts/steam_service.gd")
const CombatEngineScript = preload("res://scripts/combat_engine.gd")
const RunSceneScript = preload("res://scripts/run_scene.gd")
const SAMPLES_PER_BATCH: int = 6000
const MEASURED_BATCHES: int = 9
const INSTRUMENTATION_CALLS: int = 20000

class FakeSteam:
	extends Object
	signal user_stats_stored(game_id: int, result: int)

	var stats: Dictionary = {}

	func loggedOn() -> bool:
		return true

	func getSteamID() -> String:
		return "76561198027391269"

	func getPersonaName() -> String:
		return "Benchmark"

	func getStatInt(stat_name: String) -> int:
		return int(stats.get(stat_name, 0))

	func setStatInt(stat_name: String, value: int) -> bool:
		stats[stat_name] = value
		return true

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var global_sampler: Node = root.get_node_or_null("PerformanceTelemetry")
	if global_sampler != null:
		global_sampler.set_process(false)
	var sampler: Node = PerformanceTelemetryScript.new()
	sampler.call("set_storage_dir_for_test", "user://performance_telemetry_overhead_benchmark")
	root.add_child(sampler)
	sampler.set_process(false)
	var fake_steam := FakeSteam.new()
	var fake_steam_service: Node = SteamServiceScript.new()
	fake_steam_service.call("_initialize_with_steam_for_test", fake_steam, {"status": 0})
	sampler.call("set_gameplay_context", {
		"mode": "combat",
		"room_depth": 14,
		"living_enemy_count": 6,
		"relic_count": 12,
		"card_targeting": true,
	})
	var durations_usec: Array[float] = []
	var flush_durations_usec: Array[float] = []
	var semantic_errors: Array[String] = []
	for batch_index: int in range(MEASURED_BATCHES + 1):
		var started_usec: int = Time.get_ticks_usec()
		for sample_index: int in range(SAMPLES_PER_BATCH):
			sampler.call("sample_frame_for_test", 16.0 + float(sample_index % 6))
		var duration_usec: int = Time.get_ticks_usec() - started_usec
		var flush_started_usec: int = Time.get_ticks_usec()
		var summary: Dictionary = sampler.call("flush_now", "overhead_benchmark") as Dictionary
		var steam_deltas: Dictionary = sampler.call(
			"steam_metric_deltas_for_test",
			summary,
			"Linux",
			true,
			true
		) as Dictionary
		var steam_status: Dictionary = fake_steam_service.call("accumulate_int_stats", steam_deltas) as Dictionary
		var flush_duration_usec: int = Time.get_ticks_usec() - flush_started_usec
		var frame_stats: Dictionary = summary.get("frame_interval_ms", {}) as Dictionary
		if int(frame_stats.get("sample_count", 0)) != SAMPLES_PER_BATCH:
			semantic_errors.append("sampler dropped frames in batch %d" % batch_index)
		if batch_index > 0:
			durations_usec.append(float(duration_usec))
			flush_durations_usec.append(float(flush_duration_usec))
		if (steam_status.get("accepted", []) as Array).is_empty():
			semantic_errors.append("fake Steam aggregate submission accepted no stats in batch %d" % batch_index)
	durations_usec.sort()
	flush_durations_usec.sort()
	var median_batch_usec: float = _percentile(durations_usec, 0.50)
	var p95_batch_usec: float = _percentile(durations_usec, 0.95)
	var median_flush_usec: float = _percentile(flush_durations_usec, 0.50)
	var p95_flush_usec: float = _percentile(flush_durations_usec, 0.95)
	var run_scene: Node = RunSceneScript.new()
	var combat_engine = CombatEngineScript.new()
	var run_scene_instrumentation: Dictionary = _measure_instrumentation_branch(run_scene)
	var combat_engine_instrumentation: Dictionary = _measure_instrumentation_branch(combat_engine)
	if p95_batch_usec / float(SAMPLES_PER_BATCH) > 10.0:
		semantic_errors.append("frame sampler exceeded 10 usec/frame p95 budget")
	if p95_flush_usec > 100000.0:
		semantic_errors.append("summary sort/write plus fake Steam updates exceeded 100 ms p95 budget")
	if float(run_scene_instrumentation.get("enabled_usec_per_call", 0.0)) > 10.0:
		semantic_errors.append("RunScene section instrumentation exceeded 10 usec/call budget")
	if float(combat_engine_instrumentation.get("enabled_usec_per_call", 0.0)) > 10.0:
		semantic_errors.append("CombatEngine section instrumentation exceeded 10 usec/call budget")
	var result: Dictionary = {
		"schema_version": 1,
		"workload_id": "performance_telemetry_sample_frame",
		"samples_per_batch": SAMPLES_PER_BATCH,
		"measured_batches": MEASURED_BATCHES,
		"median_batch_usec": median_batch_usec,
		"p95_batch_usec": p95_batch_usec,
		"median_usec_per_frame": median_batch_usec / float(SAMPLES_PER_BATCH),
		"p95_usec_per_frame": p95_batch_usec / float(SAMPLES_PER_BATCH),
		"median_percent_of_16_67_ms_budget": median_batch_usec / float(SAMPLES_PER_BATCH) / 16670.0 * 100.0,
		"flush_and_fake_steam_median_usec": median_flush_usec,
		"flush_and_fake_steam_p95_usec": p95_flush_usec,
		"flush_p95_percent_of_16_67_ms_budget": p95_flush_usec / 16670.0 * 100.0,
		"run_scene_section_instrumentation": run_scene_instrumentation,
		"combat_engine_section_instrumentation": combat_engine_instrumentation,
		"semantic_errors": semantic_errors,
	}
	run_scene.free()
	fake_steam_service.free()
	fake_steam.free()
	sampler.queue_free()
	await process_frame
	if semantic_errors.is_empty():
		print("PERFORMANCE TELEMETRY OVERHEAD RESULT: %s" % JSON.stringify(result))
		quit(0)
		return
	push_error("PERFORMANCE TELEMETRY OVERHEAD RESULT: FAIL %s" % JSON.stringify(result))
	quit(1)

func _percentile(sorted: Array[float], percentile: float) -> float:
	if sorted.is_empty():
		return 0.0
	var index: int = clampi(int(ceil(percentile * float(sorted.size()))) - 1, 0, sorted.size() - 1)
	return sorted[index]

func _measure_instrumentation_branch(target: Object) -> Dictionary:
	target.call("set_runtime_performance_instrumentation_enabled", false)
	var disabled_started_usec: int = Time.get_ticks_usec()
	for _index: int in range(INSTRUMENTATION_CALLS):
		target.call("_record_runtime_performance_phase", "benchmark", 0)
	var disabled_usec: int = Time.get_ticks_usec() - disabled_started_usec
	target.call("set_runtime_performance_instrumentation_enabled", true)
	var enabled_started_usec: int = Time.get_ticks_usec()
	for _index: int in range(INSTRUMENTATION_CALLS):
		var phase_started_usec: int = Time.get_ticks_usec()
		target.call("_record_runtime_performance_phase", "benchmark", phase_started_usec)
	var enabled_usec: int = Time.get_ticks_usec() - enabled_started_usec
	return {
		"calls": INSTRUMENTATION_CALLS,
		"disabled_usec_per_call": float(disabled_usec) / float(INSTRUMENTATION_CALLS),
		"enabled_usec_per_call": float(enabled_usec) / float(INSTRUMENTATION_CALLS),
		"added_usec_per_call": float(enabled_usec - disabled_usec) / float(INSTRUMENTATION_CALLS),
	}
