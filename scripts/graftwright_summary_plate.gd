extends Control

const Palette = preload("res://scripts/ui_palette.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const GildedFrame = preload("res://scripts/ui_gilded_frame.gd")

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func setup(carried: String, replaced: String, violet: Color, rose: Color) -> void:
	var rows := PackedStringArray(["GRAFT", carried, "replaces", replaced])
	for i: int in range(rows.size()):
		var label := Label.new()
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.name = ["GraftEyebrow", "CarriedName", "ReplacesEyebrow", "ReplacedName"][i]
		label.text = rows[i]
		label.position = Vector2(10, 8 + i * 23)
		label.size = Vector2(size.x - 20, 23)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(label)
		if i % 2 == 0:
			Typography.apply_eyebrow(label, 14, violet if i == 0 else Palette.TEXT_2)
		else:
			Typography.apply_label_role(label, Typography.ROLE_BODY_LARGE)
			Typography.set_label_size(label, 18)
			label.add_theme_color_override("font_color", violet if i == 1 else rose)
			label.size.y = label.get_line_count() * label.get_line_height()
	_layout_rows()

func _layout_rows() -> void:
	var top: float = 8.0
	for child: Node in get_children():
		var label := child as Label
		label.position.y = top
		top += maxf(23, label.size.y)
	size.y = maxf(size.y, top + 8)
	queue_redraw()

func _draw() -> void:
	GildedFrame.draw_panel(self, Rect2(Vector2.ZERO, size), {
		"top": Color(Palette.INK_2, 0.9), "bottom": Color(Palette.INK_0, 0.85),
		"corner_studs": false, "shadow_spread": Typography.scaled_value(self, 8.0),
	})
