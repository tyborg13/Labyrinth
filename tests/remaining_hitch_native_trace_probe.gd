extends "res://tests/runtime_frame_performance_benchmark.gd"

# Causal lane only. These brackets partition wall time around the main process
# and native submission; they are not GPU execution measurements.
var _native_process_usec: int = 0
var _native_process_frame: int = -1
var _native_pre_draw_usec: int = 0
var _native_pre_draw_frame: int = -1
var _native_previous_post_usec: int = 0
var _native_compilations_before: int = 0
var _native_brackets: Dictionary = {}
var _native_processes_since_post: int = 0
var _native_undrawable_processes: int = 0
var _native_unfocused_processes: int = 0
var _native_low_usage_processes: int = 0
var _native_max_process_gap_usec: int = 0
var _native_previous_process_usec: int = 0
var _native_root_undrawable_processes: int = 0
var _native_window_transitions: Array[Dictionary]
var _native_last_window_state: Array

func _initialize() -> void:
	process_frame.connect(_native_process)
	RenderingServer.frame_pre_draw.connect(_native_pre_draw)
	RenderingServer.frame_post_draw.connect(_native_post_draw)
	super._initialize()

func _native_process() -> void:
	_native_process_usec = Time.get_ticks_usec()
	_native_processes_since_post += 1
	var window_state: Array = [root.size, DisplayServer.window_get_size(root.get_window_id()), DisplayServer.window_get_mode(root.get_window_id()), DisplayServer.window_can_draw(root.get_window_id())]
	if window_state != _native_last_window_state:
		_native_window_transitions.append({"at_usec": _native_process_usec, "frame": Engine.get_process_frames(), "root_size": window_state[0], "native_size": window_state[1], "mode": window_state[2], "can_draw": window_state[3], "screen_usable_rect": DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen()), "current_scene": str(current_scene.name) if is_instance_valid(current_scene) else ""})
		_native_last_window_state = window_state
	if not DisplayServer.window_can_draw(): _native_undrawable_processes += 1
	if not DisplayServer.window_can_draw(root.get_window_id()): _native_root_undrawable_processes += 1
	if not DisplayServer.window_is_focused(): _native_unfocused_processes += 1
	if OS.low_processor_usage_mode: _native_low_usage_processes += 1
	if _native_previous_process_usec > 0: _native_max_process_gap_usec = maxi(_native_max_process_gap_usec, _native_process_usec - _native_previous_process_usec)
	_native_previous_process_usec = _native_process_usec
	_native_process_frame = Engine.get_process_frames()
	_native_compilations_before = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_CANVAS)

func _native_pre_draw() -> void:
	_native_pre_draw_usec = Time.get_ticks_usec()
	_native_pre_draw_frame = Engine.get_process_frames()

func _native_post_draw() -> void:
	var now_usec: int = Time.get_ticks_usec()
	var frame: int = Engine.get_process_frames()
	_native_brackets[frame] = {
		"frame": frame,
		"brackets_same_frame": _native_process_frame == frame and _native_pre_draw_frame == frame,
		"previous_draw_to_process_wall_ms": float(_native_process_usec - _native_previous_post_usec) / 1000.0 if _native_previous_post_usec > 0 else 0.0,
		"process_to_pre_draw_wall_ms": float(_native_pre_draw_usec - _native_process_usec) / 1000.0,
		"native_draw_wall_ms": float(now_usec - _native_pre_draw_usec) / 1000.0,
		"process_frames_since_previous_draw": _native_processes_since_post,
		"undrawable_process_frames": _native_undrawable_processes,
		"root_undrawable_process_frames": _native_root_undrawable_processes,
		"root_window_id": root.get_window_id(),
		"root_window_size": [root.size.x, root.size.y],
		"native_window_size": [DisplayServer.window_get_size(root.get_window_id()).x, DisplayServer.window_get_size(root.get_window_id()).y],
		"unfocused_process_frames": _native_unfocused_processes,
		"low_usage_process_frames": _native_low_usage_processes,
		"max_process_gap_wall_ms": float(_native_max_process_gap_usec) / 1000.0,
		"canvas_pipeline_compilations": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_CANVAS) - _native_compilations_before,
	}
	_native_previous_post_usec = now_usec
	_native_processes_since_post = 0
	_native_undrawable_processes = 0
	_native_root_undrawable_processes = 0
	_native_unfocused_processes = 0
	_native_low_usage_processes = 0
	_native_max_process_gap_usec = 0

func _sampler_phase_result(sampled: Dictionary) -> Dictionary:
	var result: Dictionary = super._sampler_phase_result(sampled)
	var frames: Array[Dictionary]
	for frame: int in result.get("raw_frame_ids", []):
		if _native_brackets.has(frame): frames.append(_native_brackets[frame])
	result["native_brackets"] = frames
	var transitions: Array[Dictionary]
	if not frames.is_empty():
		var first_frame: int = result["raw_frame_ids"][0]
		var last_frame: int = result["raw_frame_ids"].back()
		for transition: Dictionary in _native_window_transitions:
			if int(transition["frame"]) >= first_frame and int(transition["frame"]) <= last_frame:
				transitions.append(transition)
	result["native_window_transitions"] = transitions
	return result
