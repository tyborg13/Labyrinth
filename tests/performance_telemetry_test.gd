extends SceneTree

const PerformanceTelemetryScript = preload("res://scripts/performance_telemetry.gd")

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var global_sampler: Node = root.get_node_or_null("PerformanceTelemetry")
	if global_sampler != null:
		global_sampler.set_process(false)
	await _test_sampling_configuration_matrix()
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
	_expect(sampler.steam_metric_prefix_for_test("Linux", true) == "perf_v1_linux_steamdeck", "Steam telemetry should distinguish Steam Deck from other Linux devices")
	_expect(sampler.steam_metric_prefix_for_test("Linux", false) == "perf_v1_linux_desktop", "Steam telemetry should identify Linux desktop independently")
	_expect(sampler.steam_metric_prefix_for_test("Windows", false) == "perf_v1_windows_desktop", "Steam telemetry should identify Windows independently")
	_expect(sampler.steam_metric_prefix_for_test("macOS", false) == "perf_v1_macos_desktop", "Steam telemetry should identify macOS independently")
	_expect(sampler.steam_metric_prefix_for_test("macOS", true) == "perf_v1_macos_desktop", "Steam Deck classification should remain Linux-only")
	_expect(sampler.steam_metric_prefix_for_test("Haiku", false).is_empty(), "Unsupported platforms should not emit undeclared Steam stat prefixes")
	_expect(sampler.sampling_enabled_for_test(true, false, ""), "Local JSON alone should enable sampling")
	_expect(sampler.sampling_enabled_for_test(false, true, ""), "Steam stats alone should enable sampling")
	_expect(sampler.sampling_enabled_for_test(false, false, "https://telemetry.example.test"), "HTTP upload alone should enable sampling")
	_expect(not sampler.sampling_enabled_for_test(false, false, ""), "Disabling all destinations should disable sampling and section timers")
	var cohorts: Dictionary = summary.get("frame_cohorts", {}) as Dictionary
	for expected_cohort: String in ["combat_idle", "density_5_plus", "depth_5_12", "relics_0_4"]:
		_expect(cohorts.has(expected_cohort), "Telemetry should retain the active %s frame cohort" % expected_cohort)
	summary["sections"] = {
		"stage_base": {"count": 4, "total_usec": 1200},
		"engine_trap_blast": {"count": 2, "total_usec": 500},
	}
	var steam_deltas: Dictionary = sampler.steam_metric_deltas_for_test(summary, "Linux", true)
	_expect(int(steam_deltas.get("perf_v1_linux_steamdeck_sessions", 0)) == 1, "The first Steam telemetry submission should count the platform session")
	_expect(int(steam_deltas.get("perf_v1_linux_steamdeck_frame_samples", 0)) == 5, "Steam telemetry should aggregate the sampled-frame denominator")
	_expect(int(steam_deltas.get("perf_v1_linux_steamdeck_frames_over_33_33_ms", 0)) == 2, "Steam telemetry should aggregate frame-budget misses")
	_expect(int(steam_deltas.get("perf_v1_linux_steamdeck_p95_over_33_33_ms_windows", 0)) == 1, "Steam telemetry should count slow-tail windows instead of globally summing percentiles")
	_expect(int(steam_deltas.get("perf_v1_linux_steamdeck_mean_draw_calls_window_sum", 0)) == 1225, "Steam telemetry should preserve a mergeable draw-call total for platform-wide averages")
	_expect(int(steam_deltas.get("perf_v1_linux_steamdeck_cohort_combat_idle_samples", 0)) == 5, "Steam telemetry should expose state-specific frame denominators")
	_expect(int(steam_deltas.get("perf_v1_linux_steamdeck_cohort_density_5_plus_over_33_33_ms", 0)) == 2, "Steam telemetry should locate 30 FPS misses by encounter density")
	_expect(int(steam_deltas.get("perf_v1_linux_steamdeck_section_stage_calls", 0)) == 4, "Steam telemetry should retain subsystem call denominators")
	_expect(int(steam_deltas.get("perf_v1_linux_steamdeck_section_stage_tenths_ms", 0)) == 12, "Steam telemetry should retain subsystem time in mergeable tenths of milliseconds")
	_expect(int(steam_deltas.get("perf_v1_linux_steamdeck_section_engine_traps_tenths_ms", 0)) == 5, "Steam telemetry should distinguish combat-engine trap costs")
	_expect(steam_deltas.size() < 64, "A single window should update only its active subset of the larger Steam stat schema")
	var render: Dictionary = summary.get("render", {}) as Dictionary
	_expect(int(render.get("sample_count", 0)) == 5, "Explicit render samples should be retained with the frame window")
	_expect(float(render.get("draw_calls_max", 0.0)) == 1245.0, "Telemetry should retain peak draw-call pressure")
	var context: Dictionary = summary.get("context", {}) as Dictionary
	_expect(str(context.get("mode", "")) == "combat" and int(context.get("room_depth", 0)) == 9, "Telemetry should associate performance with gameplay context that omits Steam identity")
	_expect(not summary.has("steam_id") and not summary.has("persona_name"), "Performance payloads must not include Steam identity")
	var manifest_names: Array[String] = _manifest_metric_names()
	var runtime_names: Array[String] = sampler.steam_metric_names_for_test()
	_expect(runtime_names == manifest_names, "The Steamworks manifest must exactly match every stat key the runtime can produce")
	_expect(FileAccess.file_exists(sampler.current_file_path()), "Telemetry should persist append-only JSONL under user://telemetry (or the test override)")
	if FileAccess.file_exists(sampler.current_file_path()):
		var file := FileAccess.open(sampler.current_file_path(), FileAccess.READ)
		var parsed: Variant = JSON.parse_string(file.get_line()) if file != null else null
		_expect(typeof(parsed) == TYPE_DICTIONARY, "Persisted telemetry should be valid one-record-per-line JSON")
	var upload: Dictionary = sampler.last_upload_status()
	_expect(not bool(upload.get("attempted", true)) and str(upload.get("reason", "")) == "endpoint_not_configured", "Uploads should remain off until an endpoint is explicitly configured")
	sampler.set_gameplay_context({"mode": "combat", "room_depth": 14, "living_enemy_count": 4})
	sampler.sample_frame_for_test(22.0)
	var exit_summary: Dictionary = sampler.end_gameplay_context("test_scene_exit")
	_expect((exit_summary.get("frame_cohorts", {}) as Dictionary).has("combat_idle"), "The scene-exit boundary should flush the final gameplay cohort before RunScene is freed")
	sampler.sample_frame_for_test(12.0)
	var frontend_summary: Dictionary = sampler.flush_now("test_frontend")
	var frontend_cohorts: Dictionary = frontend_summary.get("frame_cohorts", {}) as Dictionary
	_expect(
		frontend_cohorts.has("frontend") and not frontend_cohorts.has("combat_idle"),
		"Frames after RunScene exits should be attributed to frontend rather than stale gameplay cohorts: %s" % str(frontend_cohorts.keys())
	)
	_expect(str((frontend_summary.get("context", {}) as Dictionary).get("mode", "")) == "frontend", "Ending gameplay telemetry should reset the persistent autoload context")
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

func _manifest_metric_names() -> Array[String]:
	var file := FileAccess.open("res://steam/performance_stats_manifest.json", FileAccess.READ)
	if file == null:
		_failures.append("Steam performance manifest should be readable")
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		_failures.append("Steam performance manifest should contain JSON object data")
		return []
	var manifest: Dictionary = parsed as Dictionary
	var suffixes: Array[String] = []
	for metric_var: Variant in manifest.get("global_metrics", []):
		suffixes.append(str(metric_var))
	for cohort_var: Variant in manifest.get("frame_cohorts", []):
		for metric_var: Variant in manifest.get("frame_cohort_metrics", []):
			suffixes.append("cohort_%s_%s" % [str(cohort_var), str(metric_var)])
	for section_var: Variant in manifest.get("section_groups", []):
		for metric_var: Variant in manifest.get("section_metrics", []):
			suffixes.append("section_%s_%s" % [str(section_var), str(metric_var)])
	var names: Array[String] = []
	for prefix_var: Variant in manifest.get("platform_prefixes", []):
		for suffix: String in suffixes:
			names.append("%s_%s" % [str(prefix_var), suffix])
	names.sort()
	return names

func _test_sampling_configuration_matrix() -> void:
	var original_local: Variant = ProjectSettings.get_setting("telemetry/performance/local_enabled", true)
	var original_steam: Variant = ProjectSettings.get_setting("telemetry/performance/steam_stats_enabled", true)
	var original_upload: Variant = ProjectSettings.get_setting("telemetry/performance/upload_url", "")
	var configurations: Array[Dictionary] = [
		{"local": true, "steam": false, "upload": "", "expected": true},
		{"local": false, "steam": true, "upload": "", "expected": true},
		{"local": false, "steam": false, "upload": "https://telemetry.example.test", "expected": true},
		{"local": false, "steam": false, "upload": "", "expected": false},
	]
	for index: int in range(configurations.size()):
		var configuration: Dictionary = configurations[index]
		ProjectSettings.set_setting("telemetry/performance/local_enabled", bool(configuration["local"]))
		ProjectSettings.set_setting("telemetry/performance/steam_stats_enabled", bool(configuration["steam"]))
		ProjectSettings.set_setting("telemetry/performance/upload_url", str(configuration["upload"]))
		var configured_sampler := PerformanceTelemetryScript.new()
		configured_sampler.set_storage_dir_for_test("user://performance_telemetry_config_%d" % index)
		root.add_child(configured_sampler)
		configured_sampler.set_process(false)
		_expect(
			configured_sampler.sampling_enabled() == bool(configuration["expected"]),
			"Telemetry destination configuration %d should set sampler enablement consistently" % index
		)
		configured_sampler.queue_free()
		await process_frame
	ProjectSettings.set_setting("telemetry/performance/local_enabled", original_local)
	ProjectSettings.set_setting("telemetry/performance/steam_stats_enabled", original_steam)
	ProjectSettings.set_setting("telemetry/performance/upload_url", original_upload)
