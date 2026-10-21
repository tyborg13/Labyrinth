extends SceneTree

# map-03 native proof: the revision-7 scrolling section map at 1920x1080, 100% UI scale.
const MapPanelScript = preload("res://scripts/section_map_panel.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const Settings = preload("res://scripts/settings_store.gd")
const CaptureViewport = preload("res://tests/gust_shrike_capture_viewport.gd")
const PROOF_SIZE: Vector2i = Vector2i(1920, 1080)
const PANEL_POSITION: Vector2 = Vector2(28, 28)
const PANEL_SIZE: Vector2 = Vector2(1864, 1024)
const FIXTURE_SEED: int = 83
const SECTION: int = 1
const MID_RUN_STEPS: int = 4
const WALK_FRAMES: int = 37 # 0.62 s at 60 fps
const SCROLL_FRAMES: int = 96 # 1.6 s at 60 fps
const OUTPUT: String = "user://map-03-proof"
var panel: Control
var _viewport: SubViewport
var _logic_only: bool = false
var failed: bool = false

func _initialize() -> void:
	_logic_only = OS.get_cmdline_user_args().has("--logic-only")
	_run.call_deferred()

func _run() -> void:
	Settings.set_storage_path("user://map-03-proof-settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	Settings.save_settings(settings)
	if not _logic_only:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(PROOF_SIZE)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = PROOF_SIZE
	root.size = PROOF_SIZE
	_viewport = CaptureViewport.create(root)
	_viewport.notify_mouse_entered()
	panel = MapPanelScript.new()
	panel.position = PANEL_POSITION
	panel.size = PANEL_SIZE
	_viewport.add_child(panel)
	var state: Dictionary = {"seed": FIXTURE_SEED, "current_room": Vector2i.ZERO, "mode": "room"}
	Graph.initialize(state)
	_check(int(state["section_map_layout_revision"]) == 7, "New runs use layout revision 7")
	var info: Dictionary = Graph.section(state, SECTION)
	state["current_room"] = info["entry"]
	Graph.room(state, info["entry"])["visited"] = true
	Graph.refresh_knowledge(state)
	panel.set_run_state(state)
	await _capture("01_section_start.png")
	_check(panel.scroll_limit() > 0.0 and is_zero_approx(panel.scroll_offset()), "A new section opens scrolled to its threshold")
	var mid: Dictionary = state.duplicate(true)
	var cell: Vector2i = info["entry"]
	for step: int in range(MID_RUN_STEPS):
		var links: Array = Graph.room(mid, cell)["connections"]
		cell = links[(step + 1) % links.size()]["coord"]
		Graph.room(mid, cell)["visited"] = true
		Graph.room(mid, cell)["cleared"] = true
	mid["current_room"] = cell
	Graph.refresh_knowledge(mid)
	panel.set_run_state(mid)
	await _capture("02_mid_run.png")
	var current_button: Control = panel.node_buttons[cell]
	var current_x: float = current_button.position.x + current_button.size.x * 0.5 - panel.scroll_offset()
	_check(current_x > 300.0 and current_x < 1100.0, "Mid-run the map scrolls to the player's room (screen x %.0f)" % current_x)
	var choices: Array[Vector2i] = panel.available_destinations()
	_check(choices.size() >= 1, "The current room offers onward rooms")
	if not choices.is_empty():
		var target: Vector2i = choices[0]
		_move_pointer(panel.node_buttons[target].get_global_rect().get_center())
		await _capture("03_choice_hover.png")
		_move_pointer(Vector2.ZERO)
		# Real time: the walk tween advances the lantern along the trail.
		panel.activate_room(target)
		await create_timer(0.3).timeout
		var progress: float = float(panel._canvas.get("travel_progress"))
		_check(progress > 0.15 and progress < 0.85, "The lantern walk animates in real time (progress %.2f at 0.3 s)" % progress)
		panel.call("_cancel_activation")
		panel.set_run_state(mid)
		await process_frame
		# Frames for the clip: the same walk stepped at 60 fps, independent of capture speed.
		(panel.node_buttons[cell] as Control).set("lantern_marker", false)
		(panel.node_buttons[cell] as Control).queue_redraw()
		panel._canvas.set("travel_from", cell)
		panel._canvas.set("travel_to", target)
		for frame: int in range(WALK_FRAMES):
			panel.call("_set_travel_progress", float(frame + 1) / float(WALK_FRAMES))
			await _capture("walk/frame_%03d.png" % frame, false)
		panel.call("_set_travel_progress", 0.0)
		panel.set_run_state(mid)
	panel.scroll_to(panel.scroll_limit())
	await _capture("05_scrolled_end.png")
	_check(is_equal_approx(panel.scroll_offset(), panel.scroll_limit()), "The map scrolls to its boss end")
	var fog: Dictionary = state.duplicate(true)
	fog["current_room"] = Graph.section(fog, 5)["entry"]
	Graph.room(fog, fog["current_room"])["visited"] = true
	Graph.refresh_knowledge(fog)
	panel.set_run_state(fog)
	await _capture("06_section_vi_fog.png")
	_check(panel._fog.visible, "Section VI keeps its fog on a scrolling map")
	# A stepped scroll from the threshold to the boss, for the review clip.
	panel.set_run_state(state)
	await process_frame
	for frame: int in range(SCROLL_FRAMES):
		var t: float = float(frame) / float(SCROLL_FRAMES - 1)
		panel.scroll_to(panel.scroll_limit() * (0.5 - 0.5 * cos(PI * t)))
		await _capture("scroll/frame_%03d.png" % frame, false)
	if not _logic_only: print("MAP-03 captures: " + ProjectSettings.globalize_path(OUTPUT))
	print("MAP-03 probe: %s" % ("FAIL" if failed else "PASS"))
	quit(1 if failed else 0)

func _move_pointer(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	_viewport.push_input(motion, true)

func _capture(filename: String, settle: bool = true) -> void:
	await process_frame
	if settle:
		await process_frame
		await process_frame
	if _logic_only: return
	await RenderingServer.frame_post_draw
	var captured: Image = _viewport.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT.path_join(filename).get_base_dir()))
	_check(captured.get_size() == PROOF_SIZE, "Capture measures 1920x1080: " + filename)
	_check(captured.save_png(OUTPUT.path_join(filename)) == OK, "Capture writes: " + filename)

func _check(ok: bool, message: String) -> void:
	if ok: return
	failed = true
	push_error("MAP-03 probe: " + message)
