extends SceneTree

const DrawObserver = preload("res://tests/helpers/board_projection_draw_observer.gd")
const NavigationTest = preload("res://tests/combat_board_navigation_test.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const InputRouter = preload("res://scripts/input_router.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const RunScene = preload("res://scenes/run_scene.tscn")
const Settings = preload("res://scripts/settings_store.gd")
const Store = preload("res://scripts/progression_store.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")

const VIEWPORT_SIZE := Vector2i(1920, 1080)
const RESIZED_WINDOW := Vector2i(1440, 1080)
const PROOF_SCALE: float = 1.0
const SETTINGS_TEST_SCALE: float = 1.15
const SEED: int = 18131
const GESTURE_ZOOM_FACTOR: float = 1.25
const GESTURE_PAN := Vector2(64, -34)
const EDGE_ZOOM_STEPS: Array = [1.35, 0.85]
const MAP_TRIGGER_STRENGTH: float = 0.8
const MAP_TRIGGER_HOLD_SECONDS: float = 0.24
const DRAW_TOLERANCE: float = 1.0
const SETTLE_FRAMES: int = 16
const CAPTURE_DIR: String = "user://probes/combat_board_projection"

var _viewport: Viewport
var _scene: Control
var _board: DrawObserver
var _errors: Array[String] = []
var _capture: bool = false

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	_capture = DisplayServer.get_name() != "headless"
	_viewport = root
	if _capture:
		var offscreen := SubViewport.new()
		offscreen.size = VIEWPORT_SIZE
		offscreen.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		offscreen.msaa_2d = root.msaa_2d
		root.add_child(offscreen)
		_viewport = offscreen
	else:
		root.content_scale_size = VIEWPORT_SIZE
		root.size = VIEWPORT_SIZE
	Store.set_storage_path("user://projection_progression.json")
	Store.set_run_storage_path("user://projection_run.save")
	Settings.set_storage_path("user://projection_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = PROOF_SCALE
	settings["reduced_motion"] = true
	settings["board_health_bars"] = Settings.BOARD_HEALTH_ALWAYS
	settings["music_volume"] = 0.0
	settings["sfx_volume"] = 0.0
	_expect(Settings.save_preferences(settings), "Save isolated settings")
	Store.clear_saved_run()
	await _exercise_run()
	if is_instance_valid(_scene): _scene.queue_free()
	await process_frame
	print("COMBAT BOARD PROJECTION TEST: %s" % ("PASS" if _errors.is_empty() else "FAIL (%d errors)" % _errors.size()))
	quit(0 if _errors.is_empty() else 1)

func _exercise_run() -> void:
	var engine := RunEngine.new()
	var progression: Dictionary = Tutorial.dismiss_tutorial(Store.default_data())
	# Legacy saves expose the real trigger-controlled map camera.
	var initial: Dictionary = engine.create_new_run(SEED, progression, false)
	var pre_battle: Dictionary = {}
	for coord: Vector2i in engine.available_moves(initial):
		var next: Dictionary = engine.move_to_pre_battle(initial, coord)
		if str(next.get("mode", "")) == RunEngine.MODE_PRE_BATTLE:
			pre_battle = next
			break
	_expect(not pre_battle.is_empty(), "Fixture has a reachable combat room")
	if pre_battle.is_empty(): return

	_expect(Store.save_run_state(pre_battle), "Install isolated pre-battle checkpoint")
	root.set_meta("labyrinth_resume_saved_run", true)
	_install_scene()
	await _settle()
	var scrim: Control = _scene.get("_pre_battle_scrim")
	_expect(is_instance_valid(scrim) and scrim.is_visible_in_tree(), "Production pre-battle dossier is open")
	if not is_instance_valid(scrim) or not scrim.is_visible_in_tree(): return
	var pre_battle_projection: Array = _projection()
	await _scene.call("_on_pre_battle_start_pressed")
	await _settle()
	_expect(str(_scene.get("_run_state").get("mode")) == "combat", "Begin enters real combat")
	_expect(_projection() != pre_battle_projection, "Begin changes the board projection")
	_check_draws("pre-battle to combat")
	await _save_capture("01_combat_default")

	await _pointer_navigation()
	await _controller_navigation()
	if not _capture: await _window_changes()
	await _resume_combat()

func _install_scene() -> void:
	_scene = RunScene.instantiate()
	var production_board: Control = _scene.get_node("BoardUnderlay/CombatBoard")
	production_board.set_script(DrawObserver)
	_board = production_board as DrawObserver
	_viewport.add_child(_scene)

func _pointer_navigation() -> void:
	var before: Array = _projection()
	_push_board_pointer(_wheel(MOUSE_BUTTON_WHEEL_UP))
	await process_frame
	_expect(float(_board.navigation_snapshot()["zoom"]) > float(before[0]), "Mouse wheel up reaches the board zoom handler")
	_check_draws("wheel zoom in")
	await _save_capture("02_combat_wheel_zoom")

	before = _projection()
	_push_board_pointer(_wheel(MOUSE_BUTTON_WHEEL_DOWN))
	await process_frame
	_expect(float(_board.navigation_snapshot()["zoom"]) < float(before[0]), "Mouse wheel down reaches the board zoom handler")
	_check_draws("wheel zoom out")

	before = _projection()
	var magnify := InputEventMagnifyGesture.new()
	magnify.factor = GESTURE_ZOOM_FACTOR
	_push_board_pointer(magnify)
	await process_frame
	_expect(_projection() != before, "Pinch changes the board projection")
	_check_draws("trackpad magnify")

	before = _projection()
	var pan := InputEventPanGesture.new()
	pan.delta = GESTURE_PAN
	_push_board_pointer(pan)
	await process_frame
	_expect(_projection() != before, "Trackpad pan changes the board projection")
	_check_draws("trackpad pan")

	var drag_start: Vector2 = _board.get_global_transform_with_canvas() * _board.navigation_snapshot()["content_rect"].get_center()
	var press := _wheel(MOUSE_BUTTON_MIDDLE)
	press.position = drag_start
	_viewport.push_input(press, true)
	before = _projection()
	var motion := InputEventMouseMotion.new()
	motion.position = drag_start + GESTURE_PAN
	motion.global_position = motion.position
	motion.relative = GESTURE_PAN
	motion.button_mask = MOUSE_BUTTON_MASK_MIDDLE
	_viewport.push_input(motion, true)
	await process_frame
	_expect(_projection() != before, "Mouse drag changes the board projection")
	_check_draws("mouse drag pan")
	var release := _wheel(MOUSE_BUTTON_MIDDLE)
	release.pressed = false
	_push_board_pointer(release)

	var edge_tile: Vector2i = _board._rendered_tiles_in_draw_order().back()
	for zoom: float in EDGE_ZOOM_STEPS:
		var focus: Vector2 = _board.world_position_for_tile(edge_tile)
		_board.set_navigation_zoom(zoom, focus)
		await process_frame
		var label: String = "edge anchor %.2f" % zoom
		NavigationTest.expect_zoom_axes(_board, focus, _board.world_position_for_tile(edge_tile), label, _expect)
		_check_draws(label)

	var reset := _wheel(MOUSE_BUTTON_MIDDLE)
	reset.double_click = true
	_push_board_pointer(reset)
	await process_frame
	_expect(is_equal_approx(_board.navigation_snapshot()["zoom"], _board._default_navigation_zoom_for_viewport()),
		"Middle double-click restores the pointer default")
	_check_draws("middle double-click reset")

func _controller_navigation() -> void:
	var before: Array = _projection()
	var router: Node = root.get_node("InputRouter")
	router.call("set_forced_state_for_test", InputRouter.MODALITY_CONTROLLER, InputRouter.FAMILY_XBOX)
	# Controller framing is part of the next stage submission; the combat
	# trigger itself has no zoom binding.
	_scene.call("_refresh_stage_view")
	await _settle()
	_expect(bool(_board.presentation.get("controller_combat_navigation", false)), "Controller activity uses the combat controller layout")
	_expect(_projection() != before, "Controller handoff changes the fitted combat projection")
	_check_draws("controller fitted board")
	before = _projection()
	for axis: JoyAxis in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]:
		_viewport.push_input(_axis(axis, MAP_TRIGGER_STRENGTH), true)
		_viewport.push_input(_axis(axis, 0.0), true)
	await _settle()
	_expect(is_equal_approx(_projection()[0], before[0]), "Combat trigger axes do not zoom the board")
	_check_draws("combat trigger axes")

	_scene.call("_open_large_map")
	await _settle()
	var map_panel: Control = _scene.get("_large_map_view")
	var map: Control = map_panel.get_node("LegacyMap")
	_expect(map.is_visible_in_tree(), "Legacy zoomable map is visible")
	var map_zoom: float = map.call("_camera_zoom_value")
	var board_zoom: float = _projection()[0]
	for axis: JoyAxis in [JOY_AXIS_TRIGGER_RIGHT, JOY_AXIS_TRIGGER_LEFT]:
		_viewport.push_input(_axis(axis, MAP_TRIGGER_STRENGTH), true)
		map.call("_process_controller_zoom", MAP_TRIGGER_HOLD_SECONDS)
		_viewport.push_input(_axis(axis, 0.0), true)
		var next_zoom: float = map.call("_camera_zoom_value")
		_expect(next_zoom > map_zoom if axis == JOY_AXIS_TRIGGER_RIGHT else next_zoom < map_zoom,
			"Legacy map trigger %s changes only the map zoom" % axis)
		map_zoom = next_zoom
	_scene.call("_close_large_map")
	await _settle()
	_expect(is_equal_approx(_projection()[0], board_zoom), "Legacy map zoom does not leak into the board zoom")
	_check_draws("map trigger axes then return to board")

	router.call("set_forced_state_for_test", InputRouter.MODALITY_POINTER, InputRouter.FAMILY_XBOX)
	_scene.call("_refresh_stage_view")
	await _settle()
	_expect(not bool(_board.presentation.get("controller_combat_navigation", false)) and _projection() != before,
		"Pointer handoff restores pointer framing")
	_check_draws("controller to pointer")

func _window_changes() -> void:
	var before: Array = _projection()
	root.size = RESIZED_WINDOW
	await _settle()
	_expect(_projection() != before, "Window resize reaches the run scene's board projection")
	_check_draws("window resize")
	before = _projection()
	root.size = VIEWPORT_SIZE
	await _settle()
	_expect(_projection() != before, "Restoring the window updates the board projection")
	_check_draws("window resize back")

	var panel: Control = _scene.get("_settings_panel")
	var option: OptionButton = panel.get("_controls")["ui_scale"]
	for scale: float in [SETTINGS_TEST_SCALE, PROOF_SCALE]:
		before = _projection()
		for index: int in range(option.item_count):
			if option.get_item_metadata(index) == scale:
				option.item_selected.emit(index)
				break
		await _settle()
		_expect(is_equal_approx(root.content_scale_factor, scale) and _projection() != before,
			"UI scale %.2f applies through the settings panel and changes board projection" % scale)
		_check_draws("UI scale %.2f" % scale)

func _resume_combat() -> void:
	var run_state: Dictionary = _scene.get("_run_state")
	_expect(Store.save_run_state(run_state), "Combat checkpoint saves through the production store")
	_scene.queue_free()
	await process_frame
	root.set_meta("labyrinth_resume_saved_run", true)
	_install_scene()
	await _settle()
	var resumed: Dictionary = _scene.get("_run_state")
	_expect(not root.has_meta("labyrinth_resume_saved_run") and str(resumed.get("mode")) == "combat"
		and resumed.get("current_room") == run_state.get("current_room"), "Fresh run scene resumes the saved combat room")
	_check_draws("resume saved combat")
	await _save_capture("03_combat_resumed")

func _check_draws(label: String) -> void:
	var failures_before: int = _errors.size()
	var team: RefCounted = _board._occlusion_silhouettes.team
	var hud: Control = _board._hud_render_layer
	var health: Dictionary = {}
	_collect_health(hud, health)
	var units: Array[Dictionary] = _board._visible_units()
	var enemies: int = 0
	for unit: Dictionary in units:
		var key: String = str(unit["key"])
		if str(unit["role"]) == "enemy": enemies += 1
		var body: DrawObserver = team.bodies.get(key)
		var rim: Sprite2D = team.entries.get(key, {}).get("sprite")
		var prefix: String = "%s %s" % [label, key]
		_expect(is_instance_valid(body) and is_instance_valid(rim), prefix + " has a retained body and team outline")
		if not is_instance_valid(body) or not is_instance_valid(rim): continue
		var rect := Rect2()
		for child: Node in body.get_children():
			if child is DrawObserver and child.is_visible_in_tree() and child.submitted_body.has_area():
				rect = child.submitted_body
		var outline := Rect2(rim.position - rim.texture.get_size() * rim.scale * 0.5, rim.texture.get_size() * rim.scale)
		var current_rect: Rect2 = _board._unit_texture_draw_rect(unit, _board._unit_center(unit))
		_expect(_overlaps_footprint(rect, unit), "%s body rect %s overlaps its footprint diamond" % [prefix, rect])
		_expect(_rects_match(rect, current_rect) and _rects_match(rect, outline),
			"%s submitted body %s matches current projection %s and outline %s" % [prefix, rect, current_rect, outline])
		var shadow: Rect2 = body.submitted_shadow
		_expect(_overlaps_footprint(shadow, unit), "%s contact shadow %s overlaps the footprint" % [prefix, shadow])
		var expected_shadow: Rect2 = _projected_contact_shadow(unit)
		_expect(_rects_match(shadow, expected_shadow),
			"%s contact shadow %s uses current projection %s" % [prefix, shadow, expected_shadow])
		var expected_health: Rect2 = _board._hud_health_rects_cache.get(key, Rect2())
		var submitted_health: Rect2 = health.get(key, Rect2())
		_expect(_rects_match(submitted_health, expected_health),
			"%s submitted HUD %s matches its projected layout %s" % [prefix, submitted_health, expected_health])
	_expect(enemies > 0 and team.bodies.has("player"), label + " includes the hero and at least one enemy")
	print("PROJECTION %s: %s (%d units)" % [label, "PASS" if _errors.size() == failures_before else "FAIL", units.size()])

func _collect_health(canvas: DrawObserver, health: Dictionary) -> void:
	if not canvas.is_visible_in_tree(): return
	health.merge(canvas.submitted_health, true)
	for child: Node in canvas.get_children():
		if child is DrawObserver: _collect_health(child, health)

func _projected_contact_shadow(unit: Dictionary) -> Rect2:
	var texture: Texture2D = _board._unit_hud_anchor_texture(unit) if _board._unit_uses_cutout(unit) else _board._texture_for_unit(unit)
	var rect: Rect2 = _board._unit_draw_rect_for_texture(unit, _board._unit_center(unit), texture)
	var bounds: Rect2 = _board._unit_shadow_bounds_for_texture(texture)
	var center: Vector2 = _board._unit_shadow_foot_point(texture, rect, bounds, str(unit["type"]))
	center.y += _board._tile_height() * DrawObserver.UNIT_SHADOW_FOOT_OFFSET_Y_RATIO
	var extent := Vector2(_board._tile_width() * 0.48, _board._tile_height() * 0.34)
	return Rect2(center - extent * 0.5, extent)

func _overlaps_footprint(rect: Rect2, unit: Dictionary) -> bool:
	if not rect.has_area(): return false
	var rectangle := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	for tile: Vector2i in _board._unit_footprint_tiles(unit):
		var diamond: PackedVector2Array = _board._tile_polygon(tile).slice(0, 4)
		if not Geometry2D.intersect_polygons(rectangle, diamond).is_empty(): return true
	return false

func _rects_match(a: Rect2, b: Rect2) -> bool:
	return a.has_area() and b.has_area() and a.position.distance_to(b.position) <= DRAW_TOLERANCE and a.size.distance_to(b.size) <= DRAW_TOLERANCE

func _projection() -> Array:
	var navigation: Dictionary = _board.navigation_snapshot()
	return [navigation["zoom"], navigation["content_rect"], _board.get_global_transform_with_canvas(), _viewport.get_stretch_transform()]

func _push_board_pointer(event: InputEvent) -> void:
	var point: Vector2 = _board.navigation_snapshot()["content_rect"].get_center()
	event.position = _board.get_global_transform_with_canvas() * point
	if event is InputEventMouse: event.global_position = event.position
	_viewport.push_input(event, true)

func _wheel(button: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	event.factor = 1.0
	return event

func _axis(axis: JoyAxis, strength: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = strength
	return event

func _settle() -> void:
	for frame: int in range(SETTLE_FRAMES): await process_frame

func _save_capture(label: String) -> void:
	if not _capture: return
	await RenderingServer.frame_post_draw
	var folder: String = ProjectSettings.globalize_path(CAPTURE_DIR)
	DirAccess.make_dir_recursive_absolute(folder)
	var path: String = folder.path_join(label + ".png")
	var image: Image = _viewport.get_texture().get_image()
	_expect(image.get_size() == VIEWPORT_SIZE and is_equal_approx(root.content_scale_factor, PROOF_SCALE),
		"Capture uses the native 1920x1080 render at 100% UI scale")
	_expect(image.save_png(path) == OK, "Save " + path)
	print(path)

func _expect(condition: bool, message: String) -> void:
	if condition: return
	_errors.append(message)
	print("PROJECTION FAIL: " + message)
