extends SceneTree

const Audit = preload("res://tests/suites/card_targeting_audit_suite.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Trace = preload("res://tests/perf/combat_frame_trace.gd")
const Partition = preload("res://scripts/performance_phase_partitioner.gd")
const Candidate = preload("res://tools/ptf09/profiled_scene.gd")
const BASELINE: String = "/private/tmp/labyrinth_codex/ptf-09/baseline/"
const OUTPUT: String = "/private/tmp/labyrinth_codex/ptf-09/"
const SAMPLE_FRAMES: int = 120
const WARMUP_FRAMES: int = 20
const SIZE := Vector2i(1920, 1080)
const TILES: Array = [Vector2i(3, 4), Vector2i(4, 4), Vector2i(2, 3), Vector2i(1, 1)]
const ORDER: Array = ["A", "B", "B", "A", "A", "B"]
var results: Array[Dictionary]
var canvas: SubViewport
var hover_only: bool = false

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	hover_only = OS.get_cmdline_user_args().has("--hover-only")
	if DisplayServer.get_name() == "headless": process_frame.connect(_draw_boundary)
	call_deferred("_run")

func _run() -> void:
	root.size = SIZE
	root.content_scale_size = SIZE
	canvas = SubViewport.new()
	canvas.size = SIZE
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	if not FileAccess.file_exists(BASELINE + "profiled_scene.gd"):
		push_error("Run python3 tools/ptf09/prepare_baseline.py first")
		quit(1)
		return
	var reference: Script = load(BASELINE + "profiled_scene.gd")
	var reference_board: Script = load(BASELINE + "combat_board_view.gd")
	for side: String in ORDER:
		var packed: PackedScene = load("res://scenes/run_scene.tscn")
		var scene: Node = packed.instantiate()
		scene.set_script(reference if side == "A" else Candidate)
		if side == "A": scene.get_node("BoardUnderlay/CombatBoard").set_script(reference_board)
		canvas.add_child(scene)
		for frame: int in range(WARMUP_FRAMES): await process_frame
		Audit._install(scene, Audit.state_for(Combat.new(), "dull_bolt"))
		await scene.call("_on_card_pressed", 0)
		scene.call("_refresh_ui")
		for frame: int in range(WARMUP_FRAMES):
			scene.call("_on_board_tile_hovered", TILES[frame % TILES.size()])
			await process_frame
		scene.call("set_runtime_performance_instrumentation_enabled", true)
		scene.call("consume_runtime_performance_instrumentation_snapshot")
		Trace.reset()
		Trace.enabled = not hover_only
		scene.set("sample_hover", true)
		var frame_process: Array[float]
		var frame_wall: Array[int]
		for frame: int in range(SAMPLE_FRAMES):
			var started: int = Time.get_ticks_usec()
			scene.call("_on_board_tile_hovered", TILES[frame % TILES.size()])
			await process_frame
			if not hover_only:
				frame_wall.append(Time.get_ticks_usec() - started)
				frame_process.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000000.0)
		scene.set("sample_hover", false)
		Trace.enabled = false
		var cpu: Array[int]
		var row: Dictionary = {"side": side, "renderer": DisplayServer.get_name(), "hover_usec": scene.get("hover_samples")}
		if not hover_only:
			for intervals: Array in Trace.frames.values():
				var partition: Dictionary = Partition.partition(intervals)
				cpu.append(int(partition.get("total_usec", 0)))
			row.merge({"engine_process_usec": frame_process, "frame_wall_usec": frame_wall, "runtime_cpu_usec": cpu,
				"runtime": scene.call("runtime_performance_instrumentation_snapshot"), "trace": Trace.frames})
		results.append(row)
		if not hover_only and DisplayServer.get_name() != "headless" and results.size() == ORDER.size():
			await RenderingServer.frame_post_draw
			canvas.get_texture().get_image().save_png(OUTPUT + "performance.png")
		scene.queue_free()
		for frame: int in range(WARMUP_FRAMES): await process_frame
	var label: String = "headless" if DisplayServer.get_name() == "headless" else "native"
	if hover_only: label = "hover_feedback1_" + label
	var file := FileAccess.open(OUTPUT + "performance_" + label + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"baseline_head": FileAccess.get_file_as_string(BASELINE + "head.txt").strip_edges(), "order": ORDER, "sample_frames": SAMPLE_FRAMES, "results": results}, "\t"))
	file.close()
	print("PTF09 PERFORMANCE: completed A/B, B/A, A/B; " + label + " (no GPU claims for headless)")
	print(OUTPUT)
	quit()

func _draw_boundary() -> void:
	RenderingServer.frame_post_draw.emit()
