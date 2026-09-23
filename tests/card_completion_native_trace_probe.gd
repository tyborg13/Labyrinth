extends "res://tests/card_completion_stall_probe.gd"

# Diagnostic lane only: bracket native draw submission and drawable waits.
# This is wall time, not GPU execution time. Keep the clean timing probe intact.
var _native_pre_draw_usec: int = 0
var _native_pre_draw_frame: int = -1
var _native_process_usec: int = 0
var _native_process_frame: int = -1

func _initialize() -> void:
	process_frame.connect(_observe_native_process)
	RenderingServer.frame_pre_draw.connect(_observe_native_pre_draw)
	super._initialize()

func _observe_native_process() -> void:
	if _probe_active:
		_native_process_usec = Time.get_ticks_usec()
		_native_process_frame = Engine.get_process_frames()

func _observe_native_pre_draw() -> void:
	if _probe_active:
		_native_pre_draw_usec = Time.get_ticks_usec()
		_native_pre_draw_frame = Engine.get_process_frames()

func _observe_completion_draw() -> void:
	super._observe_completion_draw()
	if not _probe_active or _probe_frames.is_empty():
		return
	var frame: Dictionary = _probe_frames.back()
	var post_draw_usec: int = int(frame["usec"])
	_expect(_native_pre_draw_frame == int(frame["frame"]), "Native draw brackets must describe the same frame")
	frame["native_pre_draw_usec"] = _native_pre_draw_usec
	_expect(_native_process_frame == int(frame["frame"]), "Native process and draw brackets must describe the same frame")
	frame["process_to_pre_draw_wall_ms"] = float(_native_pre_draw_usec - _native_process_usec) / 1000.0
	frame["native_process_usec"] = _native_process_usec
	frame["native_draw_wall_ms"] = float(post_draw_usec - _native_pre_draw_usec) / 1000.0
	if _probe_frames.size() > 1:
		frame["before_draw_wall_ms"] = float(_native_pre_draw_usec - int(_probe_frames[-2]["usec"])) / 1000.0
		frame["previous_draw_to_process_wall_ms"] = float(_native_process_usec - int(_probe_frames[-2]["usec"])) / 1000.0

	# Board redraws happen in SceneTree's queued CanvasItem callbacks before the
	# native draw signal. Read the existing counters without resetting them.
	var board: Node = _probe_instance.get_node("BoardUnderlay/CombatBoard")
	if int(board.get("_retained_draw_frame_id")) == int(frame["frame"]):
		frame["board_draw_usec"] = int(board.get("_retained_draw_frame_total_usec"))
		frame["board_draw_layers_usec"] = (board.get("_retained_draw_frame_layer_usec") as Dictionary).duplicate()
	else:
		frame["board_draw_usec"] = 0
