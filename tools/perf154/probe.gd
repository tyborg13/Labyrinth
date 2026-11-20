extends "res://tools/perf134/probe.gd"
## Measure the press and the complete selected-forecast window on archived saves.

const ATTEMPTS: int = 8
const SETTLE_INPUT_FRAMES: int = 16
const FOLLOWUP_FRAMES: int = 2
const FORECAST_WINDOW_FRAMES: int = 20
const MOUSE_PRESENTATION_TIMEOUT_USEC: int = 1000000
const CANCEL_AFTER_FRAMES: Array = [0, 2]
const STICK_PHYSICS_TICKS: int = 3
const EXPOSED_CARD_POINT := Vector2(0.24, 0.35)
const NATIVE_PULSE_ALPHA: float = 0.001
const OPENING_CARD_INDEX: int = 0
const ENCOUNTERS: Array = ["normal", "tharokh"]
var _boundary_usec: int
var _sample_count: int
var _intervals: Array[int]
var _results: Dictionary
var _receipts: Dictionary
var _pulse: ColorRect

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_headless = DisplayServer.get_name() == "headless"
	if _headless:
		process_frame.connect(_boundary)
		process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	else:
		RenderingServer.frame_post_draw.connect(_boundary)
	call_deferred("_run")

func _run() -> void:
	_output = _argument("--output=")
	var bundle: String = _argument("--fixtures=")
	if _output.is_empty() or not FileAccess.file_exists(bundle):
		_finish("Supply --output=DIR and --fixtures=the perf-134 bundle.")
		return
	var archive: Dictionary = bytes_to_var(FileAccess.get_file_as_bytes(bundle))
	_fixtures = archive.get("cases", {})
	if archive.get("schema") != FIXTURE_SCHEMA or archive.get("seed") != SEED:
		_finish("Invalid perf-134 archive.")
		return
	DirAccess.make_dir_recursive_absolute(_output)
	var settings: Dictionary = View.Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["display_mode"] = "windowed"
	settings["combat_speed"] = View.Settings.COMBAT_NORMAL
	if not View.Settings.save_settings(settings):
		_finish("Could not save isolated settings.")
		return
	_make_canvas()
	# Native post-draw remains live even if both retained boards are idle.
	_pulse = ColorRect.new()
	_pulse.size = Vector2.ONE
	_pulse.modulate.a = NATIVE_PULSE_ALPHA
	_pulse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_pulse)
	Engine.max_fps = 0
	OS.low_processor_usage_mode = false
	if not _headless:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		root.grab_focus()
		await _wait_frames(SETTLE_INPUT_FRAMES)
		if not DisplayServer.window_is_focused(): _unfocused_frames += 1
	for kind: String in ENCOUNTERS:
		if not await _open(kind): break
		await _exercise(kind)
		_scene.queue_free()
		await _wait_frames(2)
	if not _headless and not DisplayServer.window_is_focused(): _unfocused_frames += 1
	var file := FileAccess.open(_output.path_join("navigation.json"), FileAccess.WRITE)
	if file == null:
		_finish("Could not write navigation report.")
		return
	file.store_string(JSON.stringify({
		"schema": 1, "headless": _headless, "detail": OS.get_cmdline_user_args().has("--detail"),
		"fixture_sha256": FileAccess.get_sha256(bundle), "unfocused": _unfocused_frames,
		"engine": Engine.get_version_info(), "samples": _results, "receipts": _receipts,
	}) + "\n")
	file.close()
	if _unfocused_frames > 0: _errors.append("Native sample lost window focus")
	print("PERF-154 PROBE: %s (%d cohorts, %d errors)" % ["PASS" if _errors.is_empty() else "FAIL", _results.size(), _errors.size()])
	_finish()

func _exercise(kind: String) -> void:
	_button(JOY_BUTTON_RIGHT_SHOULDER)
	await _wait_frames(SETTLE_INPUT_FRAMES)
	if _scene._controller_region != "hand":
		_finish("Controller failed to enter hand in " + kind)
		return
	for attempt: int in range(ATTEMPTS):
		# Each traversal uses both alternatives and verifies each logical move.
		await _measure(kind + "/shoulder", _button.bind(JOY_BUTTON_RIGHT_SHOULDER))
		await _measure(kind + "/shoulder", _button.bind(JOY_BUTTON_LEFT_SHOULDER))
		await _measure(kind + "/hand-dpad", _button.bind(JOY_BUTTON_DPAD_RIGHT))
		await _measure(kind + "/hand-dpad", _button.bind(JOY_BUTTON_DPAD_LEFT))
	_button(JOY_BUTTON_DPAD_UP)
	await _wait_frames(SETTLE_INPUT_FRAMES)
	for attempt: int in range(ATTEMPTS):
		await _measure(kind + "/board-dpad", _button.bind(JOY_BUTTON_DPAD_RIGHT))
		await _measure(kind + "/board-dpad", _button.bind(JOY_BUTTON_DPAD_LEFT))
		var anchor: Vector2i = _scene._controller_board_tile
		await _measure(kind + "/stick", _stick.bind(1.0), true)
		_scene._controller_set_board_tile(anchor)
		await _wait_frames(SETTLE_INPUT_FRAMES)
	for attempt: int in range(ATTEMPTS):
		if not await _prepare_select(): break
		await _measure(kind + "/select", _button.bind(JOY_BUTTON_A))
		if _scene._selected_card_index != OPENING_CARD_INDEX or _scene._pending_target_tiles.is_empty() or _scene._hovered_board_tile != _scene._controller_board_tile:
			_errors.append(kind + ": A failed to reach the targeted opening card's default aim")
			break
		var previous: Vector2i = _scene._hovered_board_tile
		await _measure(kind + "/target-hover", _button.bind(JOY_BUTTON_DPAD_RIGHT))
		if _scene._hovered_board_tile == previous or not _scene._pending_target_tiles.has(_scene._hovered_board_tile):
			_errors.append(kind + ": D-pad did not change the selected card's legal aim")
		_button(JOY_BUTTON_B)
		await _wait_frames(SETTLE_INPUT_FRAMES)
	if (_results.get(kind + "/select", []) as Array).size() != ATTEMPTS:
		_errors.append(kind + ": incomplete select route")
	await _check_cancel(kind)
	# Pointer card hover uses the viewport's real GUI dispatch. Tile hover uses
	# perf134's board-GUI fallback for the standalone synthetic viewport.
	if _scene._controller_region == "board":
		_button(JOY_BUTTON_X)
		await _wait_frames(SETTLE_INPUT_FRAMES)
	await _wait_for_mouse_presentation(kind + "/mouse-setup")
	var card: Control = _scene._hand_card_control(OPENING_CARD_INDEX)
	var foe: Vector2i = _navigation_foe_tile()
	if foe.x < 0: return
	for attempt: int in range(ATTEMPTS):
		await _measure(kind + "/mouse-tile", _hover.bind(foe))
		if _scene._hovered_board_tile != foe:
			_errors.append(kind + ": pointer did not enter the enemy's board tile")
		elif (_board.presentation.get("isolated_enemy_actor_keys", []) as Array).is_empty():
			_errors.append(kind + ": enemy hover did not publish its isolation")
		var rect: Rect2 = card.get_global_rect()
		await _measure(kind + "/mouse-card", _motion.bind(rect.position + rect.size * EXPOSED_CARD_POINT))
		if _scene._hovered_card_index != OPENING_CARD_INDEX:
			_errors.append(kind + ": pointer did not enter the opening card")

func _navigation_foe_tile() -> Vector2i:
	# The capture helper also hovers its chosen tile. Picking a sample target
	# must leave the first actual hover inside the measured input window.
	for unit: Dictionary in _scene._combat_state.get("enemies", []):
		var tile: Vector2i = unit["pos"]
		if _board.call("_tile_at_point", _board.world_position_for_tile(tile)) == tile:
			return tile
	_errors.append("Fixture has no hittable enemy tile")
	return Vector2i(-1, -1)

func _measure(key: String, input: Callable, stick: bool = false) -> void:
	var detail: bool = OS.get_cmdline_user_args().has("--detail")
	if detail:
		_scene.set_runtime_performance_instrumentation_enabled(true)
		_board.set_submission_performance_instrumentation_enabled(true)
	var before: Array = _focus()
	var select: bool = key.ends_with("/select")
	var retarget: bool = key.ends_with("/target-hover")
	var forecast_window: bool = select or retarget
	var mouse_hover: bool = key.get_slice("/", 1).begins_with("mouse-")
	var cursor_before: Vector2 = _scene._controller_virtual_board_position
	var redraw_before: int = _board._render_redraw_request_count
	_intervals.clear()
	_sample_count = FORECAST_WINDOW_FRAMES if forecast_window else 1 + FOLLOWUP_FRAMES
	_boundary_usec = Time.get_ticks_usec()
	input.call()
	if select and not _scene._selection_forecast_baseline:
		_check_immediate_selection(key)
	if stick:
		for tick: int in range(STICK_PHYSICS_TICKS):
			await physics_frame
		_stick(0.0)
		if _scene._controller_virtual_board_position == cursor_before:
			_errors.append(key + ": joystick did not move the cursor")
	while _sample_count > 0:
		await _wait_frames(1)
	var sections: Dictionary = _scene.runtime_performance_instrumentation_snapshot() if detail else {}
	var board_sections: Dictionary = _board.submission_performance_instrumentation_snapshot() if detail else {}
	if detail:
		_scene.set_runtime_performance_instrumentation_enabled(false)
		_board.set_submission_performance_instrumentation_enabled(false)
	var settled_forecast: Dictionary = {}
	if forecast_window:
		var chip: Button = _scene._selected_card_forecast_chip()
		var pass_key: String = _scene._pass_preview_key()
		settled_forecast = {
			"summary": chip.get_meta("pass_forecast_summary", {}),
			"cached": _scene._pass_preview_cache.get(pass_key, {}),
			"stagger": _scene._turn_order_stagger_preview_delays(),
			"rows": chip.get_meta("forecast_rows", []),
		}
		if select and not _scene._selection_forecast_baseline and not _scene._selected_pass_work.settled(_scene):
			_errors.append(key + ": initial forecast did not settle")
		if retarget and not _current_forecast_ready():
			_errors.append(key + ": retarget forecast did not publish")
	var samples: Array = _results.get_or_add(key, [])
	var sample: Dictionary = {"interval_usec": _intervals.duplicate(), "sections": sections, "board_sections": board_sections,
		"redraw_requests": _board._render_redraw_request_count - redraw_before}
	samples.append(sample)
	if mouse_hover:
		# Keep the timing boundary visible for diagnosis. Read semantic identity
		# after the existing settle interval, when hand dwell and deferred board
		# submission have both run, even at uncapped native frame rates.
		sample["presentation_at_timing_boundary"] = _navigation_presentation().duplicate(true)
		await _wait_frames(SETTLE_INPUT_FRAMES)
		await _wait_for_mouse_presentation(key)
	var after: Array = _focus()
	var receipt: Array = _receipts.get_or_add(key, [])
	# The stick advances by real physics ticks. Under uncapped native rendering
	# the three sampled display intervals need not contain those same ticks.
	if not stick:
		receipt.append(([before, after] + _navigation_presentation() + [settled_forecast]).duplicate(true))
	if before == after and key.get_slice("/", 1) in ["shoulder", "hand-dpad", "board-dpad"]:
		_errors.append(key + ": input did not move focus")
	if not forecast_window and not mouse_hover:
		await _wait_frames(SETTLE_INPUT_FRAMES)

func _navigation_presentation() -> Array:
	return [_board.presentation.get("isolated_enemy_actor_keys", []),
		_board.presentation.get("expanded_enemy_actor_keys", []), _board.move_tiles, _board.attack_tiles]

func _current_forecast_ready() -> bool:
	var chip: Button = _scene._selected_card_forecast_chip()
	var cached: Dictionary = _scene._pass_preview_cache.get(_scene._pass_preview_key(), {})
	return is_instance_valid(chip) and not cached.is_empty() and chip.get_meta("pass_forecast_summary", {}) == cached

func _wait_for_mouse_presentation(key: String) -> void:
	var deadline: int = Time.get_ticks_usec() + MOUSE_PRESENTATION_TIMEOUT_USEC
	while _scene._hand_hover_rest_pending or _scene._board_hover_refresh_pending or _scene._hover_presentation_flush_queued:
		if Time.get_ticks_usec() >= deadline:
			_errors.append(key + ": hover presentation did not settle")
			return
		await _wait_frames(1)

func _check_immediate_selection(key: String) -> void:
	var chip: Button = _scene._selected_card_forecast_chip()
	if _scene._selected_card_index != OPENING_CARD_INDEX or _scene._animation_lock:
		_errors.append(key + ": selection did not open on the press")
	if not _scene._pending_target_tiles.has(_scene._controller_board_tile) or _board.move_tiles.is_empty():
		_errors.append(key + ": legal aim and card movement were absent on the press")
	if not _scene._selected_pass_pending() or _scene._selected_pass_work._step != "source":
		_errors.append(key + ": forecast advanced on the press")
	if chip == null or not chip.visible or not chip.disabled or not (chip.get_meta("pass_forecast_summary", {}) as Dictionary).is_empty():
		_errors.append(key + ": pending Pass control was absent or contained a forecast")
	elif float(chip.get_meta("pass_forecast_alpha", 0.0)) != 0.0:
		_errors.append(key + ": pending Pass forecast rows were visible on the press")

func _prepare_select() -> bool:
	# Return through the board's hero tile before every measured press. The
	# cancelled target must never masquerade as a fresh controller aim.
	if _scene._controller_region != "hand":
		_button(JOY_BUTTON_X)
		await _wait_frames(SETTLE_INPUT_FRAMES)
	_button(JOY_BUTTON_DPAD_UP)
	await _wait_frames(SETTLE_INPUT_FRAMES)
	_button(JOY_BUTTON_X)
	await _wait_frames(SETTLE_INPUT_FRAMES)
	for step: int in range(_scene._combat_state.get("deck", {}).get("hand", []).size()):
		if _scene._controller_hand_index == OPENING_CARD_INDEX: break
		_button(JOY_BUTTON_LEFT_SHOULDER)
		await _wait_frames(SETTLE_INPUT_FRAMES)
	return _scene._controller_region == "hand" and _scene._controller_hand_index == OPENING_CARD_INDEX

func _check_cancel(kind: String) -> void:
	for wait_frames: int in CANCEL_AFTER_FRAMES:
		if not await _prepare_select():
			_errors.append(kind + ": could not prepare forecast cancel")
			return
		_button(JOY_BUTTON_A)
		if _scene._selected_card_index != OPENING_CARD_INDEX:
			_errors.append(kind + ": cancel witness did not select first")
		await _wait_frames(wait_frames)
		var canceled_key: String = _scene._pass_preview_key()
		_button(JOY_BUTTON_B)
		await _wait_frames(FORECAST_WINDOW_FRAMES)
		if _scene._selected_card_index >= 0 or _scene._selected_pass_pending() or _scene._selected_pass_work._revision >= 0:
			_errors.append(kind + ": cancel left forecast ownership behind")
		if _scene._pass_preview_cache.has(canceled_key):
			_errors.append(kind + ": a canceled selection published into the current cache")

func _focus() -> Array:
	return [_scene._controller_region, _scene._controller_hand_index, str(_scene._controller_board_tile),
		str(_scene._hovered_board_tile), _scene._selected_card_index, _scene._hovered_card_index]

func _boundary() -> void:
	if is_instance_valid(_pulse): _pulse.position.x = float(Engine.get_process_frames() % 2)
	if _sample_count == 0: return
	_sample_count -= 1
	var now: int = Time.get_ticks_usec()
	_intervals.append(now - _boundary_usec)
	_boundary_usec = now
	if not _headless and not DisplayServer.window_is_focused(): _unfocused_frames += 1

func _button(index: int) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = index
		event.pressed = pressed
		_canvas.push_input(event, true)

func _stick(value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = JOY_AXIS_LEFT_X
	event.axis_value = value
	_canvas.push_input(event, true)
