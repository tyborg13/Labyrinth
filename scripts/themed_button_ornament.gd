extends Control

const STATE_NORMAL: String = "normal"
const STATE_HOVER: String = "hover"
const STATE_PRESSED: String = "pressed"
const STATE_DISABLED: String = "disabled"
const STATE_SELECTED: String = "selected"
const STATE_FOCUS: String = "focus"

const VARIANT_COMPACT: String = "compact"
const VARIANT_DESTRUCTIVE: String = "destructive"
const VARIANT_ICON: String = "icon"
const VARIANT_SELECTED: String = "selected"

var _button: BaseButton
var _variant: String = "standard"

func configure(button: BaseButton, variant: String) -> void:
	_button = button
	_variant = variant
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var redraw := Callable(self, "queue_redraw")
	if not button.draw.is_connected(redraw):
		button.draw.connect(redraw)
	if not button.resized.is_connected(redraw):
		button.resized.connect(redraw)
	queue_redraw()

func set_variant(variant: String) -> void:
	_variant = variant
	queue_redraw()

func _draw() -> void:
	if _button == null or size.x < 20.0 or size.y < 20.0:
		return
	var state: String = _visual_state()
	var accent: Color = _accent_color(state)
	var muted: Color = Color(accent.r, accent.g, accent.b, accent.a * 0.42)
	var inset: float = 4.5 if _variant != VARIANT_COMPACT else 3.5
	var left: float = inset
	var right: float = size.x - inset
	var top: float = inset
	var bottom: float = size.y - inset
	var arm: float = clampf(size.y * 0.23, 6.0, 12.0)
	var stroke: float = 1.0

	# Fine metal inlay: short corner cuts scale cleanly without stretching artwork.
	_draw_corner(Vector2(left, top), Vector2(1.0, 1.0), arm, muted, stroke)
	_draw_corner(Vector2(right, top), Vector2(-1.0, 1.0), arm, muted, stroke)
	_draw_corner(Vector2(left, bottom), Vector2(1.0, -1.0), arm, muted, stroke)
	_draw_corner(Vector2(right, bottom), Vector2(-1.0, -1.0), arm, muted, stroke)

	if _variant != VARIANT_ICON and size.x >= 96.0:
		var rail_inset: float = maxf(arm + 10.0, size.x * 0.18)
		draw_line(Vector2(rail_inset, top), Vector2(size.x - rail_inset, top), Color(accent.r, accent.g, accent.b, accent.a * 0.26), stroke)
		draw_line(Vector2(rail_inset, bottom), Vector2(size.x - rail_inset, bottom), Color(0.02, 0.02, 0.025, 0.72), stroke)

	if _variant != VARIANT_COMPACT:
		var rivet_radius: float = 1.35 if _variant == VARIANT_ICON else 1.1
		draw_circle(Vector2(left + 3.0, size.y * 0.5), rivet_radius, muted)
		draw_circle(Vector2(right - 3.0, size.y * 0.5), rivet_radius, muted)

	if state in [STATE_HOVER, STATE_PRESSED, STATE_SELECTED, STATE_FOCUS] or _variant in [VARIANT_DESTRUCTIVE, VARIANT_SELECTED]:
		var ember: Color = Color("f19a55") if _variant != VARIANT_DESTRUCTIVE else Color("ff7c63")
		ember.a = 0.88 if state != STATE_DISABLED else 0.22
		draw_line(Vector2(left + 1.0, size.y * 0.36), Vector2(left + 1.0, size.y * 0.64), ember, 2.0)

	if state == STATE_FOCUS:
		_draw_focus_brackets(Color("ffe3a0"))

func _draw_corner(origin: Vector2, direction: Vector2, arm: float, color: Color, width: float) -> void:
	var horizontal_end := origin + Vector2(direction.x * arm, 0.0)
	var vertical_end := origin + Vector2(0.0, direction.y * minf(arm, 8.0))
	draw_line(origin, horizontal_end, color, width)
	draw_line(origin, vertical_end, color, width)

func _draw_focus_brackets(color: Color) -> void:
	var inset: float = 1.5
	var arm: float = clampf(size.y * 0.26, 8.0, 14.0)
	var points := [
		{"origin": Vector2(inset, inset), "direction": Vector2(1.0, 1.0)},
		{"origin": Vector2(size.x - inset, inset), "direction": Vector2(-1.0, 1.0)},
		{"origin": Vector2(inset, size.y - inset), "direction": Vector2(1.0, -1.0)},
		{"origin": Vector2(size.x - inset, size.y - inset), "direction": Vector2(-1.0, -1.0)}
	]
	for spec: Dictionary in points:
		_draw_corner(spec["origin"], spec["direction"], arm, color, 2.0)

func _visual_state() -> String:
	if _button == null:
		return STATE_NORMAL
	var forced_state: String = str(_button.get_meta("button_gallery_state", ""))
	if not forced_state.is_empty():
		return forced_state
	if _button.disabled:
		return STATE_DISABLED
	if _button.has_focus():
		return STATE_FOCUS
	if _button.button_pressed:
		return STATE_SELECTED
	if _button.is_pressed():
		return STATE_PRESSED
	if _button.is_hovered():
		return STATE_HOVER
	return STATE_NORMAL

func _accent_color(state: String) -> Color:
	if state == STATE_DISABLED:
		return Color("6c6458")
	if _variant == VARIANT_DESTRUCTIVE:
		return Color("d56858") if state == STATE_NORMAL else Color("ff9a73")
	if _variant == VARIANT_SELECTED or state == STATE_SELECTED:
		return Color("f0b75b")
	if state == STATE_FOCUS:
		return Color("ffe3a0")
	if state in [STATE_HOVER, STATE_PRESSED]:
		return Color("e4b66b")
	return Color("9b7844")
