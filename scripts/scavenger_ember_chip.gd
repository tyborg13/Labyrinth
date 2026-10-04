extends "res://scripts/ui_stat_chip.gd"

func _layout() -> void:
	super._layout()
	Typography.set_label_size(_value, 26)
	_value.size = _value.get_minimum_size()
	_value.position.y = floorf((size.y - _value.size.y) * 0.5)
	var value_ascent: float = _value.get_theme_font("font").get_ascent(_value.get_theme_font_size("font_size"))
	var caption_ascent: float = _caption.get_theme_font("font").get_ascent(_caption.get_theme_font_size("font_size"))
	_caption.position = Vector2(_value.position.x + _value.size.x + Typography.scaled_value(self, 8.0), _value.position.y + value_ascent - caption_ascent)
