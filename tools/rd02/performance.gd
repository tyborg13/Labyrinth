extends SceneTree

const Fixture = preload("res://tools/rd02/fixture.gd")
const Real = preload("res://tools/ptf09/real_fixture.gd")
const Trace = preload("res://tests/perf/combat_frame_trace.gd")
const Partition = preload("res://scripts/performance_phase_partitioner.gd")
const ORDER: Array = ["A", "B", "B", "A", "A", "B"]
const WARMUP: int = 30
const SAMPLE_FRAMES: int = 180
const ACTIVE_COUNT: int = 2
const UNIT_COUNT: int = 8
var results: Array[Dictionary]
var failures: Array[String]
# Optional workload: --manifest <verified fight> --active <x-rays> --units <rims> --output-dir <dir>.
var manifest_path: String = ""
var active_count: int = ACTIVE_COUNT
var unit_count: int = UNIT_COUNT
var output: String = Fixture.OUTPUT

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	if DisplayServer.get_name() == "headless": process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	call_deferred("_run")

func _run() -> void:
	# Proof-only uncapped sampling: vsync must not hide added renderer cost.
	Engine.max_fps = 0
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.has("--manifest"): manifest_path = args[args.find("--manifest") + 1]
	if args.has("--active"): active_count = int(args[args.find("--active") + 1])
	if args.has("--units"): unit_count = int(args[args.find("--units") + 1])
	if args.has("--output-dir"): output = args[args.find("--output-dir") + 1]
	DirAccess.make_dir_recursive_absolute(output)
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_write_results() # A failed fresh launch cannot leave a stale pair report.
	if manifest_path.is_empty(): Fixture.install("eight")
	else: Fixture.install_manifest(manifest_path)
	var canvas: SubViewport = Real.make_canvas(self)
	RenderingServer.viewport_set_measure_render_time(canvas.get_viewport_rid(), true)
	for side: String in ORDER:
		root.set_meta("labyrinth_resume_saved_run", true)
		var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
		scene.set_script(preload("res://tests/perf/profiled_run_scene.gd"))
		canvas.add_child(scene)
		for frame: int in range(Fixture.SETTLE_FRAMES): await process_frame
		var board: Control = scene.get("board_view")
		var overlay: Node2D = board.get("_occlusion_silhouettes")
		overlay.sync_coverage()
		var active: int = 0
		for entry: Dictionary in overlay.get("entries").values():
			if bool(entry["on"]): active += 1
		if active != active_count: failures.append("Fixture has %d x-rays; requires exactly %d" % [active, active_count])
		var team: RefCounted = overlay.get("team")
		if team.get("entries").size() != unit_count: failures.append("Fixture requires exactly %d team outlines" % unit_count)
		overlay.set_tool_enabled(side == "B")
		for frame: int in range(WARMUP): await process_frame
		scene.call("set_runtime_performance_instrumentation_enabled", true)
		board.call("set_submission_performance_instrumentation_enabled", true)
		scene.call("consume_runtime_performance_instrumentation_snapshot")
		Trace.reset()
		Trace.enabled = true
		var updates_before: int = team.get("updates")
		var queries_before: int = overlay.get("alpha_masks").get("queries")
		var engine_usec: Array[float]
		var frame_usec: Array[int]
		var render_cpu_usec: Array[float]
		var render_gpu_usec: Array[float]
		for frame: int in range(SAMPLE_FRAMES):
			var started: int = Time.get_ticks_usec()
			await process_frame
			if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
			render_cpu_usec.append(RenderingServer.viewport_get_measured_render_time_cpu(canvas.get_viewport_rid()) * 1000.0)
			render_gpu_usec.append(RenderingServer.viewport_get_measured_render_time_gpu(canvas.get_viewport_rid()) * 1000.0)
			frame_usec.append(Time.get_ticks_usec() - started)
			engine_usec.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000000.0)
		Trace.enabled = false
		var cpu_usec: Array[int]
		for intervals: Array in Trace.frames.values(): cpu_usec.append(int(Partition.partition(intervals).get("total_usec", 0)))
		results.append({"side": side, "active": active, "outlined_units": team.get("entries").size(), "steady_rim_updates": int(team.get("updates")) - updates_before, "steady_coverage_queries": int(overlay.get("alpha_masks").get("queries")) - queries_before, "frame_usec": frame_usec, "engine_usec": engine_usec,
			"render_cpu_usec": render_cpu_usec, "render_gpu_usec": render_gpu_usec, "runtime_cpu_usec": cpu_usec, "runtime": scene.call("runtime_performance_instrumentation_snapshot"),
			"board": board.call("render_instrumentation_snapshot")})
		print("RD02 STEADY %s: %d units, %d x-rays; %d rim command updates / %d frames; %d coverage recomputes" % [side, team.get("entries").size(), active, int(team.get("updates")) - updates_before, SAMPLE_FRAMES, int(overlay.get("alpha_masks").get("queries")) - queries_before])
		print("RD02 STEADY TIME %s: frame median=%.3f ms p99=%.3f ms; render CPU median=%.3f ms GPU median=%.3f ms%s" % [side, _quantile(frame_usec, 0.5) / 1000.0, _quantile(frame_usec, 0.99) / 1000.0, _quantile(render_cpu_usec, 0.5) / 1000.0, _quantile(render_gpu_usec, 0.5) / 1000.0, " HEADLESS ONLY" if DisplayServer.get_name() == "headless" else ""])
		if results.size() % 2 == 0:
			_print_pair(results.size() / 2)
			_write_results()
		if side == "B" and results.size() == ORDER.size() and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			canvas.get_texture().get_image().save_png(output.path_join("performance.png"))
		scene.queue_free()
		for frame: int in range(WARMUP): await process_frame
	var label: String = "headless" if DisplayServer.get_name() == "headless" else "native"
	var file := FileAccess.open(output.path_join("performance_" + label + ".json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"renderer": DisplayServer.get_name(), "size": [1920,1080], "order": ORDER,
		"samples": SAMPLE_FRAMES, "results": results, "failures": failures}, "\t"))
	file.close()
	print(output.path_join("performance.png"))
	for failure: String in failures: push_error(failure)
	print("RD02 PERFORMANCE: %s (A/B, B/A, A/B; %s; no GPU claims for headless)" % ["PASS" if failures.is_empty() else "FAIL", label])
	quit(0 if failures.is_empty() else 1)

func _write_results() -> void:
	var label: String = "headless" if DisplayServer.get_name() == "headless" else "native"
	var file := FileAccess.open(output.path_join("performance_" + label + ".json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"renderer": DisplayServer.get_name(), "size": [1920,1080], "order": ORDER,
		"samples": SAMPLE_FRAMES, "results": results, "failures": failures}, "\t"))
	file.close()

func _print_pair(pair: int) -> void:
	var first: Dictionary = results[(pair - 1) * 2]
	var second: Dictionary = results[(pair - 1) * 2 + 1]
	var a: Array = first["frame_usec"] if first["side"] == "A" else second["frame_usec"]
	var b: Array = first["frame_usec"] if first["side"] == "B" else second["frame_usec"]
	var median: float = (_quantile(b, 0.5) - _quantile(a, 0.5)) / 1000.0
	var p99: float = (_quantile(b, 0.99) - _quantile(a, 0.99)) / 1000.0
	print("RD02 PAIR %d %s/%s: added frame median=%.3f ms p99=%.3f ms%s" % [pair, first["side"], second["side"], median, p99, " HEADLESS ONLY" if DisplayServer.get_name() == "headless" else ""])

static func _quantile(values: Array, fraction: float) -> float:
	var ordered: Array = values.duplicate()
	ordered.sort()
	var offset: float = (ordered.size() - 1) * fraction
	return lerpf(float(ordered[int(offset)]), float(ordered[mini(int(offset) + 1, ordered.size() - 1)]), offset - int(offset))
