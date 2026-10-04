extends VBoxContainer

var enemy_name: Label
var compact: bool = false
var height_budget: float = 0.0
var compact_font_size: int = 17

func _ready() -> void:
	sort_children.connect(_fit_height)

func _fit_height() -> void:
	if enemy_name == null or size.x <= 0.0:
		return
	if compact and get_minimum_size().y > height_budget and enemy_name.get_theme_font_size("font_size") > compact_font_size:
		enemy_name.add_theme_font_size_override("font_size", compact_font_size)
		return
	offset_bottom = offset_top + get_minimum_size().y
