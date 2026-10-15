extends SceneTree

## Matched off/on production-board benchmark. Includes unchanged ambient idle,
## all five spells, and a multi-tile ground burst. No readbacks inside samples.
## --submission-only permits a headless CPU measurement; GPU budget stays open.
const Pixel = preload("res://scripts/pixel_fx_layer.gd")
const Board = preload("res://scripts/combat_board_view.gd")
const Fixture = preload("res://tests/pixel_fx_fixture.gd")
const Runtime = preload("res://scripts/parallel_runtime.gd")
const WARMUP_FRAMES: int = 45
const SAMPLE_FRAMES: int = 180
const BUDGET_MS: float = 1.0
const OUTPUT: String = "user://probes/pixel_fx_performance"
signal submission_flushed
var _viewport: SubViewport
var _board: Control
var _failures: Array[String]
var _cpu_only: bool = false

func _initialize() -> void:
	Runtime.apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	_cpu_only = "--submission-only" in OS.get_cmdline_user_args()
	if DisplayServer.get_name() == "headless" and not _cpu_only:
		push_error("Pixel FX frame budget requires a real renderer; --submission-only measures CPU only")
		quit(1)
		return
	OS.low_processor_usage_mode = false
	Engine.max_fps = 0
	if not _cpu_only:
		root.mode = Window.MODE_WINDOWED
		DisplayServer.window_set_size(Fixture.SIZE)
		root.size = Fixture.SIZE
		DisplayServer.window_move_to_foreground()
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	_viewport = SubViewport.new()
	_viewport.size = Fixture.SIZE
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	_board = Board.new()
	_board.size = Fixture.SIZE
	_viewport.add_child(_board)
	await process_frame
	# Keep idle particle clocks fixed in both variants; animation progress is
	# driven by the same authored frames in each measured spell sequence.
	_board.set_process(false)
	var rows: Array[Dictionary]
	var workloads := PackedStringArray(["idle", "fire", "ice", "lightning", "air", "earth", "fire_aoe"])
	for workload: String in workloads:
		var samples: Dictionary = {"off": [], "on": []}
		# Two rounds reverse ordering to reduce shader warmup and thermal bias.
		for round_index: int in range(2):
			var order: Array[bool]
			order.append_array([false, true] if round_index == 0 else [true, false])
			for enabled: bool in order:
				var times: Array[float] = await _measure(workload, enabled)
				(samples["on" if enabled else "off"] as Array).append_array(times)
		var off: Dictionary = _stats(samples["off"])
		var on: Dictionary = _stats(samples["on"])
		var delta: float = on["median_ms"] - off["median_ms"]
		var tail_delta: float = on["p95_ms"] - off["p95_ms"]
		rows.append({"workload": workload, "off": off, "on": on, "median_delta_ms": delta, "p95_delta_ms": tail_delta})
		if delta > BUDGET_MS or tail_delta > BUDGET_MS:
			_failures.append("%s exceeds +%.1f ms: median %.3f, p95 %.3f" % [workload, BUDGET_MS, delta, tail_delta])
		print("PIXEL FX PERF %s: median delta %.3f ms; p95 delta %.3f ms" % [workload, delta, tail_delta])
		if not _cpu_only:
			_viewport.get_texture().get_image().save_png(OUTPUT.path_join(workload + "_on.png"))
	var report: Dictionary = {"cpu_only": _cpu_only, "gpu_budget_verified": not _cpu_only and _failures.is_empty(), "budget_ms": BUDGET_MS,
		"viewport": [Fixture.SIZE.x, Fixture.SIZE.y], "warmup_frames": WARMUP_FRAMES, "sample_frames_per_variant": SAMPLE_FRAMES * 2,
		"renderer": RenderingServer.get_video_adapter_name(), "rows": rows, "errors": _failures}
	var file := FileAccess.open(OUTPUT.path_join("performance.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	Pixel.review_enabled_override = null
	print("PIXEL FX PERFORMANCE RESULT: " + JSON.stringify(report))
	print(ProjectSettings.globalize_path(OUTPUT))
	for failure: String in _failures:
		push_error(failure)
	print("PIXEL FX %s BENCHMARK: %s%s" % ["CPU" if _cpu_only else "FRAME", "PASS" if _failures.is_empty() else "FAIL", " (GPU budget pending)" if _cpu_only else ""])
	_board.queue_free()
	await process_frame
	quit(0 if _failures.is_empty() else 1)

func _measure(workload: String, enabled: bool) -> Array[float]:
	Pixel.review_enabled_override = enabled
	var state: Dictionary = Fixture.combat_state()
	var element: String = workload.trim_suffix("_aoe")
	var aoe: bool = workload.ends_with("_aoe")
	var count: int = Fixture.Fx.animation_frame_count(Fixture.effect(element, aoe), 6, false)
	var samples: Array[float]
	var previous_render_tick: int = Time.get_ticks_usec()
	for frame: int in range(WARMUP_FRAMES + SAMPLE_FRAMES):
		await process_frame
		var progress: float = float(frame % count + 1) / count
		var presentation: Dictionary = {} if workload == "idle" else Fixture.presentation(element, progress, false, aoe)
		var started: int = Time.get_ticks_usec()
		_board.call("set_combat_state", state, [], [], Vector2i(-1, -1), "", "", {}, {}, presentation)
		if frame == 0:
			_board.call("_queue_dynamic_redraw")
		if _cpu_only:
			# The dummy renderer emits no render-frame signals. Two deferred queue
			# barriers include the board's _draw and the raw drawers it schedules,
			# without timing the sleep before the next process_frame.
			call_deferred("_after_submission")
			await submission_flushed
		else:
			await RenderingServer.frame_post_draw
		var finished: int = Time.get_ticks_usec()
		# Real-renderer budget uses delivered frame intervals, just like the
		# elemental ambient benchmark; headless reports CPU submission work only.
		var elapsed: float = float(finished - (started if _cpu_only else previous_render_tick)) / 1000.0
		previous_render_tick = finished
		if frame >= WARMUP_FRAMES:
			if not _cpu_only and not DisplayServer.window_is_focused():
				if not _failures.has("Unfocused window invalidates frame-budget measurement"):
					_failures.append("Unfocused window invalidates frame-budget measurement")
			samples.append(elapsed)
	return samples

func _after_submission() -> void:
	call_deferred("_finish_submission")

func _finish_submission() -> void:
	submission_flushed.emit()

func _stats(values: Array) -> Dictionary:
	var sorted: Array = values.duplicate()
	sorted.sort()
	var total: float = 0.0
	for value: float in sorted:
		total += value
	return {"mean_ms": total / sorted.size(), "median_ms": sorted[sorted.size() / 2], "p95_ms": sorted[ceili(sorted.size() * 0.95) - 1], "samples": sorted.size()}
