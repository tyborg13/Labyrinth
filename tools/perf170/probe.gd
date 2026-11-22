extends "res://tools/perf163/probe.gd"
## Replay combat focus and cancellation through viewport joypad input.

const PHASES := ["x-open", "x-tuck", "x-cancel", "b-tuck", "b-cancel", "b-idle"]
const IntentReplay = preload("res://tools/perf170/intent_tab_replay.gd")
const TARGET_CARD: String = "flowing_step"
const READY_FRAMES: int = 6
const REST_TIMEOUT_USEC: int = 5000000

var _boundaries: Dictionary
var _sampling_press: bool
var _physics_at: int
var _process_at: int
var _draw_at: int

func _exercise(kind: String) -> void:
	if not _headless and _detail and not RenderingServer.frame_pre_draw.is_connected(_mark_draw):
		physics_frame.connect(_mark_physics)
		process_frame.connect(_mark_process)
		RenderingServer.frame_pre_draw.connect(_mark_draw)
	OS.low_processor_usage_mode_sleep_usec = 0
	_button(JOY_BUTTON_RIGHT_SHOULDER)
	await _wait_frames(READY_FRAMES)
	var combat_before: String = _combat_digest(_scene._combat_state)
	if not _capture_frames and not _detail:
		for phase: String in PHASES:
			if not await _exercise_press(kind, phase, false): return
	for attempt: int in range(1 if _capture_frames or _detail else ATTEMPTS):
		for i: int in range(PHASES.size()):
			var phase: String = PHASES[(i + attempt) % PHASES.size()]
			if not await _exercise_press(kind, phase, true): return
	if combat_before != _combat_digest(_scene._combat_state):
		_errors.append(kind + " focus and cancellation changed committed combat")
	if _capture_frames:
		await IntentReplay.run(self, kind)

func _exercise_press(kind: String, phase: String, record: bool) -> bool:
	var key: String = kind + "/" + phase
	var starts_selected: bool = phase.ends_with("cancel")
	var starts_in_hand: bool = phase.ends_with("tuck") or starts_selected
	if starts_in_hand and _scene._controller_region != "hand":
		_button(JOY_BUTTON_X)
	elif not starts_in_hand and _scene._controller_region == "hand":
		_button(JOY_BUTTON_X)
	if not await _rest(key + "/setup"): return false
	if starts_selected:
		var hand: Array = _scene._combat_state["deck"]["hand"]
		var target_index: int = hand.find(TARGET_CARD)
		if target_index < 0:
			_errors.append(key + " missing targeting card")
			return false
		for attempt: int in range(hand.size()):
			if _scene._controller_hand_index == target_index: break
			_button(JOY_BUTTON_RIGHT_SHOULDER)
			await _wait_frames(1)
		if not await _rest(key + "/card"): return false
		_button(JOY_BUTTON_A)
		var deadline: int = Time.get_ticks_usec() + REST_TIMEOUT_USEC
		while _scene._selected_pass_pending():
			await _wait_frames(1)
			if Time.get_ticks_usec() >= deadline:
				_errors.append(key + " selection forecast did not publish")
				return false
		await _wait_frames(READY_FRAMES)
		if _scene._controller_region != "board" or _scene._selected_card_index != target_index or _scene._pending_target_tiles.is_empty():
			_errors.append(key + " did not start on a selected targeting card")
			return false
	elif (_scene._controller_region == "hand") != starts_in_hand:
		_errors.append(key + " started in the wrong region")
		return false

	var button: int = JOY_BUTTON_X if phase.begins_with("x-") else JOY_BUTTON_B
	var opens_hand: bool = phase in ["x-open", "x-cancel"]
	var sample: Dictionary = {}
	var previous_hud_canvases: Dictionary = {}
	if record:
		if _detail:
			previous_hud_canvases = _hud_canvases()
			_scene.set_runtime_performance_instrumentation_enabled(true)
			_board.set_submission_performance_instrumentation_enabled(true)
			_board._submission_detail_top.clear()
			_board._submission_detail_enabled = true
			_sampling_press = true
			_boundaries = {}
			_physics_at = 0
			_process_at = 0
			_draw_at = 0
		_intervals.clear()
		_remaining_intervals = RAPID_FRAMES
	var input_start: int = Time.get_ticks_usec()
	_button(button)
	if record:
		sample["input_usec"] = Time.get_ticks_usec() - input_start
		if _detail: sample["input_sections"] = _scene.runtime_performance_instrumentation_snapshot()
	await _wait_frames(1)
	if (
		_scene._controller_region != ("hand" if opens_hand else "board")
		or _scene._controller_hand_focused != opens_hand or _scene._selected_card_index != -1
		or (opens_hand and _scene._hovered_card_index != _scene._controller_hand_index)
	):
		_errors.append(key + " did not reach its expected focus and selection")
		return false
	if record:
		if _detail:
			sample["press_sections"] = _scene.runtime_performance_instrumentation_snapshot()
			sample["board_press_sections"] = _board.submission_performance_instrumentation_snapshot()
			sample["board_press_submissions"] = _board._submission_detail_top.duplicate(true)
			sample["native_boundaries_usec"] = _boundaries
			var current_hud_canvases: Dictionary = _hud_canvases()
			var retained: int = 0
			for id: int in current_hud_canvases:
				if previous_hud_canvases.has(id): retained += 1
			sample["hud_canvases"] = {"before": previous_hud_canvases.size(), "after": current_hud_canvases.size(), "retained": retained}
		if not _headless and not _capture_frames:
			sample["press_monitors"] = _press_monitors()
		if _capture_frames: _record_frame(key, 1)
	for frame: int in range(2, RAPID_FRAMES + 1):
		await _wait_frames(1)
		if record and _capture_frames: _record_frame(key, frame)
	if record:
		sample["interval_usec"] = _intervals.duplicate()
	if not await _rest(key): return false
	if record:
		if _capture_frames: _record_frame(key, 0)
		elif not _detail: _receipts[key + "/rest"] = _receipt()
		if _detail:
			sample["window_sections"] = _scene.runtime_performance_instrumentation_snapshot()
			_scene.set_runtime_performance_instrumentation_enabled(false)
			_board.set_submission_performance_instrumentation_enabled(false)
			_board._submission_detail_enabled = false
		(_samples.get_or_add(key, []) as Array).append(sample)
	return true

func _rest(key: String) -> bool:
	var deadline: int = Time.get_ticks_usec() + REST_TIMEOUT_USEC
	await _wait_frames(READY_FRAMES)
	while (
		_scene._hand_hover_rest_pending or _scene._hand_hover_refresh_pending or _scene.hand_box.is_sliding()
		or (_scene._hovered_card_index >= 0 and _scene.hand_box.emphasis_strength() < 1.0)
	):
		await _wait_frames(1)
		if Time.get_ticks_usec() >= deadline:
			_errors.append(key + " hand did not settle")
			return false
	return true

func _record_boundary() -> void:
	if _sampling_press:
		_sampling_press = false
		var start: int = _physics_at if _physics_at > 0 else _process_at
		if start >= _last_boundary_usec and _process_at >= start and _draw_at >= _process_at:
			_boundaries = {
				"post_draw_to_first_tree_signal": start - _last_boundary_usec,
				"physics_signal_to_process_signal": _process_at - start,
				"process_signal_to_pre_draw": _draw_at - _process_at,
				"pre_draw_to_post_draw": Time.get_ticks_usec() - _draw_at,
			}
	super._record_boundary()

func _mark_physics() -> void:
	if _sampling_press and _physics_at == 0: _physics_at = Time.get_ticks_usec()

func _mark_process() -> void:
	if _sampling_press: _process_at = Time.get_ticks_usec()

func _mark_draw() -> void:
	if _sampling_press: _draw_at = Time.get_ticks_usec()

func _press_monitors() -> Dictionary:
	return {
		"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"render_objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"memory_bytes": Performance.get_monitor(Performance.MEMORY_STATIC),
		"objects": Performance.get_monitor(Performance.OBJECT_COUNT),
		"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"orphans": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
	}

func _hud_canvases() -> Dictionary:
	var active: Dictionary = {}
	for record: Dictionary in _board._aim_focus.canvases.values():
		if not record.hud or not is_instance_valid(record.canvas):
			continue
		var canvas: Control = record.canvas
		if canvas.is_visible_in_tree():
			active[canvas.get_instance_id()] = true
	return active

func _receipt() -> Dictionary:
	var receipt: Dictionary = super._receipt()
	var gui_focus: Control = _canvas.gui_get_focus_owner()
	receipt["controller"] = [
		_scene._controller_hand_focused, str(_scene._controller_board_tile), str(_board._controller_focus_tile),
		_scene._controller_focus_candidate.get("key", ""), str(gui_focus.name) if gui_focus else "",
	]
	receipt["hand_rect"] = str(_scene.hand_scroll.get_global_rect())
	receipt["card_states"] = []
	for index: int in range(_scene.hand_box.get_child_count()):
		var card: Control = _scene._hand_card_control(index)
		receipt["card_states"].append([str(card.modulate), card.visible, str(card.get_global_rect())])
	if _capture_frames:
		var highlight: CanvasItem = _board._targeted_tile_highlight
		receipt["target_highlight"] = is_instance_valid(highlight) and highlight.visible
		receipt["hud_order"] = []
		var hud: Control = _board._hud_render_layer
		var sources: Array[Control]
		sources.append(hud)
		sources.append_array(hud._layer_slices.canvases)
		for source: Control in sources:
			var children: Array = []
			for canvas: Node in source.get_children():
				if not canvas.has_meta("rd03_canvas") or not canvas.is_visible_in_tree(): continue
				var ops: Array = canvas._render_slice_ops
				children.append([ops[0][0], canvas.z_index, str(canvas.self_modulate)] if not ops.is_empty() else [])
			receipt["hud_order"].append(children)
	return receipt

func _finish(error: String = "") -> void:
	if not error.is_empty(): _errors.append(error)
	for failure: String in _errors: push_error(failure)
	print("PERF-170 ROUTE: %s (%d phases, %d frame receipts, %d errors)" % [
		"PASS" if _errors.is_empty() else "FAIL", _samples.size(), _receipts.size(), _errors.size()
	])
	quit(0 if _errors.is_empty() else 1)
