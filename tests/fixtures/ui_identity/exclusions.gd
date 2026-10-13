extends Control

# StyleBoxFlat.new(); Color("abc"); draw_rect(r, c, false)
# SegmentedHealthBar.draw_bar(); FontVariation.new(); font_size = 1
# draw_string(f, p, s, a, -1, 12); load("res://fonts/Family.tres")
var double = "StyleBoxFlat.new(); Color(0.1, 0.2, 0.3); draw_rect(r, c, false)"
var single = 'SegmentedHealthBar.draw_bar(); FontVariation.new(); font_size = 1'
var escaped = "escaped \"Color(0.1, 0.2, 0.3)\" # get_theme_default_font()"
var multiline = """
StyleBoxFlat.new()
Color("abc")
draw_multiline_string(f, p, s, a, -1, 12)
load("res://fonts/Family.tres")
font_size = 12
"""
var other_multiline = '''
SegmentedHealthBar.draw_bar()
FontVariation.new()
'''

func _ready() -> void:
	var white = Color(1, 1, 1, opacity)
	var black = Color(0, 0, 0, clampf(opacity, 0, 1))
	var decimal_white = Color(1.0, 1.0, 1.0, 0.5)
	var decimal_black = Color(0.0, 0.0, 0.0, 1.0)
	var conditional_white = Color(1, 1, 1, 0.5 if active else 1.0)
	var multiline_neutral = Color(
		0, 0, 0,
		compute_alpha({"keys": [1, 2]}),
	)
	var token = Color(Palette.GOLD, opacity)
