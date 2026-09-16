extends Button
## Native input/focus with object-specific art, never a stretched action skin.

signal inspect_requested

var card_face: Control
var kind: String = "quiet"
var accent := Color("cfa2f7")
var chosen: bool = false
var muted: bool = false
var reduced_motion: bool = false
var face_size := Vector2.ZERO
var artwork: Control
var _lift: float = 0.0
var keyboard_navigation: bool = false
var _pressed_visual: bool = false

func _ready() -> void:
	for state_name: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state_name, StyleBoxEmpty.new())
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_ALL

func art() -> Control:
	if artwork == null:
		artwork = Control.new()
		artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(artwork)
	return artwork

func interaction_active() -> bool:
	# Automatic focus is a navigation destination, not a pointer hover. Otherwise
	# the first button/card is already raised before the mouse ever reaches it.
	return not disabled and (is_hovered() or (has_focus() and (keyboard_navigation or controller_focus_visible())))

func _process(delta: float) -> void:
	var active: bool = interaction_active()
	_pressed_visual = not disabled and is_pressed()
	var next: float = -2.0 if _pressed_visual else 6.0 if active else 1.5 if chosen else 0.0
	_lift = 0.0 if reduced_motion else lerpf(_lift, next, minf(1.0, delta * 24.0))
	if artwork != null:
		artwork.position.y = -_lift
		artwork.modulate = Color(0.79, 0.73, 0.86, 1.0) if _pressed_visual else Color(1.24, 1.17, 1.29, 1.0) if active else Color(1, 1, 1, 0.58 if disabled or muted else 1.0)
	queue_redraw()

func _draw() -> void:
	var extent: Vector2 = face_size if face_size != Vector2.ZERO else size
	var rect := Rect2(Vector2(0, -_lift), extent)
	var active: bool = interaction_active()
	if kind == "card":
		var shadow := StyleBoxFlat.new()
		shadow.bg_color = Color(0.025, 0.015, 0.028, 0.8)
		shadow.set_corner_radius_all(9)
		shadow.shadow_color = Color(0, 0, 0, 0.85)
		shadow.shadow_size = 12 + int(_lift)
		shadow.shadow_offset = Vector2(0, 8 + _lift)
		draw_style_box(shadow, rect)
		if chosen or active:
			var glow := StyleBoxFlat.new()
			glow.bg_color = Color.TRANSPARENT
			glow.set_corner_radius_all(8)
			glow.set_border_width_all(2)
			glow.border_color = accent.lerp(Color("fff1d5"), 0.45) if active else accent
			glow.shadow_color = Color(accent, 0.55 if active else 0.36)
			glow.shadow_size = 13
			draw_style_box(glow, rect.grow(3))
	if controller_focus_visible() and kind in ["card", "equipment", "action"]:
		var color: Color = Color("fff1d5") if active else accent
		var r: Rect2 = rect.grow(5)
		var length: float = 17.0
		for corner: Vector2 in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
			var sx: float = 1.0 if corner.x == r.position.x else -1.0
			var sy: float = 1.0 if corner.y == r.position.y else -1.0
			draw_polyline(PackedVector2Array([corner + Vector2(0, sy * length), corner, corner + Vector2(sx * length, 0)]), color, 2.0, true)
	if kind in ["quiet", "tab"]:
		if active or chosen:
			draw_rect(rect, Color(accent, 0.23 if _pressed_visual else 0.15 if active else 0.08))
			draw_line(Vector2(0, rect.end.y), rect.end, accent, 2.0, true)
		if controller_focus_visible(): draw_rect(rect.grow(2), Color("fff1d5"), false, 1.5)

func _gui_input(event: InputEvent) -> void:
	if card_face == null: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		inspect_requested.emit()
		accept_event()

func _get_tooltip(at_position: Vector2) -> String:
	# Preserve the shared icon explanations without repeating the card's whole
	# description on hover, focus, or selection.
	if card_face != null: return str(card_face.call("_get_tooltip", at_position))
	return ""

func _make_custom_tooltip(for_text: String) -> Object:
	if card_face != null: return card_face.call("_make_custom_tooltip", for_text)
	return null

func controller_focus_visible() -> bool:
	if disabled or not has_focus(): return false
	var router: Node = get_node_or_null("/root/InputRouter")
	return router != null and bool(router.call("using_controller"))
