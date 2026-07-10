extends SceneTree

const ActionIcons = preload("res://scripts/action_icon_library.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")
const UiSkin = preload("res://scripts/ui_skin.gd")
const UiTypography = preload("res://scripts/ui_typography.gd")
const HEADER_FONT = preload("res://fonts/LabyrinthCrumble-Header.tres")
const REGULAR_FONT = preload("res://fonts/LabyrinthCrumble-Regular.tres")

const OUTPUT_DIR: String = "user://button_system_overhaul_v2"

var _ui_skin := UiSkin.new()
var _gallery_buttons: Array[Button] = []
var _focus_sample: Button
var _interactive: bool = false
var _failed: bool = false

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	SettingsStore.set_storage_path("user://button_system_overhaul_v2_settings.json")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_clear_probe_output(OUTPUT_DIR)
	_interactive = "--interactive" in OS.get_cmdline_user_args()
	if _interactive:
		root.close_requested.connect(quit)
		await _show_gallery(1.0)
		print("BUTTON_GALLERY_INTERACTIVE=100/125 controls are available in the header")
		return

	await _capture_gallery(1.0, "100")
	await _capture_gallery(1.25, "125")
	SettingsStore.apply_settings(SettingsStore.default_settings(), root, false)
	print("BUTTON_SYSTEM_PROOF_DIR=%s" % ProjectSettings.globalize_path(OUTPUT_DIR))
	quit(1 if _failed else 0)

func _capture_gallery(scale: float, suffix: String) -> void:
	await _show_gallery(scale)
	_validate_gallery(scale)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = "%s/button_gallery_%s_v2.png" % [OUTPUT_DIR, suffix]
	var error: Error = image.save_png(path)
	_require(error == OK, "Button gallery should save at %s scale" % suffix)

func _show_gallery(scale: float) -> void:
	var settings: Dictionary = SettingsStore.default_settings()
	settings["ui_scale"] = scale
	SettingsStore.save_settings(settings)
	SettingsStore.apply_settings(settings, root, false)
	for child: Node in root.get_children():
		child.queue_free()
	await process_frame
	_gallery_buttons.clear()
	_focus_sample = null
	root.add_child(_build_gallery(scale))
	await process_frame
	await process_frame
	await process_frame
	if _focus_sample != null:
		_focus_sample.grab_focus()
	await process_frame

func _build_gallery(scale: float) -> Control:
	var surface := Control.new()
	surface.name = "ButtonSystemGallery"
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("090a0e")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.add_child(background)

	var glow := ColorRect.new()
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow.color = Color(0.16, 0.08, 0.035, 0.14)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.add_child(glow)

	var safe_margin := MarginContainer.new()
	safe_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "top", "right", "bottom"]:
		safe_margin.add_theme_constant_override("margin_%s" % side, 34)
	surface.add_child(safe_margin)

	var panel := PanelContainer.new()
	panel.name = "GalleryPanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var panel_style := _ui_skin.make_plain_card_style(Color("101117"), Color("a97b39"), 0.0)
	panel_style.border_width_left = 3
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 3
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.66)
	panel_style.shadow_size = 20
	panel.add_theme_stylebox_override("panel", panel_style)
	safe_margin.add_child(panel)

	var margin := MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 24)
	panel.add_child(margin)

	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 12)
	margin.add_child(root_box)
	root_box.add_child(_build_header(scale))
	root_box.add_child(_rule(Color("a97b39")))
	root_box.add_child(_section_title("NATIVE VARIANTS", "One scalable construction, proportions authored for each job."))
	root_box.add_child(_build_variant_grid())
	root_box.add_child(_section_title("INTERACTION STATES", "Clear feedback without changing any input or focus traversal."))
	root_box.add_child(_build_state_grid())

	var footer := Label.new()
	footer.text = "INK / BRASS / EMBER / STONE     •     NO STRETCHED BUTTON BITMAPS"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_override("font", REGULAR_FONT)
	UiTypography.set_label_size(footer, UiTypography.SIZE_CAPTION)
	footer.add_theme_color_override("font_color", Color("a89b85"))
	root_box.add_child(footer)
	return surface

func _build_header(scale: float) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var accent := ColorRect.new()
	accent.custom_minimum_size = Vector2(6.0, 58.0)
	accent.color = Color("d49243")
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(accent)

	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 0)
	row.add_child(copy)
	var title := Label.new()
	title.text = "THEMED BUTTON FORGE"
	title.add_theme_font_override("font", HEADER_FONT)
	UiTypography.set_label_size(title, UiTypography.SIZE_TITLE)
	title.add_theme_color_override("font_color", Color("fff0cb"))
	title.add_theme_color_override("font_outline_color", Color("07070a"))
	title.add_theme_constant_override("outline_size", 4)
	copy.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Code-native interaction language • %d%% UI scale" % roundi(scale * 100.0)
	subtitle.add_theme_font_override("font", REGULAR_FONT)
	UiTypography.set_label_size(subtitle, UiTypography.SIZE_SMALL)
	subtitle.add_theme_color_override("font_color", Color("bbaa8c"))
	copy.add_child(subtitle)

	if _interactive:
		var controls := HBoxContainer.new()
		controls.add_theme_constant_override("separation", 8)
		var scale_100 := _gallery_button("100%", UiSkin.VARIANT_COMPACT, UiSkin.BUTTON_HEIGHT_SMALL, 96.0)
		var scale_125 := _gallery_button("125%", UiSkin.VARIANT_COMPACT, UiSkin.BUTTON_HEIGHT_SMALL, 96.0)
		scale_100.pressed.connect(func() -> void: call_deferred("_show_gallery", 1.0))
		scale_125.pressed.connect(func() -> void: call_deferred("_show_gallery", 1.25))
		controls.add_child(scale_100)
		controls.add_child(scale_125)
		row.add_child(controls)
	return row

func _build_variant_grid() -> Control:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	grid.add_child(_sample_card("COMPACT", "Dense actions", _gallery_button("Skip", UiSkin.VARIANT_COMPACT, UiSkin.BUTTON_HEIGHT_SMALL, 104.0)))
	grid.add_child(_sample_card("STANDARD", "Menus and prompts", _gallery_button("Continue", UiSkin.VARIANT_STANDARD, UiSkin.BUTTON_HEIGHT_STANDARD, 168.0)))
	grid.add_child(_sample_card("LARGE", "Primary combat action", _gallery_button("Enter the Ash", UiSkin.VARIANT_LARGE, UiSkin.BUTTON_HEIGHT_ACTION, 224.0)))
	grid.add_child(_sample_card("DESTRUCTIVE", "Irreversible choice", _gallery_button("Abandon Run", UiSkin.VARIANT_DESTRUCTIVE, UiSkin.BUTTON_HEIGHT_STANDARD, 196.0)))
	var selected := _gallery_button("Attuned", UiSkin.VARIANT_SELECTED, UiSkin.BUTTON_HEIGHT_STANDARD, 166.0)
	selected.toggle_mode = true
	selected.button_pressed = true
	selected.set_meta("button_gallery_state", UiSkin.STATE_SELECTED)
	grid.add_child(_sample_card("SELECTED / TOGGLE", "Persistent active state", selected))
	var icon := _gallery_button("", UiSkin.VARIANT_ICON, UiSkin.BUTTON_HEIGHT_STANDARD, 0.0)
	icon.icon = ActionIcons.icon_texture("melee")
	icon.expand_icon = true
	icon.tooltip_text = "Icon button"
	grid.add_child(_sample_card("ICON", "Square utility action", icon))
	return grid

func _build_state_grid() -> Control:
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.add_child(_state_card("NORMAL", _state_button("Ready", UiSkin.VARIANT_STANDARD, UiSkin.STATE_NORMAL)))
	grid.add_child(_state_card("HOVER", _state_button("Ready", UiSkin.VARIANT_STANDARD, UiSkin.STATE_HOVER)))
	grid.add_child(_state_card("PRESSED", _state_button("Ready", UiSkin.VARIANT_STANDARD, UiSkin.STATE_PRESSED)))
	var disabled := _state_button("Unavailable", UiSkin.VARIANT_STANDARD, UiSkin.STATE_DISABLED)
	disabled.disabled = true
	grid.add_child(_state_card("DISABLED", disabled))
	var selected := _state_button("Selected", UiSkin.VARIANT_SELECTED, UiSkin.STATE_SELECTED)
	selected.toggle_mode = true
	selected.button_pressed = true
	grid.add_child(_state_card("SELECTED", selected))
	grid.add_child(_state_card("DESTRUCTIVE", _state_button("Restore", UiSkin.VARIANT_DESTRUCTIVE, UiSkin.STATE_NORMAL)))
	_focus_sample = _state_button("Keyboard Focus", UiSkin.VARIANT_STANDARD, UiSkin.STATE_FOCUS)
	_focus_sample.focus_mode = Control.FOCUS_ALL
	grid.add_child(_state_card("KEYBOARD FOCUS", _focus_sample))
	return grid

func _gallery_button(text: String, variant: String, height: float, min_width: float) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_override("font", REGULAR_FONT)
	_ui_skin.apply_button_stylebox_overrides(button, variant)
	_ui_skin.apply_button_text_overrides(button)
	UiTypography.set_button_size(button, UiTypography.SIZE_BODY)
	_ui_skin.apply_button_native_size(button, height, min_width, true, variant)
	_gallery_buttons.append(button)
	return button

func _state_button(text: String, variant: String, state: String) -> Button:
	var button := _gallery_button(text, variant, UiSkin.BUTTON_HEIGHT_STANDARD, 174.0)
	button.set_meta("button_gallery_state", state)
	if state in [UiSkin.STATE_HOVER, UiSkin.STATE_PRESSED]:
		button.add_theme_stylebox_override("normal", _ui_skin.make_button_style(variant, state))
	if state == UiSkin.STATE_HOVER:
		button.add_theme_color_override("font_color", UiSkin.BUTTON_FONT_FOCUS_COLOR)
	return button

func _sample_card(title_text: String, detail_text: String, button: Button) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _sample_panel_style())
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 9)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 1)
	row.add_child(copy)
	copy.add_child(_small_label(title_text, Color("edc987")))
	copy.add_child(_small_label(detail_text, Color("9e927f")))
	row.add_child(button)
	return panel

func _state_card(title_text: String, button: Button) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _sample_panel_style())
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)
	var label := _small_label(title_text, Color("bbaa8c"))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label)
	box.add_child(button)
	return panel

func _section_title(title_text: String, detail_text: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var title := _small_label(title_text, Color("f1d59d"))
	title.add_theme_font_override("font", HEADER_FONT)
	UiTypography.set_label_size(title, UiTypography.SIZE_SECTION)
	row.add_child(title)
	var detail := _small_label(detail_text, Color("9e927f"))
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(detail)
	return row

func _small_label(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", REGULAR_FONT)
	UiTypography.set_label_size(label, UiTypography.SIZE_SMALL)
	label.add_theme_color_override("font_color", color)
	return label

func _sample_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("15161d")
	style.border_color = Color("3c3429")
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	return style

func _rule(color: Color) -> ColorRect:
	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(0.0, 1.0)
	rule.color = Color(color.r, color.g, color.b, 0.58)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rule

func _validate_gallery(scale: float) -> void:
	_require(_gallery_buttons.size() >= 13, "Gallery should expose every required variant and state")
	for button: Button in _gallery_buttons:
		_require(button.alignment == HORIZONTAL_ALIGNMENT_CENTER, "Gallery button text should be centered at %.0f%%" % (scale * 100.0))
		_require(button.get_theme_stylebox("normal") is StyleBoxFlat, "Gallery buttons should use code-native styleboxes")
		_require(button.get_node_or_null(UiSkin.BUTTON_ORNAMENT_NAME) != null, "Gallery buttons should render the shared ornament")
		_require(button.size.x > 0.0 and button.size.y > 0.0, "Gallery buttons should have a settled renderer size")

func _require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	_failed = true

func _clear_probe_output(output_dir: String) -> void:
	_clear_probe_output_absolute(ProjectSettings.globalize_path(output_dir))

func _clear_probe_output_absolute(output_dir: String) -> void:
	var dir := DirAccess.open(output_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var entry: String = dir.get_next()
		if entry.is_empty():
			break
		if entry in [".", ".."]:
			continue
		var path: String = output_dir.path_join(entry)
		if dir.current_is_dir():
			_clear_probe_output_absolute(path)
			DirAccess.remove_absolute(path)
		else:
			DirAccess.remove_absolute(path)
	dir.list_dir_end()
