extends SceneTree

const CombatBoardView = preload("res://scripts/combat_board_view.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")

const VIEWPORT_SIZE := Vector2i(1920, 1080)
const OUTPUT_DIR := "user://performance/enemy_shadow_dissolve_benchmark"
const WORKLOAD_ID := "noctyrax_lethal_shadow_dissolve_v1"
const FRAME_COUNT := 28
const FRAME_SECONDS := 0.037
const IDLE_SAMPLE_FRAMES := 90
const WARM_REPETITIONS := 4


class FrameSampler:
	extends Node

	var active: bool = false
	var previous_tick_usec: int = 0
	var last_draw_tick_usec: int = 0
	var request_render: Callable
	var observe_frame: Callable
	var measured_viewport_rid: RID
	var frame_intervals_ms: Array[float] = []
	var process_ms: Array[float] = []
	var render_setup_cpu_ms: Array[float] = []
	var viewport_render_cpu_ms: Array[float] = []
	var viewport_render_gpu_ms: Array[float] = []
	var draw_calls: Array[float] = []
	var objects_in_frame: Array[float] = []
	var primitives_in_frame: Array[float] = []
	var skip_next_observed_frame: bool = false

	func _ready() -> void:
		RenderingServer.frame_post_draw.connect(_on_frame_post_draw)
		set_process(false)

	func _exit_tree() -> void:
		if RenderingServer.frame_post_draw.is_connected(_on_frame_post_draw):
			RenderingServer.frame_post_draw.disconnect(_on_frame_post_draw)

	func _process(_delta: float) -> void:
		if request_render.is_valid():
			request_render.call()

	func begin() -> void:
		frame_intervals_ms.clear()
		process_ms.clear()
		render_setup_cpu_ms.clear()
		viewport_render_cpu_ms.clear()
		viewport_render_gpu_ms.clear()
		draw_calls.clear()
		objects_in_frame.clear()
		primitives_in_frame.clear()
		assert(last_draw_tick_usec > 0, "Frame sampling requires a settled rendered frame")
		previous_tick_usec = last_draw_tick_usec
		active = true
		set_process(true)

	func finish() -> Dictionary:
		active = false
		set_process(false)
		return {
			"frame_interval_ms": frame_intervals_ms.duplicate(),
			"process_ms": process_ms.duplicate(),
			"render_setup_cpu_ms": render_setup_cpu_ms.duplicate(),
			"viewport_render_cpu_ms": viewport_render_cpu_ms.duplicate(),
			"viewport_render_gpu_ms": viewport_render_gpu_ms.duplicate(),
			"draw_calls": draw_calls.duplicate(),
			"objects_in_frame": objects_in_frame.duplicate(),
			"primitives_in_frame": primitives_in_frame.duplicate(),
		}

	func _on_frame_post_draw() -> void:
		var now_tick: int = Time.get_ticks_usec()
		last_draw_tick_usec = now_tick
		if not active:
			return
		if observe_frame.is_valid():
			var observation: Variant = observe_frame.call()
			if typeof(observation) == TYPE_BOOL and not bool(observation):
				previous_tick_usec = now_tick
				skip_next_observed_frame = true
				return
		if skip_next_observed_frame:
			skip_next_observed_frame = false
			previous_tick_usec = now_tick
			return
		frame_intervals_ms.append(float(now_tick - previous_tick_usec) / 1000.0)
		process_ms.append(float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0)
		render_setup_cpu_ms.append(RenderingServer.get_frame_setup_time_cpu())
		viewport_render_cpu_ms.append(
			RenderingServer.viewport_get_measured_render_time_cpu(measured_viewport_rid)
			if measured_viewport_rid.is_valid()
			else 0.0
		)
		viewport_render_gpu_ms.append(
			RenderingServer.viewport_get_measured_render_time_gpu(measured_viewport_rid)
			if measured_viewport_rid.is_valid()
			else 0.0
		)
		draw_calls.append(float(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		objects_in_frame.append(float(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)))
		primitives_in_frame.append(float(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
		previous_tick_usec = now_tick


class RenderPulse:
	extends Control

	var phase: bool = false

	func pulse() -> void:
		phase = not phase
		queue_redraw()

	func _draw() -> void:
		var alpha: float = 0.001 if phase else 0.002
		draw_rect(Rect2(Vector2.ZERO, Vector2.ONE), Color(1.0, 1.0, 1.0, alpha), true)


var _errors: Array[String] = []
var _render_pulse: RenderPulse = null
var _focus_observations: int = 0
var _unfocused_observations: int = 0


func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	OS.low_processor_usage_mode = false
	OS.low_processor_usage_mode_sleep_usec = 1000
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = VIEWPORT_SIZE
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.size = VIEWPORT_SIZE
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(VIEWPORT_SIZE)
	DisplayServer.window_move_to_foreground()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_clear_probe_output(OUTPUT_DIR)

	_render_pulse = RenderPulse.new()
	_render_pulse.name = "EnemyDissolvePerformanceRenderPulse"
	_render_pulse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_render_pulse.size = Vector2.ONE
	_render_pulse.z_index = RenderingServer.CANVAS_ITEM_Z_MAX
	root.add_child(_render_pulse)

	var board: Control = CombatBoardView.new()
	board.name = "EnemyDissolvePerformanceBoard"
	board.position = Vector2.ZERO
	board.size = Vector2(VIEWPORT_SIZE)
	root.add_child(board)
	await process_frame
	board.call("_load_assets")

	var sampler := FrameSampler.new()
	sampler.request_render = _render_pulse.pulse
	sampler.observe_frame = _observe_probe_focus
	sampler.measured_viewport_rid = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(sampler.measured_viewport_rid, true)
	root.add_child(sampler)
	_expect(await _acquire_probe_window_focus(), "Native dragon-death benchmark window must become focused")
	await _settle_render_frames(12)
	var prewarmed_effect: Control = board.get("_enemy_shadow_dissolve_spare_effect") as Control
	_expect(bool(board.get("_enemy_shadow_dissolve_shader_prewarm_submitted")), "Dragon-death shader prewarm must be submitted during board setup")
	_expect(prewarmed_effect != null and is_instance_valid(prewarmed_effect), "Board setup must retain the initialized dissolve effect")
	_expect(prewarmed_effect != null and not prewarmed_effect.visible, "The retained dissolve effect must be hidden after its prewarm draw")
	var prewarmed_effect_id: int = prewarmed_effect.get_instance_id() if prewarmed_effect != null else 0

	var alive_state: Dictionary = _alive_state()
	var defeated_state: Dictionary = _defeated_state()
	board.call("set_combat_state", alive_state, [], [], Vector2i(-1, -1), "", "", {}, {}, _base_presentation())
	await _settle_render_frames(12)
	var initial_nodes: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var initial_orphans: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))

	board.call("reset_render_instrumentation")
	sampler.begin()
	for _frame: int in range(IDLE_SAMPLE_FRAMES):
		await _await_render_frame()
	var populated_idle: Dictionary = _phase_result(sampler.finish())
	populated_idle["board_instrumentation"] = board.call("render_instrumentation_snapshot")

	var cold_pipeline_before: int = _canvas_pipeline_compilation_count()
	var cold_result: Dictionary = await _measure_death(board, sampler, defeated_state)
	var cold_pipeline_after: int = _canvas_pipeline_compilation_count()
	cold_result["canvas_pipeline_compilations"] = cold_pipeline_after - cold_pipeline_before
	_expect(int(cold_result.get("authored_updates_submitted", 0)) > 0, "Cold death must submit at least one authored dissolve update")
	_expect(int(cold_result.get("skipped_authored_updates", -1)) == 0, "Cold death capture must submit every authored dissolve update")
	_expect(int(cold_result.get("effect_nodes_at_peak", 0)) == 1, "Cold death must render one procedural dissolve node")
	_expect(int(cold_result.get("canvas_pipeline_compilations", -1)) == 0, "The first dragon death must reuse the precompiled canvas pipeline")
	var cold_effect: Control = (board.get("_enemy_shadow_dissolve_effects_by_key") as Dictionary).get("enemy_401", null) as Control
	_expect(cold_effect != null and cold_effect.get_instance_id() == prewarmed_effect_id, "The first dragon death must reuse the retained effect node and material")

	var warm_runs: Array[Dictionary] = []
	for _repetition: int in range(WARM_REPETITIONS):
		board.call("set_combat_state", alive_state, [], [], Vector2i(-1, -1), "", "", {}, {}, _base_presentation())
		await _settle_render_frames(6)
		var pipeline_before: int = _canvas_pipeline_compilation_count()
		var warm_result: Dictionary = await _measure_death(board, sampler, defeated_state)
		warm_result["canvas_pipeline_compilations"] = _canvas_pipeline_compilation_count() - pipeline_before
		warm_runs.append(warm_result)
	var repeated_death: Dictionary = _aggregate_runs(warm_runs)
	_expect(int(repeated_death.get("skipped_authored_updates", -1)) == 0, "Repeated death captures must submit every authored dissolve update")

	board.call("set_combat_state", defeated_state, [], [], Vector2i(-1, -1), "", "", {}, {}, _death_presentation(0.46))
	await _settle_render_frames(3)
	var proof_image: Image = root.get_viewport().get_texture().get_image()
	if proof_image.get_size() != VIEWPORT_SIZE:
		proof_image.resize(VIEWPORT_SIZE.x, VIEWPORT_SIZE.y, Image.INTERPOLATE_LANCZOS)
	_expect(proof_image.get_size() == VIEWPORT_SIZE, "Dragon-death benchmark proof must be 1920x1080")
	_expect(
		proof_image.save_png(ProjectSettings.globalize_path("%s/noctyrax_mid_dissolve.png" % OUTPUT_DIR)) == OK,
		"Dragon-death benchmark proof image must save"
	)
	board.call("set_combat_state", defeated_state, [], [], Vector2i(-1, -1), "", "", {}, {}, _base_presentation())
	await _settle_render_frames(4)
	_expect((board.get("_enemy_shadow_dissolve_effects_by_key") as Dictionary).is_empty(), "Clearing death presentation must release the dissolve node")
	var returned_spare: Control = board.get("_enemy_shadow_dissolve_spare_effect") as Control
	_expect(returned_spare != null and is_instance_valid(returned_spare) and not returned_spare.visible, "Clearing death presentation must return one hidden dissolve effect to the spare slot")
	var final_nodes: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var final_orphans: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	_expect(final_nodes <= initial_nodes + 2, "Repeated dragon deaths must not grow the live node tree")
	_expect(final_orphans <= initial_orphans, "Repeated dragon deaths must not leak orphan nodes")

	var result := {
		"schema_version": 1,
		"workload_id": WORKLOAD_ID,
		"sample_boundary": "RenderingServer.frame_post_draw",
		"viewport": "%dx%d" % [VIEWPORT_SIZE.x, VIEWPORT_SIZE.y],
		"ui_scale": 1.0,
		"enemy_type": "noctyrax",
		"enemy_footprint": "2x2",
		"dissolve_frame_count": FRAME_COUNT,
		"dissolve_frame_seconds": FRAME_SECONDS,
		"warm_repetitions": WARM_REPETITIONS,
		"renderer": RenderingServer.get_video_adapter_name(),
		"renderer_vendor": RenderingServer.get_video_adapter_vendor(),
		"rendering_method": str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "")),
		"display_driver": DisplayServer.get_name(),
		"window_focused": DisplayServer.window_is_focused(),
		"focus_observations": _focus_observations,
		"unfocused_observations": _unfocused_observations,
		"populated_idle": populated_idle,
		"cold_death": cold_result,
		"repeated_death": repeated_death,
		"initial_nodes": initial_nodes,
		"final_nodes": final_nodes,
		"initial_orphan_nodes": initial_orphans,
		"final_orphan_nodes": final_orphans,
		"final_objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"static_memory_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
		"semantic_errors": _errors,
	}
	print("ENEMY SHADOW DISSOLVE PERF RESULT: %s" % JSON.stringify(result))
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	board.queue_free()
	sampler.queue_free()
	await process_frame
	quit(0 if _errors.is_empty() else 1)


func _measure_death(board: Control, sampler: FrameSampler, defeated_state: Dictionary) -> Dictionary:
	board.call("reset_render_instrumentation")
	var nodes_before: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var objects_before: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var submissions_usec: Array[float] = []
	var effect_nodes_at_peak: int = 0
	var authored_updates_submitted: int = 0
	var frame_duration_usec: int = int(round(FRAME_SECONDS * 1000000.0))
	var authored_duration_usec: int = FRAME_COUNT * frame_duration_usec
	var last_submitted_frame: int = 0
	var started_usec: int = Time.get_ticks_usec()
	sampler.begin()
	while true:
		var elapsed_usec: int = Time.get_ticks_usec() - started_usec
		var due_frame: int = clampi(1 + int(elapsed_usec / frame_duration_usec), 1, FRAME_COUNT)
		if due_frame > last_submitted_frame:
			var progress: float = float(due_frame - 1) / float(FRAME_COUNT - 1)
			var submission_started_usec: int = Time.get_ticks_usec()
			board.call("set_combat_state", defeated_state, [], [], Vector2i(-1, -1), "", "", {}, {}, _death_presentation(progress))
			submissions_usec.append(float(Time.get_ticks_usec() - submission_started_usec))
			authored_updates_submitted += 1
			last_submitted_frame = due_frame
			effect_nodes_at_peak = maxi(effect_nodes_at_peak, (board.get("_enemy_shadow_dissolve_effects_by_key") as Dictionary).size())
		if elapsed_usec >= authored_duration_usec:
			break
		await process_frame
	await _await_render_frame()
	var sampled: Dictionary = sampler.finish()
	var result: Dictionary = _phase_result(sampled)
	result["authored_duration_ms"] = float(authored_duration_usec) / 1000.0
	result["measured_duration_ms"] = float(Time.get_ticks_usec() - started_usec) / 1000.0
	result["authored_updates_submitted"] = authored_updates_submitted
	result["skipped_authored_updates"] = FRAME_COUNT - authored_updates_submitted
	result["submission_usec"] = _stats(submissions_usec)
	result["raw_submission_usec"] = submissions_usec
	result["effect_nodes_at_peak"] = effect_nodes_at_peak
	result["node_delta_at_end"] = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)) - nodes_before
	result["object_delta_at_end"] = int(Performance.get_monitor(Performance.OBJECT_COUNT)) - objects_before
	result["board_instrumentation"] = board.call("render_instrumentation_snapshot")
	return result


func _phase_result(sampled: Dictionary) -> Dictionary:
	var intervals: Array[float] = _float_array(sampled.get("frame_interval_ms", []))
	var gpu: Array[float] = _float_array(sampled.get("viewport_render_gpu_ms", []))
	return {
		"measurement_class": "rendered_frame_interval",
		"sample_count": intervals.size(),
		"frame_interval_ms": _stats(intervals),
		"process_ms": _stats(_float_array(sampled.get("process_ms", []))),
		"render_setup_cpu_ms": _stats(_float_array(sampled.get("render_setup_cpu_ms", []))),
		"viewport_render_cpu_ms": _stats(_float_array(sampled.get("viewport_render_cpu_ms", []))),
		"viewport_render_gpu_ms": _stats(gpu),
		"viewport_render_gpu_timing_available": float((_stats(gpu)).get("max", 0.0)) > 0.0,
		"draw_calls": _stats(_float_array(sampled.get("draw_calls", []))),
		"objects_in_frame": _stats(_float_array(sampled.get("objects_in_frame", []))),
		"primitives_in_frame": _stats(_float_array(sampled.get("primitives_in_frame", []))),
		"frames_over_16_67_ms": _count_over(intervals, 16.67),
		"frames_over_20_ms": _count_over(intervals, 20.0),
		"frames_over_33_33_ms": _count_over(intervals, 33.33),
		"raw_frame_intervals_ms": intervals,
		"raw_process_ms": sampled.get("process_ms", []),
		"raw_render_setup_cpu_ms": sampled.get("render_setup_cpu_ms", []),
		"raw_viewport_render_cpu_ms": sampled.get("viewport_render_cpu_ms", []),
		"raw_viewport_render_gpu_ms": gpu,
		"raw_draw_calls": sampled.get("draw_calls", []),
		"raw_objects_in_frame": sampled.get("objects_in_frame", []),
		"raw_primitives_in_frame": sampled.get("primitives_in_frame", []),
	}


func _aggregate_runs(runs: Array[Dictionary]) -> Dictionary:
	var intervals: Array[float] = []
	var process_samples: Array[float] = []
	var render_setup_samples: Array[float] = []
	var render_cpu_samples: Array[float] = []
	var render_gpu_samples: Array[float] = []
	var draw_calls: Array[float] = []
	var objects: Array[float] = []
	var primitives: Array[float] = []
	var submission_samples: Array[float] = []
	var pipeline_compilations: int = 0
	var skipped_updates: int = 0
	var authored_updates: int = 0
	var effect_nodes_at_peak: int = 0
	for run: Dictionary in runs:
		intervals.append_array(_float_array(run.get("raw_frame_intervals_ms", [])))
		process_samples.append_array(_float_array(run.get("raw_process_ms", [])))
		render_setup_samples.append_array(_float_array(run.get("raw_render_setup_cpu_ms", [])))
		render_cpu_samples.append_array(_float_array(run.get("raw_viewport_render_cpu_ms", [])))
		render_gpu_samples.append_array(_float_array(run.get("raw_viewport_render_gpu_ms", [])))
		draw_calls.append_array(_float_array(run.get("raw_draw_calls", [])))
		objects.append_array(_float_array(run.get("raw_objects_in_frame", [])))
		primitives.append_array(_float_array(run.get("raw_primitives_in_frame", [])))
		pipeline_compilations += int(run.get("canvas_pipeline_compilations", 0))
		skipped_updates += int(run.get("skipped_authored_updates", 0))
		authored_updates += int(run.get("authored_updates_submitted", 0))
		effect_nodes_at_peak = maxi(effect_nodes_at_peak, int(run.get("effect_nodes_at_peak", 0)))
		submission_samples.append_array(_float_array(run.get("raw_submission_usec", [])))
	return {
		"run_count": runs.size(),
		"sample_count": intervals.size(),
		"frame_interval_ms": _stats(intervals),
		"process_ms": _stats(process_samples),
		"render_setup_cpu_ms": _stats(render_setup_samples),
		"viewport_render_cpu_ms": _stats(render_cpu_samples),
		"viewport_render_gpu_ms": _stats(render_gpu_samples),
		"viewport_render_gpu_timing_available": float((_stats(render_gpu_samples)).get("max", 0.0)) > 0.0,
		"draw_calls": _stats(draw_calls),
		"objects_in_frame": _stats(objects),
		"primitives_in_frame": _stats(primitives),
		"submission_usec": _stats(submission_samples),
		"canvas_pipeline_compilations": pipeline_compilations,
		"authored_updates_submitted": authored_updates,
		"skipped_authored_updates": skipped_updates,
		"effect_nodes_at_peak": effect_nodes_at_peak,
		"frames_over_16_67_ms": _count_over(intervals, 16.67),
		"frames_over_20_ms": _count_over(intervals, 20.0),
		"frames_over_33_33_ms": _count_over(intervals, 33.33),
		"raw_frame_intervals_ms": intervals,
		"runs": runs,
	}


func _stats(source: Array[float]) -> Dictionary:
	if source.is_empty():
		return {"mean": 0.0, "median": 0.0, "p95": 0.0, "p99": 0.0, "max": 0.0}
	var values: Array[float] = source.duplicate()
	values.sort()
	var total: float = 0.0
	for value: float in values:
		total += value
	return {
		"mean": total / float(values.size()),
		"median": _percentile(values, 0.50),
		"p95": _percentile(values, 0.95),
		"p99": _percentile(values, 0.99),
		"max": values[values.size() - 1],
	}


func _percentile(values: Array[float], percentile: float) -> float:
	var index: int = clampi(int(ceil(float(values.size()) * percentile)) - 1, 0, values.size() - 1)
	return values[index]


func _count_over(values: Array[float], threshold: float) -> int:
	var count: int = 0
	for value: float in values:
		if value > threshold:
			count += 1
	return count


func _float_array(values: Variant) -> Array[float]:
	var result: Array[float] = []
	if typeof(values) != TYPE_ARRAY:
		return result
	for value: Variant in values as Array:
		if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
			result.append(float(value))
	return result


func _canvas_pipeline_compilation_count() -> int:
	return int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_CANVAS))


func _observe_probe_focus() -> bool:
	_focus_observations += 1
	var focused: bool = DisplayServer.window_is_focused()
	if not focused:
		_unfocused_observations += 1
		DisplayServer.window_move_to_foreground()
	return focused


func _await_render_frame() -> void:
	if _render_pulse != null:
		_render_pulse.pulse()
	await RenderingServer.frame_post_draw


func _acquire_probe_window_focus() -> bool:
	for _attempt: int in range(30):
		DisplayServer.window_move_to_foreground()
		await _await_render_frame()
		if DisplayServer.window_is_focused():
			return true
	return false


func _settle_render_frames(count: int) -> void:
	for _frame: int in range(count):
		await _await_render_frame()


func _base_presentation() -> Dictionary:
	return {
		"board_backdrop_visible": true,
		"visible_enemy_ids": [401, 402, 403],
		"ambient_time_seconds": 42.0,
	}


func _death_presentation(progress: float) -> Dictionary:
	var presentation: Dictionary = _base_presentation()
	presentation["death_animation_units"] = [_dragon_death_unit(progress)]
	return presentation


func _alive_state() -> Dictionary:
	var state: Dictionary = _defeated_state()
	state["enemies"] = [
		_dragon_alive_unit(),
		_support_unit(402, Vector2i(3, 5)),
		_support_unit(403, Vector2i(8, 5)),
	]
	return state


func _defeated_state() -> Dictionary:
	return {
		"name": "Noctyrax death performance chamber",
		"room_coord": Vector2i(24, 0),
		"room_element": "umbra",
		"grid": _grid(),
		"moss": {},
		"elemental_intensity": {"fire": 0, "ice": 0, "lightning": 0, "air": 0, "earth": 0},
		"player": {"pos": Vector2i(5, 6), "hp": 24, "max_hp": 24, "block": 0, "stoneskin": 0},
		"enemies": [
			_support_unit(402, Vector2i(3, 5)),
			_support_unit(403, Vector2i(8, 5)),
		],
		"illusions": [],
		"npcs": [],
		"loot": [],
		"terrain": [],
		"traps": [],
	}


func _dragon_alive_unit() -> Dictionary:
	return {
		"id": 401,
		"key": "enemy_401",
		"role": "enemy",
		"type": "noctyrax",
		"name": "Noctyrax, the Last Eclipse",
		"pos": Vector2i(5, 2),
		"footprint": Vector2i(2, 2),
		"hp": 1,
		"max_hp": 150,
		"block": 0,
		"stoneskin": 0,
	}


func _dragon_death_unit(progress: float) -> Dictionary:
	var unit: Dictionary = _dragon_alive_unit()
	unit["death_animation"] = true
	unit["death_frame"] = clampi(int(round(progress * float(FRAME_COUNT - 1))), 0, FRAME_COUNT - 1)
	unit["death_progress"] = progress
	return unit


func _support_unit(enemy_id: int, pos: Vector2i) -> Dictionary:
	return {
		"id": enemy_id,
		"key": "enemy_%d" % enemy_id,
		"role": "enemy",
		"type": "veilbound_acolyte",
		"name": "Veilbound Acolyte",
		"pos": pos,
		"footprint": Vector2i.ONE,
		"hp": 12,
		"max_hp": 12,
		"block": 0,
		"stoneskin": 0,
	}


func _grid() -> Array:
	var grid: Array = []
	for y: int in range(9):
		var row: Array = []
		for x: int in range(12):
			row.append("wall" if x == 0 or y == 0 or x == 11 or y == 8 else "stone")
		grid.append(row)
	return grid


func _clear_probe_output(path: String) -> void:
	var absolute_path: String = ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(absolute_path):
		return
	for file_name: String in DirAccess.get_files_at(absolute_path):
		if file_name.to_lower().ends_with(".png"):
			DirAccess.remove_absolute(absolute_path.path_join(file_name))


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
