extends Control
class_name CardDragTargetingArrow

const AssetLoader = preload("res://scripts/asset_loader.gd")

const SEGMENT_ASSET_PATH: String = "res://assets/art/ui/card_drag_arrow_segment_v2.png"
const HEAD_ASSET_PATH: String = "res://assets/art/ui/card_drag_arrow_head_v2.png"
const SEGMENT_DRAW_SIZE: Vector2 = Vector2(38.0, 28.0)
const HEAD_DRAW_SIZE: Vector2 = Vector2(60.0, 48.0)
const SEGMENT_SPACING: float = 42.0
const SEGMENT_START_DISTANCE: float = 22.0
const HEAD_SOCKET_OVERLAP: float = 4.0
const ARC_TANGENT_EPSILON: float = 3.0
const MIN_VISIBLE_DISTANCE: float = 54.0
const ARC_LOOKUP_STEPS: int = 160
const MAX_SEGMENT_COUNT: int = 40

var _segment_texture: Texture2D
var _head_texture: Texture2D
var _start: Vector2 = Vector2.ZERO
var _end: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_segment_texture = AssetLoader.load_texture(SEGMENT_ASSET_PATH)
	_head_texture = AssetLoader.load_texture(HEAD_ASSET_PATH)
	set_meta("raster_composed_arrow", true)
	set_meta("segmented_raster_arrow", true)
	set_meta("segment_asset_path", SEGMENT_ASSET_PATH)
	set_meta("head_asset_path", HEAD_ASSET_PATH)
	set_meta("fixed_native_segment_size", SEGMENT_DRAW_SIZE)
	visible = false


func set_targeting(start_global: Vector2, end_global: Vector2) -> void:
	var inverse: Transform2D = get_global_transform_with_canvas().affine_inverse()
	_start = inverse * start_global
	_end = inverse * end_global
	visible = _start.distance_to(_end) >= MIN_VISIBLE_DISTANCE
	queue_redraw()


func clear_targeting() -> void:
	visible = false
	queue_redraw()


func targeting_start() -> Vector2:
	return _start


func targeting_end() -> Vector2:
	return _end


func _draw() -> void:
	if not visible or _segment_texture == null or _head_texture == null:
		return
	var placements: Array[Dictionary] = segment_placements(_start, _end)
	set_meta("last_segment_count", placements.size())
	for placement: Dictionary in placements:
		_draw_raster_piece(
			_segment_texture,
			placement.get("center", Vector2.ZERO),
			float(placement.get("angle", 0.0))
		)
	var head: Dictionary = head_placement(_start, _end)
	_draw_raster_piece(
		_head_texture,
		head.get("center", _end),
		float(head.get("angle", 0.0))
	)


func _draw_raster_piece(texture: Texture2D, center: Vector2, rotation_radians: float) -> void:
	draw_set_transform(center, rotation_radians, Vector2.ONE)
	draw_texture(texture, -texture.get_size() * 0.5, Color.WHITE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func sampled_curve(start: Vector2, finish: Vector2, spacing: float = SEGMENT_SPACING) -> PackedVector2Array:
	var lookup: PackedVector2Array = curve_lookup(start, finish)
	var total_length: float = curve_arc_length(lookup)
	var points := PackedVector2Array()
	points.append(start)
	var distance: float = maxf(8.0, spacing)
	while distance < total_length:
		points.append(point_at_arc_distance(lookup, distance))
		distance += maxf(8.0, spacing)
	points.append(finish)
	return points


static func segment_placements(start: Vector2, finish: Vector2) -> Array[Dictionary]:
	var placements: Array[Dictionary] = []
	var lookup: PackedVector2Array = curve_lookup(start, finish)
	var total_length: float = curve_arc_length(lookup)
	var terminal_center_distance: float = (
		total_length
		- HEAD_DRAW_SIZE.x
		- SEGMENT_DRAW_SIZE.x * 0.5
		+ HEAD_SOCKET_OVERLAP
	)
	var available_length: float = terminal_center_distance - SEGMENT_START_DISTANCE
	if available_length < 0.0:
		return placements
	var interval_count: int = clampi(int(round(available_length / SEGMENT_SPACING)), 1, MAX_SEGMENT_COUNT - 1)
	var actual_spacing: float = available_length / float(interval_count)
	if actual_spacing < SEGMENT_DRAW_SIZE.x + 2.0 and interval_count > 1:
		interval_count -= 1
		actual_spacing = available_length / float(interval_count)
	for index: int in range(interval_count + 1):
		var distance: float = SEGMENT_START_DISTANCE + actual_spacing * float(index)
		var tangent: Vector2 = tangent_at_arc_distance(lookup, distance)
		placements.append({
			"center": point_at_arc_distance(lookup, distance),
			"angle": tangent.angle(),
			"distance": distance,
			"spacing": actual_spacing,
			"tangent": tangent,
		})
	return placements


static func head_placement(start: Vector2, finish: Vector2) -> Dictionary:
	var lookup: PackedVector2Array = curve_lookup(start, finish)
	var total_length: float = curve_arc_length(lookup)
	var tangent: Vector2 = tangent_at_arc_distance(lookup, total_length)
	if tangent.length_squared() <= 0.001:
		tangent = (finish - start).normalized()
	var center: Vector2 = finish - tangent * HEAD_DRAW_SIZE.x * 0.5
	return {
		"center": center,
		"angle": tangent.angle(),
		"tangent": tangent,
		"tip": center + tangent * HEAD_DRAW_SIZE.x * 0.5,
		"tail": center - tangent * HEAD_DRAW_SIZE.x * 0.5,
		"arc_length": total_length,
	}


static func curve_lookup(start: Vector2, finish: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index: int in range(ARC_LOOKUP_STEPS + 1):
		points.append(curve_point(start, finish, float(index) / float(ARC_LOOKUP_STEPS)))
	return points


static func curve_arc_length(points: PackedVector2Array) -> float:
	var length: float = 0.0
	for index: int in range(1, points.size()):
		length += points[index - 1].distance_to(points[index])
	return length


static func point_at_arc_distance(points: PackedVector2Array, requested_distance: float) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	var target_distance: float = maxf(0.0, requested_distance)
	var traversed: float = 0.0
	for index: int in range(1, points.size()):
		var chord_length: float = points[index - 1].distance_to(points[index])
		if traversed + chord_length >= target_distance:
			var progress: float = 0.0 if chord_length <= 0.001 else (target_distance - traversed) / chord_length
			return points[index - 1].lerp(points[index], clampf(progress, 0.0, 1.0))
		traversed += chord_length
	return points[points.size() - 1]


static func tangent_at_arc_distance(points: PackedVector2Array, requested_distance: float) -> Vector2:
	var total_length: float = curve_arc_length(points)
	var before: Vector2 = point_at_arc_distance(points, maxf(0.0, requested_distance - ARC_TANGENT_EPSILON))
	var after: Vector2 = point_at_arc_distance(points, minf(total_length, requested_distance + ARC_TANGENT_EPSILON))
	var tangent: Vector2 = (after - before).normalized()
	if tangent.length_squared() <= 0.001 and points.size() >= 2:
		tangent = (points[points.size() - 1] - points[points.size() - 2]).normalized()
	return tangent


static func curve_controls(start: Vector2, finish: Vector2) -> PackedVector2Array:
	var delta: Vector2 = finish - start
	var distance: float = maxf(MIN_VISIBLE_DISTANCE, delta.length())
	var lift: float = clampf(distance * 0.32, 92.0, 238.0)
	var approach: float = clampf(distance * 0.22, 58.0, 158.0)
	var first_control: Vector2 = start + Vector2(delta.x * 0.06, -lift)
	var second_control: Vector2 = finish + Vector2(-delta.x * 0.12, approach)
	return PackedVector2Array([start, first_control, second_control, finish])


static func curve_point(start: Vector2, finish: Vector2, progress: float) -> Vector2:
	var controls: PackedVector2Array = curve_controls(start, finish)
	var t: float = clampf(progress, 0.0, 1.0)
	var inverse: float = 1.0 - t
	return (
		controls[0] * inverse * inverse * inverse
		+ controls[1] * 3.0 * inverse * inverse * t
		+ controls[2] * 3.0 * inverse * t * t
		+ controls[3] * t * t * t
	)


static func curve_tangent(start: Vector2, finish: Vector2, progress: float) -> Vector2:
	var controls: PackedVector2Array = curve_controls(start, finish)
	var t: float = clampf(progress, 0.0, 1.0)
	var inverse: float = 1.0 - t
	return (
		(controls[1] - controls[0]) * 3.0 * inverse * inverse
		+ (controls[2] - controls[1]) * 6.0 * inverse * t
		+ (controls[3] - controls[2]) * 3.0 * t * t
	)
