extends Control

const Palette = preload("res://scripts/ui_palette.gd")
const HEALTH_SIZE_RATIO: float = 0.62
const BASELINE_ABOVE_BAR: float = 2.0
var text: String
var font: Font
var font_size: int
var outline_color: Color
var outline_size: int

func configure(entry: Dictionary, bar: Control, time_numeral: Label) -> void:
	name = "TurnOrderHealthNumeral"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = time_numeral.z_index
	font = time_numeral.get_theme_font("font")
	font_size = roundi(time_numeral.get_theme_font_size("font_size") * HEALTH_SIZE_RATIO)
	outline_color = time_numeral.get_theme_color("font_outline_color")
	outline_size = time_numeral.get_theme_constant("outline_size")
	text = "%d/%d" % [int(entry.get("hp", 0)), int(entry.get("max_hp", 1))] if str(entry.get("kind", "")) == "player" else str(int(entry.get("hp", 0)))
	position = bar.position
	size = bar.size
	queue_redraw()

func _draw() -> void:
	var origin := Vector2(size.x - font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x, -BASELINE_ABOVE_BAR)
	draw_string_outline(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline_size, outline_color)
	draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Palette.TEXT)
