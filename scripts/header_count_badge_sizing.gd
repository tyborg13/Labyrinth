extends RefCounted

const Typography = preload("res://scripts/ui_typography.gd")
static func fit(badge: PanelContainer, label: Label, previous_size: Vector2, previous_font_size: int) -> void:
	# Keep the authored single-digit padding, growing away from the same top-right
	# anchor. Read the inherited font only after the badge joins the HUD tree.
	var font: Font = label.get_theme_font("font")
	previous_font_size = Typography.scaled_size(label, previous_font_size)
	var font_size: int = label.get_theme_font_size("font_size")
	var previous_width: float = font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, previous_font_size).x
	var width: float = font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var right_edge: float = badge.position.x + badge.size.x
	badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	badge.custom_minimum_size = previous_size + Vector2(width - previous_width, font.get_height(font_size) - font.get_height(previous_font_size))
	badge.size = badge.custom_minimum_size
	badge.position.x = right_edge - badge.size.x
