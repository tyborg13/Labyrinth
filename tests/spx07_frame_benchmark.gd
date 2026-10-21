extends SceneTree

# Real iteration twin of the director's native pointer probe. Never drains
# deferred calls or invokes draw handlers: completed iterations include _draw.
const Fixture = preload("res://tools/warband_inspection.gd")
const Run = preload("res://scripts/run_engine.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const PROOF_SIZE := Vector2i(1920, 1080)
const SETTLE_SECONDS: float = 1.5
const IDLE_SECONDS: float = 4.0
const SWEEP_SECONDS: float = 6.0
const PROOF_FRAME_CAP: int = 0
const MAX_PROCESS_MS: float = 16.0
const P95_PROCESS_MS: float = 10.0
var output: String = "res://output/spx07/r1/frames.json"
var baseline: bool = false
var failures: Array[String]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--baseline": baseline = true
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	call_deferred("_run")

func _run() -> void:
	Engine.max_fps = PROOF_FRAME_CAP
	OS.low_processor_usage_mode = false
	OS.low_processor_usage_mode_sleep_usec = 0
	Settings.set_storage_path("user://spx07-frame-settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	Settings.save_settings(settings)
	root.size = PROOF_SIZE
	root.content_scale_size = PROOF_SIZE
	var report: Dictionary = {"schema_version": 1, "headless": true, "frame_cap": PROOF_FRAME_CAP, "low_processor_usage_mode": OS.low_processor_usage_mode, "low_processor_sleep_usec": OS.low_processor_usage_mode_sleep_usec, "size": PROOF_SIZE, "ui_scale": 1.0, "seed": Fixture.FIXTURE_SEED, "environment": {"cpu": OS.get_processor_name(), "os": OS.get_name(), "godot": Engine.get_version_info()["string"]}, "cases": []}
	for case: Dictionary in [{"name": "ordinary"}, {"name": "air_t2", "biome": "air", "tier": 2}, {"name": "lightning_t3", "biome": "lightning", "tier": 3}]:
		(report["cases"] as Array).append(await _measure(case))
	report["resources_end"] = {"memory": Performance.get_monitor(Performance.MEMORY_STATIC), "nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT), "orphan_nodes": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)}
	if int(report["resources_end"]["orphan_nodes"]) != 0: failures.append("Frame probe leaves orphan nodes")
	report["failures"] = failures
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	for failure: String in failures: push_error(failure)
	print("SPX07 FRAME RESULT: %s (%d failures)" % ["PASS" if failures.is_empty() else "FAIL", failures.size()])
	quit(0 if failures.is_empty() else 1)

func _measure(case: Dictionary) -> Dictionary:
	var engine := Run.new()
	var combat := Combat.new()
	var state: Dictionary = engine.create_new_run(Fixture.FIXTURE_SEED, Store.default_data())
	if case.has("biome"): state = Fixture.build(engine, combat, state, {"warband_biome": case["biome"], "warband_tier": case["tier"]})
	else: state = engine.move_to_room(state, engine.available_moves(state)[0])
	var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.call("_load_run_state", state)
	if bool(scene.get("_dialogue_active")): scene.call("_close_dialogue")
	await create_timer(SETTLE_SECONDS).timeout
	var board: Control = scene.get("board_view")
	scene.call("set_runtime_performance_instrumentation_enabled", true)
	board.call("set_submission_performance_instrumentation_enabled", true)
	board.call("reset_render_instrumentation")
	var idle: Dictionary = await _sample(IDLE_SECONDS, Callable())
	# Snapshot I/O and aggregation are outside all timed phases.
	scene.call("set_runtime_performance_instrumentation_enabled", true)
	board.call("reset_render_instrumentation")
	var rect: Rect2 = board.get_global_rect()
	var sweep: Dictionary = await _sample(SWEEP_SECONDS, func(t: float) -> void:
		var point := Vector2(rect.position.x + rect.size.x * (0.2 + 0.6 * fmod(t * 0.35, 1.0)), rect.position.y + rect.size.y * (0.3 + 0.4 * (0.5 + 0.5 * sin(t * 2.3))))
		var motion := InputEventMouseMotion.new()
		motion.position = point
		motion.global_position = point
		root.push_input(motion, true))
	var render: Dictionary = board.call("render_instrumentation_snapshot")
	var phases: Dictionary = scene.call("runtime_performance_frame_instrumentation_snapshot")
	var totals: Dictionary = scene.call("runtime_performance_instrumentation_snapshot")
	if int(totals.get("hover_stage_refresh_total", {}).get("count", 0)) == 0: failures.append("Viewport sweep never refreshed a hovered tile: " + case["name"])
	if int(scene.get("_selected_card_index")) >= 0: failures.append("Frame sweep unexpectedly selected a card: " + case["name"])
	var sample_path: String = output.get_basename() + "-" + str(case["name"]) + "-samples.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(sample_path.get_base_dir()))
	FileAccess.open(sample_path, FileAccess.WRITE).store_string(JSON.stringify({"idle": idle["samples"], "sweep": sweep["samples"]}))
	idle.erase("samples")
	sweep.erase("samples")
	if int(render.get("dynamic_draw_count", 0)) == 0: failures.append("No real CanvasItem draws: " + case["name"])
	# TIME_PROCESS is the preceding second's maximum (Godot 4.6.1 main.cpp,
	# Main::iteration, lines 4621–4643), not a fresh per-frame sample. Its raw
	# maximum must fit too; actual uncapped iteration intervals supply p95.
	if not baseline and (sweep["frame_ms"]["max"] > MAX_PROCESS_MS or sweep["frame_ms"]["p95"] > P95_PROCESS_MS or sweep["process_ms"]["max"] > MAX_PROCESS_MS): failures.append("Frame CPU budget " + case["name"])
	print("SPX07 FRAME %s max=%.3f p95=%.3f monitor_max=%.3f monitor_p95=%.3f ms draws=%d frames=%d" % [case["name"], sweep["frame_ms"]["max"], sweep["frame_ms"]["p95"], sweep["process_ms"]["max"], sweep["process_ms"]["p95"], render["dynamic_draw_count"], sweep["frames"]])
	var result: Dictionary = {"case": case["name"], "idle": idle, "sweep": sweep, "samples_file": sample_path, "render": render, "script_frames": phases, "script_totals": totals, "resources": {"memory": Performance.get_monitor(Performance.MEMORY_STATIC), "nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT)}}
	scene.queue_free()
	await process_frame
	await process_frame
	return result

func _sample(seconds: float, step: Callable) -> Dictionary:
	var samples: Array[Dictionary]
	var frames: Array[float]
	var process_times: Array[float]
	# Read the monitor after real iterations, including queued CanvasItem draws.
	# Godot holds monitor peaks across multiple frames; retain every raw reading
	# alongside actual iteration intervals rather than relabelling it CPU latency.
	await process_frame
	var started: int = Time.get_ticks_usec()
	var last: int = started
	while Time.get_ticks_usec() - started < int(seconds * 1000000.0):
		if step.is_valid(): step.call(float(Time.get_ticks_usec() - started) / 1000000.0)
		await process_frame
		var now: int = Time.get_ticks_usec()
		var elapsed: float = float(now - last) / 1000.0
		var process_ms: float = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		samples.append({"frame_id": Engine.get_process_frames() - 1, "frame_ms": elapsed, "process_ms": process_ms})
		frames.append(elapsed)
		process_times.append(process_ms)
		last = now
	return {"frames": samples.size(), "frame_ms": _stats(frames), "process_ms": _stats(process_times), "samples": samples}

func _stats(values: Array[float]) -> Dictionary:
	values.sort()
	var counts: Dictionary = {}
	for limit: float in [16.67, 20.0, 33.33]:
		var count: int = 0
		for value: float in values:
			if value > limit: count += 1
		counts[str(limit)] = count
	return {"median": values[values.size() / 2], "p95": values[int(values.size() * 0.95)], "p99": values[int(values.size() * 0.99)], "max": values.back(), "over_ms": counts}
