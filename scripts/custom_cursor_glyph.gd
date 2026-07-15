extends Control
class_name CustomCursorGlyph

const STATE_IDLE: String = "idle"
const STATE_ACTION: String = "action"
const STATE_PRESSED_VALID: String = "pressed_valid"
const STATE_PRESSED_INVALID: String = "pressed_invalid"
const STATE_DRAG_READY: String = "drag_ready"
const STATE_DRAGGING: String = "dragging"
const STATE_LOADING: String = "loading"
const STATE_INVALID: String = "invalid"

const GLYPH_SIZE: Vector2 = Vector2(58.0, 58.0)
const HOTSPOT: Vector2 = Vector2(4.0, 3.0)
const WARD_CENTER: Vector2 = Vector2(19.0, 25.5)

const SHADOW: Color = Color(0.025, 0.018, 0.016, 0.78)
const IRON_EDGE: Color = Color("242124")
const IRON_DARK: Color = Color("4b4b4d")
const IRON_MID: Color = Color("8c8982")
const IRON_LIGHT: Color = Color("e2d5b9")
const ASH_FACE: Color = Color("bbb09d")
const BRASS_DARK: Color = Color("6b431f")
const BRASS: Color = Color("b97931")
const EMBER: Color = Color("efad51")
const EMBER_CORE: Color = Color("ffe5a2")
const INVALID_DARK: Color = Color("4d2927")
const INVALID: Color = Color("9a5141")

var cursor_state: String = STATE_IDLE
var animation_phase: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = GLYPH_SIZE
	size = GLYPH_SIZE
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	if not state_requires_animation(cursor_state):
		return
	animation_phase = fmod(animation_phase + delta * (1.55 if cursor_state == STATE_LOADING else 0.72), 1.0)
	queue_redraw()

func set_cursor_state(next_state: String) -> void:
	if not state_names().has(next_state):
		next_state = STATE_IDLE
	if cursor_state == next_state:
		return
	cursor_state = next_state
	queue_redraw()

func set_animation_phase(next_phase: float) -> void:
	animation_phase = fposmod(next_phase, 1.0)
	queue_redraw()

static func state_names() -> PackedStringArray:
	return PackedStringArray([
		STATE_IDLE,
		STATE_ACTION,
		STATE_PRESSED_VALID,
		STATE_PRESSED_INVALID,
		STATE_DRAG_READY,
		STATE_DRAGGING,
		STATE_LOADING,
		STATE_INVALID
	])

static func state_requires_animation(state: String) -> bool:
	return state in [STATE_LOADING, STATE_DRAGGING]

static func visual_contract() -> Dictionary:
	return {
		"size": GLYPH_SIZE,
		"hotspot": HOTSPOT,
		"states": state_names(),
		"loading_spins": true,
		"layers": ["shadow", "context_ward", "forged_edge", "iron_facets", "brass_inlay", "state_accent"]
	}

func _draw() -> void:
	match cursor_state:
		STATE_LOADING:
			_draw_loading_ward()
		STATE_DRAG_READY:
			_draw_drag_ward(false)
		STATE_DRAGGING:
			_draw_drag_ward(true)
		STATE_ACTION, STATE_PRESSED_VALID:
			_draw_action_ward()
		STATE_INVALID, STATE_PRESSED_INVALID:
			_draw_invalid_ward()

	_draw_pointer_blade()

	if cursor_state == STATE_PRESSED_VALID:
		_draw_valid_impact()
	elif cursor_state == STATE_PRESSED_INVALID:
		_draw_invalid_impact()

func _draw_action_ward() -> void:
	draw_circle(WARD_CENTER + Vector2(1.5, 2.0), 9.8, Color(0.0, 0.0, 0.0, 0.34))
	draw_arc(WARD_CENTER, 9.0, -0.55, 4.55, 28, Color(EMBER.r, EMBER.g, EMBER.b, 0.23), 4.5, true)
	draw_arc(WARD_CENTER, 8.0, -0.55, 4.55, 28, Color(EMBER_CORE.r, EMBER_CORE.g, EMBER_CORE.b, 0.82), 1.25, true)
	for angle: float in [-0.55, 1.02, 2.59, 4.16]:
		var inner: Vector2 = WARD_CENTER + Vector2.from_angle(angle) * 10.0
		var outer: Vector2 = WARD_CENTER + Vector2.from_angle(angle) * 13.0
		draw_line(inner, outer, Color(EMBER.r, EMBER.g, EMBER.b, 0.78), 1.4, true)

func _draw_drag_ward(active: bool) -> void:
	var turn: float = animation_phase * TAU * (0.24 if active else 0.0)
	var radius: float = 12.0 if active else 11.0
	draw_circle(WARD_CENTER + Vector2(1.8, 2.4), radius + 2.0, Color(0.0, 0.0, 0.0, 0.36))
	draw_arc(WARD_CENTER, radius, 0.0, TAU, 40, Color(BRASS_DARK.r, BRASS_DARK.g, BRASS_DARK.b, 0.92), 3.8, true)
	draw_arc(WARD_CENTER, radius, -2.55 + turn, 0.72 + turn, 26, Color(EMBER.r, EMBER.g, EMBER.b, 0.92 if active else 0.72), 1.65, true)
	for index: int in range(4):
		var angle: float = turn + float(index) * TAU / 4.0
		var direction: Vector2 = Vector2.from_angle(angle)
		var side: Vector2 = direction.orthogonal()
		var base: Vector2 = WARD_CENTER + direction * (radius - 1.0)
		var tip: Vector2 = WARD_CENTER + direction * (radius + (6.4 if active else 5.2))
		var hook := PackedVector2Array([base - side * 3.1, tip, base + side * 3.1])
		draw_colored_polygon(hook, SHADOW)
		var inset := PackedVector2Array([base - side * 1.8, tip - direction * 1.5, base + side * 1.8])
		draw_colored_polygon(inset, EMBER if active else BRASS)
	if active:
		for index: int in range(3):
			var mote_angle: float = turn * 1.7 + float(index) * TAU / 3.0
			var mote_position: Vector2 = WARD_CENTER + Vector2.from_angle(mote_angle) * (16.5 + float(index % 2) * 2.0)
			draw_circle(mote_position, 1.25, Color(EMBER_CORE.r, EMBER_CORE.g, EMBER_CORE.b, 0.82))

func _draw_loading_ward() -> void:
	var turn: float = animation_phase * TAU
	draw_circle(WARD_CENTER + Vector2(1.8, 2.4), 16.0, Color(0.0, 0.0, 0.0, 0.34))
	draw_arc(WARD_CENTER, 13.1, 0.0, TAU, 46, Color(BRASS_DARK.r, BRASS_DARK.g, BRASS_DARK.b, 0.58), 1.3, true)
	for index: int in range(3):
		var start: float = turn + float(index) * TAU / 3.0
		var color: Color = EMBER_CORE if index == 0 else EMBER
		var alpha: float = 0.95 - float(index) * 0.20
		draw_arc(WARD_CENTER, 13.1, start, start + 0.76, 12, Color(color.r, color.g, color.b, alpha), 3.1 - float(index) * 0.45, true)
		var cinder: Vector2 = WARD_CENTER + Vector2.from_angle(start + 0.76) * 13.1
		draw_circle(cinder, 1.7 - float(index) * 0.25, Color(color.r, color.g, color.b, alpha))
	var counter_turn: float = -turn * 0.62
	for index: int in range(4):
		var mote_angle: float = counter_turn + float(index) * TAU / 4.0
		var mote: Vector2 = WARD_CENTER + Vector2.from_angle(mote_angle) * (17.0 + float(index % 2) * 1.5)
		draw_circle(mote, 0.95, Color(EMBER.r, EMBER.g, EMBER.b, 0.55))

func _draw_invalid_ward() -> void:
	draw_circle(WARD_CENTER + Vector2(1.4, 1.8), 10.6, Color(0.0, 0.0, 0.0, 0.30))
	draw_arc(WARD_CENTER, 9.7, 0.2, 5.0, 28, Color(INVALID.r, INVALID.g, INVALID.b, 0.38), 2.7, true)
	draw_line(WARD_CENTER + Vector2(-6.5, 6.5), WARD_CENTER + Vector2(6.5, -6.5), Color(INVALID.r, INVALID.g, INVALID.b, 0.86), 2.1, true)
	draw_line(WARD_CENTER + Vector2(-5.5, 6.0), WARD_CENTER + Vector2(5.0, -4.5), Color(0.93, 0.60, 0.45, 0.46), 0.8, true)

func _draw_pointer_blade() -> void:
	var pressed: bool = cursor_state in [STATE_PRESSED_VALID, STATE_PRESSED_INVALID]
	var scale_factor: float = 0.94 if pressed else 1.0
	var shift: Vector2 = Vector2(0.0, 1.0) if pressed else Vector2.ZERO
	var invalid_state: bool = cursor_state in [STATE_INVALID, STATE_PRESSED_INVALID]
	var bright_state: bool = cursor_state in [STATE_ACTION, STATE_PRESSED_VALID, STATE_DRAG_READY, STATE_DRAGGING, STATE_LOADING]

	var outer: PackedVector2Array = _transformed_blade_points(PackedVector2Array([
		Vector2(4.0, 3.0),
		Vector2(24.5, 27.0),
		Vector2(16.4, 27.6),
		Vector2(20.2, 40.0),
		Vector2(14.1, 42.1),
		Vector2(10.1, 29.4),
		Vector2(4.1, 34.2)
	]), scale_factor, shift)
	var inner: PackedVector2Array = _transformed_blade_points(PackedVector2Array([
		Vector2(5.9, 7.0),
		Vector2(20.8, 24.8),
		Vector2(13.5, 25.1),
		Vector2(17.6, 38.0),
		Vector2(15.2, 38.9),
		Vector2(11.1, 26.2),
		Vector2(6.4, 30.0)
	]), scale_factor, shift)
	var shadow_points: PackedVector2Array = _offset_points(outer, Vector2(2.0, 2.8))
	draw_colored_polygon(shadow_points, SHADOW)
	draw_colored_polygon(outer, IRON_EDGE if not invalid_state else INVALID_DARK)
	draw_polyline(_closed_points(outer), Color(0.02, 0.015, 0.018, 0.96), 1.25, true)
	draw_colored_polygon(inner, IRON_DARK if not invalid_state else Color("563b38"))

	var left_facet := PackedVector2Array([inner[0], inner[5], inner[6]])
	var right_facet := PackedVector2Array([inner[0], inner[1], inner[2], inner[5]])
	var tang_facet := PackedVector2Array([inner[2], inner[3], inner[4], inner[5]])
	draw_colored_polygon(left_facet, ASH_FACE.darkened(0.20) if invalid_state else ASH_FACE)
	draw_colored_polygon(right_facet, Color("65504b") if invalid_state else IRON_MID)
	draw_colored_polygon(tang_facet, Color("4b3938") if invalid_state else Color("696764"))
	draw_line(inner[0], inner[5], Color(IRON_LIGHT.r, IRON_LIGHT.g, IRON_LIGHT.b, 0.86 if bright_state else 0.62), 1.05, true)
	draw_line(inner[5], inner[4], Color(IRON_LIGHT.r, IRON_LIGHT.g, IRON_LIGHT.b, 0.38), 0.75, true)

	var inlay_color: Color = INVALID if invalid_state else (EMBER if bright_state else BRASS)
	var inlay_core: Color = Color(0.96, 0.65, 0.43, 0.50) if invalid_state else (EMBER_CORE if bright_state else Color("d0a063"))
	var inlay_start: Vector2 = _transform_blade_point(Vector2(6.9, 9.4), scale_factor, shift)
	var inlay_end: Vector2 = _transform_blade_point(Vector2(12.0, 27.2), scale_factor, shift)
	draw_line(inlay_start, inlay_end, Color(inlay_color.r, inlay_color.g, inlay_color.b, 0.92), 2.15, true)
	draw_line(inlay_start, inlay_end, Color(inlay_core.r, inlay_core.g, inlay_core.b, 0.82), 0.75, true)

	var rune_center: Vector2 = _transform_blade_point(Vector2(12.2, 26.8), scale_factor, shift)
	var rune := PackedVector2Array([
		rune_center + Vector2(0.0, -3.3),
		rune_center + Vector2(3.1, 0.0),
		rune_center + Vector2(0.0, 3.3),
		rune_center + Vector2(-3.1, 0.0)
	])
	draw_colored_polygon(rune, BRASS_DARK if invalid_state else inlay_color)
	var rune_inner := PackedVector2Array([
		rune_center + Vector2(0.0, -1.5),
		rune_center + Vector2(1.4, 0.0),
		rune_center + Vector2(0.0, 1.5),
		rune_center + Vector2(-1.4, 0.0)
	])
	draw_colored_polygon(rune_inner, inlay_core)

func _draw_valid_impact() -> void:
	draw_arc(HOTSPOT + Vector2(1.0, 1.0), 5.5, -0.15, 1.18, 10, Color(EMBER_CORE.r, EMBER_CORE.g, EMBER_CORE.b, 0.94), 1.5, true)
	draw_line(HOTSPOT + Vector2(5.2, 0.8), HOTSPOT + Vector2(8.4, -0.3), Color(EMBER.r, EMBER.g, EMBER.b, 0.84), 1.2, true)
	draw_line(HOTSPOT + Vector2(3.6, 4.4), HOTSPOT + Vector2(5.8, 7.3), Color(EMBER.r, EMBER.g, EMBER.b, 0.72), 1.1, true)

func _draw_invalid_impact() -> void:
	draw_arc(HOTSPOT + Vector2(2.0, 2.0), 6.2, 0.1, 1.36, 10, Color(INVALID.r, INVALID.g, INVALID.b, 0.70), 2.2, true)
	draw_circle(HOTSPOT + Vector2(5.5, 4.0), 1.35, Color(0.32, 0.20, 0.18, 0.90))

func _transformed_blade_points(points: PackedVector2Array, scale_factor: float, shift: Vector2) -> PackedVector2Array:
	var transformed := PackedVector2Array()
	for point: Vector2 in points:
		transformed.append(_transform_blade_point(point, scale_factor, shift))
	return transformed

func _transform_blade_point(point: Vector2, scale_factor: float, shift: Vector2) -> Vector2:
	return HOTSPOT + (point - HOTSPOT) * scale_factor + shift

func _offset_points(points: PackedVector2Array, offset: Vector2) -> PackedVector2Array:
	var shifted := PackedVector2Array()
	for point: Vector2 in points:
		shifted.append(point + offset)
	return shifted

func _closed_points(points: PackedVector2Array) -> PackedVector2Array:
	var closed: PackedVector2Array = points.duplicate()
	if not closed.is_empty():
		closed.append(closed[0])
	return closed
