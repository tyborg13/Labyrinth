extends "res://scripts/combat_board_view.gd"

## The run scene's board creates its retained children with get_script().
## Keep the normal paint paths and record the geometry they actually submit.
var submitted_body: Rect2
var submitted_shadow: Rect2
var submitted_health: Dictionary = {}
var _drawing_body: bool = false

func _draw() -> void:
	_drawing_body = _render_layer_kind == "unit_body_outline"
	submitted_body = Rect2()
	submitted_shadow = Rect2()
	submitted_health.clear()
	super._draw()
	_drawing_body = false

func _unit_texture_draw_rect(unit: Dictionary, center: Vector2, body_scale: float = 1.0, align_pixels: bool = true) -> Rect2:
	var rect: Rect2 = super._unit_texture_draw_rect(unit, center, body_scale, align_pixels)
	if has_meta("rd03_canvas") and get_parent().get("_render_layer_kind") == "unit_body_outline":
		submitted_body = rect
	return rect

func _draw_contact_pool(center: Vector2, width: float, height: float, alpha: float) -> void:
	if _drawing_body:
		var extent := Vector2(width, height)
		submitted_shadow = Rect2(center - extent * 0.5, extent)
	super._draw_contact_pool(center, width, height, alpha)

func _draw_iso_ground_shadow(center: Vector2, width: float, height: float, skew: float, alpha: float) -> void:
	if _drawing_body:
		var extent := Vector2(width, height)
		submitted_shadow = Rect2(center - extent * 0.5, extent)
	super._draw_iso_ground_shadow(center, width, height, skew, alpha)

func _draw_health_bar(unit: Dictionary, rect: Rect2, bar_alpha: float = 1.0) -> void:
	submitted_health[str(unit.get("key", ""))] = rect
	super._draw_health_bar(unit, rect, bar_alpha)
