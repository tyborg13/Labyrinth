extends RefCounted
## Offline bounds of submitted paint, including live bones and skinned meshes.
const Raster = preload("res://tools/hero_rest_coverage_raster.gd")
const Assets = preload("res://scripts/asset_loader.gd")
const LOOP_SIZE := Vector2(282, 168)
const REQUIRED_PIXELS: float = 4.0
const FILTER_PAD_PIXELS: float = 1.0 # Conservative readback/filter/outline allowance.
static var _used: Dictionary = {}

static func used(texture: Texture2D) -> Rect2:
	var key: int = texture.get_instance_id()
	if not _used.has(key): _used[key] = Rect2(Assets.texture_source_image(texture).get_used_rect())
	return _used[key]

static func _append_visible(paint: PackedVector2Array, extent: Vector2, points: PackedVector2Array) -> void:
	if paint.is_empty(): return
	var bounds := Rect2(paint[0], Vector2.ZERO)
	for point: Vector2 in paint: bounds = bounds.expand(point)
	# Burrow/death can park individual parts outside their private canvas.
	# Clip each paint item before union, so invisible stored parts add no bounds.
	bounds = bounds.intersection(Rect2(Vector2.ZERO, extent))
	if bounds.has_area():
		points.append(bounds.position)
		points.append(bounds.end)

static func _points(node: Node, rig: Node2D, points: PackedVector2Array) -> void:
	if node is CanvasItem and (not node.visible or node.modulate.a <= 0.0): return
	var paint := PackedVector2Array()
	if node is Sprite2D and node.texture != null and node.self_modulate.a > 0.0:
		var rect: Rect2 = used(node.texture)
		var target: Rect2 = node.get_rect()
		var scale: Vector2 = target.size / Vector2(node.texture.get_size())
		rect = Rect2(target.position + rect.position * scale, rect.size * scale)
		if node.flip_h: rect.position.x = target.end.x - (rect.end.x - target.position.x)
		if node.flip_v: rect.position.y = target.end.y - (rect.end.y - target.position.y)
		for p: Vector2 in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]: paint.append(node.global_transform * p)
	elif node is Polygon2D and node.texture != null and node.self_modulate.a > 0.0:
		for p: Vector2 in Raster._skin_vertices(node, rig): paint.append(node.global_transform * p)
	_append_visible(paint, Vector2(rig.get_viewport().size), points)
	for child: Node in node.get_children(): _points(child, rig, points)

static func screen_rect(board: Control, unit: Dictionary) -> Rect2:
	var renderer: Node = board.unit_cutout_renderer(unit)
	var draw: Rect2 = board._unit_texture_draw_rect(unit, board._unit_center(unit))
	var points := PackedVector2Array()
	if is_instance_valid(renderer) and renderer.get("rigs") is Dictionary:
		for rig: Node2D in renderer.get("rigs").values():
			if rig.visible: _points(rig, rig, points)
		var extent: Vector2 = Vector2(renderer.get("viewport").size)
		for index: int in range(points.size()): points[index] = draw.position + points[index] * draw.size / extent
	else:
		var texture: Texture2D = board._texture_for_unit(unit)
		if texture == null: return board.get_global_transform_with_canvas() * board._unit_draw_rect(unit)
		var source: Rect2 = used(texture)
		var scale: Vector2 = draw.size / Vector2(texture.get_size())
		var rect := Rect2(draw.position + source.position * scale, source.size * scale)
		points.append(rect.position)
		points.append(rect.end)
	if points.is_empty(): return Rect2()
	var transform: Transform2D = board.get_global_transform_with_canvas()
	var bounds := Rect2(transform * points[0], Vector2.ZERO)
	for point: Vector2 in points: bounds = bounds.expand(transform * point)
	# Impact shake is submitted outside the rig texture.
	if board._unit_impact_shake_strength(unit) > 0.0: bounds = bounds.grow(3.0)
	return bounds

static func margin(rect: Rect2, crop: Rect2i) -> float:
	var scale: Vector2 = LOOP_SIZE / Vector2(crop.size)
	var inset: Vector2 = (rect.position - Vector2(crop.position)) * scale
	var trailing: Vector2 = (Vector2(crop.end) - rect.end) * scale
	return minf(minf(inset.x, inset.y), minf(trailing.x, trailing.y)) - FILTER_PAD_PIXELS
