extends "res://scripts/ui_card_strip.gd"

# Character's compact lists keep the shared strip's fitting and typography.
# Only a name that would have used 13px grows its own strip to fit at 14px;
# HFlowContainer then reflows it inside the existing column.
var enforce_caption_floor: bool = false
var _caption_floor_width: float = 0.0

func _layout() -> void:
	super._layout()
	custom_minimum_size.x = maxf(custom_minimum_size.x, _caption_floor_width)

func _fit_name() -> void:
	super._fit_name()
	if not enforce_caption_floor or _name.get_theme_font_size("font_size") >= Typography.SIZE_CAPTION:
		return
	Typography.set_label_size(_name, Typography.SIZE_CAPTION)
	var font: Font = _name.get_theme_font("font")
	var text_width: float = font.get_string_size(_name.text, HORIZONTAL_ALIGNMENT_LEFT, -1, _name.get_theme_font_size("font_size")).x
	_caption_floor_width = maxf(_caption_floor_width, ceilf(size.x + text_width - _name.size.x))
