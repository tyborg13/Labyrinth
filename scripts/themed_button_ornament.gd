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
const VARIANT_UMBRA: String = "umbra"

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
	if _variant == VARIANT_UMBRA:
		_draw_umbra_ornament(state)
		return
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

func _draw_umbra_ornament(state: String) -> void:
	var selected: bool = state in [STATE_HOVER, STATE_PRESSED, STATE_SELECTED, STATE_FOCUS]
	var disabled: bool = state == STATE_DISABLED
	var inset: float = 3.0
	var left: float = inset
	var right: float = size.x - inset
	var top: float = inset
	var bottom: float = size.y - inset

	# Obsidian facets stay nearly black; they should read as material, not noise.
	draw_colored_polygon(PackedVector2Array([
		Vector2(left + 18.0, top + 5.0),
		Vector2(size.x * 0.42, top + 2.0),
		Vector2(size.x * 0.34, bottom - 3.0),
		Vector2(left + 8.0, bottom - 8.0),
	]), Color(0.20, 0.19, 0.23, 0.075 if not disabled else 0.035))
	draw_colored_polygon(PackedVector2Array([
		Vector2(size.x * 0.42, top + 2.0),
		Vector2(right - 16.0, top + 7.0),
		Vector2(right - 7.0, bottom - 9.0),
		Vector2(size.x * 0.34, bottom - 3.0),
	]), Color(0.02, 0.02, 0.035, 0.22 if not disabled else 0.12))

	var edge: Color = Color("d29a50") if selected else (Color("484238") if disabled else Color("776142"))
	var edge_shadow := Color(0.02, 0.015, 0.012, 0.94)
	draw_line(Vector2(left + 17.0, top), Vector2(right - 17.0, top), edge_shadow, 4.0)
	draw_line(Vector2(left + 17.0, bottom), Vector2(right - 17.0, bottom), edge_shadow, 5.0)
	draw_line(Vector2(left + 17.0, top), Vector2(right - 17.0, top), Color(edge.r, edge.g, edge.b, edge.a * 0.64), 1.5)
	draw_line(Vector2(left + 17.0, bottom), Vector2(right - 17.0, bottom), Color(edge.r, edge.g, edge.b, edge.a * 0.52), 1.5)
	draw_line(Vector2(left + 11.0, top + 6.0), Vector2(right - 11.0, top + 6.0), Color(0.36, 0.32, 0.27, 0.25), 1.0)
	draw_line(Vector2(left + 11.0, bottom - 6.0), Vector2(right - 11.0, bottom - 6.0), Color(0.01, 0.01, 0.014, 0.88), 1.0)

	_draw_umbra_corner(Vector2(left + 2.0, top + 2.0), Vector2(1.0, 1.0), edge)
	_draw_umbra_corner(Vector2(right - 2.0, top + 2.0), Vector2(-1.0, 1.0), edge)
	_draw_umbra_corner(Vector2(left + 2.0, bottom - 2.0), Vector2(1.0, -1.0), edge)
	_draw_umbra_corner(Vector2(right - 2.0, bottom - 2.0), Vector2(-1.0, -1.0), edge)

	_draw_umbra_fractures(selected, disabled)
	if selected:
		_draw_umbra_selection_markers(state == STATE_PRESSED)

func _draw_umbra_corner(origin: Vector2, direction: Vector2, brass: Color) -> void:
	var plate := PackedVector2Array([
		origin + Vector2(0.0, direction.y * 14.0),
		origin,
		origin + Vector2(direction.x * 14.0, 0.0),
		origin + Vector2(direction.x * 18.0, direction.y * 4.0),
		origin + Vector2(direction.x * 14.0, direction.y * 8.0),
		origin + Vector2(direction.x * 8.0, direction.y * 5.0),
		origin + Vector2(direction.x * 5.0, direction.y * 13.0),
	])
	draw_colored_polygon(plate, Color(0.018, 0.014, 0.011, 0.96))
	var plate_inner := PackedVector2Array()
	for point: Vector2 in plate:
		plate_inner.append(origin + (point - origin) * 0.82)
	draw_colored_polygon(plate_inner, Color(brass.r, brass.g, brass.b, brass.a * 0.46))
	var path := PackedVector2Array([
		origin + Vector2(0.0, direction.y * 13.0),
		origin,
		origin + Vector2(direction.x * 14.0, 0.0),
		origin + Vector2(direction.x * 18.0, direction.y * 4.0),
	])
	draw_polyline(path, Color(0.015, 0.012, 0.01, 0.96), 7.0, true)
	draw_polyline(path, Color(brass.r, brass.g, brass.b, brass.a * 0.72), 4.0, true)
	draw_polyline(path, Color(brass.lightened(0.26), 0.86), 1.1, true)
	var inner_origin := origin + Vector2(direction.x * 5.0, direction.y * 5.0)
	_draw_corner(inner_origin, direction, 9.0, Color(brass.r, brass.g, brass.b, brass.a * 0.62), 1.0)
	draw_circle(inner_origin + Vector2(direction.x * 1.0, direction.y * 1.0), 1.15, Color(0.07, 0.05, 0.035, 0.82))

func _draw_umbra_fractures(selected: bool, disabled: bool) -> void:
	var paths: Array[PackedVector2Array]
	paths.append(_umbra_crack_path(PackedVector2Array([Vector2(0.48, 0.98), Vector2(0.54, 0.78), Vector2(0.59, 0.69), Vector2(0.62, 0.48), Vector2(0.68, 0.35)])))
	paths.append(_umbra_crack_path(PackedVector2Array([Vector2(0.59, 0.69), Vector2(0.68, 0.63), Vector2(0.73, 0.48)])))
	paths.append(_umbra_crack_path(PackedVector2Array([Vector2(0.62, 0.48), Vector2(0.57, 0.36), Vector2(0.55, 0.22)])))
	paths.append(_umbra_crack_path(PackedVector2Array([Vector2(0.68, 0.35), Vector2(0.75, 0.29), Vector2(0.81, 0.13)])))
	paths.append(_umbra_crack_path(PackedVector2Array([Vector2(0.68, 0.63), Vector2(0.77, 0.72), Vector2(0.85, 0.67)])))
	for path: PackedVector2Array in paths:
		draw_polyline(path, Color(0.005, 0.004, 0.006, 0.96), 4.8, true)
		if selected:
			draw_polyline(path, Color(1.0, 0.15, 0.015, 0.10), 8.0, true)
			draw_polyline(path, Color(0.96, 0.27, 0.035, 0.56), 3.0, true)
			draw_polyline(path, Color(1.0, 0.70, 0.24, 0.94), 0.95, true)
		else:
			var etched := Color(0.12, 0.115, 0.14, 0.20 if disabled else 0.46)
			draw_polyline(path, etched, 1.15, true)

func _umbra_crack_path(points: PackedVector2Array) -> PackedVector2Array:
	var path := PackedVector2Array()
	for point: Vector2 in points:
		path.append(Vector2(point.x * size.x, point.y * size.y))
	return path

func _draw_umbra_selection_markers(pressed: bool) -> void:
	var center_y: float = size.y * 0.5 + (1.5 if pressed else 0.0)
	var brass := Color("dca251")
	var glow := Color(1.0, 0.36, 0.06, 0.14)
	_draw_umbra_marker(Vector2(-22.0, center_y), 1.0, brass, glow)
	_draw_umbra_marker(Vector2(size.x + 22.0, center_y), -1.0, brass, glow)

func _draw_umbra_marker(tip: Vector2, inward: float, brass: Color, glow: Color) -> void:
	var outer := PackedVector2Array([
		tip + Vector2(-inward * 2.0, 0.0),
		tip + Vector2(inward * 12.0, -14.0),
		tip + Vector2(inward * 12.0, 14.0),
	])
	draw_colored_polygon(outer, Color(0.015, 0.01, 0.008, 0.96))
	var inner := PackedVector2Array([
		tip,
		tip + Vector2(inward * 9.0, -10.0),
		tip + Vector2(inward * 9.0, 10.0),
	])
	draw_colored_polygon(inner, glow)
	draw_polyline(PackedVector2Array([inner[1], inner[0], inner[2]]), brass, 2.0, true)
	draw_line(tip + Vector2(inward * 10.0, -13.0), tip + Vector2(inward * 10.0, 13.0), Color(brass.r, brass.g, brass.b, 0.72), 1.2)

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
	if bool(_button.get_meta("umbra_selected", false)):
		return STATE_SELECTED
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
