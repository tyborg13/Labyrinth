extends SceneTree

## Paired, interleaved off/on samples at fixed SubViewport sizes. Vulkan GPU
## timings include the board and every nested pixel target, without readbacks.
## --submission-only exercises the harness headless; it cannot pass a GPU gate.
const Pixel = preload("res://scripts/pixel_fx_layer.gd")
const Board = preload("res://scripts/combat_board_view.gd")
const Fixture = preload("res://tests/pixel_fx_fixture.gd")
const Runtime = preload("res://scripts/parallel_runtime.gd")
const Metrics = preload("res://tests/pixel_fx_benchmark_metrics.gd")
const WARMUP_FRAMES: int = 45
const SAMPLE_PAIRS: int = 180
const QUERY_MARGIN_FRAMES: int = 2
const CAPTURE_PROGRESS: float = 0.62
const CAPTURE_SETTLE_FRAMES: int = 3
const BUDGET_MS: float = 1.0
const SUBMISSION_BUDGET_MS: float = 0.3
const VIEWPORTS: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(3840, 2160)]
const OUTPUT: String = "user://probes/pixel_fx_performance"
signal submission_flushed
var _viewport: SubViewport
var _board: Control
var _device: RenderingDevice
var _failures: Array[String]
var _cpu_only: bool = false
var _settle_frames: int = 1
var _window_sizes: Dictionary = {}
var _measured: Array[SubViewport]
var _timing_enabled: Dictionary = {}

func _initialize() -> void:
	Runtime.apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	_cpu_only = "--submission-only" in OS.get_cmdline_user_args()
	if not _cpu_only:
		if DisplayServer.get_name() == "headless" or RenderingServer.get_current_rendering_driver_name() != "vulkan":
			push_error("Pixel FX GPU budget requires a windowed Vulkan renderer (--rendering-driver vulkan); --submission-only is CPU-only")
			quit(1)
			return
		_device = RenderingServer.get_rendering_device()
		_settle_frames = _device.get_frame_delay() + QUERY_MARGIN_FRAMES
		DisplayServer.window_move_to_foreground()
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	OS.low_processor_usage_mode = false
	Engine.max_fps = 0
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
	_board.set_process(false)
	var rows: Array[Dictionary]
	var gpu_passed: bool = true
	var submission_passed: bool = true
	var workloads := PackedStringArray(["idle", "fire", "ice", "lightning", "air", "earth", "fire_aoe", "dragon_fan", "chain", "tether"])
	for resolution: Vector2i in VIEWPORTS:
		_viewport.size = resolution
		_viewport.size_2d_override = Fixture.SIZE
		_viewport.size_2d_override_stretch = true
		for frame: int in range(CAPTURE_SETTLE_FRAMES): await process_frame
		var actual: Vector2i = DisplayServer.window_get_size()
		_window_sizes[str(resolution)] = [actual.x, actual.y]
		for workload: String in workloads:
			var row: Dictionary = await _measure(workload)
			row["viewport"] = [resolution.x, resolution.y]
			row["workload"] = workload
			rows.append(row)
			if not _cpu_only:
				row["gpu_gate"] = Metrics.gpu_verdict(row["gpu"], SAMPLE_PAIRS, BUDGET_MS, resolution == Fixture.SIZE)
				gpu_passed = gpu_passed and bool(row["gpu_gate"]["passed"])
				if not row["gpu_gate"]["valid_samples"]:
					_failures.append("%s %dp Vulkan GPU samples unavailable: off=%d on=%d, require >=%d nonzero sums each" % [workload, resolution.y, row["gpu"]["off"]["samples"], row["gpu"]["on"]["samples"], row["gpu_gate"]["minimum_nonzero_samples_per_variant"]])
				elif not row["gpu_gate"]["passed"]:
					_failures.append("%s GPU median increase %.3f ms exceeds +%.1f ms" % [workload, row["gpu"]["paired_delta"]["median_ms"], BUDGET_MS])
				print("PIXEL FX GPU GATE %dx%d %s: %s (nonzero off %d/%d, on %d/%d; paired median %.3f ms%s)" % [resolution.x, resolution.y, workload, "PASS" if row["gpu_gate"]["passed"] else "FAIL", row["gpu"]["off"]["samples"], SAMPLE_PAIRS, row["gpu"]["on"]["samples"], SAMPLE_PAIRS, row["gpu"]["paired_delta"]["median_ms"], " <= 1.0 ms" if resolution == Fixture.SIZE else "; 4K report only"])
			if resolution == Fixture.SIZE and workload in ["lightning", "chain", "tether"]:
				row["submission_gate"] = {"budget_ms": SUBMISSION_BUDGET_MS, "passed": float(row["submission"]["paired_delta"]["median_ms"]) <= SUBMISSION_BUDGET_MS}
				submission_passed = submission_passed and bool(row["submission_gate"]["passed"])
				if not row["submission_gate"]["passed"]:
					_failures.append("%s CPU submission median increase %.3f ms exceeds +%.1f ms" % [workload, row["submission"]["paired_delta"]["median_ms"], SUBMISSION_BUDGET_MS])
			for metric: String in ["gpu", "frame_interval", "submission"]:
				var delta: Dictionary = row[metric]["paired_delta"]
				print("PIXEL FX PERF %dx%d %s %s: paired median delta %.3f ms; p95 delta %.3f ms" % [resolution.x, resolution.y, workload, metric, delta["median_ms"], delta["p95_ms"]])
			if not _cpu_only:
				await _capture_on(workload)
				_viewport.get_texture().get_image().save_png(OUTPUT.path_join("%s_%dp_on.png" % [workload, resolution.y]))
	var report: Dictionary = {"cpu_only": _cpu_only, "gpu_budget_verified": not _cpu_only and gpu_passed, "budget_ms": BUDGET_MS,
		"submission_budget_verified": submission_passed, "submission_budget_ms": SUBMISSION_BUDGET_MS, "submission_budget_workloads": ["lightning", "chain", "tether"],
		"gate": "paired GPU median increase per 1080p workload; p95 and 4K reported only", "min_spec_hardware": "out of scope",
		"viewports": [[1920, 1080], [3840, 2160]], "budget_viewport": [1920, 1080], "warmup_frames_per_variant": WARMUP_FRAMES,
		"sample_pairs": SAMPLE_PAIRS, "interleave": "off/on per pair, reversing first variant each pair at the same progress",
		"sample_settle_frames": _settle_frames, "renderer": RenderingServer.get_video_adapter_name(), "driver": RenderingServer.get_current_rendering_driver_name(),
		"observed_window_sizes": _window_sizes, "rows": rows, "errors": _failures}
	var file := FileAccess.open(OUTPUT.path_join("performance.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	Pixel.review_enabled_override = null
	print("PIXEL FX PERFORMANCE RESULT: " + JSON.stringify(report))
	print(ProjectSettings.globalize_path(OUTPUT))
	for failure: String in _failures: push_error(failure)
	print("PIXEL FX %s BENCHMARK: %s%s" % ["CPU" if _cpu_only else "GPU", "PASS" if _failures.is_empty() else "FAIL", " (GPU budget pending; CPU report only)" if _cpu_only else ""])
	_board.queue_free()
	await process_frame
	quit(0 if _failures.is_empty() else 1)

func _effect(workload: String) -> Dictionary:
	if workload in ["chain", "tether"]: return Fixture.line_sample(workload)["presentation"]["effect"]
	return Fixture.dragon_fan_effect() if workload == "dragon_fan" else Fixture.effect(workload.trim_suffix("_aoe"), workload.ends_with("_aoe"))

func _measure(workload: String) -> Dictionary:
	var state: Dictionary = Fixture.combat_state()
	var effect: Dictionary = _effect(workload)
	var count: int = Fixture.Fx.animation_frame_count(effect, 6, false)
	var samples: Dictionary = {"off": [], "on": []}
	for enabled: bool in [false, true]:
		for frame: int in range(WARMUP_FRAMES):
			await _sample(state, effect, workload, float(frame % count + 1) / count, enabled, 1)
	for pair: int in range(SAMPLE_PAIRS):
		var order: Array[bool]
		order.append_array([false, true] if pair % 2 == 0 else [true, false])
		for enabled: bool in order:
			var sample: Dictionary = await _sample(state, effect, workload, float(pair % count + 1) / count, enabled, _settle_frames)
			(samples["on" if enabled else "off"] as Array).append(sample)
	var result: Dictionary = {"samples": samples}
	for metric: String in ["gpu", "frame_interval", "submission"]:
		result[metric] = Metrics.summarize(samples, metric)
	# Outside all timed samples: report the memory/rebuild tradeoff and assert
	# the production cache caps, including owners with no currently active run.
	result["line_cache"] = _line_cache_counters()
	return result

func _line_cache_counters() -> Dictionary:
	var result: Dictionary = {"owners": 0, "shapes": 0, "core_cells": 0, "halo_cells": 0, "batches": 0, "quads": 0, "rasterizations": 0, "mesh_builds": 0}
	for node: Node in _board.find_children("*", "", true, false):
		if node.get_script() != Pixel: continue
		var cache: RefCounted = node.get("_line_cache")
		if cache == null: continue
		var shapes: Dictionary = cache.get("_shapes")
		var batches: Dictionary = cache.get("_batches")
		result["owners"] += 1
		result["shapes"] += shapes.size()
		result["batches"] += batches.size()
		result["quads"] += int(cache.get("_cached_quads"))
		result["rasterizations"] += int(cache.get("rasterizations"))
		result["mesh_builds"] += int(cache.get("mesh_builds"))
		for shape: Dictionary in shapes.values():
			result["core_cells"] += shape["cells"].size()
			result["halo_cells"] += shape.get("halo", []).size()
		if shapes.size() > cache.MAX_SHAPES or batches.size() > cache.MAX_BATCHES or int(cache.get("_cached_quads")) > cache.MAX_CACHED_QUADS:
			_failures.append("Line cache exceeded its production bounds")
	return result

func _sample(state: Dictionary, effect: Dictionary, workload: String, progress: float, enabled: bool, frames: int) -> Dictionary:
	Pixel.review_enabled_override = enabled
	var presentation: Dictionary = {"ambient_time_seconds": 0.37, "scene_props": []}
	if workload != "idle": presentation.merge({"effect": effect, "effect_progress": progress, "reduced_motion": false})
	var sample: Dictionary = {}
	var previous: int = Time.get_ticks_usec()
	for frame: int in range(frames):
		await process_frame
		var started: int = Time.get_ticks_usec()
		_board.call("set_combat_state", state, [], [], Vector2i(-1, -1), "", "", {}, {}, presentation)
		# The same phase is held until the GPU query queue has drained. Re-submit
		# retained drawings so UPDATE_ONCE pixel targets render in every held frame.
		_board.call("_queue_dynamic_redraw")
		call_deferred("_after_submission")
		await submission_flushed
		var submitted: int = Time.get_ticks_usec()
		if not _cpu_only: await RenderingServer.frame_post_draw
		var finished: int = Time.get_ticks_usec()
		sample = {"gpu": 0.0, "frame_interval": float(finished - previous) / 1000.0, "submission": float(submitted - started) / 1000.0, "pixel_viewports": maxi(0, _measured.size() - 1)}
		previous = finished
	if not _cpu_only:
		# frame_post_draw precedes Godot's timestamp handling. Read on the next
		# process tick, before changing any viewport or the off/on variant.
		await process_frame
		for viewport: SubViewport in _measured:
			var elapsed: float = RenderingServer.viewport_get_measured_render_time_gpu(viewport.get_viewport_rid())
			sample["gpu"] += elapsed
		# An inactive/empty child target may legitimately report zero. Validate
		# the board-plus-pixel sum over each row, allowing <=10% missing queries.
		sample["window_focused"] = DisplayServer.window_is_focused()
	return sample

func _after_submission() -> void:
	call_deferred("_after_pixel_drawings")

func _after_pixel_drawings() -> void:
	# Board -> low-resolution drawing -> cell canvas: include all three draw
	# queues in the CPU submission sample, including already-retained lines.
	call_deferred("_finish_submission")

func _finish_submission() -> void:
	_measured.clear()
	_collect_viewports(_viewport)
	submission_flushed.emit()

func _collect_viewports(node: Node) -> void:
	if node.is_queued_for_deletion(): return
	if node is SubViewport:
		var viewport := node as SubViewport
		if not viewport.is_queued_for_deletion():
			_measured.append(viewport)
			if not _cpu_only and not _timing_enabled.has(viewport.get_instance_id()):
				RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(), true)
				_timing_enabled[viewport.get_instance_id()] = true
	for child: Node in node.get_children(): _collect_viewports(child)

func _capture_on(workload: String) -> void:
	await _sample(Fixture.combat_state(), _effect(workload), workload, CAPTURE_PROGRESS, true, CAPTURE_SETTLE_FRAMES)
