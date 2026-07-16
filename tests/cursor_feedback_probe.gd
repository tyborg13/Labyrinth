extends SceneTree

const CustomCursorGlyphScript = preload("res://scripts/custom_cursor_glyph.gd")
const CursorFeedbackScript = preload("res://scripts/cursor_feedback.gd")
const LabyrinthMapViewScript = preload("res://scripts/labyrinth_map_view.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")

const OUTPUT_DIR: String = "user://cursor_feedback_probe"
const PROOF_SIZES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1920, 1080)]
const STATE_LABELS: Array[String] = [
	"IDLE",
	"READY",
	"PRESS / HOLD",
	"DULL HOLD",
	"DRAG READY",
	"DRAG HELD",
	"LOADING",
	"UNAVAILABLE"
]

var _errors: Array[String] = []

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_clear_probe_output()
	_verify_contract()
	await _verify_native_cursor_suppression()
	for viewport_size: Vector2i in PROOF_SIZES:
		await _capture_gallery(viewport_size)
	await _capture_runtime_menu_states()
	await _capture_runtime_map_contexts()
	if _errors.is_empty():
		print("CURSOR FEEDBACK PROBE: PASS")
		print(ProjectSettings.globalize_path(OUTPUT_DIR))
		quit(0)
		return
	for error: String in _errors:
		push_error(error)
	print("CURSOR FEEDBACK PROBE: FAIL (%d errors)" % _errors.size())
	quit(1)

func _capture_gallery(viewport_size: Vector2i) -> void:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.msaa_2d = int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_2d", Viewport.MSAA_DISABLED))
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.disable_3d = true
	root.add_child(viewport)
	var gallery: Control = _build_gallery(viewport_size)
	viewport.add_child(gallery)
	for _frame: int in range(4):
		await process_frame
	var image: Image = viewport.get_texture().get_image()
	var file_name: String = "cursor_gallery_%dx%d.png" % [viewport_size.x, viewport_size.y]
	var output_path: String = ProjectSettings.globalize_path("%s/%s" % [OUTPUT_DIR, file_name])
	_expect(image != null and image.get_size() == viewport_size, "%s should capture at its exact proof size" % file_name)
	if image != null:
		_verify_gallery_pixels(image, gallery)
		_expect(image.save_png(output_path) == OK, "%s should save successfully" % file_name)
	viewport.queue_free()
	await process_frame

func _capture_runtime_menu_states() -> void:
	for proof_state: String in ["action", "pressed", "release"]:
		await _capture_runtime_menu_state(proof_state)

func _capture_runtime_menu_state(proof_state: String) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.msaa_2d = int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_2d", Viewport.MSAA_DISABLED))
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.disable_3d = true
	root.add_child(viewport)
	var packed: PackedScene = load("res://scenes/main_menu.tscn")
	_expect(packed != null, "Runtime cursor proof should load the production main menu")
	if packed == null:
		viewport.queue_free()
		return
	var menu: Control = packed.instantiate() as Control
	viewport.add_child(menu)
	var controller: CanvasLayer = CursorFeedbackScript.new()
	controller.name = "RuntimeCursorFeedback"
	viewport.add_child(controller)
	for _frame: int in range(4):
		await process_frame
	controller.set("_loading_until_msec", 0)
	var settings_button: Button = menu.get_node("MenuColumn/SettingsButton") as Button
	var pointer_position: Vector2 = settings_button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = pointer_position
	motion.global_position = pointer_position
	viewport.push_input(motion, true)
	await process_frame
	controller.call("_process", 0.0)
	var glyph: Control = controller.call("glyph_for_test") as Control
	_expect(glyph != null and str(glyph.get("cursor_state")) == "action", "Global controller should resolve a production menu button as a valid target")
	_expect(glyph != null and (glyph.position + CustomCursorGlyphScript.HOTSPOT).distance_to(pointer_position) <= 1.0, "Runtime cursor tip should land exactly on the production UI hotspot")
	if proof_state == "action":
		await _save_viewport_image(viewport, "cursor_runtime_action_1920x1080.png", Vector2i(200, 100))
	else:
		var press := InputEventMouseButton.new()
		press.position = pointer_position
		press.global_position = pointer_position
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = true
		viewport.push_input(press, true)
		for _frame: int in range(7):
			await process_frame
			if glyph != null:
				glyph.call("_process", 0.02)
		controller.call("_process", 0.0)
		_expect(glyph != null and str(glyph.get("cursor_state")) == "pressed_valid", "Global controller should resolve a production button press as valid feedback")
		var held_response: Dictionary = glyph.call("response_snapshot") if glyph != null else {}
		_expect(float(held_response.get("press_depth", 0.0)) > 0.90 and not bool(held_response.get("rebound_active", true)), "A production press should remain compressed for as long as the button is held")
		if proof_state == "pressed":
			glyph.set_process(false)
			await _save_viewport_image(viewport, "cursor_runtime_pressed_1920x1080.png", Vector2i(200, 100))
		else:
			var release := InputEventMouseButton.new()
			release.position = Vector2(viewport.size) - Vector2(80.0, 80.0)
			release.global_position = release.position
			release.button_index = MOUSE_BUTTON_LEFT
			release.pressed = false
			viewport.push_input(release, true)
			await process_frame
			await _move_runtime_pointer(viewport, controller, pointer_position)
			if glyph != null:
				glyph.call("_process", 0.035)
			var release_response: Dictionary = glyph.call("response_snapshot") if glyph != null else {}
			_expect(bool(release_response.get("rebound_active", false)), "Releasing a production click should start the cursor rebound")
			if glyph != null:
				glyph.set_process(false)
				glyph.call("set_pose_for_test", float(release_response.get("press_depth", 0.35)), 0.32)
			await _save_viewport_image(viewport, "cursor_runtime_release_1920x1080.png", Vector2i(200, 100))
		controller.call("_end_pointer_press")
	var music_player: AudioStreamPlayer = menu.get_node_or_null("MusicPlayer") as AudioStreamPlayer
	if music_player != null:
		music_player.stop()
		music_player.stream = null
	viewport.queue_free()
	await process_frame

func _capture_runtime_map_contexts() -> void:
	await _capture_runtime_map_context(true)
	await _capture_runtime_map_context(false)

func _capture_runtime_map_context(valid_target: bool) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.msaa_2d = int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_2d", Viewport.MSAA_DISABLED))
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.disable_3d = true
	root.add_child(viewport)

	var stage := Control.new()
	stage.size = Vector2(viewport.size)
	viewport.add_child(stage)
	var background := ColorRect.new()
	background.color = Color("100d11")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(background)
	var map_panel := PanelContainer.new()
	map_panel.position = Vector2(230.0, 110.0)
	map_panel.size = Vector2(1460.0, 860.0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("17110f")
	panel_style.border_color = Color("9d7a50")
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(12)
	map_panel.add_theme_stylebox_override("panel", panel_style)
	stage.add_child(map_panel)
	var map: Control = LabyrinthMapViewScript.new()
	map.name = "ProductionLargeMapProof"
	map.position = Vector2(20.0, 20.0)
	map.size = map_panel.size - Vector2(40.0, 40.0)
	map.set("interactive", true)
	map.set("show_legend", true)
	map.set("draw_background", false)
	map.call("set_run_state", _map_cursor_fixture())
	map_panel.add_child(map)

	var title := Label.new()
	title.text = "THE LABYRINTH ANSWERS ONLY ON OPEN PATHS"
	title.position = Vector2(0.0, 44.0)
	title.size = Vector2(viewport.size.x, 42.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_override("font", load("res://fonts/LabyrinthCrumble-Header.tres"))
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color("f2d394"))
	title.add_theme_color_override("font_outline_color", Color("120a09"))
	title.add_theme_constant_override("outline_size", 5)
	stage.add_child(title)

	var controller: CanvasLayer = CursorFeedbackScript.new()
	controller.name = "RuntimeMapCursorFeedback"
	viewport.add_child(controller)
	for _frame: int in range(5):
		await process_frame
	controller.set("_loading_until_msec", 0)
	var pointer_local: Vector2 = map.call("_coord_position", Vector2i(1, 0)) if valid_target else Vector2(12.0, 12.0)
	var pointer_global: Vector2 = map.get_global_transform_with_canvas() * pointer_local
	await _move_runtime_pointer(viewport, controller, pointer_global)
	var glyph: Control = controller.call("glyph_for_test") as Control
	if valid_target:
		_expect(glyph != null and str(glyph.get("cursor_state")) == "action", "Runtime controller should resolve a reachable production map room as valid")
		await _save_viewport_image(viewport, "cursor_runtime_map_valid_1920x1080.png")
	else:
		_expect(glyph != null and str(glyph.get("cursor_state")) == "idle", "Runtime controller should keep production map background click-inert")
		await _save_viewport_image(viewport, "cursor_runtime_map_inert_1920x1080.png")
	viewport.queue_free()
	await process_frame

func _move_runtime_pointer(viewport: SubViewport, controller: CanvasLayer, pointer_position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pointer_position
	motion.global_position = pointer_position
	viewport.push_input(motion, true)
	await process_frame
	controller.call("_process", 0.0)

func _map_cursor_fixture() -> Dictionary:
	return {
		"mode": "room",
		"current_room": Vector2i.ZERO,
		"rooms": {
			"0,0": {"coord": Vector2i.ZERO, "depth": 0, "type": "start", "revealed": true, "visited": true, "connections": [{"coord": Vector2i(1, 0)}, {"coord": Vector2i(0, 1)}]},
			"1,0": {"coord": Vector2i(1, 0), "depth": 1, "type": "combat", "element": "fire", "revealed": true, "connections": [{"coord": Vector2i.ZERO}, {"coord": Vector2i(2, 0)}]},
			"0,1": {"coord": Vector2i(0, 1), "depth": 1, "type": "treasure", "revealed": true, "sealed": true, "connections": [{"coord": Vector2i.ZERO}]},
			"2,0": {"coord": Vector2i(2, 0), "depth": 2, "type": "campfire", "revealed": true, "connections": [{"coord": Vector2i(1, 0)}]},
			"2,-1": {"coord": Vector2i(2, -1), "depth": 2, "type": "boss", "revealed": true, "connections": [{"coord": Vector2i(1, 0)}]}
		}
	}

func _save_viewport_image(viewport: SubViewport, file_name: String, expected_lit_point: Vector2i = Vector2i(-1, -1)) -> void:
	var image: Image = null
	var output_path: String = ProjectSettings.globalize_path("%s/%s" % [OUTPUT_DIR, file_name])
	var capture_complete := false
	for _attempt: int in range(6):
		_queue_canvas_redraw(viewport)
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		for _frame: int in range(6):
			await process_frame
		image = viewport.get_texture().get_image()
		if image == null:
			continue
		if expected_lit_point.x < 0:
			capture_complete = true
			break
		if image.save_png(output_path) != OK:
			continue
		var saved_image := Image.load_from_file(output_path)
		if saved_image != null and _image_has_point(saved_image, expected_lit_point) and saved_image.get_pixelv(expected_lit_point).get_luminance() > 0.035:
			image = saved_image
			capture_complete = true
			break
	_expect(image != null and image.get_size() == viewport.size, "%s should capture at the exact production viewport size" % file_name)
	if image != null and expected_lit_point.x >= 0:
		_expect(capture_complete, "%s should retain the complete production scene rather than a partial Metal frame" % file_name)
	if image != null and expected_lit_point.x < 0:
		_expect(image.save_png(output_path) == OK, "%s should save successfully" % file_name)

func _queue_canvas_redraw(node: Node) -> void:
	if node is CanvasItem:
		(node as CanvasItem).queue_redraw()
	for child: Node in node.get_children():
		_queue_canvas_redraw(child)

func _image_has_point(image: Image, point: Vector2i) -> bool:
	return point.x >= 0 and point.y >= 0 and point.x < image.get_width() and point.y < image.get_height()

func _build_gallery(viewport_size: Vector2i) -> Control:
	var root_control := Control.new()
	root_control.size = Vector2(viewport_size)
	var background := ColorRect.new()
	background.color = Color("100d11")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(background)

	var title := Label.new()
	title.text = "FORGED WAYFINDER"
	title.position = Vector2(0.0, 48.0 if viewport_size.y <= 720 else 150.0)
	title.size = Vector2(viewport_size.x, 42.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", load("res://fonts/LabyrinthCrumble-Header.tres"))
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("f2d394"))
	title.add_theme_color_override("font_outline_color", Color("120a09"))
	title.add_theme_constant_override("outline_size", 5)
	root_control.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "ONE FORGED POINTER — MATERIAL, MOTION, AND PRESSURE"
	subtitle.position = title.position + Vector2(0.0, 40.0)
	subtitle.size = Vector2(viewport_size.x, 28.0)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_override("font", load("res://fonts/LabyrinthCrumble-Regular.tres"))
	subtitle.add_theme_font_size_override("font_size", 15)
	subtitle.add_theme_color_override("font_color", Color("a99980"))
	root_control.add_child(subtitle)

	var panel_size := Vector2(172.0, 164.0)
	var gap := Vector2(18.0, 18.0)
	var grid_size := Vector2(panel_size.x * 4.0 + gap.x * 3.0, panel_size.y * 2.0 + gap.y)
	var grid_origin := Vector2((float(viewport_size.x) - grid_size.x) * 0.5, subtitle.position.y + 62.0)
	root_control.set_meta("grid_origin", grid_origin)
	root_control.set_meta("panel_size", panel_size)
	root_control.set_meta("gap", gap)
	var states: PackedStringArray = CustomCursorGlyphScript.state_names()
	for index: int in range(states.size()):
		var panel := Panel.new()
		panel.position = grid_origin + Vector2(float(index % 4) * (panel_size.x + gap.x), float(index / 4) * (panel_size.y + gap.y))
		panel.size = panel_size
		var panel_style := StyleBoxFlat.new()
		panel_style.bg_color = Color("211a1c") if index % 2 == 0 else Color("271e1b")
		panel_style.border_color = Color("6f5433")
		panel_style.border_width_left = 1
		panel_style.border_width_top = 1
		panel_style.border_width_right = 1
		panel_style.border_width_bottom = 2
		panel_style.corner_radius_top_left = 5
		panel_style.corner_radius_top_right = 5
		panel_style.corner_radius_bottom_left = 5
		panel_style.corner_radius_bottom_right = 5
		panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.38)
		panel_style.shadow_size = 7
		panel.add_theme_stylebox_override("panel", panel_style)
		root_control.add_child(panel)

		var glyph: Control = CustomCursorGlyphScript.new()
		glyph.name = "StateGlyph%d" % index
		glyph.position = Vector2(56.0, 34.0)
		glyph.set_cursor_state(states[index])
		if states[index] in ["pressed_valid", "pressed_invalid"]:
			glyph.call("set_pose_for_test", 1.0)
		elif states[index] == "dragging":
			glyph.call("set_pose_for_test", 0.92, 1.0, Vector2(1.0, 0.25), 0.88)
		glyph.set_animation_phase(0.17 if states[index] == "dragging" else 0.31)
		glyph.set_process(false)
		panel.add_child(glyph)

		var label := Label.new()
		label.text = STATE_LABELS[index]
		label.position = Vector2(8.0, 115.0)
		label.size = Vector2(panel_size.x - 16.0, 30.0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_override("font", load("res://fonts/LabyrinthCrumble-Regular.tres"))
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", Color("ddc7a2"))
		panel.add_child(label)
	return root_control

func _verify_contract() -> void:
	var contract: Dictionary = CustomCursorGlyphScript.visual_contract()
	_expect((contract.get("states", PackedStringArray()) as PackedStringArray).size() == STATE_LABELS.size(), "Probe should cover every cursor state")
	_expect((contract.get("layers", []) as Array).size() >= 6, "Cursor proof should exercise the full layered-art contract")
	_expect(bool(contract.get("single_silhouette", false)) and not bool(contract.get("context_glyphs", true)), "Cursor proof should use one coherent silhouette without a context-glyph language")
	_expect(not bool(contract.get("center_stripe", true)), "Cursor proof should use joined forged facets instead of a bright stripe down the blade")
	_expect(not bool(contract.get("press_tip_glint", true)), "Pressed cursor proof should not add a detached white tip glint")
	_expect(bool(contract.get("press_holds", false)) and bool(contract.get("release_rebounds", false)), "Cursor proof should cover held compression and release rebound")
	_expect(bool(contract.get("loading_spins", false)) and str(contract.get("loading_integration", "")) == "heel_bearing", "Cursor proof should include the integrated spinning heel bearing")
	_expect(str(contract.get("pommel_detail", "")) == "faceted_socket_and_bearing", "Cursor proof should include the detailed pommel socket and inset bearing")
	_expect(int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_2d", 0)) >= Viewport.MSAA_4X, "Cursor edges should use the same project-wide 4x MSAA standard as the movement arrows")

func _verify_native_cursor_suppression() -> void:
	var controller: CanvasLayer = root.get_node_or_null("CursorFeedback") as CanvasLayer
	var owns_controller: bool = controller == null
	if owns_controller:
		controller = CursorFeedbackScript.new()
		controller.name = "CursorFeedbackProof"
		root.add_child(controller)
	await process_frame
	controller.call("_process", 0.0)
	_expect(Input.get_mouse_mode() == Input.MOUSE_MODE_HIDDEN, "GPU runtime should hide every native system cursor while the forged cursor is active")
	var suppression: Dictionary = controller.call("native_suppression_snapshot_for_test")
	var installed_shapes: PackedInt32Array = suppression.get("installed_shapes", PackedInt32Array())
	var expected_shapes: PackedInt32Array = suppression.get("expected_shapes", PackedInt32Array())
	_expect(installed_shapes == expected_shapes and installed_shapes.size() == 17, "GPU runtime should install a transparent fallback for every Godot native cursor shape")
	_expect(float(suppression.get("transparent_alpha_max", 1.0)) <= 0.0, "Native cursor fallback texture should be fully transparent")
	for shape: int in expected_shapes:
		Input.call("set_default_cursor_shape", shape)
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		controller.call("_process", CursorFeedbackScript.NATIVE_CURSOR_REFRESH_SECONDS)
		_expect(Input.get_mouse_mode() == Input.MOUSE_MODE_HIDDEN, "Cursor suppression should recover after native shape %d and visible-mode resets" % shape)
	Input.call("set_default_cursor_shape", Control.CURSOR_ARROW)
	var glyph: Control = controller.call("glyph_for_test") as Control
	_expect(glyph != null and glyph.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Global cursor glyph should render above UI without stealing target input")
	if owns_controller:
		controller.queue_free()
		await process_frame

func _verify_gallery_pixels(image: Image, gallery: Control) -> void:
	var grid_origin: Vector2 = gallery.get_meta("grid_origin", Vector2.ZERO)
	var panel_size: Vector2 = gallery.get_meta("panel_size", Vector2.ZERO)
	var gap: Vector2 = gallery.get_meta("gap", Vector2.ZERO)
	var unique_hashes: Dictionary = {}
	for index: int in range(STATE_LABELS.size()):
		var panel_origin: Vector2 = grid_origin + Vector2(float(index % 4) * (panel_size.x + gap.x), float(index / 4) * (panel_size.y + gap.y))
		var glyph_rect := Rect2i(Vector2i(panel_origin + Vector2(48.0, 26.0)), Vector2i(78, 78))
		var region: Image = image.get_region(glyph_rect)
		unique_hashes[hash(region.get_data())] = true
		var metrics: Dictionary = _region_metrics(region)
		_expect(float(metrics.get("luma_range", 0.0)) >= 0.48, "%s cursor should retain a crisp dark-to-light forged-metal range" % STATE_LABELS[index])
		_expect(int(metrics.get("warm_pixels", 0)) >= 8, "%s cursor should retain visible brass or ember inlay" % STATE_LABELS[index])
	_expect(unique_hashes.size() >= 6, "Material and motion reactions should remain legible while sharing one coherent silhouette")

func _region_metrics(image: Image) -> Dictionary:
	var minimum_luma: float = 1.0
	var maximum_luma: float = 0.0
	var warm_pixels: int = 0
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			var color: Color = image.get_pixel(x, y)
			var luma: float = color.get_luminance()
			minimum_luma = minf(minimum_luma, luma)
			maximum_luma = maxf(maximum_luma, luma)
			if color.r > color.b * 1.35 and color.r > 0.42 and color.g > 0.24:
				warm_pixels += 1
	return {"luma_range": maximum_luma - minimum_luma, "warm_pixels": warm_pixels}

func _clear_probe_output() -> void:
	var output_path: String = ProjectSettings.globalize_path(OUTPUT_DIR)
	var dir := DirAccess.open(output_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while not entry.is_empty():
		if not dir.current_is_dir():
			dir.remove(entry)
		entry = dir.get_next()
	dir.list_dir_end()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
