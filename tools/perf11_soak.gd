extends "res://tools/fight_soak.gd"
## Same real fight, policy, hover inputs and frames as fight_soak. Partitioning
## and JSON run only after sampling stops. No budgets or permanent count guards.
const Trace = preload("res://tests/perf/combat_frame_trace.gd")
const Partition = preload("res://scripts/performance_phase_partitioner.gd")
const ProfiledScene = preload("res://tools/perf11/profiled_scene.gd")
const ProfiledBoard = preload("res://tools/perf11/profiled_board.gd")
const PIPELINES: Array = [Performance.PIPELINE_COMPILATIONS_CANVAS, Performance.PIPELINE_COMPILATIONS_MESH, Performance.PIPELINE_COMPILATIONS_SURFACE, Performance.PIPELINE_COMPILATIONS_DRAW, Performance.PIPELINE_COMPILATIONS_SPECIALIZATION]
const CAPTURE_ROUNDS: Array = [1, 10, 20]
var hover_actions: Array[Dictionary]
var boundaries: Array[Dictionary]
var attribution: Array[Dictionary]
var action_started: int = 0
var action_pipelines: Array = []
var hold_frames: int = maxi(0, int(OS.get_environment("LABYRINTH_PERF11_HOLD_FRAMES")))
var viewport_input: bool = OS.get_environment("LABYRINTH_PERF11_VIEWPORT_INPUT") == "1"

func _make_scene() -> Node:
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	var bundle: Dictionary = packed._bundled.duplicate(true)
	var variants: Array = bundle["variants"]
	var scene_script: Script = ProfiledScene
	var reference_path: String = OS.get_environment("LABYRINTH_PERF11_SCENE_SCRIPT")
	if not reference_path.is_empty(): scene_script = load(reference_path)
	for index: int in range(variants.size()):
		if not variants[index] is Script: continue
		if variants[index].resource_path == "res://scripts/run_scene.gd": variants[index] = scene_script
		if variants[index].resource_path == "res://scripts/combat_board_view.gd": variants[index] = ProfiledBoard
	bundle["variants"] = variants
	var instrumented := PackedScene.new()
	instrumented._bundled = bundle
	node_added.connect(_node_added)
	node_removed.connect(_node_removed)
	RenderingServer.frame_pre_draw.connect(_pre_draw)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	return instrumented.instantiate()

func _hover_action(kind: String, tile: Vector2i, begin: bool) -> void:
	if begin:
		Trace.enabled = true
		action_started = Time.get_ticks_usec()
		action_pipelines = _pipeline_counts()
	else:
		hover_actions.append({"kind": kind, "phase": phase, "tile": tile, "frame": Engine.get_process_frames(), "started_usec": action_started, "ended_usec": Time.get_ticks_usec(), "pipelines_before": action_pipelines})

func _send_hover_motion(board: Control, motion: InputEventMouseMotion) -> void:
	if not viewport_input:
		super._send_hover_motion(board, motion)
		return
	var viewport_motion: InputEventMouseMotion = motion.duplicate()
	viewport_motion.position = board.get_global_transform() * motion.position
	viewport_motion.global_position = viewport_motion.position
	root.push_input(viewport_motion, true)

func _hover_frame(board: Control, motion: InputEventMouseMotion) -> void:
	await super._hover_frame(board, motion)
	for frame: int in range(hold_frames):
		_hover_action("same_target_motion", board.get("_hover_tile"), true)
		_send_hover_motion(board, motion)
		_hover_action("same_target_motion", board.get("_hover_tile"), false)
		await process_frame

func _pipeline_counts() -> Array:
	var counts: Array = []
	for monitor: int in PIPELINES: counts.append(Performance.get_monitor(monitor))
	return counts

func _node_added(node: Node) -> void:
	Trace.event("node_added:" + node.get_class())

func _node_removed(node: Node) -> void:
	Trace.event("node_removed:" + node.get_class())

func _pre_draw() -> void:
	Trace.mark("pre_draw")

func _sample_frame() -> void:
	super._sample_frame()
	if not Trace.enabled: return
	boundaries.append({"frame": Engine.get_process_frames(), "phase": phase, "usec": Time.get_ticks_usec(), "pipelines": _pipeline_counts(),
		"viewport_cpu_ms": RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()),
		"viewport_gpu_ms": RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())})

func _sampling(enabled: bool) -> void:
	if not enabled: Trace.enabled = false
	super._sampling(enabled)

func _capture_round_proof(round_index: int) -> void:
	var frames: Array[Dictionary]
	for frame: int in Trace.frames:
		var intervals: Array = Trace.frames[frame]
		var inclusive: Dictionary = {}
		var counts: Dictionary = {}
		for interval: Dictionary in intervals:
			var key: String = interval["phase"]
			inclusive[key] = int(inclusive.get(key, 0)) + int(interval["end_usec"]) - int(interval["start_usec"])
			counts[key] = int(counts.get(key, 0)) + 1
		frames.append({"frame": frame, "inclusive_usec": inclusive, "counts": counts, "partition": Partition.partition(intervals), "events": Trace.events.get(frame, {}), "marks": Trace.marks.get(frame, {}), "intervals": intervals})
	attribution.append({"round": round_index, "actions": hover_actions.duplicate(true), "boundaries": boundaries.duplicate(true), "frames": frames})
	Trace.reset()
	hover_actions.clear()
	boundaries.clear()
	if not native or round_index not in CAPTURE_ROUNDS: return
	scene.queue_redraw()
	await RenderingServer.frame_post_draw
	var path: String = output.path_join("round_%02d.png" % round_index)
	var image: Image = root.get_texture().get_image()
	# Readback can use Retina backing pixels; keep normalization outside samples.
	if image.get_size() != VIEWPORT:
		image.resize(VIEWPORT.x, VIEWPORT.y, Image.INTERPOLATE_LANCZOS)
	assert(image.get_size() == VIEWPORT)
	assert(image.save_png(path) == OK)
	print(ProjectSettings.globalize_path(path))
	for frame: int in range(SETTLE_FRAMES): await RenderingServer.frame_post_draw
	previous_frame_usec = 0

func _write_report() -> void:
	if hand_sweep: report["hand_sweep"] = true
	report["hover_attribution"] = attribution
	report["hover_hold_frames"] = hold_frames
	report["hover_viewport_input"] = viewport_input
	report["hover_scene_reference"] = OS.get_environment("LABYRINTH_PERF11_SCENE_SCRIPT")
	report["attribution_scope"] = "Inclusive script wall intervals, exact frame IDs, node events; headless has no GPU/pipelines or native tooltip timer. Root viewport timing is delayed and excludes subviewports."
	super._write_report()
