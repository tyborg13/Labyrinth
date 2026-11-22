extends SceneTree
## The real A button enters through the viewport; each interval ends at a draw.

const Fixtures = preload("fixtures.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Analytics = preload("res://scripts/analytics_store.gd")
const Assets = preload("res://scripts/asset_loader.gd")
const SIZE := Vector2i(1920, 1080)
const FRAME_CAP: int = 120
const DWELL_FRAMES: int = 36
const ARRIVAL_FRAMES: int = 8
const INITIAL_SETTLE_FRAMES: int = 8
const MAX_INTERVAL_USEC: int = 950000
const TIMEOUT_USEC: int = 20000000

class TracedRunEngine extends "res://scripts/run_engine.gd":
	var generation_usec: int = 0
	func move_to_pre_battle(state: Dictionary, destination: Vector2i) -> Dictionary:
		var started: int = Time.get_ticks_usec()
		var result: Dictionary = super.move_to_pre_battle(state, destination)
		generation_usec = Time.get_ticks_usec() - started
		return result

var _scene: Node
var _native: bool
var _capture: bool
var _trace: bool
var _cancel_walk: bool
var _output: String
var _iterations: int = 5
var _dwell_frames: int = DWELL_FRAMES
var _cases: Array[String]
var _samples: Array[Dictionary]
var _pulse: ColorRect
var _telemetry: Node
var _focus_losses: int = 0
var _invalid_intervals: int = 0
var _instances: Dictionary = {}

func _initialize() -> void:
	_native = DisplayServer.get_name() != "headless"
	_trace = OS.get_environment("LABYRINTH_HITCH_TRACE") == "1"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): _output = arg.trim_prefix("--output=")
		elif arg.begins_with("--iterations="): _iterations = int(arg.get_slice("=", 1))
		elif arg.begins_with("--dwell-frames="): _dwell_frames = int(arg.get_slice("=", 1))
		elif arg.begins_with("--case="): _cases.append(arg.get_slice("=", 1))
		elif arg == "--capture": _capture = true
		elif arg == "--cancel-walk": _cancel_walk = true
	if _cases.is_empty(): _cases.assign(Fixtures.CASES)
	_run.call_deferred()

func _run() -> void:
	if _output.is_empty() or _iterations < 1 or _dwell_frames < 1 or (_capture and not _native):
		_fail("Invalid output, iteration count, dwell or capture driver")
		return
	DirAccess.make_dir_recursive_absolute(_output)
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	Engine.max_fps = FRAME_CAP
	OS.low_processor_usage_mode = false
	OS.low_processor_usage_mode_sleep_usec = 1000
	root.mode = Window.MODE_WINDOWED
	root.size = SIZE
	root.content_scale_size = SIZE
	root.content_scale_factor = 1.0
	Settings.set_storage_path("user://perf168-settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings.merge({"display_mode": "windowed", "ui_scale": 1.0, "reduced_motion": false}, true)
	Settings.save_settings(settings)
	Store.set_storage_path("user://perf168-profile.json")
	Store.set_run_storage_path("user://perf168-checkpoint.save")
	Analytics.set_storage_dir("user://perf168-analytics")
	_telemetry = root.get_node("PerformanceTelemetry")
	if _trace: node_added.connect(_count_instance)
	if _native: DisplayServer.window_move_to_foreground()
	else: process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	_pulse = ColorRect.new()
	_pulse.size = Vector2.ONE
	_pulse.color = Color(0.0, 0.0, 0.0, 0.001)
	_pulse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pulse.z_index = 4095
	_pulse.visible = not _capture
	root.add_child(_pulse)
	root.get_node("InputRouter").set_forced_state_for_test("controller", "steam_deck")
	for index: int in range(1 if _capture else _iterations):
		for kind: String in _cases:
			if not Fixtures.CASES.has(kind):
				_fail("Unknown destination type " + kind)
				return
			if not await _take(kind, index): return
	var file := FileAccess.open(_output.path_join("arrival.json"), FileAccess.WRITE)
	if file == null:
		_fail("Could not write arrival.json")
		return
	file.store_string(JSON.stringify({"schema": 1, "native": _native, "captures": _capture,
		"trace": _trace, "viewport": [root.size.x, root.size.y], "ui_scale": root.content_scale_factor,
		"driver": RenderingServer.get_current_rendering_driver_name(), "display": DisplayServer.get_name(),
		"os": OS.get_version(), "cpu": OS.get_processor_name(), "adapter": RenderingServer.get_video_adapter_name(),
		"godot": Engine.get_version_info()["string"], "frame_cap": FRAME_CAP, "dwell_frames": _dwell_frames,
		"focus_losses": _focus_losses, "invalid_intervals": _invalid_intervals, "samples": _samples}))
	file.close()
	if _focus_losses > 0 or _invalid_intervals > 0:
		_fail("Native take lost focus or drawable delivery stalled")
		return
	print("TEST RESULT: PASS — %d controller map arrivals (%s)" % [_samples.size(), "native" if _native else "headless"])
	quit()

func _take(kind: String, index: int) -> bool:
	seed(Fixtures.SEED)
	var fixture: Dictionary = Fixtures.make(kind, index)
	if fixture.is_empty(): return _fail("Missing fixture for " + kind)
	var state: Dictionary = fixture["state"]
	var target: Vector2i = fixture["target"]
	if not Store.save_data(state["progression"]) or not Store.save_run_state(state):
		return _fail("Could not persist fixture " + kind)
	_scene = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	root.add_child(_scene)
	if not await _until_ready(): return _fail("Scene did not install " + kind)
	_scene._load_run_state(state)
	_scene._close_dialogue()
	_scene._close_large_map()
	for _i: int in range(INITIAL_SETTLE_FRAMES): await _frame()
	_scene._close_large_map()
	if _trace:
		_scene._run_engine = TracedRunEngine.new()
		_scene.set_runtime_performance_instrumentation_enabled(true)
	var session: String = _scene._analytics_store.session_id()
	var sequence: int = _scene._analytics_store._sequence
	var intervals: Dictionary = {"map_open": [], "map_a": [], "travel": [], "arrival": []}
	var attribution: Dictionary = {}
	var before: Dictionary = _monitors()
	var stamp: int = await _frame()
	_clear_trace()
	_scene._open_large_map()
	for _i: int in range(_dwell_frames):
		stamp = await _sample(intervals, attribution, "map_open", stamp)
	var map: Control = _scene._large_map_view
	var button: Button = map.node_buttons.get(target)
	if not is_instance_valid(button) or not button.is_visible_in_tree() or not map.can_activate_room(target):
		return _fail(kind + " map target is not reachable")
	button.grab_focus()
	await _frame()
	if not button.has_focus(): return _fail(kind + " route did not gain controller focus")
	if _cancel_walk and not await _cancel_selection(map, target, button): return false
	if _capture and not _image(kind + "_map"): return false
	stamp = await _frame()
	_clear_trace()
	var pressed: int = stamp
	_press(true)
	_press(false)
	var dispatch_usec: int = Time.get_ticks_usec() - pressed
	if map.activation_coord != target: return _fail(kind + " controller A did not activate the route")
	stamp = await _sample(intervals, attribution, "map_a", stamp)
	if _capture and not _image(kind + "_walk"): return false
	while _scene._large_map_scrim.visible:
		stamp = await _sample(intervals, attribution, "map_a", stamp)
		if stamp - pressed >= TIMEOUT_USEC: return _fail(kind + " did not finish the map walk")
	if not _scene._animation_lock or _scene._run_state.get("current_room") == target:
		return _fail(kind + " skipped the travel frame")
	var door_started: int = stamp
	var travel_visible: bool = (_scene._board_presentation.get("door_opening", {}) as Dictionary).size() > 0
	if not travel_visible: return _fail(kind + " fixture lacks an authored door opening")
	if _capture and not _image(kind + "_travel"): return false
	var landed: int = 0
	while landed == 0:
		var now: int = await _frame()
		var arrived: bool = _scene._run_state.get("current_room") == target
		_record_interval(intervals, attribution, "arrival" if arrived else "travel", now - stamp)
		stamp = now
		if arrived: landed = now
		if now - pressed >= TIMEOUT_USEC: return _fail(kind + " did not arrive before timeout")
	if not _arrival_visible(kind): return _fail(kind + " first room did not show the expected surface")
	if _capture and not _image(kind + "_arrival"): return false
	for _i: int in range(ARRIVAL_FRAMES - 1):
		stamp = await _sample(intervals, attribution, "arrival", stamp)
	var receipt: Dictionary = _receipt(fixture, kind, session, sequence)
	if receipt.is_empty(): return _fail(kind + " live state, checkpoint or route event diverged")
	var after: Dictionary = _monitors()
	_samples.append({"case": kind, "index": index, "intervals": intervals,
		"dispatch_usec": dispatch_usec, "arrival_usec": landed - pressed,
		"map_walk_usec": door_started - pressed, "door_to_arrival_usec": landed - door_started, "receipt": receipt,
		"monitors_before": before, "monitors_after": after, "attribution": attribution,
		"generation_usec": _scene._run_engine.generation_usec if _trace else 0,
		"phases": _scene.consume_runtime_performance_instrumentation_snapshot() if _trace else {}})
	print("PERF168 %s take=%d mode=%s travel_frames=%d" % [kind, index, _scene._run_state["mode"], intervals["travel"].size()])
	_scene.queue_free()
	await process_frame
	var cleanup_started: int = Time.get_ticks_usec()
	while Assets.has_preparation_drains(root):
		if Time.get_ticks_usec() - cleanup_started >= TIMEOUT_USEC:
			return _fail(kind + " left an outstanding preparation drain")
		await process_frame
	await process_frame
	return true

func _cancel_selection(map: Control, target: Vector2i, button: Button) -> bool:
	var before: Vector2i = _scene._run_state["current_room"]
	_press(true)
	_press(false)
	for _index: int in range(3): await _frame()
	if map.activation_coord != target: return _fail("Could not stage the cancelled selection")
	_press(true, JOY_BUTTON_B)
	_press(false, JOY_BUTTON_B)
	await _frame()
	if map.activation_coord == target or not map.visible:
		return _fail("Controller B did not cancel just the walk")
	if _scene._run_state["current_room"] != before or Store.load_saved_run()["current_room"] != before:
		return _fail("Cancelled map walk changed the live room or checkpoint")
	button.grab_focus()
	return true

func _arrival_visible(kind: String) -> bool:
	if _scene._run_state.get("mode") != Fixtures.expected_mode(kind): return false
	match kind:
		"combat", "elite", "guardian": return _scene._pre_battle_scrim.visible
		"event": return is_instance_valid(_scene._event_view) and _scene._event_view.visible
		"scavenger": return _scene._scavenger_shop_view.visible
		"graftwright": return _scene._graftwright_view.visible
		_: return true

func _receipt(fixture: Dictionary, kind: String, session: String, sequence: int) -> Dictionary:
	var live: Dictionary = _scene._run_state
	var saved: Dictionary = Store.load_saved_run()
	var expected: Dictionary = fixture["expected"]
	var receipt: Dictionary = {}
	for field: String in ["current_room", "mode", "current_room_layout", "pending_relics", "event_state", "turns_spent"]:
		if live.get(field) != expected.get(field) or live.get(field) != saved.get(field):
			print("PERF168 receipt mismatch %s expected=%s saved=%s" % [field, live.get(field) == expected.get(field), live.get(field) == saved.get(field)])
			return {}
		receipt[field] = live.get(field)
	var routes: Array[Dictionary]
	for event: Dictionary in Analytics.load_all_events():
		if event.get("session_id") != session or int(event.get("sequence", 0)) <= sequence: continue
		if event.get("event_type") == "route_choice_committed": routes.append(event["payload"])
	if routes.size() != 1:
		print("PERF168 route receipt count ", routes.size())
		return {}
	receipt["route"] = routes.front()
	if kind == "scavenger": receipt["stock"] = _scene._run_engine.merchant_offer_ids(live, "scavenger")
	return receipt

func _until_ready() -> bool:
	var started: int = Time.get_ticks_usec()
	while not _scene.initial_presentation_is_ready():
		if Time.get_ticks_usec() - started >= TIMEOUT_USEC: return false
		await process_frame
	return true

func _sample(intervals: Dictionary, attribution: Dictionary, phase: String, previous: int) -> int:
	var now: int = await _frame()
	_record_interval(intervals, attribution, phase, now - previous)
	return now

func _record_interval(intervals: Dictionary, attribution: Dictionary, phase: String, elapsed: int) -> void:
	intervals[phase].append(elapsed)
	if _native and not _capture:
		_focus_losses += int(not DisplayServer.window_is_focused())
		_invalid_intervals += int(elapsed >= MAX_INTERVAL_USEC)
	if _trace:
		if not attribution.has(phase): attribution[phase] = []
		attribution[phase].append({"interval_usec": elapsed, "loads": _telemetry.take_hitch_events(),
			"sections": _telemetry.take_hitch_phases(), "mounted_nodes": _instances})
		_instances = {}

func _count_instance(node: Node) -> void:
	var script: Script = node.get_script() as Script
	var key: String = script.resource_path if script != null else node.get_class()
	_instances[key] = int(_instances.get(key, 0)) + 1

func _clear_trace() -> void:
	if _trace:
		_telemetry.take_hitch_events()
		_telemetry.take_hitch_phases()
		_instances = {}

func _monitors() -> Dictionary:
	return {"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"orphans": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		"objects": Performance.get_monitor(Performance.OBJECT_COUNT),
		"memory": Performance.get_monitor(Performance.MEMORY_STATIC),
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"render_objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"process_usec": Performance.get_monitor(Performance.TIME_PROCESS) * 1000000.0}

func _frame() -> int:
	_pulse.position.x = 1.0 - _pulse.position.x
	if _native: await RenderingServer.frame_post_draw
	else: await process_frame
	return Time.get_ticks_usec()

func _press(down: bool, button: int = JOY_BUTTON_A) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = down
	root.push_input(event, true)

func _image(stem: String) -> bool:
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
