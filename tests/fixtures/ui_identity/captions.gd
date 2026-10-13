extends Control

var font_size: int = 13 # SITE_R6
var label_font_size := 12 # SITE_R6
const CAPTION_FONT_SIZE = 11 # SITE_R6
var large_font_size = 14
var fractional_font_size = 13.0
var dynamic_font_size = chosen_size
var computed_font_size = 10 + 4
var not_a_font_sizes = 9

func _draw() -> void:
	draw_string(font, pos, "1, 2, 3", ALIGNMENT, -1, 13) # SITE_R6
	draw_multiline_string( # SITE_R6
		font, Vector2(1, 2), "font_size = 1",
		ALIGNMENT, -1,
		12, -1, colour
	)
	label.add_theme_font_size_override("font_size", 11) # SITE_R6
	draw_string(font, pos, text, ALIGNMENT, -1, 14)
	draw_multiline_string(font, pos, text, ALIGNMENT, -1, 20, 10)
	draw_string(font, pos, text, ALIGNMENT, 10, 20)
	draw_string(font, pos, text, ALIGNMENT, -1, size)
	label.add_theme_font_size_override("font_size", 13 + 1)
	font_size = +12 # SITE_R6
	font_size = 0x0d # SITE_R6
	font_size = 0b1101 # SITE_R6
	font_size = 1_3 # SITE_R6
	font_size = -1 # SITE_R6
	label.font_size = 9 # SITE_R6
