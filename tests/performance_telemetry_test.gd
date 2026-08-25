extends SceneTree

const PerformanceTelemetryScript = preload("res://scripts/performance_telemetry.gd")

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var global_sampler: Node = root.get_node_or_null("PerformanceTelemetry")
	if global_sampler != null:
		global_sampler.set_process(false)
	ProjectSettings.set_setting("telemetry/performance/upload_url", "")
	var sampler := PerformanceTelemetryScript.new()
	sampler.set_storage_dir_for_test("user://performance_telemetry_test")
	root.add_child(sampler)
	sampler.set_process(false)
	sampler.set_gameplay_context({
		"mode": "combat",
		"room_depth": 9,
		"living_enemy_count": 7,
		"controller_active": true,
	})
	for frame_ms: float in [10.0, 16.0, 18.0, 34.0, 45.0]:
		sampler.sample_frame_for_test(frame_ms, {
			"draw_calls": 1200.0 + frame_ms,
			"objects": 4000.0,
			"primitives": 72000.0,
			"process_ms": 8.0,
		})
	var summary: Dictionary = sampler.flush_now("test")
	var frame_stats: Dictionary = summary.get("frame_interval_ms", {}) as Dictionary
	_expect(int(frame_stats.get("sample_count", 0)) == 5, "Telemetry should summarize every accepted frame in the bounded window")
	_expect(is_equal_approx(float(frame_stats.get("median", 0.0)), 18.0), "Telemetry median should use the sorted frame interval distribution")
	_expect(is_equal_approx(float(frame_stats.get("p95", 0.0)), 45.0), "Telemetry p95 should expose the frame-tail stall")
	_expect(int(summary.get("frames_over_33_33_ms", 0)) == 2, "Telemetry should count frames that miss the 30 FPS budget")
	var render: Dictionary = summary.get("render", {}) as Dictionary
	_expect(int(render.get("sample_count", 0)) == 5, "Explicit render samples should be retained with the frame window")
	_expect(float(render.get("draw_calls_max", 0.0)) == 1245.0, "Telemetry should retain peak draw-call pressure")
	var context: Dictionary = summary.get("context", {}) as Dictionary
	_expect(str(context.get("mode", "")) == "combat" and int(context.get("room_depth", 0)) == 9, "Telemetry should associate performance with anonymous gameplay context")
	_expect(not summary.has("steam_id") and not summary.has("persona_name"), "Performance payloads must not include Steam identity")
	_expect(FileAccess.file_exists(sampler.current_file_path()), "Telemetry should persist append-only JSONL under user://telemetry (or the test override)")
	if FileAccess.file_exists(sampler.current_file_path()):
		var file := FileAccess.open(sampler.current_file_path(), FileAccess.READ)
		var parsed: Variant = JSON.parse_string(file.get_line()) if file != null else null
		_expect(typeof(parsed) == TYPE_DICTIONARY, "Persisted telemetry should be valid one-record-per-line JSON")
	var upload: Dictionary = sampler.last_upload_status()
	_expect(not bool(upload.get("attempted", true)) and str(upload.get("reason", "")) == "endpoint_not_configured", "Uploads should remain off until an endpoint is explicitly configured")
	sampler.queue_free()
	await process_frame
	if _failures.is_empty():
		print("PERFORMANCE TELEMETRY TEST RESULT: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("PERFORMANCE TELEMETRY TEST RESULT: FAIL (%d failures)" % _failures.size())
	quit(1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
