extends SceneTree
## Real viewport controller input; warmup and readback outside timed frames.

const Fixtures = preload("confirm_fixtures.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Analytics = preload("res://scripts/analytics_store.gd")
const Recent = preload("res://scripts/recent_event_store.gd")
const SIZE := Vector2i(1920, 1080)
const FRAME_CAP := 120
const WAIT_SECONDS := 20.0
const FALLBACK_SLEEP_USEC := 1000
const SETTLE_FRAMES := 8
const MAX_VALID_INTERVAL_USEC := 950000
const RECEIPT_TYPES: Array[String] = [
	"map_event_resolved", "equipment_grafted", "merchant_trade", "reward_choice", "progression_level_up", "run_ended",
]
const CASES: Array[String] = [
	"campfire_linger", "campfire_strength", "campfire_embrace", "event_choice", "event_continue",
	"reward_card", "reward_skip", "treasure_claim", "graft_commit", "graft_continue",
	"scavenger_buy", "scavenger_sell",
]

var _output: String
var _active_cases: Array[String]
var _iterations: int = 5
var _capture: bool
var _native: bool
var _timer_deadline: int
var _focus_losses: int
var _invalid_intervals: int
var _rows: Array[Dictionary]
var _scene: Node
var _pulse: ColorRect

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): _output = arg.trim_prefix("--output=")
		elif arg.begins_with("--iterations="): _iterations = int(arg.get_slice("=", 1))
		elif arg.begins_with("--case="): _active_cases.append(arg.get_slice("=", 1))
		elif arg == "--capture": _capture = true
	_native = DisplayServer.get_name() != "headless"
	if _active_cases.is_empty(): _active_cases.assign(CASES)
	_run.call_deferred()

func _run() -> void:
	if _output.is_empty() or _iterations < 1 or (_capture and not _native):
		_fail("Provide --output, positive iterations and a native renderer for --capture")
		return
	DirAccess.make_dir_recursive_absolute(_output)
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	Engine.max_fps = FRAME_CAP
	OS.low_processor_usage_mode = false
	OS.low_processor_usage_mode_sleep_usec = FALLBACK_SLEEP_USEC
	root.mode = Window.MODE_WINDOWED
	root.size = SIZE
	root.content_scale_size = SIZE
	root.content_scale_factor = 1.0
	Settings.set_storage_path("user://perf162-settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings.merge({"display_mode": "windowed", "ui_scale": 1.0, "reduced_motion": false}, true)
	Settings.save_settings(settings)
	Store.set_storage_path("user://perf162-profile.json")
	Store.set_run_storage_path("user://perf162-checkpoint.save")
	Analytics.set_storage_dir("user://perf162-analytics")
	Recent.set_storage_path("user://perf162-recent.json")
	if not _native: process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	if _native:
		DisplayServer.window_move_to_foreground()
	_pulse = ColorRect.new()
	_pulse.color = Color(0.0, 0.0, 0.0, 0.001)
	_pulse.size = Vector2(1, 1)
	_pulse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pulse.z_index = 4095
	root.add_child(_pulse)
	root.get_node("InputRouter").set_forced_state_for_test("controller", "steam_deck")
	for case: String in _active_cases:
		if not CASES.has(case):
			_fail("Unknown confirm " + case)
			return
		var repeats: int = 1 if _capture else _iterations + 1
		for index: int in range(repeats):
			if not await _take(case, index, index > 0 or _capture): return
	if _native and not DisplayServer.window_is_focused(): _focus_losses += 1
	var file := FileAccess.open(_output.path_join("confirm.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema": 1, "native": _native, "viewport": [root.size.x, root.size.y],
		"ui_scale": 1.0, "frame_cap": FRAME_CAP, "focus_losses": _focus_losses, "invalid_intervals": _invalid_intervals,
		"display": DisplayServer.get_name(), "renderer": RenderingServer.get_current_rendering_method(),
		"driver": RenderingServer.get_current_rendering_driver_name(), "godot": Engine.get_version_info()["string"],
		"cpu": OS.get_processor_name(), "adapter": RenderingServer.get_video_adapter_name(),
		"os": OS.get_version(), "samples": _rows}))
	file.close()
	if _focus_losses > 0 or _invalid_intervals > 0:
		_fail("Invalid native take: lost focus or drawable delivery stalled")
		return
	print("PERF162 CONFIRMS: %d semantic work samples (%s)" % [_rows.size(), "native" if _native else "headless"])
	print("TEST RESULT: PASS — noncombat controller confirms and committed receipts")
	quit()

func _take(case: String, index: int, record: bool) -> bool:
	var fixture: Dictionary = Fixtures.state_for(case, index)
	if fixture.is_empty() or not Store.save_data(fixture["progression"]) or not Store.save_run_state(fixture):
		return _fail("Could not persist fixture " + case)
	_scene = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	root.add_child(_scene)
	if not await _until(_scene.initial_presentation_is_ready, case + " initial presentation"): return false
	_scene._load_run_state(fixture)
	_scene._close_dialogue()
	_scene._close_large_map()
	var selection: String = Fixtures.prepare(_scene, case)
	if case.begins_with("scavenger") and not _scene._scavenger_shop_view.visible:
		return _fail("%s shop did not open (mode=%s, merchant=%s)" % [case, _scene._run_state.get("mode"), _scene._current_room_merchant_kind()])
	if not await _until(func() -> bool: return is_instance_valid(Fixtures.target(_scene, case)), case + " target"): return false
	var target: Control = Fixtures.target(_scene, case)
	for _frame: int in range(SETTLE_FRAMES): await _frame_boundary()
	target.grab_focus()
	await _frame_boundary()
	if not target.has_focus() or not target.is_visible_in_tree() or (target is BaseButton and target.disabled):
		return _fail("%s target is unusable (target=%s current=%s)" % [case, target.name, root.gui_get_focus_owner()])
	if _capture and not await _image(case + "_before"): return false
	_scene.set_runtime_performance_instrumentation_enabled(true)
	var before: Dictionary = _scene._run_state.duplicate(true)
	var first_sequence: int = _scene._analytics_store._sequence
	var session: String = _scene._analytics_store.session_id()
	var telemetry: Node = root.get_node("PerformanceTelemetry")
	telemetry.take_hitch_events()
	telemetry.take_hitch_phases()
	var draws: int = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var nodes: int = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var start: int = await _frame_boundary()
	_press(true)
	var press_usec: int = Time.get_ticks_usec() - start
	_press(false)
	var dispatch_usec: int = Time.get_ticks_usec() - start
	var frames: PackedInt64Array
	var previous: int = start
	var settled_at: int = 0
	var remaining: int = SETTLE_FRAMES
	while remaining > 0:
		var now: int = await _frame_boundary()
		frames.append(now - previous)
		previous = now
		if _native and record and not _capture:
			_focus_losses += int(not DisplayServer.window_is_focused())
			_invalid_intervals += int(frames[-1] >= MAX_VALID_INTERVAL_USEC)
		if Fixtures.settled(_scene, case, before):
			if settled_at == 0: settled_at = now
			remaining -= 1
		if now - start >= WAIT_SECONDS * 1000000: return _fail(case + " action did not complete")
	var frames_with_work: Dictionary = _scene.runtime_performance_frame_instrumentation_snapshot()
	var phases: Dictionary = _scene.consume_runtime_performance_instrumentation_snapshot()
	var loads: Dictionary = telemetry.take_hitch_events()
	var hitch_phases: Dictionary = telemetry.take_hitch_phases()
	if _capture and not await _image(case + "_after"): return false
	var live: Dictionary = _scene._run_state
	var saved: Dictionary = Store.load_saved_run()
	if case == "campfire_embrace":
		if not saved.is_empty(): return _fail("Embrace left a resumable checkpoint")
	elif saved.is_empty() or saved.get("mode") != live["mode"] or saved.get("current_room") != live["current_room"]:
		return _fail(case + " diverged from the durable checkpoint")
	var receipt_keys: Array[String] = ["mode", "player_hp", "held_embers", "deck_cards", "relics", "event_state", "equipment_inventory", "equipment_grafts"]
	var receipt: Dictionary = {"selected_fixture": selection, "saved": not saved.is_empty()}
	for field: String in receipt_keys:
		if live.get(field) != saved.get(field) and not saved.is_empty(): return _fail(case + " checkpoint mismatch for " + field)
		receipt[field] = live.get(field)
	receipt["level"] = live.get("progression", {}).get("level")
	receipt["banked_embers"] = Store.load_data().get("embers")
	var records: Array[Dictionary]
	for event: Dictionary in Analytics.load_all_events():
		if event.get("session_id") == session and int(event.get("sequence", 0)) > first_sequence and RECEIPT_TYPES.has(event.get("event_type", "")):
			records.append({"type": event["event_type"], "payload": event["payload"]})
	receipt["analytics"] = records
	receipt["event_history"] = Recent.load_recent_events()
	if record:
		_rows.append({"case": case, "index": index, "intervals_usec": Array(frames), "press_usec": press_usec,
			"dispatch_usec": dispatch_usec, "completion_usec": settled_at - start, "phases": phases, "frames_with_work": frames_with_work, "loads": loads,
			"hitch_phases_usec": hitch_phases, "receipt": receipt, "draw_calls_before": draws,
			"draw_calls_after": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			"nodes_before": nodes, "nodes_after": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
			"orphans": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
			"memory_static": Performance.get_monitor(Performance.MEMORY_STATIC)})
	print("PERF162 %s take=%d committed=%s frames=%d" % [case, index, live["mode"], frames.size()])
	_scene.queue_free()
	await process_frame
	return true

func _until(ready: Callable, label: String) -> bool:
	_timer_deadline = Time.get_ticks_usec() + int(WAIT_SECONDS * 1000000)
	while not bool(ready.call()):
		if Time.get_ticks_usec() >= _timer_deadline: return _fail("Timed out waiting for " + label)
		await process_frame
	return true

func _frame_boundary() -> int:
	_pulse.position.x = 1.0 - _pulse.position.x
	if _native: await RenderingServer.frame_post_draw
	else: await process_frame
	return Time.get_ticks_usec()

func _press(down: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_A
	event.pressed = down
	root.push_input(event, true)

func _image(stem: String) -> bool:
	await _frame_boundary()
	var image: Image = root.get_texture().get_image()
	var path: String = _output.path_join(stem + ".png")
	if image == null or image.get_size() != SIZE or image.save_png(path) != OK:
		return _fail("Could not capture " + path)
	print(path)
	return true

func _fail(message: String) -> bool:
	push_error(message)
	print("TEST RESULT: FAIL — " + message)
	quit(1)
	return false
