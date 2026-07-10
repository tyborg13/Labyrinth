extends PanelContainer
class_name SettingsPanel

signal back_requested
signal settings_changed(settings: Dictionary)

const SettingsStore = preload("res://scripts/settings_store.gd")
const UiSkin = preload("res://scripts/ui_skin.gd")
const UiTypography = preload("res://scripts/ui_typography.gd")
const HEADER_FONT = preload("res://fonts/LabyrinthCrumble-Header.tres")
const REGULAR_FONT = preload("res://fonts/LabyrinthCrumble-Regular.tres")

const PANEL_MINIMUM_SIZE := Vector2(820.0, 720.0)
const CONTROL_WIDTH: float = 276.0
const ROW_HEIGHT: float = 56.0
const GOLD := Color("d8a356")
const PALE_GOLD := Color("f5dfae")
const MUTED_TEXT := Color("b9a98c")
const PANEL_INK := Color("100d12")
const ROW_INK := Color("18131a")

var _ui_skin: UiSkin = UiSkin.new()
var _settings: Dictionary = {}
var _controls: Dictionary = {}
var _syncing: bool = false
var _status_label: Label
var _confirmation_panel: PanelContainer
var _back_button: Button

func _ready() -> void:
	_update_responsive_minimum_size()
	get_viewport().size_changed.connect(_update_responsive_minimum_size)
	_build_surface()
	refresh_from_disk()

func open() -> void:
	refresh_from_disk()
	visible = true

func refresh_from_disk() -> void:
	_settings = SettingsStore.load_settings()
	SettingsStore.apply_settings(_settings, get_window())
	_sync_controls_from_settings()
	_dismiss_restore_confirmation()
	_set_status("Saved automatically")

func current_settings() -> Dictionary:
	return _settings.duplicate(true)

func back_button() -> Button:
	return _back_button

func _update_responsive_minimum_size() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	custom_minimum_size = Vector2(
		minf(PANEL_MINIMUM_SIZE.x, maxf(480.0, viewport_size.x - 48.0)),
		minf(PANEL_MINIMUM_SIZE.y, maxf(260.0, viewport_size.y - 48.0))
	)

func _build_surface() -> void:
	add_theme_stylebox_override("panel", _panel_style())
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_bottom", 26)
	add_child(margin)

	var root := VBoxContainer.new()
	root.name = "SettingsContent"
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)
	root.add_child(_build_header())
	root.add_child(_divider(GOLD, 0.72))

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	var sections := VBoxContainer.new()
	sections.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sections.add_theme_constant_override("separation", 12)
	scroll.add_child(sections)
	sections.add_child(_build_audio_section())
	sections.add_child(_build_display_section())
	sections.add_child(_build_accessibility_section())
	root.add_child(_build_footer())

func _build_header() -> Control:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 18)
	var accent := ColorRect.new()
	accent.custom_minimum_size = Vector2(6.0, 58.0)
	accent.color = GOLD
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(accent)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 0)
	header.add_child(copy)
	var title := Label.new()
	title.text = "SETTINGS"
	title.add_theme_font_override("font", HEADER_FONT)
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color("fff1cc"))
	title.add_theme_color_override("font_outline_color", Color("090609"))
	title.add_theme_constant_override("outline_size", 4)
	copy.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "One profile. Every run."
	subtitle.add_theme_font_override("font", REGULAR_FONT)
	UiTypography.set_label_size(subtitle, UiTypography.SIZE_BODY)
	subtitle.add_theme_color_override("font_color", MUTED_TEXT)
	copy.add_child(subtitle)
	var badge := Label.new()
	badge.text = "AUTO-SAVE"
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_font_override("font", HEADER_FONT)
	UiTypography.set_label_size(badge, UiTypography.SIZE_SMALL)
	badge.add_theme_color_override("font_color", Color("82d7b0"))
	badge.add_theme_stylebox_override("normal", _chip_style(Color("18342d"), Color("4d9a7c")))
	header.add_child(badge)
	return header

func _build_audio_section() -> Control:
	var section := _section_shell("AUDIO", "Mix each layer without muting the world.")
	var rows: VBoxContainer = section.get_meta("rows")
	_add_volume_row(rows, "Master", "Overall output", "master_volume")
	_add_volume_row(rows, "Music", "Exploration and combat score", "music_volume")
	_add_volume_row(rows, "Sound effects", "Cards, impacts, and interface", "sfx_volume")
	return section

func _build_display_section() -> Control:
	var section := _section_shell("DISPLAY", "Safe choices for the current screen.")
	var rows: VBoxContainer = section.get_meta("rows")
	var display_option := _option_control()
	display_option.add_item("Fullscreen")
	display_option.set_item_metadata(0, SettingsStore.DISPLAY_FULLSCREEN)
	display_option.add_item("Windowed")
	display_option.set_item_metadata(1, SettingsStore.DISPLAY_WINDOWED)
	display_option.item_selected.connect(_on_option_selected.bind("display_mode", display_option))
	_controls["display_mode"] = display_option
	rows.add_child(_setting_row("Display mode", "Window changes stay bounded and centered", display_option))

	var scale_option := _option_control()
	for scale_var: Variant in SettingsStore.SUPPORTED_UI_SCALES:
		var scale: float = float(scale_var)
		scale_option.add_item("%d%%" % roundi(scale * 100.0))
		scale_option.set_item_metadata(scale_option.item_count - 1, scale)
	scale_option.item_selected.connect(_on_option_selected.bind("ui_scale", scale_option))
	_controls["ui_scale"] = scale_option
	rows.add_child(_setting_row("Interface scale", "Menus, dialogue, and combat HUD", scale_option))
	return section

func _build_accessibility_section() -> Control:
	var section := _section_shell("ACCESSIBILITY", "Tune pacing without changing the rules.")
	var rows: VBoxContainer = section.get_meta("rows")
	var dialogue_option := _option_control()
	for item: Dictionary in [
		{"label": "Standard", "value": SettingsStore.DIALOGUE_STANDARD},
		{"label": "Fast", "value": SettingsStore.DIALOGUE_FAST},
		{"label": "Instant", "value": SettingsStore.DIALOGUE_INSTANT}
	]:
		dialogue_option.add_item(str(item["label"]))
		dialogue_option.set_item_metadata(dialogue_option.item_count - 1, item["value"])
	dialogue_option.item_selected.connect(_on_option_selected.bind("dialogue_speed", dialogue_option))
	_controls["dialogue_speed"] = dialogue_option
	rows.add_child(_setting_row("Dialogue speed", "Instant reveals each line at once", dialogue_option))

	var reduced_button := Button.new()
	reduced_button.toggle_mode = true
	reduced_button.custom_minimum_size = Vector2(CONTROL_WIDTH, 44.0)
	_style_button(reduced_button, CONTROL_WIDTH)
	reduced_button.toggled.connect(_on_reduced_motion_toggled)
	_controls["reduced_motion"] = reduced_button
	rows.add_child(_setting_row("Reduced motion", "Skips supported entrance and travel flourishes", reduced_button))
	return section

func _build_footer() -> Control:
	var footer := VBoxContainer.new()
	footer.size_flags_vertical = Control.SIZE_SHRINK_END
	footer.add_theme_constant_override("separation", 10)

	_confirmation_panel = PanelContainer.new()
	_confirmation_panel.visible = false
	_confirmation_panel.add_theme_stylebox_override("panel", _confirmation_style())
	var confirm_margin := MarginContainer.new()
	confirm_margin.add_theme_constant_override("margin_left", 14)
	confirm_margin.add_theme_constant_override("margin_top", 10)
	confirm_margin.add_theme_constant_override("margin_right", 14)
	confirm_margin.add_theme_constant_override("margin_bottom", 10)
	_confirmation_panel.add_child(confirm_margin)
	var confirm_row := HBoxContainer.new()
	confirm_row.add_theme_constant_override("separation", 10)
	confirm_margin.add_child(confirm_row)
	var warning := Label.new()
	warning.text = "Reset every setting?"
	warning.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	warning.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	warning.add_theme_font_override("font", HEADER_FONT)
	UiTypography.set_label_size(warning, UiTypography.SIZE_BODY)
	warning.add_theme_color_override("font_color", Color("ffd0bb"))
	confirm_row.add_child(warning)
	var cancel := Button.new()
	cancel.text = "Cancel"
	_style_button(cancel, 120.0, Color("efe4c1"), UiSkin.VARIANT_COMPACT)
	cancel.pressed.connect(_dismiss_restore_confirmation)
	confirm_row.add_child(cancel)
	var confirm := Button.new()
	confirm.text = "Restore"
	_style_button(confirm, 138.0, Color("ffcabd"), UiSkin.VARIANT_DESTRUCTIVE)
	confirm.pressed.connect(_confirm_restore_defaults)
	confirm_row.add_child(confirm)
	footer.add_child(_confirmation_panel)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	footer.add_child(actions)
	_status_label = Label.new()
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_override("font", REGULAR_FONT)
	UiTypography.set_label_size(_status_label, UiTypography.SIZE_BODY)
	_status_label.add_theme_color_override("font_color", Color("82d7b0"))
	actions.add_child(_status_label)
	var restore := Button.new()
	restore.text = "Restore defaults"
	_style_button(restore, 194.0, Color("efc7ba"), UiSkin.VARIANT_DESTRUCTIVE)
	restore.pressed.connect(_show_restore_confirmation)
	actions.add_child(restore)
	_back_button = Button.new()
	_back_button.name = "SettingsBackButton"
	_back_button.text = "Back"
	_style_button(_back_button, 152.0)
	_back_button.pressed.connect(_on_back_pressed)
	actions.add_child(_back_button)
	return footer

func _section_shell(title_text: String, subtitle_text: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _section_style())
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_top", 11)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_bottom", 11)
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	margin.add_child(stack)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	stack.add_child(header)
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_override("font", HEADER_FONT)
	UiTypography.set_label_size(title, UiTypography.SIZE_SECTION)
	title.add_theme_color_override("font_color", PALE_GOLD)
	header.add_child(title)
	var subtitle := Label.new()
	subtitle.text = subtitle_text
	subtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_override("font", REGULAR_FONT)
	UiTypography.set_label_size(subtitle, UiTypography.SIZE_SMALL)
	subtitle.add_theme_color_override("font_color", MUTED_TEXT)
	header.add_child(subtitle)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 2)
	stack.add_child(rows)
	panel.set_meta("rows", rows)
	return panel

func _add_volume_row(rows: VBoxContainer, title: String, detail: String, key: String) -> void:
	var control := HBoxContainer.new()
	control.custom_minimum_size = Vector2(CONTROL_WIDTH, 38.0)
	control.add_theme_constant_override("separation", 10)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.custom_minimum_size = Vector2(214.0, 38.0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(52.0, 38.0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.add_theme_font_override("font", HEADER_FONT)
	UiTypography.set_label_size(value_label, UiTypography.SIZE_BODY)
	value_label.add_theme_color_override("font_color", PALE_GOLD)
	slider.value_changed.connect(_on_volume_changed.bind(key, value_label))
	control.add_child(slider)
	control.add_child(value_label)
	_controls[key] = {"slider": slider, "label": value_label}
	rows.add_child(_setting_row(title, detail, control))

func _setting_row(title_text: String, detail_text: String, setting_control: Control) -> PanelContainer:
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	row.add_theme_stylebox_override("panel", _row_style())
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 13)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 7)
	row.add_child(margin)
	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 18)
	margin.add_child(content)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 1)
	content.add_child(copy)
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_override("font", HEADER_FONT)
	UiTypography.set_label_size(title, UiTypography.SIZE_BODY_LARGE)
	title.add_theme_color_override("font_color", Color("f3e7cc"))
	copy.add_child(title)
	var detail := Label.new()
	detail.text = detail_text
	detail.add_theme_font_override("font", REGULAR_FONT)
	UiTypography.set_label_size(detail, UiTypography.SIZE_SMALL)
	detail.add_theme_color_override("font_color", MUTED_TEXT)
	copy.add_child(detail)
	setting_control.custom_minimum_size.x = maxf(setting_control.custom_minimum_size.x, CONTROL_WIDTH)
	setting_control.size_flags_horizontal = Control.SIZE_SHRINK_END
	setting_control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	content.add_child(setting_control)
	return row

func _option_control() -> OptionButton:
	var option := OptionButton.new()
	option.custom_minimum_size = Vector2(CONTROL_WIDTH, 44.0)
	_ui_skin.apply_button_stylebox_overrides(option, UiSkin.VARIANT_STANDARD)
	_ui_skin.apply_button_text_overrides(option)
	UiTypography.set_option_button_size(option, UiTypography.SIZE_BODY)
	option.alignment = HORIZONTAL_ALIGNMENT_CENTER
	option.add_theme_constant_override("arrow_margin", 12)
	option.set_meta("settings_text_centered", true)
	return option

func _style_button(
	button: Button,
	width: float,
	font_color: Color = Color("efe4c1"),
	variant: String = UiSkin.VARIANT_STANDARD
) -> void:
	_ui_skin.apply_button_stylebox_overrides(button, variant)
	_ui_skin.apply_button_text_overrides(button, font_color)
	UiTypography.set_button_size(button, UiTypography.SIZE_BODY)
	_ui_skin.apply_button_native_size(button, UiSkin.BUTTON_HEIGHT_STANDARD, width, false, variant)
	button.custom_minimum_size.x = width
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.set_meta("settings_text_centered", true)

func _sync_controls_from_settings() -> void:
	if _controls.is_empty():
		return
	_syncing = true
	for key: String in ["master_volume", "music_volume", "sfx_volume"]:
		var volume_controls: Dictionary = _controls.get(key, {})
		var slider: HSlider = volume_controls.get("slider")
		var value_label: Label = volume_controls.get("label")
		if slider != null:
			slider.value = float(_settings.get(key, 1.0))
		if value_label != null:
			value_label.text = _percent_text(float(_settings.get(key, 1.0)))
	_select_option_value(_controls.get("display_mode") as OptionButton, _settings.get("display_mode"))
	_select_option_value(_controls.get("ui_scale") as OptionButton, _settings.get("ui_scale"))
	_select_option_value(_controls.get("dialogue_speed") as OptionButton, _settings.get("dialogue_speed"))
	var reduced_button: Button = _controls.get("reduced_motion") as Button
	if reduced_button != null:
		reduced_button.button_pressed = bool(_settings.get("reduced_motion", false))
		_update_reduced_motion_button(reduced_button)
	_syncing = false

func _select_option_value(option: OptionButton, value: Variant) -> void:
	if option == null:
		return
	for index: int in range(option.item_count):
		if option.get_item_metadata(index) == value:
			option.select(index)
			return

func _on_volume_changed(value: float, key: String, value_label: Label) -> void:
	value_label.text = _percent_text(value)
	if _syncing:
		return
	_settings[key] = value
	_commit_change("Audio updated")

func _on_option_selected(index: int, key: String, option: OptionButton) -> void:
	if _syncing or index < 0:
		return
	_settings[key] = option.get_item_metadata(index)
	var status: String = "Display updated" if key in ["display_mode", "ui_scale"] else "Dialogue updated"
	_commit_change(status)

func _on_reduced_motion_toggled(enabled: bool) -> void:
	var button: Button = _controls.get("reduced_motion") as Button
	_update_reduced_motion_button(button)
	if _syncing:
		return
	_settings["reduced_motion"] = enabled
	_commit_change("Motion preference updated")

func _update_reduced_motion_button(button: Button) -> void:
	if button == null:
		return
	button.text = "On — less motion" if button.button_pressed else "Off — full motion"

func _commit_change(status: String) -> void:
	_settings = SettingsStore.normalize_settings(_settings)
	if SettingsStore.save_settings(_settings):
		_set_status(status)
	else:
		_set_status("Could not save", true)
	SettingsStore.apply_settings(_settings, get_window())
	settings_changed.emit(_settings.duplicate(true))

func _show_restore_confirmation() -> void:
	_confirmation_panel.visible = true
	_set_status("Confirmation required", true)

func _dismiss_restore_confirmation() -> void:
	if _confirmation_panel != null:
		_confirmation_panel.visible = false

func _confirm_restore_defaults() -> void:
	_settings = SettingsStore.restore_defaults(get_window())
	_sync_controls_from_settings()
	_dismiss_restore_confirmation()
	_set_status("Defaults restored")
	settings_changed.emit(_settings.duplicate(true))

func _on_back_pressed() -> void:
	_dismiss_restore_confirmation()
	back_requested.emit()

func _set_status(text: String, warning: bool = false) -> void:
	if _status_label == null:
		return
	_status_label.text = text
	_status_label.add_theme_color_override("font_color", Color("f0b093") if warning else Color("82d7b0"))

func _percent_text(value: float) -> String:
	return "%d%%" % roundi(clampf(value, 0.0, 1.0) * 100.0)

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(PANEL_INK, 0.965)
	style.border_color = Color("c58a42")
	style.border_width_left = 5
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.58)
	style.shadow_size = 20
	return style

func _section_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("151118")
	style.border_color = Color("554330")
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_right = 7
	style.corner_radius_bottom_left = 7
	return style

func _row_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(ROW_INK, 0.88)
	style.border_color = Color("2d2530")
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	return style

func _confirmation_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("321b1c")
	style.border_color = Color("b66b56")
	style.border_width_left = 3
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	return style

func _chip_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_right = 5
	style.corner_radius_bottom_left = 5
	style.content_margin_left = 12
	style.content_margin_top = 7
	style.content_margin_right = 12
	style.content_margin_bottom = 7
	return style

func _divider(color: Color, alpha: float) -> ColorRect:
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(0.0, 1.0)
	line.color = Color(color.r, color.g, color.b, alpha)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line
