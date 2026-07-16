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

const GLYPH_SIZE: Vector2 = Vector2(52.0, 52.0)
const HOTSPOT: Vector2 = Vector2(3.5, 3.0)
const BEARING_CENTER: Vector2 = Vector2(15.5, 33.7)
const RELEASE_REBOUND_SECONDS: float = 0.19

const SHADOW: Color = Color(0.018, 0.013, 0.014, 0.82)
const OUTLINE: Color = Color("211f22")
const IRON_DARK: Color = Color("4a494b")
const IRON_MID: Color = Color("8b877f")
const IRON_LIGHT: Color = Color("e4d8bf")
const ASH_FACE: Color = Color("bcb19d")
const BRASS_DARK: Color = Color("68431f")
const BRASS: Color = Color("b87a32")
const EMBER: Color = Color("efa84a")
const EMBER_CORE: Color = Color("ffe3a0")
const GRIP_DARK: Color = Color("302a29")
const GRIP_MID: Color = Color("51433b")
const INVALID_DARK: Color = Color("4e3937")
const INVALID_MID: Color = Color("7d5a52")
const INVALID_GLOW: Color = Color("ba6b58")

var cursor_state: String = STATE_IDLE
var animation_phase: float = 0.0
var press_depth: float = 0.0
var rebound_phase: float = 1.0
var rebound_strength: float = 0.0
var drag_direction: Vector2 = Vector2.ZERO
var drag_energy: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = GLYPH_SIZE
	size = GLYPH_SIZE
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	var held: bool = _state_is_held(cursor_state)
	var target_depth: float = 1.0 if held else 0.0
	var response_speed: float = 24.0 if held else 15.0
	var previous_depth: float = press_depth
	press_depth = lerpf(press_depth, target_depth, 1.0 - exp(-delta * response_speed))
	if absf(press_depth - target_depth) < 0.001:
		press_depth = target_depth

	var previous_rebound_phase: float = rebound_phase
	if rebound_phase < 1.0:
		rebound_phase = minf(1.0, rebound_phase + delta / RELEASE_REBOUND_SECONDS)

	var previous_animation_phase: float = animation_phase
	if cursor_state == STATE_LOADING:
		animation_phase = fmod(animation_phase + delta * 1.42, 1.0)
	elif cursor_state == STATE_DRAGGING:
		animation_phase = fmod(animation_phase + delta * 0.58, 1.0)

	var previous_drag_energy: float = drag_energy
	if cursor_state == STATE_DRAGGING:
		drag_energy = move_toward(drag_energy, 0.42, delta * 1.8)
	else:
		drag_energy = move_toward(drag_energy, 0.0, delta * 5.5)
		drag_direction = drag_direction.lerp(Vector2.ZERO, 1.0 - exp(-delta * 10.0))

	if not is_equal_approx(previous_depth, press_depth) \
		or not is_equal_approx(previous_rebound_phase, rebound_phase) \
		or not is_equal_approx(previous_animation_phase, animation_phase) \
		or not is_equal_approx(previous_drag_energy, drag_energy):
		queue_redraw()

func set_cursor_state(next_state: String) -> void:
	if not state_names().has(next_state):
		next_state = STATE_IDLE
	if cursor_state == next_state:
		return
	var was_held: bool = _state_is_held(cursor_state)
	var will_hold: bool = _state_is_held(next_state)
	if was_held and not will_hold:
		rebound_phase = 0.0
		rebound_strength = maxf(0.64, press_depth)
	elif will_hold:
		rebound_phase = 1.0
		rebound_strength = 0.0
	cursor_state = next_state
	queue_redraw()

func push_pointer_motion(relative_motion: Vector2, dragging: bool) -> void:
	if not dragging or relative_motion.length_squared() <= 0.01:
		return
	var direction: Vector2 = relative_motion.normalized()
	drag_direction = drag_direction.lerp(direction, 0.48)
	drag_energy = maxf(drag_energy, clampf(relative_motion.length() / 13.0, 0.28, 1.0))
	queue_redraw()

func set_animation_phase(next_phase: float) -> void:
	animation_phase = fposmod(next_phase, 1.0)
	queue_redraw()

func set_pose_for_test(next_press_depth: float, next_rebound_phase: float = 1.0, next_drag_direction: Vector2 = Vector2.ZERO, next_drag_energy: float = 0.0) -> void:
	press_depth = clampf(next_press_depth, 0.0, 1.0)
	rebound_phase = clampf(next_rebound_phase, 0.0, 1.0)
	rebound_strength = 1.0 if rebound_phase < 1.0 else 0.0
	drag_direction = next_drag_direction.normalized() if next_drag_direction.length_squared() > 0.01 else Vector2.ZERO
	drag_energy = clampf(next_drag_energy, 0.0, 1.0)
	queue_redraw()

func response_snapshot() -> Dictionary:
	return {
		"press_depth": press_depth,
		"held": _state_is_held(cursor_state),
		"rebound_active": rebound_phase < 1.0,
		"rebound_amount": _release_rebound_amount(),
		"drag_energy": drag_energy
	}

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
		"single_silhouette": true,
		"context_glyphs": false,
		"center_stripe": false,
		"press_holds": true,
		"release_rebounds": true,
		"loading_spins": true,
		"loading_integration": "heel_bearing",
		"pommel_detail": "faceted_socket_and_bearing",
		"layers": ["contact_shadow", "forged_outline", "joined_blade_facets", "edge_bevels", "wrapped_handle", "pommel_housing", "bearing_race", "material_response"]
	}

func _draw() -> void:
	var outer: PackedVector2Array = _transformed_points(_outer_points())
	var inner: PackedVector2Array = _transformed_points(_inner_points())
	var invalid_state: bool = cursor_state in [STATE_INVALID, STATE_PRESSED_INVALID]
	var engaged: bool = cursor_state in [STATE_ACTION, STATE_PRESSED_VALID, STATE_DRAG_READY, STATE_DRAGGING, STATE_LOADING]
	var held_valid: bool = cursor_state in [STATE_PRESSED_VALID, STATE_DRAGGING]
	var rebound: float = _release_rebound_amount()

	var shadow_offset := Vector2(2.0, 3.0) * (1.0 - press_depth * 0.34) + Vector2(0.5, 0.7) * rebound
	draw_colored_polygon(_offset_points(outer, shadow_offset), SHADOW)
	draw_colored_polygon(outer, INVALID_DARK if invalid_state else OUTLINE)
	draw_polyline(_closed_points(outer), Color(0.01, 0.008, 0.01, 0.96), 1.2, true)

	var inner_base: Color = INVALID_DARK.lightened(0.06) if invalid_state else IRON_DARK
	draw_colored_polygon(inner, inner_base)
	var ridge: Vector2 = _transform_point(Vector2(11.15, 25.65))
	var left_facet := PackedVector2Array([inner[0], ridge, inner[5], inner[6]])
	var right_facet := PackedVector2Array([inner[0], inner[1], inner[2], ridge])
	var shoulder_facet := PackedVector2Array([ridge, inner[2], inner[5]])
	var heel_facet := PackedVector2Array([inner[2], inner[3], inner[4], inner[5]])
	draw_colored_polygon(left_facet, INVALID_MID if invalid_state else ASH_FACE)
	draw_colored_polygon(right_facet, Color("715752") if invalid_state else IRON_MID)
	draw_colored_polygon(shoulder_facet, Color("5d4542") if invalid_state else Color("737069"))
	draw_colored_polygon(heel_facet, GRIP_DARK.darkened(0.04) if invalid_state else GRIP_DARK)

	var tip_plane := PackedVector2Array([
		inner[0],
		_transform_point(Vector2(8.45, 11.4)),
		_transform_point(Vector2(7.55, 17.0))
	])
	draw_colored_polygon(tip_plane, Color(0.94, 0.72, 0.63, 0.48) if invalid_state else Color(0.97, 0.91, 0.80, 0.48))

	var edge_strength: float = 0.94 if held_valid or cursor_state == STATE_LOADING else (0.78 if engaged else 0.62)
	draw_line(inner[0], inner[6], Color(IRON_LIGHT.r, IRON_LIGHT.g, IRON_LIGHT.b, edge_strength), 0.95, true)
	draw_line(inner[6], inner[5], Color(IRON_LIGHT.r, IRON_LIGHT.g, IRON_LIGHT.b, 0.30), 0.68, true)
	draw_line(inner[0], inner[1], Color(0.98, 0.91, 0.78, 0.24 + rebound * 0.26), 0.74, true)
	draw_line(inner[1], inner[2], Color(0.10, 0.09, 0.09, 0.68), 0.72, true)

	var accent_color: Color = INVALID_GLOW if invalid_state else (EMBER if engaged else BRASS)
	var accent_core: Color = Color(0.95, 0.61, 0.46, 0.58) if invalid_state else (EMBER_CORE if held_valid or cursor_state == STATE_LOADING else Color("d6aa6a"))
	_draw_wrapped_handle(accent_color, invalid_state)
	_draw_integrated_pommel(accent_color, accent_core, invalid_state)
	if held_valid:
		var tip_glint_end: Vector2 = _transform_point(Vector2(9.0, 9.4))
		draw_line(inner[0], tip_glint_end, Color(EMBER_CORE.r, EMBER_CORE.g, EMBER_CORE.b, 0.74), 1.25, true)

func _draw_wrapped_handle(accent_color: Color, invalid_state: bool) -> void:
	var collar_outer := _transformed_points(PackedVector2Array([
		Vector2(11.15, 26.35),
		Vector2(14.55, 24.95),
		Vector2(16.15, 28.65),
		Vector2(12.75, 30.05)
	]))
	var collar_inner := _transformed_points(PackedVector2Array([
		Vector2(11.95, 26.65),
		Vector2(14.15, 25.75),
		Vector2(15.18, 28.35),
		Vector2(13.02, 29.25)
	]))
	draw_colored_polygon(collar_outer, INVALID_DARK if invalid_state else OUTLINE)
	draw_colored_polygon(collar_inner, Color("5c3f39") if invalid_state else BRASS_DARK.darkened(0.08))
	draw_line(collar_inner[0], collar_inner[1], Color(accent_color.r, accent_color.g, accent_color.b, 0.38), 0.58, true)
	var bracket_left_start: Vector2 = _transform_point(Vector2(12.95, 29.05))
	var bracket_left_end: Vector2 = _transform_point(Vector2(13.55, 31.45))
	var bracket_right_start: Vector2 = _transform_point(Vector2(15.18, 28.25))
	var bracket_right_end: Vector2 = _transform_point(Vector2(16.15, 30.7))
	var bracket_color: Color = INVALID_DARK if invalid_state else BRASS_DARK
	draw_line(bracket_left_start, bracket_left_end, bracket_color, 1.55, true)
	draw_line(bracket_right_start, bracket_right_end, bracket_color, 1.55, true)
	draw_line(bracket_left_start, bracket_left_end, Color(accent_color.r, accent_color.g, accent_color.b, 0.46), 0.52, true)
	draw_line(bracket_right_start, bracket_right_end, Color(accent_color.r, accent_color.g, accent_color.b, 0.46), 0.52, true)

	var grip_plane := _transformed_points(PackedVector2Array([
		Vector2(12.9, 29.35),
		Vector2(15.3, 28.45),
		Vector2(18.25, 37.45),
		Vector2(16.15, 38.55)
	]))
	draw_colored_polygon(grip_plane, Color("493532") if invalid_state else GRIP_MID)
	draw_line(grip_plane[1], grip_plane[2], Color(0.72, 0.55, 0.42, 0.34), 0.72, true)
	for band_y: float in [31.2, 34.1, 36.9]:
		var left: Vector2 = _transform_point(Vector2(13.45 + (band_y - 31.2) * 0.31, band_y))
		var right: Vector2 = _transform_point(Vector2(16.0 + (band_y - 31.2) * 0.31, band_y - 0.9))
		draw_line(left, right, Color(0.08, 0.06, 0.06, 0.78), 0.92, true)
		draw_line(left + Vector2(0.35, -0.25), right + Vector2(0.35, -0.25), Color(0.68, 0.49, 0.35, 0.28), 0.48, true)
	var end_cap := _transformed_points(PackedVector2Array([
		Vector2(15.15, 37.85),
		Vector2(18.35, 36.75),
		Vector2(18.95, 38.65),
		Vector2(15.85, 40.05)
	]))
	draw_colored_polygon(end_cap, INVALID_DARK if invalid_state else OUTLINE)
	draw_line(end_cap[0], end_cap[1], Color(accent_color.r, accent_color.g, accent_color.b, 0.54), 0.82, true)

func _draw_integrated_pommel(accent_color: Color, accent_core: Color, invalid_state: bool) -> void:
	var center: Vector2 = _transform_point(BEARING_CENTER)
	var radius_scale: float = 1.0 - press_depth * 0.07 + _release_rebound_amount() * 0.06
	var housing_radius: float = (5.15 if cursor_state == STATE_LOADING else 4.35) * radius_scale
	var housing: PackedVector2Array = _regular_transformed_polygon(BEARING_CENTER, housing_radius, 6, -0.27)
	var housing_inset: PackedVector2Array = _regular_transformed_polygon(BEARING_CENTER, housing_radius - 0.82, 6, -0.27)
	draw_colored_polygon(housing, Color(0.045, 0.031, 0.028, 0.96))
	draw_colored_polygon(housing_inset, INVALID_DARK if invalid_state else BRASS_DARK)
	for rivet_index: int in range(3):
		var rivet_angle: float = -0.27 + float(rivet_index) * TAU / 3.0
		var rivet_position: Vector2 = _transform_point(BEARING_CENTER + Vector2.from_angle(rivet_angle) * (housing_radius - 1.18))
		draw_circle(rivet_position, 0.31, Color(0.08, 0.055, 0.045, 0.88))
	var outer_radius: float = (3.62 if cursor_state == STATE_LOADING else 3.12) * radius_scale
	draw_circle(center, outer_radius, Color("4b3431") if invalid_state else Color("292729"))
	draw_arc(center, outer_radius - 0.18, 0.0, TAU, 24, Color(accent_color.r, accent_color.g, accent_color.b, 0.58), 0.68, true)
	var socket: PackedVector2Array = _regular_transformed_polygon(BEARING_CENTER, 1.48 * radius_scale, 6, 0.24)
	draw_colored_polygon(socket, Color("4b3432") if invalid_state else Color("716c65"))
	if cursor_state == STATE_LOADING:
		var turn: float = animation_phase * TAU
		var sweep_radius: float = outer_radius - 0.62
		draw_arc(center, sweep_radius, turn, turn + 1.82, 15, accent_core, 1.18, true)
		draw_arc(center, sweep_radius, turn - 0.72, turn - 0.16, 7, Color(accent_color.r, accent_color.g, accent_color.b, 0.36), 0.78, true)
		var sweep_tip: Vector2 = center + Vector2.from_angle(turn + 1.82) * sweep_radius
		draw_circle(sweep_tip, 0.54, accent_core)
		draw_circle(center, 0.58, Color("211f21"))
		draw_circle(center + Vector2(-0.12, -0.16), 0.28, EMBER_CORE)
	else:
		draw_circle(center, 0.76, Color(0.06, 0.045, 0.04, 0.96))
		draw_circle(center, 0.48, accent_core)
		draw_circle(center + Vector2(-0.12, -0.16), 0.18, Color(1.0, 0.94, 0.78, 0.72))

func _regular_transformed_polygon(center: Vector2, radius: float, sides: int, rotation: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index: int in range(sides):
		var angle: float = rotation + float(index) * TAU / float(sides)
		points.append(_transform_point(center + Vector2.from_angle(angle) * radius))
	return points

func _outer_points() -> PackedVector2Array:
	return PackedVector2Array([
		HOTSPOT,
		Vector2(25.1, 26.4),
		Vector2(17.7, 27.5),
		Vector2(21.8, 40.0),
		Vector2(15.7, 42.5),
		Vector2(11.1, 30.1),
		Vector2(5.5, 35.0)
	])

func _inner_points() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(5.6, 7.0),
		Vector2(21.4, 24.7),
		Vector2(14.6, 25.3),
		Vector2(18.6, 38.3),
		Vector2(16.1, 39.3),
		Vector2(11.8, 26.8),
		Vector2(7.1, 30.8)
	])

func _transformed_points(points: PackedVector2Array) -> PackedVector2Array:
	var transformed := PackedVector2Array()
	for point: Vector2 in points:
		transformed.append(_transform_point(point))
	return transformed

func _transform_point(point: Vector2) -> Vector2:
	var rebound: float = _release_rebound_amount()
	var scale_vector := Vector2(
		1.0 - press_depth * 0.085 + rebound * 0.042,
		1.0 - press_depth * 0.145 + rebound * 0.058
	)
	var local: Vector2 = point - HOTSPOT
	local *= scale_vector
	if drag_direction.length_squared() > 0.01 and drag_energy > 0.01:
		var distance_weight: float = clampf(local.length() / 40.0, 0.0, 1.0)
		local -= drag_direction * drag_energy * 2.25 * distance_weight
	var tilt: float = deg_to_rad(-2.0 * press_depth + drag_direction.x * drag_energy * 1.4)
	local = local.rotated(tilt)
	return HOTSPOT + local

func _release_rebound_amount() -> float:
	if rebound_phase >= 1.0:
		return 0.0
	return sin(rebound_phase * PI) * (1.0 - rebound_phase * 0.38) * rebound_strength

func _state_is_held(state: String) -> bool:
	return state in [STATE_PRESSED_VALID, STATE_PRESSED_INVALID, STATE_DRAGGING]

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
