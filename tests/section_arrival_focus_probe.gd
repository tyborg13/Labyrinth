extends SceneTree
## QA119 sections.gd focus audit, with real A/B activation and native capture.
const Runtime = preload("res://scripts/parallel_runtime.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Store = preload("res://scripts/progression_store.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const Fixtures = preload("res://tests/suites/section_transition_suite.gd")
const Route = preload("res://tools/qa117/route.gd")
const Tour = preload("res://tools/qa117/tour.gd")
const InputGate = preload("res://tools/hitch_census/demo/input_gate.gd")

const DECK_SIZE := Vector2i(1280, 800)
const DECK_SCALE: float = 1.15
const DESKTOP_SIZE := Vector2i(1920, 1080)
const DESKTOP_SCALE: float = 1.0
const BOOT_FRAMES: int = 8
const PROBE_FPS: int = 60
const FIRST_SECTION: int = 0
const LAST_SECTION: int = 5
const TRANSITION_LIMIT_MSEC: int = 20000
const CAPTURE_FILE: String = "section-2-arrival-focus.png"

var driver
var failure: String
var finished: bool
var _errors: Array[String]
var _report: FileAccess
var _output: String
var _native: bool
var _size: Vector2i

func _initialize() -> void:
	Runtime.apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	_native = DisplayServer.get_name() != "headless"
	var desktop: bool = OS.get_environment("GFIX20_PROFILE") == "desktop"
	_size = DESKTOP_SIZE if desktop else DECK_SIZE
	var scale: float = DESKTOP_SCALE if desktop else DECK_SCALE
	_output = OS.get_environment("GFIX20_OUTPUT")
	if _output.is_empty() or Runtime.current_namespace().is_empty() or DirAccess.make_dir_recursive_absolute(_output) != OK:
		push_error("Set GFIX20_OUTPUT and run with an isolated task namespace")
		quit(2)
		return
	_report = FileAccess.open(_output.path_join("witness.jsonl"), FileAccess.WRITE)
	if _report == null:
		push_error("Could not open section arrival witness")
		quit(2)
		return
	Fixtures.prepare_storage()
	var settings: Dictionary = Settings.load_settings()
	settings["ui_scale"] = scale
	Settings.save_settings(settings)
	root.mode = Window.MODE_WINDOWED
	root.size = _size
	root.content_scale_factor = scale
	if not _native: process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	Engine.max_fps = PROBE_FPS

	driver = Route.new(self)
	var gate := InputGate.new()
	gate.session = self
	root.add_child(gate)
	var tour := Tour.new(self)
	await tour.enter("res://scenes/main_menu.tscn")
	await driver.pad.pulse(Vector2.DOWN)
	_check(root.size == _size and is_equal_approx(root.content_scale_factor, scale)
		and root.get_node("InputRouter").controller_family() == "steam_deck", "Controller proof profile")
	var arrivals: int = 0
	var section_end: int = FIRST_SECTION + 1 if _native else LAST_SECTION
	for index: int in range(FIRST_SECTION, section_end):
		if await _visit(index, tour): arrivals += 1
		if not failure.is_empty(): _errors.append(failure)
	var sent: int = driver.inputs["joypad_button"] + driver.inputs["joypad_motion"]
	_check(sent > 0 and gate.accepted == sent, "Joypad input gate count", {"admitted": gate.accepted, "sent": sent})
	finished = true
	unload_current_scene()
	await frames(BOOT_FRAMES)
	_report.close()
	print("GFIX20 SECTION ARRIVAL: %d/%d passed, %d failures, joypad=%d/%d" %
		[arrivals, section_end - FIRST_SECTION, _errors.size(), gate.accepted, sent])
	quit(0 if _errors.is_empty() else 1)

func _visit(index: int, tour: RefCounted) -> bool:
	var label: String = "section-%d" % (index + 2)
	if not _check(await tour.install(Fixtures.fixture(index)), label + " reward fixture"): return false
	var scene: Node = current_scene
	var destination: Vector2i = Graph.section(scene._run_state, index + 1).get("entry", Graph.INVALID)
	var reward: Control = scene.find_child("DragonRewardContinue", true, false)
	if not _check(reward != null and await driver.control(reward), label + " Continue focused"): return false
	if not _check(await driver.pad.button(JOY_BUTTON_A), label + " Continue pressed"): return false
	var deadline: int = Time.get_ticks_msec() + TRANSITION_LIMIT_MSEC
	var transition: Node = scene._section_transition
	if not _check(is_instance_valid(transition), label + " transition started"): return false
	while is_instance_valid(scene._section_transition) and Time.get_ticks_msec() < deadline:
		await process_frame
	var first_owner: Control = root.gui_get_focus_owner()
	await frames(BOOT_FRAMES)
	var map: Control = scene._large_map_view
	if not _check(not is_instance_valid(scene._section_transition) and map.is_visible_in_tree()
		and scene._run_state.get("current_room") == destination and Store.load_saved_run().get("current_room") == destination,
		label + " restored map and saved destination"): return false
	return await _audit_focus(label, index + 1, scene, map, first_owner)

func _audit_focus(label: String, section: int, scene: Node, map: Control, first_owner: Control) -> bool:
	var choices: Array[Vector2i] = map._choice_destinations()
	var state: Dictionary = scene._run_state
	var threshold: Vector2i = state.get("current_room", Graph.INVALID)
	choices.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return float(Graph.room(state, a).get("map_lane", 0)) < float(Graph.room(state, b).get("map_lane", 0)))
	var wanted_coord: Vector2i = Graph.INVALID
	for coord: Vector2i in choices:
		if map.node_buttons.has(coord) and map.can_activate_room(coord):
			wanted_coord = coord
			break
	var wanted: Control = map.node_buttons.get(wanted_coord)
	var owner: Control = root.gui_get_focus_owner()
	var focus_name: String = str(owner.name) if owner != null else ""
	var wanted_name: String = str(wanted.name) if wanted != null else ""
	var visible_focus: bool = wanted != null and owner == wanted and first_owner == wanted and wanted.is_visible_in_tree() \
		and map._field.get_global_rect().intersects(wanted.get_global_rect()) and map.viewed_section == section
	if visible_focus and _native: await _capture()
	# Press immediately on the arrival focus. The activation is observable
	# before the authored movement animation commits travel.
	_tap(JOY_BUTTON_A)
	var opened_history: bool = map.viewed_section < section
	var opened_route: bool = wanted != null and map.viewed_section == section and map.activation_coord == wanted_coord
	var passed: bool = visible_focus and opened_route
	var receipt: Dictionary = {"actual": focus_name, "expected": wanted_name, "visible_focus": visible_focus,
		"a_opened_route": opened_route, "a_opened_history": opened_history}
	_check(passed, label + " initial route focus and A", receipt)
	print("QA119 SECTION FOCUS %s: %s actual=%s expected=%s A_opened_route=%s A_opened_history=%s" %
		[label, "PASS" if passed else "FAIL", focus_name, wanted_name, opened_route, opened_history])
	if not passed: return false

	_tap(JOY_BUTTON_B)
	var canceled: bool = _check(map.activation_coord == Graph.INVALID and map.is_visible_in_tree()
		and scene._run_state.get("current_room") == threshold, label + " B cancels route")
	var history: Control = map._tabs.get_child(section - 1)
	var tabs: bool = _check(await driver.control(history), label + " D-pad reaches history tab")
	var closed: bool = _check(await driver.pad.button(JOY_BUTTON_B) and not map.is_visible_in_tree(), label + " B closes map")
	return canceled and tabs and closed

func _tap(button: int) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.device = driver.pad.DEVICE_ID
		event.button_index = button
		event.pressed = pressed
		driver.inputs["joypad_button"] += 1
		driver.pad.send(event)
		Input.flush_buffered_events()

func _capture() -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = _output.path_join(CAPTURE_FILE)
	if _check(image != null and image.get_size() == _size and image.save_png(path) == OK, "Native arrival capture"):
		print(path)

func _check(passed: bool, label: String, data: Dictionary = {}) -> bool:
	if not passed: _errors.append(label)
	log_event("check", {"label": label, "passed": passed, "receipt": data})
	print("GFIX20 CHECK %s: %s" % [label, "PASS" if passed else "FAIL"])
	return passed

func fail(reason: String) -> void:
	if failure.is_empty(): failure = reason
	log_event("driver_failure", {"reason": reason})

func log_event(kind: String, data: Dictionary = {}) -> void:
	_report.store_line(JSON.stringify({"kind": kind, "frame": Engine.get_process_frames(), "data": data}))

func hold(seconds: float) -> void:
	await create_timer(seconds).timeout

func frames(count: int) -> void:
	for frame: int in range(count): await process_frame
