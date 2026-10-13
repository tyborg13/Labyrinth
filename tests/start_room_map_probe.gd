extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const Suite = preload("res://tests/suites/start_room_map_suite.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const Settings = preload("res://scripts/settings_store.gd")

const OUTPUT_DIR: String = "user://probes/start_room_map"
const VIEWPORT_SIZE: Vector2i = Vector2i(1920, 1080)
var _scene: Node
var _canvas: SubViewport
var _failures: Array[String]
var _captures: Array[Dictionary]

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	# Headless mode validates imports and logic only; it never claims captures.
	if OS.get_cmdline_user_args().has("--validate-only"):
		print("START ROOM MAP PROBE VALIDATION: PASS (no captures)")
		quit(0)
		return
	if DisplayServer.get_name() == "headless":
		push_error("Start room map captures require the windowed visual probe runner")
		quit(1)
		return
	Suite.prepare_storage()
	root.size = VIEWPORT_SIZE
	root.content_scale_size = VIEWPORT_SIZE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_run.call_deferred()

func _run() -> void:
	_canvas = SubViewport.new()
	_canvas.size = VIEWPORT_SIZE
	_canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_canvas)
	_scene = load("res://scenes/run_scene.tscn").instantiate()
	_canvas.add_child(_scene)
	await Suite.settle(self)
	var settings: Dictionary = _scene.get("_settings").duplicate(true)
	settings["reduced_motion"] = false
	Settings.apply_settings(settings, null, false)
	_scene.call("_on_settings_changed", settings)
	var initial: Dictionary = Suite.fixture()
	await Suite.install(self, _scene, initial)
	_scene.call("_complete_current_dialogue_line")
	_expect(_scene.get("_dialogue_active") and not _scene.get("_large_map_scrim").visible, "Opening narration is visible before map handoff")
	await _capture("01_narration", {"dialogue_id": _scene.get("_dialogue_script").get("id"), "text": _scene.get("_dialogue_text_label").text})
	await Suite.finish_narration(self, _scene, "keyboard")
	var panel: Control = _scene.get("_large_map_view")
	var choices: Array[Vector2i] = panel.call("available_destinations")
	_expect(_scene.get("_large_map_scrim").visible and not choices.is_empty(), "Narration automatically opens the existing map with travel choices")
	for coord: Vector2i in choices:
		_expect(panel.get("node_buttons")[coord].get("route_state") == "reachable", "Existing map highlights each available destination")
	_expect(panel.get("run_state").get("current_room") == initial.get("current_room"), "Map remains centered on the current start room")
	await _capture("02_auto_map", {"current_room": str(initial["current_room"]), "choices": _coords(choices), "ui_scale": _scene.get("_settings").get("ui_scale")})

	var selected: Vector2i = choices[0]
	var target: Control = panel.get("node_buttons")[selected]
	await Suite.pointer(self, _canvas, target.get_global_rect().get_center())
	var deadline: int = Time.get_ticks_msec() + Suite.WAIT_TIMEOUT_MSEC
	while Time.get_ticks_msec() < deadline and not _scene.get("_board_presentation").has("door_opening"):
		await process_frame
	_expect(_scene.get("_animation_lock") and _scene.get("_board_presentation").has("door_opening"), "Map activation starts the existing physical-door travel animation")
	var travel: Dictionary = _scene.get("_board_presentation").get("door_opening", {}).duplicate(true)
	await _capture("03_travel_started", {"destination": str(selected), "door_animation": travel, "animation_lock": _scene.get("_animation_lock")})
	await Suite.wait_for_travel(self, _scene, Callable(self, "_expect"))

	await Suite.install(self, _scene, initial)
	await Suite.finish_narration(self, _scene, "escape")
	await Suite.key(self, _canvas, KEY_ESCAPE)
	await Suite.settle(self)
	var flow: RefCounted = _scene.get("_start_room_map")
	_expect(flow.get("_label").text == "Choose your path on the map [M]", "Closing map leaves exact authored hint")
	Suite.check_hint_layout(_scene, Callable(self, "_expect"))
	await _capture("04_close_hint", _hint_semantics())

	var router: Node = root.get_node("InputRouter")
	router.call("set_forced_state_for_test", "controller", "steam_deck")
	await Suite.install(self, _scene, initial)
	await Suite.finish_narration(self, _scene, "controller_back")
	choices = panel.call("available_destinations")
	var first: Vector2i = choices[0]
	for coord: Vector2i in choices:
		if float(Graph.room(initial, coord)["map_lane"]) < float(Graph.room(initial, first)["map_lane"]): first = coord
	_expect(_canvas.gui_get_focus_owner() == panel.get("node_buttons")[first], "Controller auto-open focuses the left-most available lane")
	await _capture("05_controller_focus", {"focused_room": str(first), "lane": Graph.room(initial, first)["map_lane"], "input": "steam_deck"})
	await Suite.joy(self, _canvas, JOY_BUTTON_B)
	await Suite.settle(self)
	_expect(flow.get("_hint").is_visible_in_tree() and flow.get("_glyph").is_visible_in_tree(), "Controller close shows the existing map-action glyph")
	Suite.check_hint_layout(_scene, Callable(self, "_expect"))
	await _capture("06_controller_hint", _hint_semantics())
	var report := FileAccess.open(OUTPUT_DIR.path_join("semantic-proof.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"captures": _captures, "failures": _failures}, "\t"))
	for failure: String in _failures: push_error(failure)
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	print("START ROOM MAP PROBE RESULT: PASS" if _failures.is_empty() else "START ROOM MAP PROBE RESULT: FAIL (%d failures)" % _failures.size())
	quit(0 if _failures.is_empty() else 1)

func _capture(name: String, semantics: Dictionary) -> void:
	await RenderingServer.frame_post_draw
	var path: String = OUTPUT_DIR.path_join(name + ".png")
	var frame: Image = _canvas.get_texture().get_image()
	_expect(frame.get_size() == VIEWPORT_SIZE, "Capture is exactly 1920x1080")
	_expect(frame.save_png(ProjectSettings.globalize_path(path)) == OK, "Capture writes " + name)
	_captures.append({"path": path, "semantics": semantics})
	print("START ROOM MAP CAPTURE: " + ProjectSettings.globalize_path(path))

func _expect(condition: bool, message: String) -> void:
	if not condition: _failures.append(message)

func _rect(control: Control) -> Array:
	var rect: Rect2 = control.get_global_rect()
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]

func _hint_semantics() -> Dictionary:
	var flow: RefCounted = _scene.get("_start_room_map")
	var hint: Control = flow.get("_hint")
	var label: Label = flow.get("_label")
	var row: Rect2 = flow.call("action_row_rect", _scene)
	return {"hint": label.text, "hint_visible": hint.is_visible_in_tree(), "hint_inside_viewport": _canvas.get_visible_rect().encloses(hint.get_global_rect()), "hint_rect": _rect(hint), "action_row_rect": [row.position.x, row.position.y, row.size.x, row.size.y], "font_size": label.get_theme_font_size("font_size"), "glyph_action": str(flow.get("_glyph").get("action_name")), "glyph_visible": flow.get("_glyph").visible, "doors": _scene.get("_exit_destinations_by_tile").size()}

func _coords(coords: Array[Vector2i]) -> Array[String]:
	var result: Array[String]
	for coord: Vector2i in coords: result.append(str(coord))
	return result
