extends SceneTree

const Fixture = preload("res://tests/helpers/special_map_proof_fixture.gd")
const MapPanelScript = preload("res://scripts/section_map_panel.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const Specials = preload("res://scripts/special_encounter_library.gd")
const Settings = preload("res://scripts/settings_store.gd")
const OUTPUT: String = "user://spx-02-map-proof"
var panel: Control
var failed: bool = false

func _initialize() -> void:
	if Fixture.write_contract() != OK:
		quit(1)
		return
	if OS.get_cmdline_user_args().has("--proof-contract-only"):
		quit()
		return
	_run.call_deferred()

func _run() -> void:
	Settings.set_storage_path("user://spx-proof-settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	Settings.save_settings(settings)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Fixture.PROOF_SIZE)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Fixture.PROOF_SIZE
	root.size = Fixture.PROOF_SIZE
	panel = MapPanelScript.new()
	panel.position = Fixture.PANEL_POSITION
	panel.size = Fixture.PANEL_SIZE
	root.add_child(panel)
	var original: Dictionary = Fixture.new_state()
	var target: Vector2i = Fixture.special_coord(original)
	panel.set_run_state(original)
	await _capture("01_future.png")
	_check(panel.node_buttons[target].route_state == "ahead", "Special future state uses ordinary medallion state")
	var available: Dictionary = Fixture.available_state(original, target)
	panel.set_run_state(available)
	await _capture("02_available.png")
	_check(panel.node_buttons[target].actionable and panel.node_buttons[target].route_state == "reachable", "Available special retains normal input and availability treatment")
	Input.warp_mouse(panel.node_buttons[target].get_global_rect().get_center())
	var motion := InputEventMouseMotion.new()
	motion.position = panel.node_buttons[target].get_global_rect().get_center()
	motion.global_position = motion.position
	Input.parse_input_event(motion)
	await _capture("03_hover.png")
	_check(panel._preview_text.begins_with(Specials.display_name(Graph.room(available, target)) + "\n" + Specials.tooltip_line(Graph.room(available, target)) + "\n"), "Pointer hover exposes approved title and rules line")
	Input.warp_mouse(Vector2.ZERO)
	panel.node_buttons[target].grab_focus()
	await _capture("04_focus.png")
	_check(panel.node_buttons[target].has_focus() and panel._preview_text == panel.room_description(target), "Native focus exposes the same tooltip")
	var visited: Dictionary = available.duplicate(true)
	Graph.room(visited, target)["visited"] = true
	Graph.room(visited, target)["cleared"] = true
	visited["current_room"] = Graph.room(visited, target)["connections"][0]["coord"]
	Graph.refresh_knowledge(visited)
	panel.set_run_state(visited)
	await _capture("05_visited.png")
	_check(panel.node_buttons[target].route_state == "visited", "Visited special retains its completion seal")
	panel.set_run_state(Fixture.bypassed_state(original, target))
	await _capture("06_bypassed.png")
	_check(panel.node_buttons[target].route_state == "bypassed" and not panel.can_activate_room(target), "Bypassed special remains inspectable without travel")
	var fullest: Dictionary = Fixture.fullest_state()
	panel.set_run_state(fullest)
	await _capture("07_fullest_legend.png")
	_check(panel._legend_types.size() == 10, "Fullest legal enabled section displays ten legend entries")
	_check(panel._legend.get_global_rect().end.x <= panel._scout.get_global_rect().position.x, "Full legend fits beside Scout")
	for item: Control in panel._legend.get_children():
		_check(item.get_rect().position.x >= 0 and item.get_rect().end.x <= panel._legend.size.x + 0.01, "Full legend has no clipped entries")
	var fog: Dictionary = original.duplicate(true)
	fog["current_room"] = Graph.section(fog, 5)["entry"]
	Graph.refresh_knowledge(fog)
	var landmark: Vector2i = Fixture.special_coord(fog, 5)
	panel.set_run_state(fog)
	await _capture("08_section_vi_fog.png")
	_check(panel._fog.visible and panel.node_buttons.has(landmark) and Graph.room(fog, landmark)["revealed"], "Section VI fog preserves the special landmark")
	print("SPX map captures: " + ProjectSettings.globalize_path(OUTPUT))
	print("SPX special visual probe: " + ("FAIL" if failed else "PASS"))
	quit(1 if failed else 0)

func _capture(filename: String) -> void:
	await process_frame
	await process_frame
	await process_frame
	RenderingServer.force_draw()
	await process_frame
	var captured: Image = root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	_check(captured.get_size() == Fixture.PROOF_SIZE and captured.save_png(OUTPUT.path_join(filename)) == OK, "Capture writes at 1920x1080: " + filename)

func _check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
