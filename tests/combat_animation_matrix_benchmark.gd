extends "res://tests/enemy_shadow_dissolve_performance_benchmark.gd"
## Presentation matrix, complementary to runtime_frame's routed gameplay actions.
## Singleton actors isolate content costs; small groups exercise combinations.
const MATRIX_OUTPUT := "user://performance/combat_animation_matrix"
const MATRIX_FRAMES: int = 96
const GuardianRenderer = preload("res://scripts/guardian_cutout/renderer.gd")
const TYPES = ["crawler", "warden", "acolyte", "bile_bloomer", "chainbound_gaoler", "cinder_droplet", "cinder_ooze", "frostglass_lancer", "grave_surgeon", "harrier", "iskaldra", "lightning_wisp", "noctyrax", "tharokh", "vaeloryx", "veilbound_acolyte", "vyraketh", "zekarion"]
const MOTION_KEYS = {"warden":"warden_motion", "chainbound_gaoler":"gaoler_motion", "frostglass_lancer":"frostglass_motion"}
var _viewports: Array[SubViewport] = []
var _viewport_cpu: Array[float] = []
var _viewport_gpu: Array[float] = []
var _phase_active: bool = false
var _drawn_viewports: Array[SubViewport] = []

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	OS.low_processor_usage_mode = false
	OS.low_processor_usage_mode_sleep_usec = 1000
	root.mode = Window.MODE_WINDOWED
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_size = VIEWPORT_SIZE
	root.size = VIEWPORT_SIZE
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(VIEWPORT_SIZE)
	if OS.get_environment("LABYRINTH_ANIMATION_MATRIX_UNCAPPED") == "1":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DisplayServer.window_move_to_foreground()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MATRIX_OUTPUT))
	_render_pulse = RenderPulse.new()
	_render_pulse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_render_pulse.z_index = RenderingServer.CANVAS_ITEM_Z_MAX
	root.add_child(_render_pulse)
	var board: Control = CombatBoardView.new()
	board.size = Vector2(VIEWPORT_SIZE)
	root.add_child(board)
	var sampler := FrameSampler.new()
	sampler.request_render = _render_pulse.pulse
	sampler.observe_frame = _observe_probe_focus
	sampler.measured_viewport_rid = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(sampler.measured_viewport_rid, true)
	root.add_child(sampler)
	RenderingServer.frame_pre_draw.connect(_observe_drawn_viewports)
	RenderingServer.frame_post_draw.connect(_sample_all_viewports)
	if not await _acquire_probe_window_focus():
		push_error("Animation matrix requires an unlocked display and foreground window")
		quit(1)
		return
	await _settle_matrix_window()
	await _settle_render_frames(30)
	var cases: Dictionary = {}
	for actor: String in TYPES:
		cases[actor] = [actor]
	for actor: String in GuardianRenderer.ACTOR_IDS:
		cases[actor] = [actor]
	cases["early_melee"] = ["crawler", "crawler", "warden"]
	cases["mixed_casters"] = ["acolyte", "lightning_wisp", "veilbound_acolyte", "grave_surgeon"]
	cases["split_family"] = ["cinder_ooze", "cinder_droplet", "cinder_droplet", "cinder_droplet"]
	cases["guardian_helpers"] = ["gallows_roc", "roc_fledgling", "roc_fledgling"]
	cases["dragon_support"] = ["noctyrax", "warden", "acolyte"]
	cases["late_specialists"] = ["chainbound_gaoler", "harrier", "frostglass_lancer", "bile_bloomer"]
	var filter: PackedStringArray = OS.get_environment("LABYRINTH_ANIMATION_MATRIX_FILTER").split(",", false)
	var results: Dictionary = {}
	for case_id: String in cases:
		if not filter.is_empty() and not filter.has(case_id):
			continue
		print("ANIMATION MATRIX PHASE: " + case_id)
		var state: Dictionary = _matrix_state(cases[case_id])
		var presentation: Dictionary = _matrix_presentation(state, "idle", 0)
		var start: int = Time.get_ticks_usec()
		board.call("set_combat_state", state, [], [], Vector2i(-1,-1), "", "", {}, {}, presentation)
		var install_usec: int = Time.get_ticks_usec() - start
		await _settle_render_frames(30)
		_viewports.clear()
		_collect_viewports(board)
		var entry: Dictionary = {"actor_types":cases[case_id], "install_usec":install_usec, "subviewport_count":_viewports.size(), "lighting":board.call("art_treatment_snapshot")["light_count"]}
		if (cases[case_id] as Array).size() > 1 and not (cases[case_id] as Array).has("crawler"):
			_expect(int(entry["lighting"]) > 0, case_id + " must exercise real torch illumination")
		for phase_name: String in ["idle", "walk", "attack", "reduced_motion"]:
			entry[phase_name] = await _measure_matrix_phase(board, sampler, state, phase_name)
		entry["pose_microbenchmark"] = _pose_microbenchmark(board, state)
		entry["static_memory_bytes"] = int(Performance.get_monitor(Performance.MEMORY_STATIC))
		entry["nodes"] = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		entry["objects"] = int(Performance.get_monitor(Performance.OBJECT_COUNT))
		_expect(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) == 0, case_id + " has no orphan nodes")
		results[case_id] = entry
	# Readbacks and PNG encoding are a separate replay after ALL timed phases.
	for case_id: String in results:
		if (cases[case_id] as Array).size() < 2:
			continue
		var state: Dictionary = _matrix_state(cases[case_id])
		board.process_mode = Node.PROCESS_MODE_DISABLED
		var proof_presentation: Dictionary = _matrix_presentation(state, "attack", 40)
		proof_presentation["ambient_time_seconds"] = 42.0
		proof_presentation["umbra_time_seconds"] = 42.0
		proof_presentation["protagonist_motion"] = {"clip":"attack", "phase":0.5, "direction":Vector2i(0,1)}
		board.call("set_combat_state", state, [], [], Vector2i(-1,-1), "", "", {}, {}, proof_presentation)
		var treatment: RefCounted = board.get("_art_treatment")
		treatment.set("_clock", 42.0)
		treatment.call("advance", 0.0, false)
		board.set("_idle_elapsed", 42.0)
		for layer: Control in board.call("_retained_render_layers"):
			layer.set("_idle_elapsed", 42.0)
			layer.queue_redraw()
		await _settle_render_frames(4)
		var image: Image = root.get_texture().get_image()
		_expect(image.get_size() == VIEWPORT_SIZE, "Matrix proof size must be exact")
		image.save_png(ProjectSettings.globalize_path(MATRIX_OUTPUT.path_join(case_id + ".png")))
		board.process_mode = Node.PROCESS_MODE_INHERIT
	var report := {"schema_version":1, "workload_id":"all_combat_cutouts_and_six_small_groups_v3", "sample_boundary":"RenderingServer.frame_post_draw", "phase_frames":MATRIX_FRAMES, "warmup_frames":30, "viewport":"1920x1080", "actual_backing_size":str(root.get_texture().get_size()), "actual_window_size":str(DisplayServer.window_get_size()), "display_driver":DisplayServer.get_name(), "transition_frames":12, "vsync_mode":DisplayServer.window_get_vsync_mode(), "renderer":RenderingServer.get_video_adapter_name(), "rendering_method":RenderingServer.get_current_rendering_method(), "cases":results, "case_ids":results.keys(), "unfocused_observations":_unfocused_observations, "semantic_errors":_errors}
	_expect(_unfocused_observations == 0, "Focus loss invalidates the matrix")
	var file := FileAccess.open(MATRIX_OUTPUT.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("ANIMATION MATRIX RESULT: %s" % JSON.stringify(report))
	print(ProjectSettings.globalize_path(MATRIX_OUTPUT))
	board.free()
	quit(0 if _errors.is_empty() else 1)

func _matrix_state(types: Array) -> Dictionary:
	var state: Dictionary = _defeated_state()
	state["room_element"] = "fire" if types.has("cinder_ooze") else "earth"
	state["surfaces"] = {}
	if types.size() > 1 and not types.has("crawler"):
		for tile: Vector2i in [Vector2i(1,1), Vector2i(10,1), Vector2i(1,7), Vector2i(10,7), Vector2i(5,1)]:
			state["grid"][tile.y][tile.x] = "pillar"
	state["enemies"] = []
	var positions = [Vector2i(3,2), Vector2i(7,2), Vector2i(2,5), Vector2i(8,5)]
	for index: int in range(types.size()):
		var actor: String = types[index]
		var unit: Dictionary = _support_unit(index+1, positions[index])
		unit["type"] = actor
		unit["name"] = actor
		unit["hp"] = 60
		unit["max_hp"] = 60
		unit["footprint"] = Vector2i(2,2) if actor in ["noctyrax","tharokh","iskaldra","vaeloryx","vyraketh","zekarion"] else Vector2i.ONE
		(state["enemies"] as Array).append(unit)
	return state

func _matrix_presentation(state: Dictionary, phase_name: String, frame: int) -> Dictionary:
	var result: Dictionary = {"board_backdrop_visible":true, "reduced_motion":phase_name == "reduced_motion"}
	if phase_name in ["idle", "reduced_motion"]:
		return result
	var direction: Vector2i = [Vector2i(1,0),Vector2i(0,-1),Vector2i(-1,0),Vector2i(0,1)][int(frame / 24) % 4]
	for unit: Dictionary in state["enemies"]:
		var actor: String = unit["type"]
		var key: String = "guardian_motion" if GuardianRenderer.handles(actor) else str(MOTION_KEYS.get(actor, actor+"_motion"))
		if not result.has(key): result[key] = {}
		var clip: String = "claw" if actor == "noctyrax" and phase_name == "attack" else phase_name
		var motion: Dictionary = {"clip":clip, "phase":float(frame % 48)/48.0, "direction":direction, "contact":0.42}
		if GuardianRenderer.handles(actor): motion["action"] = "strike"
		if actor == "iskaldra": motion["action"] = "talon"
		result[key]["enemy_%d" % int(unit["id"])] = motion
	return result

func _measure_matrix_phase(board: Control, sampler: FrameSampler, state: Dictionary, phase_name: String) -> Dictionary:
	board.call("set_combat_state",state,[],[],Vector2i(-1,-1),"","",{},{},_matrix_presentation(state,phase_name,0))
	await _settle_render_frames(12)
	board.call("reset_render_instrumentation")
	var submissions: Array[float] = []
	_viewport_cpu.clear()
	_viewport_gpu.clear()
	var starting_poses: Dictionary = {}
	var observed_clips: Dictionary = {}
	var pipelines: int = _canvas_pipeline_compilation_count()
	_phase_active = true
	sampler.begin()
	for frame: int in range(MATRIX_FRAMES):
		if phase_name not in ["idle", "reduced_motion"]:
			var presentation: Dictionary = _matrix_presentation(state,phase_name,frame)
			var started: int = Time.get_ticks_usec()
			board.call("set_combat_state",state,[],[],Vector2i(-1,-1),"","",{},{},presentation)
			submissions.append(float(Time.get_ticks_usec()-started))
		await _await_render_frame()
		if frame == 0 or frame == 23:
			for unit: Dictionary in state["enemies"]:
				var renderer: Node = board.call("unit_cutout_renderer", unit)
				var actor_key: String = "enemy_%d" % int(unit["id"])
				_expect(renderer != null, actor_key + " must have a live cutout")
				if renderer == null: continue
				var snapshot: Dictionary = renderer.call("snapshot")
				var observed: String = str(snapshot["clip"])
				observed_clips[str(unit["type"])] = observed
				_expect(bool(snapshot["active"]), actor_key + " must be active")
				_expect(observed == "rest" if phase_name == "reduced_motion" else observed == "idle" if phase_name == "idle" else observed == "walk" if phase_name == "walk" else observed not in ["idle", "walk", "rest"], str(unit["type"]) + ": intended " + phase_name + ", observed " + observed)
				var pose: Array = _visible_pose(renderer)
				if frame == 0: starting_poses[actor_key] = pose
				else: _expect((pose == starting_poses[actor_key]) if phase_name == "reduced_motion" else (pose != starting_poses[actor_key]), actor_key + " obeys motion setting during " + phase_name)
	_phase_active = false
	var result: Dictionary = _phase_result(sampler.finish())
	# TIME_PROCESS is refreshed by Godot at roughly one-second intervals and
	# includes previous actor construction during short uncapped phases. It is
	# not a per-frame CPU timer; use submission_usec and delivered intervals.
	result.erase("process_ms")
	result.erase("raw_process_ms")
	result["observed_clips"] = observed_clips
	result["submission_usec"] = _stats(submissions)
	result["all_subviewport_cpu_ms"] = _stats(_viewport_cpu)
	result["all_subviewport_gpu_ms"] = _stats(_viewport_gpu)
	result["all_subviewport_gpu_timing_available"] = float(result["all_subviewport_gpu_ms"]["max"]) > 0.0
	result["canvas_pipeline_compilations"] = _canvas_pipeline_compilation_count()-pipelines
	result["board_profile"] = board.call("render_instrumentation_snapshot")
	_expect(int(result["sample_count"]) == MATRIX_FRAMES, "Every matrix frame must be sampled")
	_expect(float(result["frame_interval_ms"]["max"]) < 500.0, "Delivery throttle invalidates steady matrix")
	return result

func _collect_viewports(node: Node) -> void:
	for child: Node in node.get_children():
		if child is SubViewport:
			_viewports.append(child as SubViewport)
			RenderingServer.viewport_set_measure_render_time((child as SubViewport).get_viewport_rid(),true)
		_collect_viewports(child)

func _observe_drawn_viewports() -> void:
	_drawn_viewports.clear()
	if not _phase_active: return
	for viewport: SubViewport in _viewports:
		if viewport.render_target_update_mode != SubViewport.UPDATE_DISABLED:
			_drawn_viewports.append(viewport)

func _sample_all_viewports() -> void:
	if not _phase_active: return
	var cpu: float = 0.0
	var gpu: float = 0.0
	for viewport: SubViewport in _drawn_viewports:
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(viewport.get_viewport_rid())
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(viewport.get_viewport_rid())
	_viewport_cpu.append(cpu)
	_viewport_gpu.append(gpu)

func _pose_microbenchmark(board: Control, state: Dictionary) -> Dictionary:
	var results: Dictionary = {}
	for unit: Dictionary in state["enemies"]:
		var renderer: Node = board.call("unit_cutout_renderer",unit)
		_expect(renderer != null, "Every intended actor must have its live renderer")
		if renderer == null: continue
		var rigs: Dictionary = renderer.get("rigs")
		var times: Array[float] = []
		for facing: String in rigs:
			var rig: Node = rigs[facing]
			for sample: int in range(48):
				var start: int = Time.get_ticks_usec()
				rig.call("apply_pose","walk",float(sample)/48.0)
				times.append(float(Time.get_ticks_usec()-start))
		results[str(unit["type"])] = _stats(times)
	return results

func _visible_pose(renderer: Node) -> Array:
	var rigs: Dictionary = renderer.get("rigs")
	var pose: Array = []
	for rig: Node2D in rigs.values():
		if not rig.visible: continue
		for bone: Bone2D in (rig.get("bones") as Dictionary).values():
			pose.append(bone.transform)
	return pose

func _settle_matrix_window() -> void:
	var deadline: int = Time.get_ticks_msec() + 5000
	var stable_samples: int = 0
	while Time.get_ticks_msec() < deadline and stable_samples < 20:
		if root.size != VIEWPORT_SIZE or DisplayServer.window_get_size() != VIEWPORT_SIZE or DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
			root.mode = Window.MODE_WINDOWED
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			root.size = VIEWPORT_SIZE
			DisplayServer.window_set_size(VIEWPORT_SIZE)
			stable_samples = 0
		else:
			stable_samples += 1
		await create_timer(0.05).timeout
	_expect(stable_samples == 20, "Native window must retain 1920x1080 for a full second before timing")
