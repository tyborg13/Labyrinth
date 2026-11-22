extends "res://tools/perf154/probe.gd"
## Match the D-pad route, then drive pointer and stick over its same tile edge.

const SWEEPS: int = 8
const STICK_LIMIT_TICKS: int = 8
const FOCUS_WINDOW_FRAMES: int = 3
const INVALID_TILE := Vector2i(-1, -1)
const BossAreaMarks = preload("res://scripts/boss_area_marks.gd")

func _exercise(kind: String) -> void:
	if _board._focus_submission_baseline != (OS.get_environment("LABYRINTH_PERF159_BASELINE") == "1"):
		_errors.append(kind + ": board did not activate the requested comparison arm")
		return
	_button(JOY_BUTTON_RIGHT_SHOULDER)
	await _wait_frames(SETTLE_INPUT_FRAMES)
	_button(JOY_BUTTON_DPAD_UP)
	await _wait_frames(SETTLE_INPUT_FRAMES)
	var left: Vector2i = _scene._controller_board_tile
	_button(JOY_BUTTON_DPAD_RIGHT)
	await _wait_frames(SETTLE_INPUT_FRAMES)
	var right: Vector2i = _scene._controller_board_tile
	_button(JOY_BUTTON_DPAD_LEFT)
	await _wait_frames(SETTLE_INPUT_FRAMES)
	if left.x < 0 or right.x < 0 or left == right or _scene._controller_board_tile != left:
		_errors.append(kind + ": D-pad warmup did not traverse both tiles")
		return
	var combat: String = _combat_digest(_scene._combat_state)
	for sweep: int in range(SWEEPS):
		await _focus_sample(kind + "/board-dpad", _button.bind(JOY_BUTTON_DPAD_RIGHT), right)
		await _focus_sample(kind + "/board-dpad", _button.bind(JOY_BUTTON_DPAD_LEFT), left)
	# Place the virtual cursor just at the next snap point so the first held
	# physics tick actually changes the focused tile on both renderer paths.
	for sweep: int in range(SWEEPS):
		_scene._controller_virtual_board_position = _scene._controller_board_point(right)
		await _focus_sample(kind + "/stick", _stick.bind(1.0), right, true)
		_button(JOY_BUTTON_DPAD_LEFT)
		await _wait_frames(SETTLE_INPUT_FRAMES)
	_hover(left)
	await _wait_frames(SETTLE_INPUT_FRAMES)
	for sweep: int in range(SWEEPS):
		await _focus_sample(kind + "/mouse-tile", _hover.bind(right), right)
		await _focus_sample(kind + "/mouse-tile", _hover.bind(left), left)
	# Another motion at the settled tile keeps the presented aim and owner.
	await _focus_sample(kind + "/same-tile", _hover.bind(left), left)
	if _combat_digest(_scene._combat_state) != combat:
		_errors.append(kind + ": hover changed committed combat")

func _focus_sample(key: String, input: Callable, expected: Vector2i, stick: bool = false) -> void:
	# Start inside the physics tick that consumes the stick event. An uncapped
	# native run can draw several frames between two physics ticks.
	if stick: await physics_frame
	var detail: bool = OS.get_cmdline_user_args().has("--detail")
	var trace: RefCounted = _board._board_redraw_trace
	if detail:
		_scene.set_runtime_performance_instrumentation_enabled(true)
		_board.set_submission_performance_instrumentation_enabled(true)
		_board._submission_detail_enabled = true
		_board._submission_detail_top.clear()
		trace.begin()
	var before: Array = _focus()
	var state: Dictionary = _board.combat_state
	var shown: Dictionary = _board.presentation
	var moves: Array = _board.move_tiles
	var attacks: Array = _board.attack_tiles
	var redraws: int = _board._render_redraw_request_count
	var plates: int = _board.plate_visibility.redraw_requests
	_intervals.clear()
	_sample_count = FOCUS_WINDOW_FRAMES
	_boundary_usec = Time.get_ticks_usec()
	input.call()
	if stick:
		for tick: int in range(STICK_LIMIT_TICKS):
			if _scene._controller_board_tile == expected: break
			await physics_frame
		_stick(0.0)
	while _sample_count > 0: await _wait_frames(1)
	var after: Array = _focus()
	if _scene._hovered_board_tile != expected:
		_errors.append("%s: hovered %s, expected %s" % [key, _scene._hovered_board_tile, expected])
	if (key.ends_with("/board-dpad") or stick) and _scene._controller_board_tile != expected:
		_errors.append("%s: controller did not focus %s" % [key, expected])
	if not key.ends_with("/same-tile") and before == after:
		_errors.append(key + ": input did not move focus")
	var row: Dictionary = {
		"interval_usec": _intervals.duplicate(),
		"monitors": {
			"process_usec": Performance.get_monitor(Performance.TIME_PROCESS) * 1000000.0,
			"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			"objects": Performance.get_monitor(Performance.OBJECT_COUNT),
			"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
			"orphan_nodes": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
			"static_memory": Performance.get_monitor(Performance.MEMORY_STATIC),
		},
	}
	if detail:
		var area_marks: Dictionary = {}
		for enemy: Dictionary in _board.combat_state.get("enemies", []):
			var tiles: Array[Vector2i] = BossAreaMarks.tiles(_board.combat_state, enemy)
			if not tiles.is_empty(): area_marks[str(enemy["id"])] = tiles
		row.merge({
			"boss_area_marks": area_marks,
			"move_tiles_changed": moves != _board.move_tiles,
			"attack_tiles_changed": attacks != _board.attack_tiles,
			"sections": _scene.runtime_performance_instrumentation_snapshot(),
			"board_sections": _board.submission_performance_instrumentation_snapshot(),
			"submission_detail": _board._submission_detail_top.duplicate(true),
			"draws": trace.finish(),
			"changed_state_fields": _board._changed_presentation_keys(state, _board.combat_state).keys(),
			"changed_presentation_fields": _board._changed_presentation_keys(shown, _board.presentation).keys(),
			"redraw_requests": _board._render_redraw_request_count - redraws,
			"plate_redraw_requests": _board.plate_visibility.redraw_requests - plates,
		})
		if not row["changed_state_fields"].is_empty():
			_errors.append(key + ": input changed rendered combat state")
		if key.ends_with("/same-tile") and row["sections"].has("stage_board_submission"):
			_errors.append(key + ": unchanged pointer and aim submitted the stage")
		var plan: RefCounted = _board._overlay_render_layer._layer_slices
		if plan._focus_spares.size() > plan.FOCUS_SPARE_LIMIT:
			_errors.append(key + ": overlay spare count exceeded its limit")
		for spare: Control in plan._focus_spares:
			if not spare._render_slice_ops.is_empty() or spare in plan.canvases:
				_errors.append(key + ": spare overlay still owns an active paint plan")
		_board._submission_detail_enabled = false
		_board.set_submission_performance_instrumentation_enabled(false)
		_scene.set_runtime_performance_instrumentation_enabled(false)
	(_results.get_or_add(key, []) as Array).append(row)
	var witness: Array = [before, after] + _navigation_presentation() + [
		_board.presentation.get("hover_owner_tile", INVALID_TILE),
		_board.plate_visibility.inspected_keys.keys(),
	]
	(_receipts.get_or_add(key, []) as Array).append(witness.duplicate(true))
	await _wait_frames(SETTLE_INPUT_FRAMES)
