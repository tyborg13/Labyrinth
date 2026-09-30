extends Control

# A short ornamental divider (line - diamond - line) in the shared gilded style.

const GildedFrame = preload("res://scripts/ui_gilded_frame.gd")
const Palette = preload("res://scripts/ui_palette.gd")

var accent: Color = Palette.GOLD:
	set(value):
		accent = value
		queue_redraw()
var span_ratio: float = 0.46

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	if size.x <= 0.0:
		return
	var half: float = size.x * span_ratio * 0.5
	var center := Vector2(size.x * 0.5, size.y * 0.5)
	GildedFrame.draw_rule(self, center - Vector2(half, 0.0), center + Vector2(half, 0.0), accent, 1.0)
