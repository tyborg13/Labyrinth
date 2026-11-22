extends "res://tools/perf134/probe.gd"
## Use the production viewport input route on both archived combat boards.

const BUTTONS := [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]
const ACTIONS := ["lb", "rb", "left", "right"]
const ENCOUNTERS := ["normal", "tharokh"]
const ATTEMPTS: int = 10
const RAPID_FRAMES: int = 3
const SETTLE_LIMIT: int = 240
const TIMING_PULSE_ALPHA: float = 0.001

var _samples: Dictionary = {}
var _receipts: Dictionary = {}
var _last_boundary_usec: int
var _intervals: Array[int]
var _remaining_intervals: int
var _capture_frames: bool
var _timing_pulse: ColorRect

func _run() -> void:
	_output = _argument("--output=")
	var bundle: String = _argument("--fixtures=")
	var archive: Variant = bytes_to_var(FileAccess.get_file_as_bytes(bundle)) if FileAccess.file_exists(bundle) else null
	if _output.is_empty() or not archive is Dictionary or archive.get("schema") != FIXTURE_SCHEMA or archive.get("seed") != SEED:
		_finish("Supply --output=DIR and --fixtures=the perf-134 bundle.")
		return
	_fixtures = archive["cases"]
	_fixture_digest = FileAccess.get_sha256(bundle)
	_capture_frames = OS.get_cmdline_user_args().has("--frames")
	_detail = OS.get_cmdline_user_args().has("--detail")
	if _capture_frames: _capture = "hand-cycle"
	RenderingServer.frame_post_draw.connect(_record_boundary)
	DirAccess.make_dir_recursive_absolute(_output)
	var settings: Dictionary = View.Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["display_mode"] = "windowed"
	settings["combat_speed"] = View.Settings.COMBAT_NORMAL
	if not View.Settings.save_settings(settings):
		_finish("Could not save isolated settings.")
		return
	_make_canvas()
	if not _headless and not _capture_frames:
		# Keep the root drawing while a retained hand is idle. The pulse is
		# outside the proof SubViewport and never enters a captured image.
		_timing_pulse = ColorRect.new()
		_timing_pulse.size = Vector2.ONE
		_timing_pulse.modulate.a = TIMING_PULSE_ALPHA
		_timing_pulse.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(_timing_pulse)
	Engine.max_fps = 0
	OS.low_processor_usage_mode = false
	if not _headless:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		root.grab_focus()
		await _wait_frames(SETTLE_FRAMES)
		RenderingServer.frame_post_draw.connect(_check_focus)
	for kind: String in ENCOUNTERS:
		if not await _open(kind): break
		await _exercise(kind)
		_scene.queue_free()
		await _wait_frames(2)
	if _capture_frames and _errors.is_empty():
		await preload("res://tools/perf163/tooltip_restart_check.gd").run(self)
	if _unfocused_frames > 0:
		_errors.append("Window lost focus on %d rendered frames" % _unfocused_frames)
	var file := FileAccess.open(_output.path_join("cycle.json"), FileAccess.WRITE)
	if file == null:
		_finish("Could not write cycle.json")
		return
	file.store_string(JSON.stringify({
		"schema": 1, "headless": _headless, "fixture_sha256": _fixture_digest,
		"engine": Engine.get_version_info(), "os": OS.get_name(), "cpu": OS.get_processor_name(),
		"gpu": RenderingServer.get_video_adapter_name(), "display": DisplayServer.get_name(),
		"viewport": str(_canvas.size), "max_fps": Engine.max_fps,
		"samples": _samples, "receipts": _receipts, "errors": _errors,
	}) + "\n")
	file.close()
	print("PERF-163 ROUTE: %s (%d cohorts, %d receipts, %d errors)" % [
		"PASS" if _errors.is_empty() else "FAIL", _samples.size(), _receipts.size(), _errors.size()])
	_finish()

func _exercise(kind: String) -> void:
	# First establish controller modality, then enter the hand if the room
	# resumed with board focus. Measured presses always start in the hand.
	_button(JOY_BUTTON_RIGHT_SHOULDER)
	await _wait_frames(RAPID_FRAMES)
	if _scene._controller_region != "hand":
		_button(JOY_BUTTON_X)
	if not await _settle(kind + "/setup"): return
	var combat_before: String = _combat_digest(_scene._combat_state)
	for mode: String in ["rapid", "settled"]:
		for attempt: int in range(1 if _capture_frames or _detail else ATTEMPTS):
			for i: int in range(BUTTONS.size()):
				await _press(kind, mode, (i + attempt) % BUTTONS.size())
		if not await _settle(kind + "/end"): return
		_receipts[kind + "/" + mode + "/rest"] = _receipt()
	if combat_before != _combat_digest(_scene._combat_state):
		_errors.append(kind + " hand cycling modified committed combat")

func _press(kind: String, mode: String, i: int) -> void:
	var key: String = "%s/%s/%s" % [kind, mode, ACTIONS[i]]
	var rows: Array = _samples.get_or_add(key, [])
	var before: int = _scene._controller_hand_index
	var count: int = _scene.hand_box.get_child_count()
	if _scene._controller_region != "hand" or before < 0 or count < 2:
		_errors.append(key + " did not start on a valid hand card")
		return
	var expected: int = posmod(before + (-1 if i % 2 == 0 else 1), count)
	if _detail:
		_scene.set_runtime_performance_instrumentation_enabled(true)
	_intervals.clear()
	_remaining_intervals = RAPID_FRAMES
	var input_start: int = Time.get_ticks_usec()
	_button(BUTTONS[i])
	var input_usec: int = Time.get_ticks_usec() - input_start
	await _wait_frames(1)
	if _scene._controller_hand_index != expected or _scene._hovered_card_index != expected or _scene._selected_card_index != -1:
		_errors.append(key + " did not focus the expected card")
	var first: Dictionary = _scene.runtime_performance_instrumentation_snapshot() if _detail else {}
	var sample: Dictionary = {"input_usec": input_usec, "press_sections": first}
	if not _headless and not _capture_frames:
		sample["press_monitors"] = {
			"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			"render_objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			"memory_bytes": Performance.get_monitor(Performance.MEMORY_STATIC),
			"objects": Performance.get_monitor(Performance.OBJECT_COUNT),
			"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
			"orphans": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		}
	rows.append(sample)
	if _capture_frames:
		_record_frame(key, 1)
	for frame: int in range(2, RAPID_FRAMES + 1):
		await _wait_frames(1)
		if _capture_frames: _record_frame(key, frame)
	sample["interval_usec"] = _intervals.duplicate()
	if mode == "settled":
		if not await _settle(key): return
		if _capture_frames: _record_frame(key, 0)
	if _detail:
		sample["window_sections"] = _scene.runtime_performance_instrumentation_snapshot()
		_scene.set_runtime_performance_instrumentation_enabled(false)

func _settle(key: String) -> bool:
	for frame: int in range(SETTLE_LIMIT):
		if not _scene._hand_hover_rest_pending and not _scene._hand_hover_refresh_pending and _scene.hand_box.emphasis_strength() == 1.0 and not _scene.hand_box.is_sliding():
			return true
		await _wait_frames(1)
	_errors.append(key + " hover did not settle")
	return false

func _record_boundary() -> void:
	var now: int = Time.get_ticks_usec()
	if _remaining_intervals > 0:
		_intervals.append(now - _last_boundary_usec)
		_remaining_intervals -= 1
	_last_boundary_usec = now
	if _timing_pulse != null:
		_timing_pulse.position.x = float(Engine.get_process_frames() % 2)

func _check_focus() -> void:
	if not DisplayServer.window_is_focused():
		_unfocused_frames += 1

func _button(index: int) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = index
		event.pressed = pressed
		_canvas.push_input(event, true)

func _record_frame(key: String, frame: int) -> void:
	var name: String = "%s-%02d" % [key.replace("/", "-"), frame]
	_receipts[name] = _receipt()
	# Capture the input, next two draws, and a settled image for each route.
	if _headless: return
	var picture: Image = _canvas.get_texture().get_image()
	picture.convert(Image.FORMAT_RGBA8)
	var path: String = _output.path_join(name + ".png")
	if picture.save_png(path) == OK:
		print(path)
	else:
		_errors.append("PNG failed: " + path)

func _receipt() -> Dictionary:
	var cards: Array = []
	for slot: Control in _scene.hand_box.get_children():
		cards.append([str(slot.position), str(slot.size), str(slot.scale), slot.rotation, slot.z_index])
	var stack: Control = _scene.get("_card_focus_tooltip_stack")
	var chip: Button = _scene._selected_card_forecast_chip()
	var badges: Dictionary = {}
	for glyph: Control in _scene._controller_glyph_badges._badges.values():
		if glyph.is_visible_in_tree():
			badges[str(glyph.action_name)] = [str(glyph.target.name), str(glyph.visual_rect()), glyph._glyph.family]
	return {
		"focus": [_scene._controller_region, _scene._controller_hand_index, _scene._hovered_card_index, _scene._selected_card_index],
		"hover_pending": _scene._hand_hover_rest_pending, "strength": _scene.hand_box.emphasis_strength(),
		"cards": cards, "tooltip": [stack.visible, str(stack.get_rect()), stack.entry_icon_keys()],
		"moves": str(_board.move_tiles), "attacks": str(_board.attack_tiles),
		"damage": _board.presentation.get("damage_preview", {}),
		"badges": badges, "rail_rect": str(_scene._turn_order_panel.get_global_rect()),
		"rail": _scene._turn_order_render_signature, "entries": str(_scene._turn_order_all_entries),
		"pass": [chip.disabled, chip.get_meta("pass_forecast_summary", {}), chip.get_meta("forecast_rows", [])] if chip != null else [],
	}
