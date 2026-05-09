extends RefCounted
class_name UiTooltipPanel

const UiTypography = preload("res://scripts/ui_typography.gd")

const TITLE_COLOR: Color = Color("fff0d1")
const BODY_COLOR: Color = Color("dcc7a6")
const OUTLINE_COLOR: Color = Color("2c1f16")
const PANEL_COLOR: Color = Color(0.12, 0.08, 0.055, 0.98)
const BORDER_COLOR: Color = Color("c79652")
const MIN_PANEL_WIDTH: float = 250.0
const MAX_BODY_WIDTH: float = 340.0

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
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = Vector2(MIN_PANEL_WIDTH, 0.0)
	panel.add_theme_stylebox_override("panel", _panel_style())

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)
	var title_text: String = title.strip_edges()
	if not title_text.is_empty():
		var title_label := Label.new()
		title_label.text = title_text.to_upper()
		title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title_label.custom_minimum_size = Vector2(MAX_BODY_WIDTH, 0.0)
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
		body_label.custom_minimum_size = Vector2(MAX_BODY_WIDTH, 0.0)
		UiTypography.set_label_size(body_label, UiTypography.SIZE_BODY)
		body_label.add_theme_color_override("font_color", BODY_COLOR)
		body_label.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
		body_label.add_theme_constant_override("outline_size", 1)
		vbox.add_child(body_label)
	return panel

static func _panel_style() -> StyleBoxFlat:
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
	style.content_margin_left = 16.0
	style.content_margin_top = 14.0
	style.content_margin_right = 16.0
	style.content_margin_bottom = 14.0
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.0)
	style.shadow_size = 0
	style.shadow_offset = Vector2.ZERO
	return style
