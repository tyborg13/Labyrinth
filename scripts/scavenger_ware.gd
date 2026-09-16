extends Button
## A ware is an object on a shelf, with its own small contact shadow and light.
const Materials = preload("res://scripts/scavenger_materials.gd")
var chosen: bool = false
var pack: bool = false
var reduced_motion: bool = false

func _ready() -> void:
	for state_name: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state_name, StyleBoxEmpty.new())
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_ALL

func _process(_delta: float) -> void:
	if not is_visible_in_tree(): return
	queue_redraw()
	var content: Control = get_node_or_null("CenteredOfferContent") as Control
	if content != null:
		content.position.y = 2.0 if is_pressed() and not reduced_motion else 0.0
		content.modulate = Color(0.78, 0.71, 0.60) if is_pressed() else Color.WHITE

func _draw() -> void:
	var active: bool = is_hovered() or has_focus()
	var accent := Color("edbe72")
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color.TRANSPARENT
	frame.set_corner_radius_all(8)
	frame.set_border_width_all(1 if pack or chosen or active else 0)
	frame.border_color = Color(accent, 0.9 if chosen else 0.6 if active else 0.24)
	frame.shadow_color = Color(1.0, 0.52, 0.15, 0.17 if active else 0.09 if chosen else 0.0)
	frame.shadow_size = 16
	if pack: Materials.paint(self, "tray", Rect2(Vector2(3, 2), size - Vector2(6, 4)), Color(0.80, 0.74, 0.63))
	draw_style_box(frame, Rect2(Vector2(5, 4), size - Vector2(10, 8)))
	if chosen:
		draw_line(Vector2(size.x * 0.25, size.y - 2), Vector2(size.x * 0.75, size.y - 2), accent, 3, true)
		var middle := Vector2(size.x * 0.5, size.y - 2)
		draw_colored_polygon(PackedVector2Array([middle + Vector2(-5, 0), middle + Vector2(0, -5), middle + Vector2(5, 0), middle + Vector2(0, 5)]), accent)
