extends Button

const Palette = preload("res://scripts/ui_palette.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const UiSkin = preload("res://scripts/ui_skin.gd")
const Text = preload("res://scripts/event_view_text.gd")
const Gilding = preload("res://scripts/ui_gilded_frame.gd")

var available: bool = true
var choice_id: String = ""
var choice_label: String = ""
var plate: PanelContainer
var rows: Array[RichTextLabel]
var hovered: bool = false
var _skin := UiSkin.new()

func configure(index: int, definition: Dictionary, lines: Array[String], reason: String, effect_size: int) -> void:
	choice_id = str(definition["id"])
	choice_label = str(definition["label"])
	available = reason.is_empty()
	name = "Choice%d" % (index + 1)
	set_meta("event_label", choice_label)
	set_meta("cursor_feedback_context", "action" if available else "invalid")
	tooltip_text = reason
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if available else Control.CURSOR_FORBIDDEN
	focus_mode = Control.FOCUS_ALL
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	plate = PanelContainer.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.INK_2
	for side: int in range(4): style.set_content_margin(side, 0)
	plate.add_theme_stylebox_override("panel", style)
	add_child(plate)
	_skin.apply_choice_finish(plate, Palette.GOLD_DIM)
	var content := Control.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(content)
	var title := Label.new()
	title.text = choice_label
	title.position = Vector2(58, 13)
	title.size.x = 472
	title.add_theme_font_override("font", Typography.ui_font())
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Palette.TEXT if available else Palette.TEXT_2)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(title)
	var y: float = 13 + title.get_minimum_size().y
	for line: String in lines:
		var row: RichTextLabel = Text.label(line, 472, effect_size, Palette.TEXT_2, false, true)
		content.add_child(row)
		row.position = Vector2(58, y + 4)
		y += 4 + Text.height(row)
		rows.append(row)
	if not available:
		var explanation: RichTextLabel = Text.label(reason, 472, 17, Palette.TEXT_3, true)
		content.add_child(explanation)
		explanation.position = Vector2(58, y + 3)
		y += 3 + Text.height(explanation)
		rows.append(explanation)
	custom_minimum_size = Vector2(548, maxf(78, y + 13))
	size = custom_minimum_size
	plate.modulate.a = 1.0 if available else 0.5
	set_meta("key_number", index + 1)
	mouse_entered.connect(func() -> void: hovered = true; refresh_emphasis())
	mouse_exited.connect(func() -> void: hovered = false; refresh_emphasis())
	focus_entered.connect(refresh_emphasis)
	focus_exited.connect(refresh_emphasis)
	# The key disc sits above the retained choice material, under the content.
	content.draw.connect(func() -> void:
		var center := Vector2(29, 27)
		content.draw_circle(center, 13, Palette.INK_1)
		content.draw_arc(center, 13, 0, TAU, 40, Palette.GOLD_DIM, 1, true)
		var font: Font = Typography.ui_font()
		var numeral: String = str(index + 1)
		content.draw_string(font, center + Vector2(-font.get_string_size(numeral, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x * 0.5, 5), numeral, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Palette.GOLD)
	)

func refresh_emphasis() -> void:
	var emphasized: bool = hovered or has_focus()
	_skin.apply_choice_finish(plate, Palette.GOLD_DIM, emphasized, true)
	queue_redraw()

func _draw() -> void:
	if available and (hovered or has_focus()):
		Gilding.draw_glow(self, Rect2(Vector2.ZERO, size), Color(Palette.EMBER, 0.28), 22, 3)
