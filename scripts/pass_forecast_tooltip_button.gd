extends "res://scripts/ui_tooltip_button.gd"

# PASS presents icon rows in its retained in-scene panel for both input
# paths. Keep tooltip_text only for existing semantic consumers.
func _get_tooltip(_at_position: Vector2) -> String:
	return ""

func _make_custom_tooltip(_for_text: String) -> Object:
	return null

# Director 2026-11-11 (ptf-08 r2): the forecast ribbon under PASS is gone, so
# only the drawn button (the top 66 px of the 270x100 chip) takes the pointer.
const BUTTON_ART_HEIGHT: float = 66.0

func _has_point(point: Vector2) -> bool:
	return Rect2(Vector2.ZERO, Vector2(size.x, BUTTON_ART_HEIGHT)).has_point(point)
