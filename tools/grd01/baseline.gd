extends SceneTree

const Fixture = preload("res://tools/grd01/fixtures.gd")
const Metrics = preload("res://tools/grd01/surface_metrics.gd")
const GpuTiming = preload("res://tools/grd01/gpu_timing.gd")
const GroundLayer = preload("res://scripts/board_pixel_surface_layer.gd")
const Cel = preload("res://scripts/cel_look.gd")
const OUTPUT: String = "/private/tmp/labyrinth_codex/grd-02"
const WARMUP_FRAMES: int = 60
const SAMPLE_FRAMES: int = 180
const DECK_SIZE := Vector2i(1280, 800)
const DECK_UI_SCALE: float = 1.15
const DESKTOP_UI_SCALE: float = 1.0
const GRD04_CPU_BUDGET_USEC: int = 500
const BOARD_STATE: Dictionary = {"biome_id": "stone", "reduced_motion": false}
const MEASURED_LAYERS: PackedStringArray = ["fire", "ice", "electric", "rubble"]

var _native: bool
var _pixel: bool
var _view: SubViewport
var _board_script: Script
var _device: RenderingDevice

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	assert(Cel.mode == "all", "Run with LABYRINTH_CEL_LOOK=all")
	var output: String = OS.get_environment("LABYRINTH_GRD01_OUTPUT")
	if output.is_empty(): output = OUTPUT
	_board_script = load(output.path_join("profile/combat_board_view.gd")) as Script
	if _board_script == null or not _board_script.can_instantiate():
		push_error("Run python3 tools/grd01/prepare_baseline.py first")
		quit(1)
		return
	_native = DisplayServer.get_name() != "headless"
	_pixel = GroundLayer.enabled()
	var grd04_budget: bool = "--verify-grd04-budget" in OS.get_cmdline_user_args()
	assert(not grd04_budget or _pixel, "The grd-04 budget requires LABYRINTH_GROUND_FX=pixel")
	var cases: Array[Dictionary] = Fixture.baseline_cases(grd04_budget)
	root.mode = Window.MODE_WINDOWED
	root.msaa_2d = Viewport.MSAA_DISABLED
	Engine.max_fps = 0
	Engine.time_scale = 1.0
	OS.low_processor_usage_mode = false
	if _native:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		# The matched native command uses --render-thread safe for direct RD reads.
		if RenderingServer.is_on_render_thread():
			_device = RenderingServer.get_rendering_device()
	var rows: Array[Dictionary]
	for resolution: Vector2i in [Fixture.SIZE, DECK_SIZE]:
		var ui_scale: float = DECK_UI_SCALE if resolution == DECK_SIZE else DESKTOP_UI_SCALE
		root.content_scale_size = Fixture.SIZE
		root.content_scale_factor = ui_scale
		root.size = resolution
		for frame: int in range(2):
			await process_frame
		# Project window uses canvas_items + EXPAND. Reproduce its uniform
		# stretch in an exact-sized backing target, independent of Retina scale.
		var aspect_scale: float = minf(float(resolution.x) / Fixture.SIZE.x, float(resolution.y) / Fixture.SIZE.y)
		var logical := Vector2i((Vector2(resolution) / (aspect_scale * ui_scale)).round())
		_view = Fixture.make_view(resolution, logical, Viewport.MSAA_DISABLED)
		root.add_child(_view)
		if _native:
			RenderingServer.viewport_set_measure_render_time(_view.get_viewport_rid(), true)
		for sample: Dictionary in cases:
			var row: Variant = await _measure(sample, resolution, logical, ui_scale)
			if not row is Dictionary or row.is_empty():
				push_error("Baseline failed at %s %s" % [resolution, sample["id"]])
				quit(1)
				return
			rows.append(row)
		_view.queue_free()
		await process_frame
	assert(rows.size() == 2 * cases.size())
	var lane: String = "native" if _native else "headless"
	var mode: String = "pixel" if _pixel else "legacy"
	var path: String = output.path_join("baseline-" + lane + "-" + mode + ".json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify({"renderer": DisplayServer.get_name(),
		"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
		"adapter": RenderingServer.get_video_adapter_name(), "godot": Engine.get_version_info()["string"],
		"edge_smoothing": "off", "cel_look": Cel.mode, "warmup_frames": WARMUP_FRAMES,
		"sample_frames_each": SAMPLE_FRAMES, "ground_fx": mode, "cpu_unit": "microseconds per engine frame",
		"scope": "standalone production CombatBoardView; tile submission minus nested configure, each layer configure plus scripted draw, and pixel step and projection callbacks",
		"gpu_scope": "GPU frame start through all viewport draws, before window blit and present; milliseconds. Requires --gpu-profile for the frame markers. Each row declares a fallback source if unavailable.",
		"draw_scope": "target viewport canvas and whole process; nested viewport draws are included in whole-process totals",
		"particle_definition": "retained particle quad MeshInstance2D nodes; no emitting system in this fixture",
		"rows": rows}, "\t"))
	file.close()
	print(path)
	print("GRD-02 BASELINE: PASS (%s %s, %d cases, %d sampled frames each)" % [lane, mode, rows.size(), SAMPLE_FRAMES])
	if grd04_budget and not _check_grd04_budget(rows):
		quit(1)
		return
	quit()

static func _check_grd04_budget(rows: Array[Dictionary]) -> bool:
	var peak: int = 0
	var samples: int = 0
	for row: Dictionary in rows:
		if row["case"].ends_with("_many"):
			var maximum: int = row["cpu_usec_per_frame"]["total"]["max"]
			if maximum > GRD04_CPU_BUDGET_USEC:
				push_error("GRD-04 CPU BUDGET: %s %s reached %d us/frame" % [row["resolution"], row["case"], maximum])
			peak = maxi(peak, maximum)
			samples += 1
	if peak > GRD04_CPU_BUDGET_USEC:
		return false
	print("GRD-04 CPU BUDGET: PASS (%d 25-tile cases, maximum %d us/frame <= %d us/frame)" % [samples, peak, GRD04_CPU_BUDGET_USEC])
	return true

func _measure(sample: Dictionary, resolution: Vector2i, logical: Vector2i, ui_scale: float) -> Dictionary:
	var board: Control = _board_script.new()
	board.size = Vector2(logical)
	_view.add_child(board)
	Fixture.submit(board, sample["state"], BOARD_STATE)
	var pixel: Node = board.get_node_or_null("PixelGround")
	var cell_view: SubViewport = pixel.get("target") if pixel != null else null
	var cell_rid: RID = cell_view.get_viewport_rid() if _native and cell_view != null else RID()
	if cell_rid.is_valid():
		RenderingServer.viewport_set_measure_render_time(cell_rid, true)
	for frame: int in range(WARMUP_FRAMES):
		await _next_frame()
	var counts: Dictionary = Fixture.counts(sample["state"])
	var layers: Dictionary = Metrics.inventory(board)
	var tile_count: int = Fixture.Ground.tiles(sample["state"]).size()
	if _pixel:
		assert(int(layers["surface_roots"]) == int(tile_count > 0) and layers["surface_particle_quads"] == 0)
		assert(int(pixel.get("grid")) == (1 if resolution == DECK_SIZE else 2) or tile_count == 0)
		assert(int(layers["surface_live_nodes"]) <= 4)
	else:
		assert(int(layers["surface_roots"]) == tile_count,
			"Every placed surface should have a retained layer, with no stale layers")
	var started: int = Time.get_ticks_usec()
	var cpu: Dictionary = {"tile_dispatch": [], "pixel": [], "total": []}
	var calls: Dictionary = {}
	var draw_calls: Array[int]
	var viewport_draw_calls: Array[int]
	var timing := GpuTiming.new()
	var board_rid: RID = _view.get_viewport_rid()
	for kind: String in MEASURED_LAYERS:
		cpu[kind] = []
	Metrics.take()
	for frame: int in range(SAMPLE_FRAMES):
		await _next_frame()
		var frame_result: Dictionary = Metrics.take()
		var elapsed: Dictionary = frame_result["usec"]
		var tile: int = elapsed.get("tile_submission", 0)
		var dispatch: int = tile
		var total: int = tile
		for kind: String in MEASURED_LAYERS:
			var configure: int = elapsed.get(kind + "_configure", 0)
			var paint: int = elapsed.get(kind + "_draw", 0)
			cpu[kind].append(configure + paint)
			dispatch -= configure
			total += paint
		assert(dispatch >= 0, "Layer configuration must sit inside tile submission")
		var pixel_usec: int = int(elapsed.get("pixel_clock", 0)) + int(elapsed.get("pixel_project", 0))
		cpu["tile_dispatch"].append(dispatch)
		cpu["pixel"].append(pixel_usec)
		cpu["total"].append(total + pixel_usec)
		for section: String in frame_result["calls"]:
			calls[section] = int(calls.get(section, 0)) + int(frame_result["calls"][section])
		if _native:
			draw_calls.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
			viewport_draw_calls.append(_view.get_render_info(Viewport.RENDER_INFO_TYPE_CANVAS, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME))
			timing.record(_device, board_rid, cell_rid, cell_rid.is_valid() and frame_result["calls"].has("pixel_update"))
	var sample_wall_usec: int = Time.get_ticks_usec() - started
	for section: String in cpu:
		cpu[section] = Metrics.stats(cpu[section])
	var animated: bool = counts["fire"] + counts["ice"] + counts["electrified"] > 0
	if _pixel:
		assert(int(calls.get("pixel_update", 0)) > 0 if animated else not calls.has("pixel_clock"))
		for section: String in ["fire_configure", "ice_configure", "electric_configure", "rubble_configure"]:
			assert(not calls.has(section))
	elif animated:
		assert(int(calls.get("tile_submission", 0)) > 0, "Surface animation did not submit during the sample")
		if counts["fire"] > 0 or counts["ice"] > 0:
			assert(int(calls.get("fire_draw", 0)) + int(calls.get("ice_draw", 0)) > 0, "Retained child drawing was never timed")
	var gpu: Dictionary = {}
	if _native:
		assert(draw_calls.max() > 0 and viewport_draw_calls.max() > 0)
		assert(_view.get_texture().get_image().get_size() == resolution)
		gpu = timing.summary(SAMPLE_FRAMES)
	var row: Dictionary = {"case": sample["id"], "resolution": [resolution.x, resolution.y],
		"logical_size": [logical.x, logical.y], "ui_scale": ui_scale, "surface_counts": counts,
		"sample_wall_usec": sample_wall_usec, "cpu_usec_per_frame": cpu, "script_calls": calls,
		"gpu": gpu if _native else null,
		"process_draw_calls_per_frame": Metrics.stats(draw_calls) if _native else null,
		"viewport_canvas_draw_calls_per_frame": Metrics.stats(viewport_draw_calls) if _native else null}
	row.merge(layers)
	var gpu_label: String = "unavailable (headless)"
	if _native:
		gpu_label = "unavailable" if gpu["mean_ms_per_frame"] == null else "%.3f ms (%s)" % [gpu["mean_ms_per_frame"], gpu["timing_source"]]
	print("GRD-02 %dx%d %s: CPU mean %.2f us/frame, surface nodes %d, quads %d, shaders %d, canvas draws %s, GPU mean %s" % [
		resolution.x, resolution.y, row["case"], cpu["total"]["mean"], row["surface_live_nodes"],
		row["surface_particle_quads"], row["surface_shader_count"],
		str(row["viewport_canvas_draw_calls_per_frame"]["p50"]) if _native else "unavailable (headless)",
		gpu_label])
	board.queue_free()
	await _next_frame()
	return row

func _next_frame() -> void:
	if _native:
		await RenderingServer.frame_post_draw
	else:
		await process_frame
