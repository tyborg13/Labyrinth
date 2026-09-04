extends Control
class_name CardDragTargetingArrow

const AssetLoader = preload("res://scripts/asset_loader.gd")

const RIBBON_ASSET_PATH: String = "res://assets/art/ui/card_drag_arrow_ribbon_v1.png"
const HEAD_ASSET_PATH: String = "res://assets/art/ui/card_drag_arrow_head_v1.png"
const SAMPLE_SPACING: float = 34.0
const RIBBON_DRAW_SIZE: Vector2 = Vector2(76.0, 15.0)
const HEAD_DRAW_SIZE: Vector2 = Vector2(66.0, 49.5)
const MIN_VISIBLE_DISTANCE: float = 54.0
const MAX_SAMPLE_COUNT: int = 40

var _ribbon_texture: Texture2D
var _head_texture: Texture2D
var _start: Vector2 = Vector2.ZERO
var _end: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	_ribbon_texture = AssetLoader.load_texture(RIBBON_ASSET_PATH)
	_head_texture = AssetLoader.load_texture(HEAD_ASSET_PATH)
	set_meta("raster_composed_arrow", true)
	set_meta("ribbon_asset_path", RIBBON_ASSET_PATH)
	set_meta("head_asset_path", HEAD_ASSET_PATH)
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
	if not visible or _ribbon_texture == null or _head_texture == null:
		return
	var points: PackedVector2Array = sampled_curve(_start, _end, SAMPLE_SPACING)
	if points.size() < 2:
		return
	for index: int in range(points.size() - 1):
		var progress: float = float(index) / float(maxi(1, points.size() - 2))
		var direction: Vector2 = points[index + 1] - points[index]
		if direction.length_squared() <= 0.001:
			continue
		var tangent: Vector2 = direction.normalized()
		var center: Vector2 = points[index].lerp(points[index + 1], 0.5)
		var taper: float = lerpf(0.72, 1.0, smoothstep(0.0, 0.46, progress))
		_draw_raster_piece(
			_ribbon_texture,
			center,
			tangent.angle(),
			Vector2(RIBBON_DRAW_SIZE.x, RIBBON_DRAW_SIZE.y * taper),
			Color(1.0, 1.0, 1.0, lerpf(0.80, 0.98, taper))
		)
	var head_tangent: Vector2 = curve_tangent(_start, _end, 1.0).normalized()
	if head_tangent.length_squared() <= 0.001:
		head_tangent = (_end - _start).normalized()
	var head_center: Vector2 = _end - head_tangent * HEAD_DRAW_SIZE.x * 0.47
	_draw_raster_piece(_head_texture, head_center, head_tangent.angle(), HEAD_DRAW_SIZE, Color.WHITE)


func _draw_raster_piece(texture: Texture2D, center: Vector2, rotation_radians: float, draw_size: Vector2, tint: Color) -> void:
	draw_set_transform(center, rotation_radians, Vector2.ONE)
	draw_texture_rect(texture, Rect2(-draw_size * 0.5, draw_size), false, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func sampled_curve(start: Vector2, finish: Vector2, spacing: float = SAMPLE_SPACING) -> PackedVector2Array:
	var controls: PackedVector2Array = curve_controls(start, finish)
	var estimated_length: float = (
		controls[0].distance_to(controls[1])
		+ controls[1].distance_to(controls[2])
		+ controls[2].distance_to(controls[3])
	)
	var sample_count: int = clampi(int(ceil(estimated_length / maxf(8.0, spacing))), 3, MAX_SAMPLE_COUNT)
	var points := PackedVector2Array()
	for index: int in range(sample_count + 1):
		points.append(curve_point(start, finish, float(index) / float(sample_count)))
	return points


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
