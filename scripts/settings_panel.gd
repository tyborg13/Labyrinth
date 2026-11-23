extends PanelContainer
class_name SettingsPanel

signal back_requested
signal settings_changed(settings: Dictionary)

const DemoBuild = preload("res://scripts/demo_build.gd")
const DemoEndPanel = preload("res://scripts/demo_end_panel.gd")
const KeyBindings = preload("res://scripts/key_bindings.gd")
const KeyButton = preload("res://scripts/settings_key_button.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")
const UiSkin = preload("res://scripts/ui_skin.gd")
const UiTypography = preload("res://scripts/ui_typography.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const GildedFrame = preload("res://scripts/ui_gilded_frame.gd")
const InputRouterScript = preload("res://scripts/input_router.gd")
const UI_FONT = preload("res://fonts/LabyrinthCrumble-UI.tres")
const TEXT_FONT = preload("res://fonts/LabyrinthCrumble-Text.tres")

# Cap the panel height and keep the existing scroll behavior.
const PANEL_MINIMUM_SIZE := Vector2(820.0, 836.0)
const CONTROL_WIDTH: float = 276.0
const ROW_HEIGHT: float = 56.0
# The brief supplies the label/options, but no secondary row copy.
const COMBAT_SPEED_DETAIL: String = "How quickly enemy turns and card effects play out"
# Controls rows are data, so later units add rows without code: a label, pointer
# tokens (a phrase string, or {"key": …, "rebind": …} for a keycap) and controller action
# names. See spec/settings.md.
const CONTROLS_DATA_PATH: String = "res://data/controls.json"
const CONTROLS_NONE_TEXT: String = "—"
const LISTENING_TEXT: String = "Press a key"
const ROW_MARGIN_RIGHT: int = 10
const ROW_SEPARATION: int = 18
const GOLD := Color("d8a356")
const PALE_GOLD := Color("f5dfae")
const MUTED_TEXT := Color("b9a98c")
const PANEL_INK := Color("100d12")
const ROW_INK := Color("18131a")

var _ui_skin: UiSkin = UiSkin.new()
var _settings: Dictionary = {}
var _controls: Dictionary = {}
var _syncing: bool = false
var _demo_links: Array[Button]
var _status_label: Label
var _confirmation_panel: PanelContainer
var _footer_actions: HBoxContainer
var _back_button: Button
var _confirmation_cancel: Button
var _confirmation_confirm: Button
var _confirmation_title: Label
var _confirming_key_restore: bool
var _restore_keys: Button
var _keycaps: Dictionary = {}
var _key_pointer_cells: Array[Control]
var _listening_action: String = ""
var _rebind_trigger: InputEvent
var _confirmation_return_focus: Control
var _confirmation_focus_modes: Dictionary = {}
var _defer_initial_refresh: bool

# Keep HSlider's native hit testing, drag, wheel and keyboard behaviour. Only
# its drawing changes; the transparent native grabber reserves its travel size.
class VolumeSlider extends HSlider:
	const TRACK_HEIGHT: float = 8.0
	const FILL_INSET: float = 1.0
	const GRABBER_SIZE: int = 14
	const ENGAGED_GRABBER_SIZE: int = 18
	const OUTLINE_WIDTH: float = 1.0
	var _track: StyleBoxFlat
	var _focus_ring: StyleBoxFlat
	var _hovered: bool = false

	func _init(skin: UiSkin) -> void:
		_track = skin.make_button_style(UiSkin.VARIANT_STANDARD)
		_focus_ring = skin.make_button_style(UiSkin.VARIANT_STANDARD, UiSkin.STATE_FOCUS)
		var empty := StyleBoxEmpty.new()
		for style: String in ["slider", "grabber_area", "grabber_area_highlight"]:
			add_theme_stylebox_override(style, empty)
		var gradient := Gradient.new()
		gradient.colors = PackedColorArray([Color.TRANSPARENT, Color.TRANSPARENT])
		var native_grabber := GradientTexture2D.new()
		native_grabber.gradient = gradient
		native_grabber.width = GRABBER_SIZE
		native_grabber.height = GRABBER_SIZE
		for icon: String in ["grabber", "grabber_highlight", "grabber_disabled"]:
			add_theme_icon_override(icon, native_grabber)
		mouse_entered.connect(_set_hovered.bind(true))
		mouse_exited.connect(_set_hovered.bind(false))
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)
		value_changed.connect(func(_value: float) -> void: queue_redraw())

	func _set_hovered(hovered: bool) -> void:
		_hovered = hovered
		queue_redraw()

	func _draw() -> void:
		var track := Rect2(0.0, (size.y - TRACK_HEIGHT) * 0.5, size.x, TRACK_HEIGHT)
		draw_style_box(_track, track)
		GildedFrame.draw_sheen(self, track)
		var center := Vector2(GRABBER_SIZE * 0.5 + get_as_ratio() * (size.x - GRABBER_SIZE), size.y * 0.5)
		var fill := Rect2(track.position + Vector2.ONE * FILL_INSET, Vector2(maxf(0.0, center.x - FILL_INSET), TRACK_HEIGHT - FILL_INSET * 2.0))
		draw_rect(fill, Palette.GOLD)
		var diameter: float = ENGAGED_GRABBER_SIZE if _hovered or has_focus() else GRABBER_SIZE
		var radius: float = (diameter - OUTLINE_WIDTH) * 0.5
		var diamond := PackedVector2Array([
			center + Vector2(0.0, -radius), center + Vector2(radius, 0.0),
			center + Vector2(0.0, radius), center + Vector2(-radius, 0.0),
		])
		draw_colored_polygon(diamond, Palette.GOLD_BRIGHT)
		diamond.append(diamond[0])
		draw_polyline(diamond, Palette.INK_0, OUTLINE_WIDTH, true)
		if has_focus(): draw_style_box(_focus_ring, Rect2(Vector2.ZERO, size))

# A read-only Controls row. Focus exists only so the D-pad and keys scroll the
# panel through the section (A does nothing); it draws the skin's standard
# focus ring. Clicks leave the focus hidden, and hover draws nothing: a lit row
# would read as a button.
class ControlsRow extends PanelContainer:
	var _focus_ring: StyleBoxFlat

	func _init(skin: UiSkin) -> void:
		_focus_ring = skin.make_button_style(UiSkin.VARIANT_STANDARD, UiSkin.STATE_FOCUS)
		focus_mode = Control.FOCUS_ALL
		focus_neighbor_left = NodePath(".")
		focus_neighbor_right = NodePath(".")
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)

	func _draw() -> void:
		if has_focus(true): draw_style_box(_focus_ring, Rect2(Vector2.ZERO, size))

# A keyboard key as InputGlyph's rounded key in its Xbox (dark) styling: 17 pt
# for a single letter, 13 pt for longer keys (Shift, Esc, 1–9), widened to fit.
class ControlsKeycap extends "res://scripts/input_glyph.gd":
	const KEY_SIZE := Vector2(36.0, 27.0) # InputGlyph's rounded key
	const LABEL_PADDING: float = 12.0 # Each side of a label wider than KEY_SIZE.
	var key_text: String = ""

	func _init(next_key_text: String) -> void:
		key_text = next_key_text
		family = InputRouterScript.FAMILY_XBOX

	func set_key_text(next_text: String) -> void:
		key_text = next_text
		custom_minimum_size = _scaled_preferred_size()
		queue_redraw()

	func _glyph_text() -> String:
		return key_text

	func _rounded_key_label_size() -> int:
		return UiTypography.scaled_size(self, 17 if key_text.length() == 1 else 13)

	func _draw() -> void:
		_draw_rounded_key(Rect2(Vector2.ZERO, size), key_text)

	func _scaled_preferred_size() -> Vector2:
		var factor: float = UiTypography.ui_scale(self)
		var label_width: float = UiTypography.ui_font().get_string_size(key_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, _rounded_key_label_size()).x
		return Vector2(maxf(KEY_SIZE.x * factor, ceilf(label_width + LABEL_PADDING * 2.0 * factor)), KEY_SIZE.y * factor)

# InputGlyph badge that follows the router's current controller family live.
class ControlsGlyph extends "res://scripts/input_glyph.gd":
	func _ready() -> void:
		super._ready()
		var router: Node = get_node_or_null("/root/InputRouter")
		if router != null and not router.controller_family_changed.is_connected(_follow_family):
			router.controller_family_changed.connect(_follow_family)
		_follow_family()

	func _follow_family(_family: String = "") -> void:
		var router: Node = get_node_or_null("/root/InputRouter")
		configure(action_name, str(router.call("controller_family")) if router != null else InputRouterScript.FAMILY_XBOX)

func _enter_tree() -> void:
	get_viewport().size_changed.connect(_update_responsive_minimum_size)

func _exit_tree() -> void:
	get_viewport().size_changed.disconnect(_update_responsive_minimum_size)

func _ready() -> void:
	_update_responsive_minimum_size()
	_build_surface()
	if not _defer_initial_refresh: refresh_from_disk()
	_build_demo_links()
	visibility_changed.connect(_on_panel_visibility_changed)
	preload("res://scripts/controller_gui_navigation.gd").install(self, func() -> bool: return _listening_action.is_empty())

func defer_initial_refresh() -> void:
	_defer_initial_refresh = true

func open() -> void:
	refresh_from_disk()
	visible = true

func refresh_from_disk() -> void:
	apply_saved_settings(SettingsStore.load_settings())

func apply_saved_settings(settings: Dictionary) -> void:
	_listening_action = ""
	_settings = settings
	SettingsStore.apply_settings(_settings, get_window())
	_sync_controls_from_settings()
	_dismiss_restore_confirmation()
	_set_save_status("Saved automatically")

func current_settings() -> Dictionary:
	return _settings.duplicate(true)

func back_button() -> Button:
	return _back_button

func contains_pointer_position(viewport_position: Vector2) -> bool:
	var local_position: Vector2 = get_global_transform_with_canvas().affine_inverse() * viewport_position
	return Rect2(Vector2.ZERO, size).has_point(local_position)

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
	scroll.follow_focus = true
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
	sections.add_child(_build_controls_section())
	root.add_child(_build_footer())
	_ui_skin.apply_outer_panel_frame(self, UiSkin.SURFACE_DIALOG)

func _build_header() -> Control:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 18)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 0)
	header.add_child(copy)
	var title := Label.new()
	title.text = "SETTINGS"
	title.add_theme_font_override("font", UI_FONT)
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color("fff1cc"))
	title.add_theme_color_override("font_outline_color", Color("090609"))
	title.add_theme_constant_override("outline_size", 4)
	copy.add_child(title)
	return header

func _build_audio_section() -> Control:
	var section := _section_shell("AUDIO", "How loud each part of the game plays.")
	var rows: VBoxContainer = section.get_meta("rows")
	_add_volume_row(rows, "Master", "Everything at once", "master_volume")
	_add_volume_row(rows, "Music", "Exploration and combat music", "music_volume")
	_add_volume_row(rows, "Sound effects", "Cards, impacts, and interface", "sfx_volume")
	_add_volume_row(rows, "Interface", "Cards, menus and rewards", "ui_volume")

	var mute_option := _option_control()
	mute_option.name = "MuteInBackgroundOption"
	mute_option.add_item("Off")
	mute_option.set_item_metadata(0, false)
	mute_option.add_item("On")
	mute_option.set_item_metadata(1, true)
	mute_option.item_selected.connect(_on_option_selected.bind("mute_in_background", mute_option))
	_controls["mute_in_background"] = mute_option
	rows.add_child(_setting_row("Mute in background", "Silence the game when its window isn't in front", mute_option))
	return section

func _build_display_section() -> Control:
	var section := _section_shell("DISPLAY", "How the game fills your screen.")
	var rows: VBoxContainer = section.get_meta("rows")
	var display_option := _option_control()
	display_option.add_item("Fullscreen")
	display_option.set_item_metadata(0, SettingsStore.DISPLAY_FULLSCREEN)
	display_option.add_item("Windowed")
	display_option.set_item_metadata(1, SettingsStore.DISPLAY_WINDOWED)
	display_option.item_selected.connect(_on_option_selected.bind("display_mode", display_option))
	_controls["display_mode"] = display_option
	rows.add_child(_setting_row("Display mode", "Fullscreen, or a window you can move", display_option))

	var scale_option := _option_control()
	for scale_var: Variant in SettingsStore.SUPPORTED_UI_SCALES:
		var scale: float = float(scale_var)
		scale_option.add_item("%d%%" % roundi(scale * 100.0))
		scale_option.set_item_metadata(scale_option.item_count - 1, scale)
	scale_option.item_selected.connect(_on_option_selected.bind("ui_scale", scale_option))
	_controls["ui_scale"] = scale_option
	rows.add_child(_setting_row("Interface scale", "Size of menus, dialogue and the combat HUD", scale_option))

	var smoothing_option := _option_control()
	smoothing_option.name = "EdgeSmoothingOption"
	for item: Dictionary in [
		{"label": "High", "value": SettingsStore.EDGE_SMOOTHING_HIGH},
		{"label": "Low", "value": SettingsStore.EDGE_SMOOTHING_LOW},
		{"label": "Off", "value": SettingsStore.EDGE_SMOOTHING_OFF}
	]:
		smoothing_option.add_item(str(item["label"]))
		smoothing_option.set_item_metadata(smoothing_option.item_count - 1, item["value"])
	smoothing_option.item_selected.connect(_on_option_selected.bind("edge_smoothing", smoothing_option))
	_controls["edge_smoothing"] = smoothing_option
	rows.add_child(_setting_row("Edge smoothing", "Smoother tile and HUD edges. Lower runs faster.", smoothing_option))
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
	rows.add_child(_setting_row("Dialogue speed", "How fast dialogue appears", dialogue_option))

	var combat_option := _option_control()
	combat_option.name = "CombatSpeedOption"
	for item: Dictionary in [
		{"label": "Normal", "value": SettingsStore.COMBAT_NORMAL},
		{"label": "Fast", "value": SettingsStore.COMBAT_FAST},
		{"label": "Fastest", "value": SettingsStore.COMBAT_FASTEST}
	]:
		combat_option.add_item(str(item["label"]))
		combat_option.set_item_metadata(combat_option.item_count - 1, item["value"])
	combat_option.focus_entered.connect(_reveal_combat_speed.bind(combat_option))
	combat_option.item_selected.connect(_on_option_selected.bind("combat_speed", combat_option))
	_controls["combat_speed"] = combat_option
	rows.add_child(_setting_row("Combat speed", COMBAT_SPEED_DETAIL, combat_option))

	var health_option := _option_control()
	health_option.name = "BoardHealthBarsOption"
	health_option.add_item("Always")
	health_option.set_item_metadata(0, SettingsStore.BOARD_HEALTH_ALWAYS)
	health_option.add_item("On hover and aim")
	health_option.set_item_metadata(1, SettingsStore.BOARD_HEALTH_CONTEXTUAL)
	health_option.item_selected.connect(_on_option_selected.bind("board_health_bars", health_option))
	_controls["board_health_bars"] = health_option
	rows.add_child(_setting_row("Board Health Bars", "", health_option))

	var reduced_button := Button.new()
	reduced_button.toggle_mode = true
	reduced_button.custom_minimum_size = Vector2(CONTROL_WIDTH, 44.0)
	_style_button(reduced_button, CONTROL_WIDTH)
	reduced_button.toggled.connect(_on_reduced_motion_toggled)
	_controls["reduced_motion"] = reduced_button
	rows.add_child(_setting_row("Reduced motion", "Fewer entrance, travel and effect animations", reduced_button))

	var vibration_button := Button.new()
	vibration_button.name = "ControllerVibrationButton"
	vibration_button.toggle_mode = true
	vibration_button.custom_minimum_size = Vector2(CONTROL_WIDTH, 44.0)
	_style_button(vibration_button, CONTROL_WIDTH)
	vibration_button.toggled.connect(_on_controller_vibration_toggled.bind(vibration_button))
	_controls["controller_vibration"] = vibration_button
	rows.add_child(_setting_row("Controller vibration", "", vibration_button))
	return section

func _reveal_combat_speed(option: Control) -> void:
	var parent: Node = option.get_parent()
	while parent != null and not parent is ScrollContainer:
		parent = parent.get_parent()
	if parent is ScrollContainer:
		parent.ensure_control_visible(option)

func _build_controls_section() -> Control:
	var section := _section_shell("CONTROLS", "What each key and button does.")
	section.name = "ControlsSection"
	var rows: VBoxContainer = section.get_meta("rows")
	var focus_targets: Array[Control]
	var controller_cells: Array[Control]
	# Column headings share the rows' right edge and column gap.
	var headings_margin := MarginContainer.new()
	headings_margin.name = "ControlsHeadings"
	headings_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	headings_margin.size_flags_vertical = Control.SIZE_SHRINK_END
	headings_margin.add_theme_constant_override("margin_right", ROW_MARGIN_RIGHT)
	(section.get_meta("header") as HBoxContainer).add_child(headings_margin)
	var headings := HBoxContainer.new()
	headings.alignment = BoxContainer.ALIGNMENT_END
	headings.add_theme_constant_override("separation", ROW_SEPARATION)
	headings_margin.add_child(headings)
	var pointer_heading := _caption_label("Keyboard and mouse")
	var controller_heading := _caption_label("Controller")
	for heading: Label in [pointer_heading, controller_heading]:
		heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		headings.add_child(heading)
	_key_pointer_cells.append(pointer_heading)
	controller_cells.append(controller_heading)
	for entry: Dictionary in controls_entries():
		var row := ControlsRow.new(_ui_skin)
		row.name = "Controls_%s" % str(entry.get("id", ""))
		var content: HBoxContainer = _row_frame(row)
		var title := _row_title(str(entry.get("label", "")))
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.size_flags_vertical = Control.SIZE_FILL
		title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		content.add_child(title)
		var pointer := _controls_cell("PointerBindings")
		var focus_target: Control = row
		for token: Variant in entry.get("pointer", []):
			if token is Dictionary:
				var keycap := ControlsKeycap.new(str(token.get("key", "")))
				keycap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				var action: String = str(token.get("rebind", ""))
				if KeyBindings.DEFAULT_KEYS.has(action):
					var button := KeyButton.new(keycap, _ui_skin)
					button.name = "RebindKey"
					button.pressed.connect(_listen_for_key.bind(action))
					_keycaps[action] = button
					row.focus_mode = Control.FOCUS_NONE
					focus_target = button
					pointer.add_child(button)
				else:
					pointer.add_child(keycap)
			else:
				pointer.add_child(_caption_label(str(token)))
		var controller := _controls_cell("ControllerBindings")
		for action_var: Variant in entry.get("controller", []):
			var glyph := ControlsGlyph.new()
			glyph.action_name = StringName(str(action_var))
			glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			controller.add_child(glyph)
		for cell: HBoxContainer in [pointer, controller]:
			if cell.get_child_count() == 0: cell.add_child(_caption_label(CONTROLS_NONE_TEXT))
			content.add_child(cell)
		_key_pointer_cells.append(pointer)
		controller_cells.append(controller)
		rows.add_child(row)
		focus_targets.append(focus_target)
	_restore_keys = Button.new()
	_restore_keys.name = "RestoreDefaultKeys"
	_restore_keys.text = "Restore default keys"
	_restore_keys.disabled = true
	_style_button(_restore_keys, 0.0)
	_restore_keys.size_flags_horizontal = Control.SIZE_SHRINK_END
	_restore_keys.pressed.connect(_show_restore_confirmation.bind(true))
	rows.add_child(_restore_keys)
	# Keep the vertical route between adjacent rows when focus moves between a
	# full-width read-only row and a small button in the keycap column.
	for index: int in range(1, focus_targets.size()):
		var above: Control = focus_targets[index - 1]
		var below: Control = focus_targets[index]
		above.focus_neighbor_bottom = above.get_path_to(below)
		below.focus_neighbor_top = below.get_path_to(above)
	if not focus_targets.is_empty():
		_restore_keys.focus_neighbor_top = _restore_keys.get_path_to(focus_targets.back())
	# Glyph sizes and label metrics resolve once the section is in the tree.
	section.ready.connect(func() -> void:
		_sync_keycaps()
		_align_controls_column(controller_cells))
	return section

static func controls_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary]
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONTROLS_DATA_PATH))
	if typeof(parsed) != TYPE_ARRAY:
		push_error("Controls must contain an array of rows")
		return entries
	for value: Variant in parsed:
		if typeof(value) == TYPE_DICTIONARY: entries.append(value)
	return entries

func _controls_cell(cell_name: String) -> HBoxContainer:
	var cell := HBoxContainer.new()
	cell.name = cell_name
	cell.alignment = BoxContainer.ALIGNMENT_END
	cell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_theme_constant_override("separation", UiTypography.SPACE_SMALL)
	return cell

func _align_controls_column(cells: Array[Control]) -> void:
	var width: float = 0.0
	for cell: Control in cells:
		cell.custom_minimum_size.x = 0.0
		width = maxf(width, cell.get_combined_minimum_size().x)
	for cell: Control in cells:
		cell.custom_minimum_size.x = width

func _build_footer() -> Control:
	# Both states occupy the existing actions row's height. Confirmation must
	# never take space from the settings scroll area.
	var footer := MarginContainer.new()
	footer.size_flags_vertical = Control.SIZE_SHRINK_END

	_confirmation_panel = PanelContainer.new()
	_confirmation_panel.visible = false
	var confirmation_style := _confirmation_style()
	confirmation_style.content_margin_top = 0
	confirmation_style.content_margin_bottom = 0
	_confirmation_panel.add_theme_stylebox_override("panel", confirmation_style)
	var confirm_margin := MarginContainer.new()
	confirm_margin.add_theme_constant_override("margin_left", 14)
	confirm_margin.add_theme_constant_override("margin_top", 0)
	confirm_margin.add_theme_constant_override("margin_right", 14)
	confirm_margin.add_theme_constant_override("margin_bottom", 0)
	_confirmation_panel.add_child(confirm_margin)
	var confirm_row := HBoxContainer.new()
	confirm_row.add_theme_constant_override("separation", 10)
	confirm_margin.add_child(confirm_row)
	var warning := Label.new()
	_confirmation_title = warning
	warning.text = "Reset every setting?"
	warning.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	warning.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	warning.add_theme_font_override("font", UI_FONT)
	UiTypography.set_label_size(warning, UiTypography.SIZE_BODY)
	warning.add_theme_color_override("font_color", Color("ffd0bb"))
	confirm_row.add_child(warning)
	var cancel := Button.new()
	_confirmation_cancel = cancel
	cancel.text = "Cancel"
	_style_button(cancel, 120.0, Color("efe4c1"), UiSkin.VARIANT_COMPACT)
	cancel.pressed.connect(_cancel_restore_confirmation)
	confirm_row.add_child(cancel)
	var confirm := Button.new()
	_confirmation_confirm = confirm
	confirm.text = "Reset All"
	_style_button(confirm, 138.0, Color("ffcabd"), UiSkin.VARIANT_DESTRUCTIVE)
	confirm.pressed.connect(_confirm_restore_defaults)
	confirm_row.add_child(confirm)
	for button: Button in [cancel, confirm]:
		var other: Button = confirm if button == cancel else cancel
		button.focus_neighbor_left = button.get_path_to(other)
		button.focus_neighbor_right = button.get_path_to(other)
		button.focus_neighbor_top = button.get_path_to(button)
		button.focus_neighbor_bottom = button.get_path_to(button)
	footer.add_child(_confirmation_panel)

	var actions := HBoxContainer.new()
	_footer_actions = actions
	actions.add_theme_constant_override("separation", 12)
	footer.add_child(actions)
	_status_label = Label.new()
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_override("font", TEXT_FONT)
	UiTypography.set_label_size(_status_label, UiTypography.SIZE_BODY)
	_status_label.add_theme_color_override("font_color", Color("82d7b0"))
	actions.add_child(_status_label)
	var restore := Button.new()
	restore.text = "Restore Defaults"
	_style_button(restore, 194.0, Color("efc7ba"), UiSkin.VARIANT_DESTRUCTIVE)
	restore.pressed.connect(_show_restore_confirmation)
	actions.add_child(restore)
	_back_button = Button.new()
	_back_button.name = "SettingsBackButton"
	_back_button.text = "Back"
	_style_button(_back_button, 152.0)
	_back_button.pressed.connect(_on_back_pressed)
	actions.add_child(_back_button)
	footer.custom_minimum_size.y = actions.get_combined_minimum_size().y
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
	title.add_theme_font_override("font", UI_FONT)
	UiTypography.set_label_size(title, UiTypography.SIZE_SECTION)
	title.add_theme_color_override("font_color", PALE_GOLD)
	header.add_child(title)
	var subtitle := _caption_label(subtitle_text)
	subtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Section names already say what each group does; taglines only add noise.
	subtitle.visible = false
	header.add_child(subtitle)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 2)
	stack.add_child(rows)
	panel.set_meta("header", header)
	panel.set_meta("rows", rows)
	return panel

# Section captions and row details share one secondary-text style.
func _caption_label(text: String) -> Label:
	var caption := Label.new()
	caption.text = text
	caption.add_theme_font_override("font", TEXT_FONT)
	UiTypography.set_label_size(caption, UiTypography.SIZE_SMALL)
	caption.add_theme_color_override("font_color", MUTED_TEXT)
	return caption

func _add_volume_row(rows: VBoxContainer, title: String, detail: String, key: String) -> void:
	var control := HBoxContainer.new()
	control.custom_minimum_size = Vector2(CONTROL_WIDTH, 38.0)
	control.add_theme_constant_override("separation", 10)
	var slider := VolumeSlider.new(_ui_skin)
	slider.focus_neighbor_left = NodePath(".")
	slider.focus_neighbor_right = NodePath(".")
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.custom_minimum_size = Vector2(214.0, 38.0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(52.0, 38.0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.add_theme_font_override("font", UI_FONT)
	UiTypography.set_label_size(value_label, UiTypography.SIZE_BODY)
	value_label.add_theme_color_override("font_color", PALE_GOLD)
	slider.value_changed.connect(_on_volume_changed.bind(key, value_label))
	control.add_child(slider)
	control.add_child(value_label)
	_controls[key] = {"slider": slider, "label": value_label}
	rows.add_child(_setting_row(title, detail, control))

func _setting_row(title_text: String, detail_text: String, setting_control: Control) -> PanelContainer:
	var row := PanelContainer.new()
	var content: HBoxContainer = _row_frame(row)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 1)
	content.add_child(copy)
	copy.add_child(_row_title(title_text))
	copy.add_child(_caption_label(detail_text))
	setting_control.custom_minimum_size.x = maxf(setting_control.custom_minimum_size.x, CONTROL_WIDTH)
	setting_control.size_flags_horizontal = Control.SIZE_SHRINK_END
	setting_control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	content.add_child(setting_control)
	return row

# Every settings row shares this frame; returns the row's content line.
func _row_frame(row: PanelContainer) -> HBoxContainer:
	row.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	row.add_theme_stylebox_override("panel", _row_style())
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 13)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_right", ROW_MARGIN_RIGHT)
	margin.add_theme_constant_override("margin_bottom", 7)
	row.add_child(margin)
	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", ROW_SEPARATION)
	margin.add_child(content)
	return content

func _row_title(text: String) -> Label:
	var title := Label.new()
	title.text = text
	title.add_theme_font_override("font", UI_FONT)
	UiTypography.set_label_size(title, UiTypography.SIZE_BODY_LARGE)
	title.add_theme_color_override("font_color", Color("f3e7cc"))
	return title

func _option_control() -> OptionButton:
	var option := OptionButton.new()
	option.custom_minimum_size = Vector2(CONTROL_WIDTH, 44.0)
	_ui_skin.apply_button_stylebox_overrides(option, UiSkin.VARIANT_STANDARD)
	_ui_skin.apply_button_text_overrides(option)
	UiTypography.set_option_button_size(option, UiTypography.SIZE_BODY)
	option.alignment = HORIZONTAL_ALIGNMENT_CENTER
	option.add_theme_constant_override("arrow_margin", 12)
	option.set_meta("settings_text_centered", true)
	preload("res://scripts/controller_option_navigation.gd").install(option)
	return option

func _style_button(
	button: Button,
	width: float,
	font_color: Color = Color("efe4c1"),
	variant: String = UiSkin.VARIANT_STANDARD
) -> void:
	_ui_skin.apply_button_stylebox_overrides(button, variant)
	_ui_skin.apply_button_text_overrides(button, font_color)
	UiTypography.apply_button_role(button, UiTypography.ROLE_BODY)
	_ui_skin.apply_button_native_size(button, UiSkin.BUTTON_HEIGHT_STANDARD, width, false, variant)
	button.custom_minimum_size.x = width
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.set_meta("settings_text_centered", true)

func _sync_controls_from_settings() -> void:
	if _controls.is_empty():
		return
	_syncing = true
	for key: String in ["master_volume", "music_volume", "sfx_volume", "ui_volume"]:
		var volume_controls: Dictionary = _controls.get(key, {})
		var slider: HSlider = volume_controls.get("slider")
		var value_label: Label = volume_controls.get("label")
		if slider != null:
			slider.value = float(_settings.get(key, 1.0))
		if value_label != null:
			value_label.text = _percent_text(float(_settings.get(key, 1.0)))
	_select_option_value(_controls.get("mute_in_background") as OptionButton, _settings.get("mute_in_background"))
	_select_option_value(_controls.get("display_mode") as OptionButton, _settings.get("display_mode"))
	_select_option_value(_controls.get("ui_scale") as OptionButton, _settings.get("ui_scale"))
	_select_option_value(_controls.get("edge_smoothing") as OptionButton, _settings.get("edge_smoothing"))
	_select_option_value(_controls.get("dialogue_speed") as OptionButton, _settings.get("dialogue_speed"))
	_select_option_value(_controls.get("board_health_bars") as OptionButton, _settings.get("board_health_bars"))
	_select_option_value(_controls.get("combat_speed") as OptionButton, _settings.get("combat_speed"))
	var reduced_button: Button = _controls.get("reduced_motion") as Button
	if reduced_button != null:
		reduced_button.button_pressed = bool(_settings.get("reduced_motion", false))
		_update_reduced_motion_button(reduced_button)
	var vibration_button: Button = _controls.get("controller_vibration") as Button
	if vibration_button != null:
		vibration_button.set_pressed_no_signal(SettingsStore.controller_vibration_enabled(_settings))
		vibration_button.text = "On" if vibration_button.button_pressed else "Off"
	_sync_keycaps()
	_syncing = false

func _sync_keycaps() -> void:
	for action: String in _keycaps:
		var listening: bool = action == _listening_action
		var key_label: String = KeyBindings.label(action)
		var button: Button = _keycaps[action]
		button.set_binding_text(LISTENING_TEXT if listening else (CONTROLS_NONE_TEXT if key_label.is_empty() else key_label), listening)
	_align_controls_column(_key_pointer_cells)
	_restore_keys.disabled = _settings.get(KeyBindings.SETTING, KeyBindings.defaults()) == KeyBindings.defaults()

func _listen_for_key(action: String) -> void:
	if _confirmation_panel.visible: return
	_listening_action = action
	_sync_keycaps()

func _on_panel_visibility_changed() -> void:
	if not is_visible_in_tree():
		_listening_action = ""
		_rebind_trigger = null
		_sync_keycaps()

func _handle_rebind_input(event: InputEvent) -> bool:
	# Consume the ending press's release and echoes as well. In particular
	# an Escape release must not escape the panel or a keycap activate twice.
	if _matches_rebind_trigger(event):
		if not event.is_pressed():
			_rebind_trigger = null
			return true
		if event.is_echo(): return true
		_rebind_trigger = null
	if _listening_action.is_empty(): return false
	if event is InputEventMouseButton:
		if event.pressed and event.button_index not in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
			_finish_key_prompt(event)
		return true
	if InputRouterScript.is_controller_event(event):
		if event is InputEventJoypadButton and event.is_action_pressed("ui_cancel"):
			_finish_key_prompt(event)
		return true
	if not event is InputEventKey: return false
	if not event.pressed or event.echo: return true
	var physical: Key = KeyBindings.event_physical_key(event)
	if physical == KEY_ESCAPE:
		_finish_key_prompt(event)
	elif physical in [KEY_BACKSPACE, KEY_DELETE]:
		_rebind_key(event, KEY_NONE)
	elif KeyBindings.can_bind(physical):
		_rebind_key(event, physical)
	return true

func _matches_rebind_trigger(event: InputEvent) -> bool:
	if _rebind_trigger == null: return false
	if _rebind_trigger is InputEventKey:
		return event is InputEventKey and KeyBindings.event_physical_key(event) == KeyBindings.event_physical_key(_rebind_trigger)
	return event.is_match(_rebind_trigger, false)

func _is_other_keycap_accept(event: InputEvent) -> bool:
	# The native accept action also includes Space. Only Enter starts the
	# keyboard capture, so Space remains available to bind once listening.
	return (
		event is InputEventKey and event.is_action("ui_accept")
		and get_viewport().gui_get_focus_owner() is KeyButton
		and KeyBindings.event_physical_key(event) not in [KEY_ENTER, KEY_KP_ENTER]
	)

func _finish_key_prompt(event: InputEvent) -> void:
	_rebind_trigger = event
	_listening_action = ""
	_sync_keycaps()

func _rebind_key(event: InputEvent, physical: Key) -> void:
	var action: String = _listening_action
	_rebind_trigger = event
	_listening_action = ""
	var bindings: Dictionary = SettingsStore.load_settings()[KeyBindings.SETTING]
	var conflict: String = KeyBindings.swap_binding(bindings, action, physical)
	_commit_change(KeyBindings.SETTING, bindings, "Saved automatically")
	if not conflict.is_empty():
		_keycaps[action].play_swap_pulse()
		_keycaps[conflict].play_swap_pulse()

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
	_commit_change(key, value, "Audio updated")

func _on_option_selected(index: int, key: String, option: OptionButton) -> void:
	if _syncing or index < 0:
		return
	var status: String = "Display updated" if key in ["display_mode", "ui_scale", "edge_smoothing", "board_health_bars"] else "Dialogue updated"
	if key == "mute_in_background":
		status = "Audio updated"
	elif key == "combat_speed":
		status = "Saved automatically"
	_commit_change(key, option.get_item_metadata(index), status)

func _on_reduced_motion_toggled(enabled: bool) -> void:
	var button: Button = _controls.get("reduced_motion") as Button
	_update_reduced_motion_button(button)
	if _syncing:
		return
	_commit_change("reduced_motion", enabled, "Motion preference updated")

func _update_reduced_motion_button(button: Button) -> void:
	if button == null:
		return
	button.text = "On — Less Motion" if button.button_pressed else "Off — Full Motion"

func _on_controller_vibration_toggled(enabled: bool, button: Button) -> void:
	button.text = "On" if enabled else "Off"
	if _syncing:
		return
	_commit_change("controller_vibration", enabled, "Saved automatically")

func _commit_change(key: String, value: Variant, status: String) -> void:
	# A settings file update can arrive while the panel is open.
	_settings = SettingsStore.load_settings()
	_settings[key] = value
	_settings = SettingsStore.normalize_settings(_settings)
	SettingsStore.save_preferences(_settings)
	_set_save_status(status)
	SettingsStore.apply_settings(_settings, get_window())
	_sync_controls_from_settings()
	settings_changed.emit(_settings.duplicate(true))

func _show_restore_confirmation(keys_only: bool = false) -> void:
	_confirming_key_restore = keys_only
	_confirmation_title.text = "Restore default keys?" if keys_only else "Reset every setting?"
	_confirmation_confirm.text = "Restore Keys" if keys_only else "Reset All"
	_confirmation_panel.visible = true
	_focus_restore_confirmation()
	_footer_actions.visible = false
	_set_status("Confirmation required", true)

func _focus_restore_confirmation() -> void:
	_confirmation_return_focus = get_viewport().gui_get_focus_owner()
	for node: Node in find_children("*", "Control", true, false):
		var control := node as Control
		if _confirmation_panel.is_ancestor_of(control) or control.focus_mode == Control.FOCUS_NONE: continue
		_confirmation_focus_modes[control] = control.focus_mode
		control.focus_mode = Control.FOCUS_NONE
	_confirmation_cancel.grab_focus()

func _dismiss_restore_confirmation() -> void:
	if _confirmation_panel != null:
		_confirmation_panel.visible = false
	if _footer_actions != null:
		_footer_actions.visible = true
	var router: Node = get_node_or_null("/root/InputRouter")
	_release_confirmation_focus(router != null and bool(router.call("using_controller")))

func _release_confirmation_focus(restore: bool) -> void:
	for control: Control in _confirmation_focus_modes:
		if is_instance_valid(control): control.focus_mode = _confirmation_focus_modes[control]
	_confirmation_focus_modes.clear()
	if restore and is_instance_valid(_confirmation_return_focus) and _confirmation_return_focus.is_visible_in_tree():
		_confirmation_return_focus.grab_focus()
	_confirmation_return_focus = null

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree(): return
	if _handle_rebind_input(event) or _is_other_keycap_accept(event):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and not contains_pointer_position(event.position):
		# The menu backdrop blocks GUI input. Stop new outside presses before
		# cursor audio, and let releases through to finish an in-panel drag.
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT and _confirmation_panel != null and _confirmation_panel.visible:
				_cancel_restore_confirmation()
			get_viewport().set_input_as_handled()
		return
	var router: Node = get_node_or_null("/root/InputRouter")
	if router != null: router.call("record_input_activity", event)
	if _confirmation_panel != null and _confirmation_panel.visible:
		# Settings owns Back until its confirmation closes, before the parent
		# menu can dismiss Settings or keyboard input releases controller focus.
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed(InputRouterScript.ACTION_CANCEL):
			_cancel_restore_confirmation()
			get_viewport().set_input_as_handled()
			return
		if event is InputEventKey or event is InputEventMouseButton:
			_release_confirmation_focus(false)
		elif router != null and bool(router.call("using_controller")) and (event is InputEventJoypadButton or event is InputEventJoypadMotion) and _confirmation_focus_modes.is_empty():
			_focus_restore_confirmation()
	# D-pad volume changes use the authored slider step; analog repeats share
	# the native focus adapter used by the other screens.
	var slider: HSlider = get_viewport().gui_get_focus_owner() as HSlider
	if slider != null and is_ancestor_of(slider) and not _confirmation_panel.visible and event is InputEventJoypadButton:
		var direction: int = int(event.is_action_pressed("ui_right")) - int(event.is_action_pressed("ui_left"))
		if direction != 0:
			slider.value += direction * slider.step
			get_viewport().set_input_as_handled()
			return

func _cancel_restore_confirmation() -> void:
	_dismiss_restore_confirmation()
	_set_save_status("Saved automatically")

func _confirm_restore_defaults() -> void:
	if _confirming_key_restore:
		_dismiss_restore_confirmation()
		_commit_change(KeyBindings.SETTING, KeyBindings.defaults(), "Defaults restored")
		return
	_settings = SettingsStore.restore_defaults(get_window())
	_sync_controls_from_settings()
	_dismiss_restore_confirmation()
	_set_save_status("Defaults restored")
	settings_changed.emit(_settings.duplicate(true))

func _on_back_pressed() -> void:
	_dismiss_restore_confirmation()
	back_requested.emit()

func _set_save_status(success_text: String) -> void:
	var failed: bool = SettingsStore.has_unsaved_preferences()
	_set_status("Could not save" if failed else success_text, failed)

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

func _build_demo_links() -> void:
	if not DemoBuild.is_demo():
		return
	# A free-layout child avoids changing the existing header's minimum size.
	var layer := Control.new()
	layer.name = "DemoHeaderLinks"
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer)
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for action: String in ["wishlist", "discord"]:
		var link := DemoEndPanel.make_link(action)
		layer.add_child(link)
		_demo_links.append(link)
	var audio: Control = _controls["master_volume"]["slider"] as Control
	audio.focus_neighbor_top = audio.get_path_to(_demo_links[0])
	for index: int in range(_demo_links.size()):
		var link: Button = _demo_links[index]
		var other: Button = _demo_links[1 - index]
		link.focus_neighbor_left = link.get_path_to(other)
		link.focus_neighbor_right = link.get_path_to(other)
		link.focus_neighbor_top = link.get_path_to(link)
		link.focus_neighbor_bottom = link.get_path_to(audio)
	resized.connect(_layout_demo_links)
	call_deferred("_layout_demo_links")

func _layout_demo_links() -> void:
	var right: float = size.x - 30.0
	for index: int in range(_demo_links.size() - 1, -1, -1):
		var link: Button = _demo_links[index]
		right -= link.size.x
		link.position = Vector2(right, 30.0)
		right -= 32.0
