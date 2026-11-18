extends Control

const Palette = preload("res://scripts/ui_palette.gd")
const ORIGIN_FILL: Color = Palette.PATTERN_ORIGIN_FILL
const ORIGIN_BORDER: Color = Palette.PATTERN_ORIGIN_BORDER
const HIT_FILL: Color = Palette.PATTERN_HIT_FILL
const HIT_BORDER: Color = Palette.PATTERN_HIT_BORDER

var _triangles := preload("res://scripts/card_triangle_batch.gd").new()

const TILE_WIDTH: float = 16.0
const TILE_HEIGHT: float = 10.0
const TILE_PADDING: float = 5.0

var pattern_offsets: Array[Vector2i]
var show_origin: bool = false
var mark_affected_origin: bool = false
var tile_scale: float = 1.0

func setup(raw_pattern: Variant, next_show_origin: bool, next_tooltip: String, next_tile_scale: float = 1.0, next_mark_affected_origin: bool = false) -> void:
	pattern_offsets = _parse_offsets(raw_pattern)
	show_origin = next_show_origin
	mark_affected_origin = next_mark_affected_origin
	tile_scale = clampf(next_tile_scale, 0.42, 1.0)
	tooltip_text = next_tooltip
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = _desired_size()
	queue_redraw()

func _draw() -> void:
	var draw_offsets: Array[Vector2i] = _draw_offsets()
	if draw_offsets.is_empty():
		return
	var bounds: Rect2 = _bounds_for_offsets(draw_offsets)
	var shift: Vector2 = size * 0.5 - bounds.get_center()
	var hit_lookup: Dictionary = {}
	for offset: Vector2i in pattern_offsets:
		hit_lookup[offset] = true
	for offset: Vector2i in draw_offsets:
		var is_origin: bool = show_origin and offset == Vector2i.ZERO and not hit_lookup.has(offset)
		var fill: Color = ORIGIN_FILL if is_origin else HIT_FILL
		var border: Color = ORIGIN_BORDER if is_origin else HIT_BORDER
		var center: Vector2 = _iso_center(offset) + shift
		_draw_tile(center, fill, border)
		if mark_affected_origin and offset == Vector2i.ZERO and hit_lookup.has(offset):
			draw_circle(center, tile_scale, ORIGIN_FILL, true, -1.0, true)

	_triangles.flush(self)

func _desired_size() -> Vector2:
	return measured_size(pattern_offsets, show_origin, tile_scale)

static func measured_size(raw_pattern: Variant, include_origin: bool, scale_factor: float) -> Vector2:
	var offsets: Array[Vector2i] = _parse_offsets(raw_pattern)
	if include_origin and not offsets.has(Vector2i.ZERO): offsets.append(Vector2i.ZERO)
	var bounds: Rect2 = _bounds_at_scale(offsets, scale_factor)
	return Vector2(maxf(34.0 * scale_factor, bounds.size.x + TILE_PADDING * scale_factor * 2.0), maxf(24.0 * scale_factor, bounds.size.y + TILE_PADDING * scale_factor * 2.0))

func _draw_offsets() -> Array[Vector2i]:
	var lookup: Dictionary = {}
	for offset: Vector2i in pattern_offsets:
		lookup[offset] = true
	if show_origin:
		lookup[Vector2i.ZERO] = true
	var offsets: Array[Vector2i]
	for offset_var: Variant in lookup.keys():
		if typeof(offset_var) == TYPE_VECTOR2I:
			offsets.append(offset_var)
	offsets.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.y == b.y:
			return a.x < b.x
		return a.y < b.y
	)
	return offsets

func _bounds_for_offsets(offsets: Array[Vector2i]) -> Rect2:
	return _bounds_at_scale(offsets, tile_scale)

static func _bounds_at_scale(offsets: Array[Vector2i], scale_factor: float) -> Rect2:
	var first: bool = true
	var rect := Rect2()
	var tile_size := Vector2(TILE_WIDTH, TILE_HEIGHT) * scale_factor
	for offset: Vector2i in offsets:
		var center := Vector2(float(offset.x - offset.y) * tile_size.x * 0.5, float(offset.x + offset.y) * tile_size.y * 0.5)
		var tile_rect := Rect2(center - tile_size * 0.5, tile_size)
		if first:
			rect = tile_rect
			first = false
		else:
			rect = rect.merge(tile_rect)
	return rect

func _iso_center(offset: Vector2i) -> Vector2:
	return Vector2(float(offset.x - offset.y) * _tile_width() * 0.5, float(offset.x + offset.y) * _tile_height() * 0.5)

func _draw_tile(center: Vector2, fill: Color, border: Color) -> void:
	var tile_width: float = _tile_width()
	var tile_height: float = _tile_height()
	var points := PackedVector2Array([
		center + Vector2(0.0, -tile_height * 0.5),
		center + Vector2(tile_width * 0.5, 0.0),
		center + Vector2(0.0, tile_height * 0.5),
		center + Vector2(-tile_width * 0.5, 0.0),
		center + Vector2(0.0, -tile_height * 0.5)
	])
	_triangles.colored_polygon(points, fill)
	_triangles.flush(self)
	draw_polyline(points, border, 1.0, true)

func _tile_width() -> float:
	return TILE_WIDTH * tile_scale

func _tile_height() -> float:
	return TILE_HEIGHT * tile_scale

static func _parse_offsets(raw_pattern: Variant) -> Array[Vector2i]:
	var parsed: Array[Vector2i]
	if typeof(raw_pattern) != TYPE_ARRAY:
		parsed.append(Vector2i.ZERO)
		return parsed
	for offset_var: Variant in raw_pattern:
		match typeof(offset_var):
			TYPE_VECTOR2I:
				parsed.append(offset_var)
			TYPE_ARRAY:
				var pair: Array = offset_var
				if pair.size() >= 2:
					parsed.append(Vector2i(int(pair[0]), int(pair[1])))
			TYPE_DICTIONARY:
				var offset_dict: Dictionary = offset_var
				parsed.append(Vector2i(int(offset_dict.get("x", 0)), int(offset_dict.get("y", 0))))
	if parsed.is_empty():
		parsed.append(Vector2i.ZERO)
	return parsed

