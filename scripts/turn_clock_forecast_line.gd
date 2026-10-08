extends Label

# Keep the existing Label/text contract, but paint each cell in its own ink.
# This also seats the Time icon within the same centred, measured line.
const ActionIcons = preload("res://scripts/action_icon_library.gd")
const UiTypography = preload("res://scripts/ui_typography.gd")
const UiPalette = preload("res://scripts/ui_palette.gd")
const ICON_SIZE := 15.0
var _cells: Array[Dictionary]
var _wait_time: int = 0
var _time_icon: Texture2D

func _init() -> void:
	name = "PassPreviewForecastLine"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_text = false
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiTypography.set_label_size(self, UiTypography.SIZE_SMALL)
	add_theme_color_override("font_color", Color.TRANSPARENT)
	add_theme_color_override("font_outline_color", Color.TRANSPARENT)
	resized.connect(queue_redraw)

func configure(wait_time: int, entries: Array[Dictionary]) -> void:
	_wait_time = wait_time
	_time_icon = ActionIcons.icon_texture("time") if wait_time > 0 else null
	_cells.clear()
	var lead_color: Color = UiPalette.TEXT
	for index: int in range(entries.size() - 1, -1, -1):
		if not bool(entries[index].get("suffix", false)):
			lead_color = entries[index].get("color", UiPalette.TEXT)
			break
	if wait_time > 0:
		lead_color = UiPalette.GOLD_BRIGHT
	_cells.append({"text": "+%d" % wait_time if wait_time > 0 else "TURN END", "color": lead_color})
	for entry: Dictionary in entries:
		_cells.append({"text": " " if bool(entry.get("suffix", false)) else "  •  ", "color": lead_color})
		_cells.append({"text": str(entry.get("text", "")), "color": entry.get("color", UiPalette.TEXT)})
	var parts := PackedStringArray()
	for cell: Dictionary in _cells:
		parts.append(str(cell["text"]))
	text = "".join(parts)
	set_meta("pass_preview_values", entries.duplicate(true))
	set_meta("pass_preview_wait_time", wait_time)
	queue_redraw()

func content_width() -> float:
	var width: float = ICON_SIZE + 4.0 if _wait_time > 0 else 0.0
	var font: Font = get_theme_font("font")
	for cell: Dictionary in _cells:
		width += font.get_string_size(str(cell["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, UiTypography.SIZE_SMALL).x
	return width

func _draw() -> void:
	var font: Font = get_theme_font("font")
	var font_size: int = UiTypography.SIZE_SMALL
	var x: float = (size.x - content_width()) * 0.5
	var baseline: float = (size.y - font.get_height(font_size)) * 0.5 + font.get_ascent(font_size)
	if _wait_time > 0:
		if _time_icon != null:
			draw_texture_rect(_time_icon, Rect2(x, (size.y - ICON_SIZE) * 0.5, ICON_SIZE, ICON_SIZE), false)
		x += ICON_SIZE + 4.0
	for cell: Dictionary in _cells:
		var value: String = str(cell["text"])
		font.draw_string_outline(get_canvas_item(), Vector2(x, baseline), value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 3, Color("200806"))
		font.draw_string(get_canvas_item(), Vector2(x, baseline), value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, cell["color"])
		x += font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
