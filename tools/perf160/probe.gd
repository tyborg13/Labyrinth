extends "res://tools/perf149/probe.gd"

const READY_SPAN: String = "post_draw:run_scene:enemy_round_handoff_ready"
var _first_ready: Dictionary = {}
var _ready_phases: Dictionary = {}
var _ready_monitors: Dictionary = {}
var _unfocused: int = 0

func _pass_round(kind: String, button: int) -> Dictionary:
	_first_ready = {}
	_ready_phases = {}
	_ready_monitors = {}
	_unfocused = 0
	var detail: bool = OS.get_cmdline_user_args().has("--detail")
	_board.set_submission_performance_instrumentation_enabled(detail)
	_board._submission_detail_enabled = detail
	var result: Dictionary = await super._pass_round(kind, button)
	if _first_ready.is_empty():
		_errors.append(kind + ": no first ready frame")
	if detail and not _ready_phases.has("stage_board_submission"):
		_errors.append(kind + ": no stage attribution on the ready frame")
	if _unfocused > 0 and Engine.get_write_movie_path().is_empty():
		_errors.append("%s: native window unfocused in %d sampled intervals" % [kind, _unfocused])
	result["receipt"]["first_ready"] = _first_ready
	result["ready_phases_usec"] = _ready_phases
	result["ready_monitors"] = _ready_monitors
	return result

func _boundary() -> void:
	if not _record_frames: return
	super._boundary()
	if not _headless and not DisplayServer.window_is_focused(): _unfocused += 1
	var frame: Dictionary = _trace_frames.back()
	if not _first_ready.is_empty() or _scene._animation_lock or not frame["spans"].has(READY_SPAN): return
	var chip: Button = _scene._selected_card_forecast_chip()
	var state: Dictionary = _scene._combat_state
	var hand: Array = state.get("deck", {}).get("hand", [])
	var shown: Array[String] = _scene._draw_hand_card_ids()
	if (
		_board.combat_state != state or not is_instance_valid(chip) or chip.disabled
		or not chip.is_visible_in_tree() or not _scene.hand_box.is_visible_in_tree()
		or not _scene._draw_hand_transition_proxies.is_empty() or shown != hand
	):
		_errors.append("First unlocked presented frame did not publish board, Pass and live hand together.")
	_first_ready = {"turn": state.get("turn"), "board_turn": _board.combat_state.get("turn"),
		"hand": shown, "pass": chip.tooltip_text if is_instance_valid(chip) else ""}
	_ready_monitors = {
		"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"objects_drawn": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"static_bytes": Performance.get_monitor(Performance.MEMORY_STATIC),
		"objects": Performance.get_monitor(Performance.OBJECT_COUNT),
		"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"orphans": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
	}
	if not _capture.is_empty() and not _headless:
		var path: String = _output.path_join("first-ready.png")
		var image: Image = _canvas.get_texture().get_image()
		image.convert(Image.FORMAT_RGBA8)
		if image.save_png(path) != OK:
			_errors.append("Could not capture " + path)
		else:
			print(path)
	if not _board._submission_detail_enabled: return
	for sample: Dictionary in _scene._runtime_performance_frame_top:
		if int(sample["frame_id"]) == int(frame["frame"]) - 1:
			_ready_phases = sample["phase_usec"].duplicate()
			break
	if int(_scene._runtime_performance_frame_id) == int(frame["frame"]) - 1:
		_ready_phases = _scene._runtime_performance_frame_phase_usec.duplicate()
	for sample: Dictionary in _board._submission_detail_top:
		if int(sample["frame"]) == int(frame["frame"]) - 1:
			for section: String in sample["sections"]:
				_ready_phases["board/" + section] = sample["sections"][section]["usec"]
			for layer: String in sample["layers"]:
				_ready_phases["board_layer/" + layer] = sample["layers"][layer]["usec"]
			break
