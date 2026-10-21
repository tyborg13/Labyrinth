extends SceneTree

const Fixture = preload("res://tests/helpers/special_map_proof_fixture.gd")
const MapPanelScript = preload("res://scripts/section_map_panel.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const Specials = preload("res://scripts/special_encounter_library.gd")
const Settings = preload("res://scripts/settings_store.gd")
const CaptureViewport = preload("res://tests/gust_shrike_capture_viewport.gd")
const OUTPUT: String = "user://spx-02-map-proof"
# Headless-only fixture reproduces a constrained desktop window without
# changing the director's capture viewport or its 100% UI scale.
const CONSTRAINED_WINDOW_TEST_SIZE: Vector2i = Vector2i(1280, 720)
var panel: Control
var _viewport: SubViewport
var _logic_only: bool = false
var failed: bool = false

func _initialize() -> void:
	if Fixture.write_contract() != OK:
		quit(1)
		return
	if OS.get_cmdline_user_args().has("--proof-contract-only"):
		quit()
		return
	_logic_only = OS.get_cmdline_user_args().has("--logic-only")
	_run.call_deferred()

func _run() -> void:
	Settings.set_storage_path("user://spx-proof-settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	Settings.save_settings(settings)
	if not _logic_only:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Fixture.PROOF_SIZE)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Fixture.PROOF_SIZE
	root.size = Fixture.PROOF_SIZE
	if _logic_only: root.size = CONSTRAINED_WINDOW_TEST_SIZE
	_viewport = CaptureViewport.create(root)
	_viewport.notify_mouse_entered()
	print("SPX capture geometry: viewport=%s root=%s UI scale=%s" % [_viewport.size, root.size, settings["ui_scale"]])
	panel = MapPanelScript.new()
	panel.position = Fixture.PANEL_POSITION
	panel.size = Fixture.PANEL_SIZE
	_viewport.add_child(panel)
	var original: Dictionary = Fixture.new_state()
	var target: Vector2i = Fixture.special_coord(original)
	panel.set_run_state(original)
	await _capture("01_future.png")
	_check(panel.node_buttons[target].route_state == "ahead", "Special future state uses ordinary medallion state")
	var available: Dictionary = Fixture.available_state(original, target)
	panel.set_run_state(available)
	await _capture("02_available.png")
	_check(panel.node_buttons[target].actionable and panel.node_buttons[target].route_state == "reachable", "Available special retains normal input and availability treatment")
	_move_pointer(panel.node_buttons[target].get_global_rect().get_center())
	await _capture("03_hover.png")
	_check(_viewport.gui_get_hovered_control() == panel.node_buttons[target] and panel.node_buttons[target].is_hovered(), "Pointer motion reaches the actual Warband button")
	var room: Dictionary = Graph.room(available, target)
	var expected: String = Specials.display_name(room) + "\n" + Specials.tooltip_line(room) + "\nNot yet visited"
	_check(panel._preview_text == expected and is_instance_valid(panel._preview) and panel._preview.is_visible_in_tree(), "Pointer hover exposes approved title, rules line and state line")
	if is_instance_valid(panel._preview):
		var labels: Node = panel._preview.get_child(0)
		_check(labels.get_child(0).text == Specials.display_name(room).to_upper() and labels.get_child(1).text == Specials.tooltip_line(room) + "\nNot yet visited", "Visible tooltip labels contain the approved title, rules and state")
		_check(Rect2(Vector2.ZERO, Vector2(Fixture.PROOF_SIZE)).encloses(panel._preview.get_global_rect()), "Hovered tooltip fits inside the capture viewport")
	print("SPX pointer hover: " + panel._preview_text.replace("\n", " | "))
	_move_pointer(Vector2.ZERO)
	await process_frame
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
	if not _logic_only: print("SPX map captures: " + ProjectSettings.globalize_path(OUTPUT))
	print("SPX special %s probe: %s" % ["headless input" if _logic_only else "visual", "FAIL" if failed else "PASS"])
	quit(1 if failed else 0)

func _move_pointer(point: Vector2) -> void:
	# Forward viewport-local pointer input through Godot's GUI hit testing,
	# independent of the desktop window's Retina scale or constrained size.
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	_viewport.push_input(motion, true)

func _capture(filename: String) -> void:
	await process_frame
	await process_frame
	await process_frame
	_check(_viewport.size == Fixture.PROOF_SIZE, "Capture viewport remains fixed at 1920x1080: " + filename)
	if _logic_only: return
	await RenderingServer.frame_post_draw
	var captured: Image = _viewport.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	_check(captured.get_size() == Fixture.PROOF_SIZE, "Capture measures 1920x1080: " + filename)
	_check(captured.save_png(OUTPUT.path_join(filename)) == OK, "Capture writes: " + filename)

func _check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
