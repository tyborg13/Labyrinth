extends SceneTree
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const RunEngineScript = preload("res://scripts/run_engine.gd")
const Progression = preload("res://scripts/progression_store.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const MapPanelScript = preload("res://scripts/section_map_panel.gd")
const Settings = preload("res://scripts/settings_store.gd")
const OUTPUT: String = "user://section_map_probe_v3"
var proof_viewport: SubViewport
var panel: Control
var failed: bool = false

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	Settings.set_storage_path("user://section_map_panel_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["reduced_motion"] = false
	Settings.save_settings(settings)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)
	root.size = Vector2i(1920, 1080)
	proof_viewport = SubViewport.new()
	proof_viewport.size = Vector2i(1920, 1080)
	proof_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(proof_viewport)
	var background := ColorRect.new()
	background.color = Color("171218")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	proof_viewport.add_child(background)
	panel = MapPanelScript.new()
	panel.position = Vector2(28, 28)
	panel.size = Vector2(1864, 1024)
	proof_viewport.add_child(panel)
	var engine := RunEngineScript.new()
	var state: Dictionary = engine.create_new_run(90429, Progression.default_data())
	panel.call("set_run_state", state)
	await _capture("01_entry.png")
	# Fixture setup preserves the generated graph and advances only the visited
	# route. Gameplay transitions and persistence are covered by the logic suite.
	for step: int in range(3):
		var current: Dictionary = Graph.room(state, state.get("current_room", Vector2i.ZERO))
		current["cleared"] = true
		current["sealed"] = true
		var dest: Vector2i = (current.get("connections", []) as Array)[0].get("coord", Graph.INVALID)
		state["current_room"] = dest
		Graph.room(state, dest)["visited"] = true
		Graph.room(state, dest)["cleared"] = true
		Graph.refresh_knowledge(state)
	panel.call("set_run_state", state)
	await _capture("02_three_rooms.png")
	var available: Array = panel.call("available_destinations")
	var pulsing: Control = (panel.get("node_buttons") as Dictionary)[available[0]]
	var phase_before: float = float(pulsing.get("pulse_phase"))
	await create_timer(0.35).timeout
	_check(float(pulsing.get("pulse_phase")) != phase_before and pulsing.is_processing(), "Available rooms pulse with normal motion")
	await _capture("02b_available_pulse.png")
	settings["reduced_motion"] = true
	Settings.save_settings(settings)
	panel.call("center_on_current")
	await _capture("02c_reduced_motion.png")
	for button: Control in (panel.get("node_buttons") as Dictionary).values():
		_check(button.get_child_count() == 0, "Room icons have no attached text labels")
		if str(button.get("route_state")) == "reachable":
			_check(not button.is_processing() and float(button.call("pulse_scale")) == 1.0, "Reduced motion freezes availability without losing its static seal")
		if str((button.get("room_data") as Dictionary).get("type", "")) == "boss":
			_check(float(button.call("visual_radius")) >= 2.7 * 29.0, "Boss icon is substantially larger than future rooms")
	_check(panel.find_child("EnterRoomButton", true, false) == null, "Map has no select-then-confirm travel button")
	var choice: Vector2i = (panel.call("available_destinations") as Array)[0]
	panel.call("select_room", choice)
	panel.call("focus_controller_on_current")
	await _capture("03_focus.png")
	state = Graph.scout(state, choice)
	panel.call("set_run_state", state)
	await _capture("04_scouted.png")
	Graph.section(state, 0)["scouts"] = 0
	panel.call("set_run_state", state)
	await _capture("04b_scout_exhausted.png")
	if not (panel.get("_scout") as Button).disabled:
		failed = true
		push_error("Exhausted Scouts must remain disabled")
	for node: Dictionary in (state.get("rooms", {}) as Dictionary).values():
		var coord: Vector2i = node.get("coord", Graph.INVALID)
		var button: Control = (panel.get("node_buttons") as Dictionary).get(coord)
		if button != null and str(button.get("route_state")) == "bypassed":
			panel.call("select_room", coord)
			await _capture("04c_bypassed_inspection.png")
			_check(not bool(panel.call("can_activate_room", coord)), "Inspecting a route not taken must never enable travel")
			break
	for index: int in range(6):
		var info: Dictionary = Graph.section(state, index)
		state["current_room"] = info.get("entry", Vector2i.ZERO)
		Graph.room(state, state["current_room"])["visited"] = true
		Graph.refresh_knowledge(state)
		panel.call("set_run_state", state)
		await _capture("domain_%d.png" % index)
	panel.call("select_section", 0)
	await _capture("05_history.png")
	print(ProjectSettings.globalize_path(OUTPUT))
	quit(1 if failed else 0)

func _capture(filename: String) -> void:
	await process_frame
	await process_frame
	RenderingServer.force_draw()
	await process_frame
	var image: Image = proof_viewport.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	if image.get_size() != Vector2i(1920, 1080) or image.save_png(OUTPUT.path_join(filename)) != OK:
		failed = true
		push_error("Capture failed: " + filename)

func _check(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error(message)
