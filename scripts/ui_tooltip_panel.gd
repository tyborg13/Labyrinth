extends RefCounted
class_name UiTooltipPanel

const UiTypography = preload("res://scripts/ui_typography.gd")
const UiSkin = preload("res://scripts/ui_skin.gd")

const TITLE_COLOR: Color = Color("fff0d1")
const BODY_COLOR: Color = Color("dcc7a6")
const OUTLINE_COLOR: Color = Color("2c1f16")
const PANEL_COLOR: Color = Color(0.12, 0.08, 0.055, 0.98)
const BORDER_COLOR: Color = Color("c79652")
const MIN_PANEL_WIDTH: float = 250.0
const MAX_BODY_WIDTH: float = 340.0
const ICON_TOOLTIP_WIDTH: float = 306.0
const ICON_SIZE: float = 42.0
const ICON_BODY_WIDTH: float = 226.0

static func make_text(text: String) -> PanelContainer:
	var lines: PackedStringArray = text.split("\n", false)
	if lines.is_empty():
		return make_lines(text.strip_edges(), PackedStringArray())
	var title: String = lines[0].strip_edges()
	var body_lines := PackedStringArray()
	for index: int in range(1, lines.size()):
		var body_line: String = lines[index].strip_edges()
		if not body_line.is_empty():
			body_lines.append(body_line)
	return make_lines(title, body_lines)

static func make_lines(title: String, body_lines: PackedStringArray) -> PanelContainer:
	var panel: PanelContainer = _make_panel(MIN_PANEL_WIDTH, 16.0)
	panel.add_child(_make_text_box(title, body_lines, MAX_BODY_WIDTH, 8))
	_finish_panel(panel)
	return panel

static func make_icon_lines(
	icon_texture: Texture2D,
	title: String,
	body_lines: PackedStringArray
) -> PanelContainer:
	var panel: PanelContainer = _make_panel(ICON_TOOLTIP_WIDTH, 12.0)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)

	var icon := TextureRect.new()
	icon.name = "TooltipIcon"
	icon.texture = icon_texture
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	row.add_child(_make_text_box(title, body_lines, ICON_BODY_WIDTH, 4))
	_finish_panel(panel)
	return panel

static func _make_panel(minimum_width: float, content_margin: float) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = Vector2(minimum_width, 0.0)
	panel.add_theme_stylebox_override("panel", _panel_style(content_margin))
	return panel

static func _make_text_box(
	title: String,
	body_lines: PackedStringArray,
	body_width: float,
	separation: int
) -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", separation)
	var title_text: String = title.strip_edges()
	if not title_text.is_empty():
		var title_label := Label.new()
		title_label.text = title_text.to_upper()
		title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title_label.custom_minimum_size = Vector2(body_width, 0.0)
		UiTypography.set_label_size(title_label, UiTypography.SIZE_BODY_LARGE)
		title_label.add_theme_color_override("font_color", TITLE_COLOR)
		title_label.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
		title_label.add_theme_constant_override("outline_size", 2)
		vbox.add_child(title_label)
	if not body_lines.is_empty():
		var body_label := Label.new()
		body_label.text = "\n".join(body_lines)
		body_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body_label.custom_minimum_size = Vector2(body_width, 0.0)
		UiTypography.set_label_size(body_label, UiTypography.SIZE_BODY)
		body_label.add_theme_color_override("font_color", BODY_COLOR)
		body_label.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
		body_label.add_theme_constant_override("outline_size", 1)
		vbox.add_child(body_label)
	return vbox

static func _finish_panel(panel: PanelContainer) -> void:
	panel.set_meta("tooltip_surface", true)
	panel.set_meta("panel_surface_accent", BORDER_COLOR)
	var skin := UiSkin.new()
	skin.apply_inset_surface(panel, UiSkin.SURFACE_HUD)

static func _panel_style(content_margin: float = 16.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.border_color = BORDER_COLOR
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.content_margin_left = content_margin
	style.content_margin_top = content_margin
	style.content_margin_right = content_margin
	style.content_margin_bottom = content_margin
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.0)
	style.shadow_size = 0
	style.shadow_offset = Vector2.ZERO
	return style
