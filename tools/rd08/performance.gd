extends SceneTree

## One native sample. The Python driver runs exact A/B, B/A, A/B processes.
const Fixture = preload("res://tools/rd04/real_fixture.gd")
const ROOT: String = "/private/tmp/labyrinth_codex/rd-08"
const WARMUP: int = 30
const SAMPLE_FRAMES: int = 180
var check_only: bool = false

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	check_only = OS.get_cmdline_user_args().has("--check-only")
	if DisplayServer.get_name() == "headless": process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless" and not check_only:
		push_error("Native frame costs belong to the design owner"); quit(1); return
	var args := OS.get_cmdline_user_args()
	var sample_id: String = args[args.find("--sample-id") + 1] if args.has("--sample-id") else "check"
	Fixture.install_save(ROOT + "/overlap.json")
	Engine.max_fps = 0
	if not check_only: DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var canvas := Fixture.make_canvas(self)
	RenderingServer.viewport_set_measure_render_time(canvas.get_viewport_rid(), true)
	var scene := Fixture.resume(self, canvas)
	for frame: int in range(WARMUP): await process_frame
	var board: Control = scene.get("board_view")
	var frame_usec: Array[int]
	var engine_usec: Array[float]
	var render_cpu_usec: Array[float]
	var render_gpu_usec: Array[float]
	for frame: int in range(SAMPLE_FRAMES):
		var started: int = Time.get_ticks_usec()
		await process_frame
		if not check_only: await RenderingServer.frame_post_draw
		frame_usec.append(Time.get_ticks_usec() - started)
		engine_usec.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000000.0)
		render_cpu_usec.append(RenderingServer.viewport_get_measured_render_time_cpu(canvas.get_viewport_rid()) * 1000.0)
		render_gpu_usec.append(RenderingServer.viewport_get_measured_render_time_gpu(canvas.get_viewport_rid()) * 1000.0)
	DirAccess.make_dir_recursive_absolute(ROOT + "/performance")
	var file := FileAccess.open(ROOT + "/performance/" + sample_id + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"sample_id": sample_id, "renderer": DisplayServer.get_name(), "size": [1920,1080], "check_only": check_only, "samples": SAMPLE_FRAMES, "frame_usec": frame_usec, "engine_usec": engine_usec, "render_cpu_usec": render_cpu_usec, "render_gpu_usec": render_gpu_usec}, "\t"))
	if not check_only:
		await RenderingServer.frame_post_draw
		canvas.get_texture().get_image().save_png(ROOT + "/performance/" + sample_id + ".png")
	if not check_only: print(ROOT + "/performance/" + sample_id + ".png")
	print("RD08 PERFORMANCE SAMPLE: PASS (%s, %d frames, %s)" % [sample_id, SAMPLE_FRAMES, "headless setup only" if check_only else "native"])
	quit()
