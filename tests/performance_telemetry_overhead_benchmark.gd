extends SceneTree

const PerformanceTelemetryScript = preload("res://scripts/performance_telemetry.gd")
const SAMPLES_PER_BATCH: int = 6000
const MEASURED_BATCHES: int = 9

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
	sampler.call("set_gameplay_context", {
		"mode": "combat",
		"room_depth": 14,
		"living_enemy_count": 6,
		"relic_count": 12,
		"card_targeting": true,
	})
	var durations_usec: Array[float] = []
	var semantic_errors: Array[String] = []
	for batch_index: int in range(MEASURED_BATCHES + 1):
		var started_usec: int = Time.get_ticks_usec()
		for sample_index: int in range(SAMPLES_PER_BATCH):
			sampler.call("sample_frame_for_test", 16.0 + float(sample_index % 6))
		var duration_usec: int = Time.get_ticks_usec() - started_usec
		var summary: Dictionary = sampler.call("flush_now", "overhead_benchmark") as Dictionary
		var frame_stats: Dictionary = summary.get("frame_interval_ms", {}) as Dictionary
		if int(frame_stats.get("sample_count", 0)) != SAMPLES_PER_BATCH:
			semantic_errors.append("sampler dropped frames in batch %d" % batch_index)
		if batch_index > 0:
			durations_usec.append(float(duration_usec))
	durations_usec.sort()
	var median_batch_usec: float = _percentile(durations_usec, 0.50)
	var p95_batch_usec: float = _percentile(durations_usec, 0.95)
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
		"semantic_errors": semantic_errors,
	}
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
