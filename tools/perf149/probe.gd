extends "res://tools/perf134/probe.gd"
## Real controller input on the shared perf-140 saves. Record complete intervals
## and label the physical press separately from later work in the same action.

const ROUTES: Dictionary = {"normal": JOY_BUTTON_Y, "tharokh": JOY_BUTTON_Y, "normal-accept": JOY_BUTTON_A}
const Analytics = preload("res://scripts/analytics_store.gd")
const INPUT_SETTLE_FRAMES: int = 10
const READY_SETTLE_FRAMES: int = 10
const FRAME_LOAD_USEC: int = 1000
const UNCAPPED_FPS: int = 0
const CAPTURE_READY_FRAME: int = 720
const CAPTURE_REDRAW_FRAMES: int = 2
var _trace_frames: Array[Dictionary]
var _record_frames: bool = false
var _last_boundary: int = 0
var _cohort: String = ""
var _telemetry: Node
var _load_enabled: bool
var _capture_boot_frame: int
var _capture_check: bool

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_headless = DisplayServer.get_name() == "headless"
	# Connect before the emulated post-draw signal. Its continuations belong to
	# the following interval, the same convention as the native census.
	if _headless:
		process_frame.connect(_boundary)
		process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	else:
		RenderingServer.frame_post_draw.connect(_boundary)
	call_deferred("_run")

func _run() -> void:
	_output = _argument("--output=")
	_capture = _argument("--capture=")
	if OS.get_cmdline_user_args().has("--capture"):
		_finish("Choose a single fixture with --capture=normal|tharokh.")
		return
	if _headless:
		_capture_check = not _argument("--capture-check=").is_empty()
		if _capture_check: _capture = _argument("--capture-check=")
	if not _capture.is_empty() and (
		_capture not in ["normal", "tharokh"] or (_headless and not _capture_check)
		or (not _headless and (Engine.get_write_movie_path().is_empty() or Clock._read_movie_fps() != CAPTURE_FPS))
	):
		_finish("Use --capture=normal|tharokh with a 60 FPS movie, or --capture-check=normal|tharokh headlessly.")
		return
	var bundle: String = _argument("--fixtures=")
	if _output.is_empty() or not FileAccess.file_exists(bundle):
		_finish("Supply --output=DIR and --fixtures=the perf-140 fixture bundle.")
		return
	var archive: Dictionary = bytes_to_var(FileAccess.get_file_as_bytes(bundle))
	_fixture_digest = FileAccess.get_sha256(bundle)
	_fixtures = archive.get("cases", {})
	DirAccess.make_dir_recursive_absolute(_output)
	var settings: Dictionary = View.Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["combat_speed"] = View.Settings.COMBAT_NORMAL
	settings["display_mode"] = "windowed"
	if not View.Settings.save_settings(settings):
		_finish("Could not save isolated proof settings.")
		return
	_make_canvas()
	Engine.max_fps = UNCAPPED_FPS
	OS.low_processor_usage_mode = false
	if not _headless: DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_telemetry = root.get_node("PerformanceTelemetry")
	_load_enabled = OS.get_cmdline_user_args().has("--load=1")
	var results: Dictionary = {}
	var routes: Array = ROUTES.keys() if _capture.is_empty() else [_capture]
	for route: String in routes:
		Analytics.set_storage_dir("user://perf149-" + route)
		_capture_boot_frame = Engine.get_process_frames()
		if not await _open(route.trim_suffix("-accept")): break
		if not _capture.is_empty() and not _check_capture_encounter(_scene._combat_state): break
		results[route] = await _pass_round(route, ROUTES[route])
		_scene.queue_free()
		await _wait_frames(2)
	var result_file := FileAccess.open(_output.path_join("pass-rounds.json"), FileAccess.WRITE)
	if result_file == null:
		_finish("Could not write Pass report.")
		return
	result_file.store_string(JSON.stringify(results) + "\n")
	result_file.close()
	if results.size() != routes.size():
		_errors.append("Did not exercise all controller routes.")
	print("PERF-149 PROBE: %s (%d routes, %d errors)" % [
		"PASS" if _errors.is_empty() else "FAIL", results.size(), _errors.size()
	])
	_finish()

func _button(index: int, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = index
	event.pressed = pressed
	_canvas.push_input(event, true)

func _pass_round(kind: String, button: int) -> Dictionary:
	_button(JOY_BUTTON_X, true)
	_button(JOY_BUTTON_X, false)
	await _wait_frames(INPUT_SETTLE_FRAMES)
	if not _scene._controller_hand_focused:
		_button(JOY_BUTTON_X, true)
		_button(JOY_BUTTON_X, false)
		await _wait_frames(INPUT_SETTLE_FRAMES)
	if not _scene._controller_is_active() or not _scene._controller_hand_focused:
		_errors.append(kind + ": controller did not focus the hand before Pass")
	if button == JOY_BUTTON_A:
		# Seed the Pass focus target, then use the ordinary controller Accept event.
		_scene._controller_enter_board(false)
		var chip: Button = _scene._selected_card_forecast_chip()
		var candidate: Dictionary = preload("res://scripts/controller_focus_candidates.gd").for_control(_scene, chip)
		_scene._controller_set_focus_candidate(candidate, true)
		await _wait_frames(INPUT_SETTLE_FRAMES)
	var before: Dictionary = _scene._combat_state
	var before_summary: Dictionary = _scene._pass_preview_summary()
	_scene.set_runtime_performance_instrumentation_enabled(OS.get_cmdline_user_args().has("--detail"))
	_telemetry.take_hitch_phases()
	_trace_frames.clear()
	_last_boundary = Time.get_ticks_usec()
	_record_frames = true
	_cohort = "press"
	_button(button, true)
	_button(button, false)
	var accepted: bool = _scene._animation_lock
	await _wait_frames(1)
	_cohort = "round"
	var settled: bool = await _wait_for_action()
	await _wait_frames(READY_SETTLE_FRAMES)
	_record_frames = false
	var stats: Dictionary = _scene.runtime_performance_instrumentation_snapshot()
	var final_state: Dictionary = _scene._combat_state.duplicate(true)
	if not accepted or not settled or int(final_state.get("turn", 0)) <= int(before.get("turn", 0)):
		_errors.append(kind + ": controller did not commit and finish an enemy round")
	var chip: Button = _scene._selected_card_forecast_chip()
	var forecast_is_ready: bool = is_instance_valid(chip) and chip.is_visible_in_tree() and not chip.disabled
	forecast_is_ready = forecast_is_ready and not _scene._pass_preview_warm_active
	var after_summary: Dictionary = _scene._pass_preview_summary()
	if not forecast_is_ready or after_summary.is_empty():
		_errors.append(kind + ": Pass was not ready after the handoff")
	var turn_receipt: Dictionary = _turn_receipt(kind, int(before.get("turn", 0)))
	var receipt: Dictionary = {
		"initial_summary": before_summary,
		"final_summary": after_summary,
		"analytics": turn_receipt,
	}
	# Objective/forecast totals and deterministic gameplay state, excluding the
	# fixture's storage identity and elapsed wall clock.
	final_state.erase("analytics")
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(var_to_bytes(final_state))
	receipt["final_battle_sha256"] = digest.finish().hex_encode()
	if not _capture.is_empty():
		await _capture_ready(kind, int(before["turn"]))
	return {"frames": _trace_frames.duplicate(true), "phases": stats, "receipt": receipt}

func _turn_receipt(kind: String, turn: int) -> Dictionary:
	var turn_ended: Dictionary = {}
	var next_turn_playable: Array[Dictionary]
	for event: Dictionary in Analytics.load_all_events():
		var event_turn: int = int(event.get("turn", -1))
		if event.get("event_type") == "card_became_playable" and event_turn > turn:
			next_turn_playable.append({"turn": event_turn, "card": event["card_id"], "payload": event["payload"]})
		if event.get("event_type") != "player_turn_ended" or event_turn != turn:
			continue
		if not turn_ended.is_empty():
			_errors.append(kind + ": multiple player_turn_ended receipts")
			break
		turn_ended = event["payload"]
	if turn_ended.get("end_reason") != "pass":
		_errors.append(kind + ": missing committed Pass receipt")
	return {"turn_ended": turn_ended, "next_turn_playable": next_turn_playable}

func _boundary() -> void:
	if not _record_frames: return
	var now: int = Time.get_ticks_usec()
	_trace_frames.append({
		"cohort": _cohort,
		"frame": Engine.get_process_frames(),
		"usec": now - _last_boundary,
		"spans": _telemetry.take_hitch_phases(),
	})
	_last_boundary = now
	if not _load_enabled: return
	# Fixed main-thread contention per interval, outside the press and trace
	# scopes but included in the frame wall time in both variants.
	while Time.get_ticks_usec() - now < FRAME_LOAD_USEC:
		pass

func _check_capture_encounter(combat: Dictionary) -> bool:
	var actual: Array[String] = _capture_enemy_types(combat)
	var expected: Array[String] = _capture_enemy_types(_fixtures[_capture]["combat_state"])
	if actual == expected and not actual.is_empty() and actual.has("tharokh") == (_capture == "tharokh"):
		return true
	_errors.append("%s loaded enemies %s, expected %s" % [_capture, actual, expected])
	return false

func _capture_enemy_types(combat: Dictionary) -> Array[String]:
	var types: Array[String]
	for enemy: Dictionary in combat.get("enemies", []):
		types.append(str(enemy["type"]))
	types.sort()
	return types

func _capture_ready(kind: String, initial_turn: int) -> void:
	if not _capture_check:
		# Both arms finish combat motion before taking the same numbered draw.
		# Align restless presentation clocks to that movie frame independently of
		# the combat speed scale and the number of deferred CPU slices.
		var redraw_frame: int = _capture_boot_frame + CAPTURE_READY_FRAME - CAPTURE_REDRAW_FRAMES
		if Engine.get_process_frames() > redraw_frame:
			_errors.append(kind + ": missed the fixed capture frame")
			return
		await _wait_frames(redraw_frame - Engine.get_process_frames())
		var idle_seconds: float = float(CAPTURE_READY_FRAME - CAPTURE_REDRAW_FRAMES) / CAPTURE_FPS
		Clock._frame = Engine.get_process_frames()
		Clock._scaled_usec = idle_seconds * 1000000.0
		Clock._unscaled_usec = Clock._scaled_usec
		_board.set("_idle_elapsed", idle_seconds)
		_align_capture_idles(_board, idle_seconds)
		_board.call("_queue_dynamic_redraw")
		await _wait_frames(CAPTURE_REDRAW_FRAMES)
		if Engine.get_process_frames() != _capture_boot_frame + CAPTURE_READY_FRAME:
			_errors.append(kind + ": capture was taken on an unexpected movie frame")
			return
	var rendered: Dictionary = _board.combat_state
	var ready_turn: int = int(_scene._combat_state["turn"])
	var chip: Button = _scene._selected_card_forecast_chip()
	if (
		not _check_capture_encounter(rendered) or ready_turn <= initial_turn
		or int(rendered.get("turn", 0)) != ready_turn or _scene._animation_lock
		or not is_instance_valid(chip) or not chip.is_visible_in_tree() or chip.disabled
	):
		_errors.append(kind + ": the board and Pass chip did not publish the ready turn")
		return
	var path: String = _output.path_join(kind + "-pass-ready")
	var receipt := FileAccess.open(path + ".json", FileAccess.WRITE)
	if receipt == null:
		_errors.append("Could not write the capture witness " + path)
		return
	receipt.store_string(JSON.stringify({
		"fixture": kind, "bundle_sha256": _fixture_digest,
		"enemies": _capture_enemy_types(rendered), "ready_turn": ready_turn,
		"frame": CAPTURE_READY_FRAME, "fps": CAPTURE_FPS, "movie": not _capture_check,
		"size": [_canvas.size.x, _canvas.size.y], "ui_scale": 1.0,
	}) + "\n")
	receipt.close()
	if _capture_check:
		print("PERF-149 CAPTURE SETUP: PASS (%s, turn %d, %s)" % [kind, ready_turn, str(_capture_enemy_types(rendered))])
		return
	var picture: Image = _canvas.get_texture().get_image()
	picture.convert(Image.FORMAT_RGBA8)
	if picture.save_png(path + ".png") != OK:
		_errors.append("Could not capture " + path)
	else:
		print(ProjectSettings.globalize_path(path + ".png"))

func _align_capture_idles(node: Node, idle_seconds: float) -> void:
	# Visual-only clock alignment. The real route supplies all actor identities,
	# positions, facings, clips and the HUD. No animation is disabled.
	if node.has_method("_apply_pose") and node.get("_idle_seconds") != null:
		node.set("_idle_seconds", idle_seconds)
		node.call("_apply_pose")
	for child: Node in node.get_children():
		_align_capture_idles(child, idle_seconds)
