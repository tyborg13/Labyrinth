extends VBoxContainer

var enemy_name: Label
var name_font_size: int = 19
var compact_font_size: int = 17
var _measured_width: float = -1.0

func measure(width: float) -> float:
	if not is_equal_approx(width, _measured_width):
		_measured_width = width
		size.x = width
		enemy_name.size.x = width
		enemy_name.add_theme_font_size_override("font_size", name_font_size)
		if enemy_name.get_line_count() > 2:
			enemy_name.add_theme_font_size_override("font_size", compact_font_size)
	return get_combined_minimum_size().y
