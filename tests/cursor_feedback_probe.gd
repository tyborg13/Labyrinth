extends SceneTree

const CustomCursorGlyphScript = preload("res://scripts/custom_cursor_glyph.gd")
const CursorFeedbackScript = preload("res://scripts/cursor_feedback.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")

const OUTPUT_DIR: String = "user://cursor_feedback_probe"
const PROOF_SIZES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1920, 1080)]
const STATE_LABELS: Array[String] = [
	"IDLE",
	"VALID TARGET",
	"VALID PRESS",
	"DULL PRESS",
	"DRAG READY",
	"DRAGGING",
	"LOADING",
	"INVALID"
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
	await _save_viewport_image(viewport, "cursor_runtime_action_1920x1080.png")

	var press := InputEventMouseButton.new()
	press.position = pointer_position
	press.global_position = pointer_position
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	viewport.push_input(press, true)
	await process_frame
	controller.call("_process", 0.0)
	_expect(glyph != null and str(glyph.get("cursor_state")) == "pressed_valid", "Global controller should resolve a production button press as valid feedback")
	await _save_viewport_image(viewport, "cursor_runtime_pressed_1920x1080.png")
	controller.call("_end_pointer_press")
	var music_player: AudioStreamPlayer = menu.get_node_or_null("MusicPlayer") as AudioStreamPlayer
	if music_player != null:
		music_player.stop()
		music_player.stream = null
	viewport.queue_free()
	await process_frame

func _save_viewport_image(viewport: SubViewport, file_name: String) -> void:
	for _frame: int in range(2):
		await process_frame
	var image: Image = viewport.get_texture().get_image()
	var output_path: String = ProjectSettings.globalize_path("%s/%s" % [OUTPUT_DIR, file_name])
	_expect(image != null and image.get_size() == viewport.size, "%s should capture at the exact production viewport size" % file_name)
	if image != null:
		_expect(image.save_png(output_path) == OK, "%s should save successfully" % file_name)

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
	subtitle.text = "IRON, ASH, AND EMBER — ONE LANGUAGE FOR EVERY POINTER STATE"
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
	_expect(bool(contract.get("loading_spins", false)), "Cursor proof should include the spinning loading ward")
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
	_expect(unique_hashes.size() >= 7, "Contextual cursor states should remain visually distinct rather than reusing one crude silhouette")

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
