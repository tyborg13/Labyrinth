extends RefCounted

## Consecutive untextured HUD geometry, in its original paint order. Callers
## flush before any native command or transform change; nothing is reordered.
## Use canvas triangle arrays rather than ArrayMesh's packed vertex colours:
## this retains the same float-colour polygon upload as draw_polygon/circle.
const CACHE_CAPACITY: int = 128
const CIRCLE_SEGMENTS: int = 64
const CIRCLE_FEATHER: float = 1.25
var cache_capacity: int = CACHE_CAPACITY
var _pending: Array[Array]
var _cache: Dictionary = {}
var _order: Array[int]
static var _circle_directions: PackedVector2Array

func polygon(points: PackedVector2Array, colors: PackedColorArray) -> void:
	_pending.append([points, colors])

func circle(center: Vector2, radius: float, color: Color, antialiased: bool = false) -> void:
	_pending.append([center, radius, color, antialiased])

func flush(canvas: CanvasItem) -> void:
	if _pending.is_empty(): return
	var key: int = hash(_pending)
	var entry: Dictionary = _cache.get(key, {})
	if entry.is_empty() or entry["inputs"] != _pending:
		entry = _build(_pending)
		entry["inputs"] = _pending.duplicate(true)
		if not _cache.has(key):
			if _order.size() >= cache_capacity: _cache.erase(_order.pop_front())
			_order.append(key)
		_cache[key] = entry
	_pending.clear()
	if not (entry["indices"] as PackedInt32Array).is_empty():
		RenderingServer.canvas_item_add_triangle_array(canvas.get_canvas_item(), entry["indices"], entry["points"], entry["colors"])

func _build(commands: Array[Array]) -> Dictionary:
	var result: Dictionary = {"points": PackedVector2Array(), "colors": PackedColorArray(), "indices": PackedInt32Array()}
	for command: Array in commands:
		if command[0] is PackedVector2Array:
			_append(result, command[0], command[1], Geometry2D.triangulate_polygon(command[0]))
		else:
			_append_circle(result, command[0], command[1], command[2], command[3])
	return result

func _append(result: Dictionary, points: PackedVector2Array, colors: PackedColorArray, indices: PackedInt32Array) -> void:
	var first: int = (result["points"] as PackedVector2Array).size()
	var all_points: PackedVector2Array = result["points"]
	var all_colors: PackedColorArray = result["colors"]
	var all_indices: PackedInt32Array = result["indices"]
	all_points.append_array(points)
	for index: int in range(points.size()): all_colors.append(colors[0] if colors.size() == 1 else colors[index])
	for index: int in indices: all_indices.append(first + index)
	result["points"] = all_points
	result["colors"] = all_colors
	result["indices"] = all_indices

func _append_circle(result: Dictionary, center: Vector2, radius: float, color: Color, antialiased: bool) -> void:
	# Match Godot 4.6.1 RendererCanvasCull::canvas_item_add_ellipse (MIT):
	# https://github.com/godotengine/godot/blob/4.6.1-stable/servers/rendering/renderer_canvas_cull.cpp
	# Native real_t/angle/radius arithmetic is float32. Vector2 operations and
	# from_angle retain those rounding points (GDScript scalar floats are doubles).
	if _circle_directions.is_empty():
		var step: float = Vector2(TAU / CIRCLE_SEGMENTS, 0.0).x
		for index: int in range(CIRCLE_SEGMENTS + 1):
			_circle_directions.append(Vector2.from_angle(Vector2(float(index) * step, 0.0).x))
	radius = Vector2(radius, 0.0).x
	var points := PackedVector2Array()
	var indices := PackedInt32Array()
	for direction: Vector2 in _circle_directions: points.append(direction * radius + center)
	points.append(center)
	for index: int in range(CIRCLE_SEGMENTS): indices.append_array(PackedInt32Array([CIRCLE_SEGMENTS + 1, index, index + 1]))
	_append(result, points, PackedColorArray([color]), indices)
	if not antialiased: return
	var feather: float = CIRCLE_FEATHER
	var diameter: float = Vector2(radius * 2.0, 0.0).x
	if diameter >= 0.0 and diameter < 1.0: feather = Vector2(feather * diameter * 0.5, 0.0).x
	var outer_radius: float = Vector2(radius + feather, 0.0).x
	points.clear()
	indices.clear()
	var colors := PackedColorArray()
	for direction: Vector2 in _circle_directions:
		points.append(direction * radius + center)
		points.append(direction * outer_radius + center)
		colors.append(color)
		colors.append(Color(color, 0.0))
	# Preserve the feather strip's exact triangles and winding, after the fan.
	for index: int in range(points.size() - 2):
		indices.append_array(PackedInt32Array([index + (index % 2), index + 1 - (index % 2), index + 2]))
	_append(result, points, colors, indices)
