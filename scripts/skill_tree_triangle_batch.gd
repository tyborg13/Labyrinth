extends "res://scripts/board_hud_triangle_batch.gd"

## Skill-tree-only, ordered untextured uploads. Geometry follows Godot 4.6.1's
## RendererCanvasCull and CanvasItem (MIT; Godot Engine contributors):
## https://github.com/godotengine/godot/blob/4.6.1-stable/servers/rendering/renderer_canvas_cull.cpp
## https://github.com/godotengine/godot/blob/4.6.1-stable/scene/main/canvas_item.cpp
## Keep native tessellation, feather strips, float32 rounding and paint order.
## RD primitives store half colours; polygons store float colours. Never merge
## across a texture or transform. The inherited cache compares exact inputs as
## well as their hash, and has a bounded lifetime per drawing owner.
# Godot geometry portions: Copyright (c) 2014-present Godot Engine contributors.
# Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
# of the Software, and to permit persons to whom the Software is furnished to do
# so, subject to the following conditions: The above copyright notice and this
# permission notice shall be included in all copies or substantial portions of
# the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
# EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES
# OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
# DEALINGS IN THE SOFTWARE.
const FEATHER: float = 1.25
const RETAINED_STATES: int = 4
const MODULATION_WATCH_USEC: int = 1000000
var _quad_indices := PackedInt32Array([0, 1, 2, 0, 2, 3])
var _half_colors: Dictionary = {}
var _modulation_deadline_usec: int = 0
var _modulation_watch_scheduled: bool = false
var _points := PackedVector2Array()
var _colors := PackedColorArray()
var _indices := PackedInt32Array()
var _half_buffer := PackedByteArray()

func _init() -> void:
	cache_capacity = RETAINED_STATES

func line(from: Vector2, to: Vector2, color: Color, width: float, aa: bool = true) -> void:
	_pending.append(["draw_line", from, to, color, width, aa])

func polyline(points: PackedVector2Array, color: Color, width: float, aa: bool = true) -> void:
	_pending.append(["draw_polyline", points, color, width, aa])

func multiline(points: PackedVector2Array, color: Color, width: float, aa: bool = true) -> void:
	_pending.append(["draw_multiline", points, color, width, aa])

func arc(center: Vector2, radius: float, start: float, end: float, count: int, color: Color, width: float, aa: bool = true) -> void:
	_pending.append(["draw_arc", center, radius, start, end, count, color, width, aa])

func rectangle(rect: Rect2, color: Color, filled: bool, width: float, aa: bool = true) -> void:
	assert(not filled and width < minf(rect.size.x, rect.size.y))
	_pending.append(["draw_rect", rect, color, filled, width, aa])

func circle(center: Vector2, radius: float, color: Color, antialiased: bool = false) -> void:
	disc(center, radius, color, true, -1.0, antialiased)

func polygon(points: PackedVector2Array, colors: PackedColorArray) -> void:
	_pending.append(["draw_polygon", points, colors])

func disc(center: Vector2, radius: float, color: Color, filled: bool = true, width: float = -1.0, antialiased: bool = false) -> void:
	_pending.append(["draw_circle", center, radius, color, true, -1.0, antialiased])

func flush(canvas: CanvasItem) -> void:
	# Primitive half-colour packing occurs AFTER inherited modulation and linear
	# conversion. Retain native commands for those paths, and other engines or
	# backends, rather than approximate their output with prepacked vertices.
	if not _can_batch(canvas):
		for command: Array in _pending:
			canvas.callv(command[0], command.slice(1))
		_pending.clear()
		if _supports_batch(canvas): _watch_modulation(canvas)
		return
	super.flush(canvas)

func _supports_batch(canvas: CanvasItem) -> bool:
	var version: Dictionary = Engine.get_version_info()
	if int(version["major"]) != 4 or int(version["minor"]) != 6 or int(version["patch"]) != 1:
		return false
	if canvas.get_viewport().use_hdr_2d:
		return false
	# Compatibility's native primitive colour path differs from RD's half floats.
	return DisplayServer.get_name() == "headless" or RenderingServer.get_rendering_device() != null

func _can_batch(canvas: CanvasItem) -> bool:
	if not _supports_batch(canvas): return false
	if canvas.self_modulate != Color.WHITE:
		return false
	var item: CanvasItem = canvas
	while item != null:
		if item.modulate != Color.WHITE:
			return false
		item = _parent_item(item)
	return true

func _watch_modulation(canvas: CanvasItem) -> void:
	if _modulation_watch_scheduled: return
	_modulation_deadline_usec = Time.get_ticks_usec() + MODULATION_WATCH_USEC
	_schedule_modulation_check(canvas)

func _schedule_modulation_check(canvas: CanvasItem) -> void:
	_modulation_watch_scheduled = true
	canvas.get_tree().process_frame.connect(_check_modulation.bind(weakref(canvas)), CONNECT_ONE_SHOT)

func _check_modulation(reference: WeakRef) -> void:
	_modulation_watch_scheduled = false
	var canvas: CanvasItem = reference.get_ref() as CanvasItem
	if not is_instance_valid(canvas) or not canvas.is_inside_tree() or not canvas.is_visible_in_tree(): return
	# Character arrives with inherited opacity 0.86 -> 1. Native commands render
	# that fade unchanged; modulation alone does not send NOTIFICATION_DRAW.
	# Repaint once it becomes opaque, then stop observing. Stable non-white
	# callers also stop after the bounded watch; no idle processing is added.
	if _can_batch(canvas):
		canvas.queue_redraw()
	elif Time.get_ticks_usec() < _modulation_deadline_usec:
		_schedule_modulation_check(canvas)

func _parent_item(item: CanvasItem) -> CanvasItem:
	if item.is_set_as_top_level(): return null
	var parent: Node = item.get_parent()
	while parent != null and not parent is Viewport and not parent is CanvasLayer:
		if parent is CanvasItem: return parent as CanvasItem
		parent = parent.get_parent()
	return null

func _build(commands: Array[Array]) -> Dictionary:
	_points = PackedVector2Array()
	_colors = PackedColorArray()
	_indices = PackedInt32Array()
	var result: Dictionary = {}
	for command: Array in commands:
		match command[0]:
			"draw_polygon":
				_append(result, command[1], command[2], Geometry2D.triangulate_polygon(command[1]))
			"draw_circle":
				_append_circle(result, command[1], command[2], command[3], command[6])
			"draw_line":
				_append_line(result, command[1], command[2], command[3], command[4], command[5])
			"draw_multiline":
				var points: PackedVector2Array = command[1]
				for index: int in range(0, points.size(), 2):
					_append_line(result, points[index], points[index + 1], command[2], command[3], command[4])
			"draw_polyline":
				_append_polyline(result, command[1], command[2], command[3], command[4])
			"draw_arc":
				_append_arc(result, command)
			"draw_rect":
				var rect: Rect2 = command[1]
				_append_polyline(result, PackedVector2Array([rect.position, rect.position + Vector2(rect.size.x, 0.0), rect.end, rect.position + Vector2(0.0, rect.size.y), rect.position]), command[2], command[4], command[5])
	return {"points": _points, "colors": _colors, "indices": _indices}

func _append(_result: Dictionary, points: PackedVector2Array, colors: PackedColorArray, indices: PackedInt32Array) -> void:
	var first: int = _points.size()
	_points.append_array(points)
	for index: int in range(points.size()): _colors.append(colors[0] if colors.size() == 1 else colors[index])
	for index: int in indices: _indices.append(first + index)

func _f32(value: float) -> float:
	return Vector2(value, 0.0).x

func _half(color: Color) -> Color:
	if _half_colors.has(color): return _half_colors[color]
	if _half_buffer.is_empty(): _half_buffer.resize(8)
	for index: int in range(4): _half_buffer.encode_half(index * 2, color[index])
	var packed := Color(_half_buffer.decode_half(0), _half_buffer.decode_half(2), _half_buffer.decode_half(4), _half_buffer.decode_half(6))
	if _half_colors.size() >= CACHE_CAPACITY: _half_colors.clear()
	_half_colors[color] = packed
	return packed

func _quad(result: Dictionary, points: PackedVector2Array, colors: PackedColorArray) -> void:
	_append(result, points, colors, _quad_indices)

func _append_line(result: Dictionary, from: Vector2, to: Vector2, color: Color, width: float, aa: bool) -> void:
	width = _f32(width)
	assert(width >= 0.0)
	var diff: Vector2 = from - to
	var normal: Vector2 = diff.orthogonal().normalized()
	var offset: Vector2 = normal * width * 0.5
	var a: Vector2 = from + offset
	var b: Vector2 = from - offset
	var c: Vector2 = to + offset
	var d: Vector2 = to - offset
	color = _half(color)
	_quad(result, PackedVector2Array([a, b, d, c]), PackedColorArray([color]))
	if not aa: return
	var feather: float = _f32(FEATHER * width) if width < 1.0 else FEATHER
	var side: Vector2 = normal * feather
	var cap: Vector2 = diff.normalized() * feather
	var clear := Color(color, 0.0)
	var edge_colors := PackedColorArray([color, clear, clear, color])
	var corner_colors := PackedColorArray([color, clear, clear, clear])
	_quad(result, PackedVector2Array([a, a + side, c + side, c]), edge_colors)
	_quad(result, PackedVector2Array([b, b - side, d - side, d]), edge_colors)
	_quad(result, PackedVector2Array([a, a + cap, b + cap, b]), edge_colors)
	_quad(result, PackedVector2Array([c, c - cap, d - cap, d]), edge_colors)
	_quad(result, PackedVector2Array([a, a + cap, a + side + cap, a + side]), corner_colors)
	_quad(result, PackedVector2Array([b, b + cap, b - side + cap, b - side]), corner_colors)
	_quad(result, PackedVector2Array([c, c - cap, c + side - cap, c + side]), corner_colors)
	_quad(result, PackedVector2Array([d, d - cap, d - side - cap, d - side]), corner_colors)

func _append_arc(result: Dictionary, command: Array) -> void:
	var points := PackedVector2Array()
	var start: float = _f32(command[3])
	var difference: float = clampf(_f32(_f32(command[4]) - start), -_f32(TAU), _f32(TAU))
	var count: int = command[5]
	for index: int in range(count):
		var angle: float = _f32(_f32(_f32(float(index) / float(count - 1)) * difference) + start)
		points.append(command[1] + Vector2.from_angle(angle) * _f32(command[2]))
	_append_polyline(result, points, command[6], command[7], command[8])

func _edge_offset(segment: Vector2, previous: Vector2) -> Vector2:
	var bisector: Vector2 = (previous * segment.length() - segment * previous.length()).normalized()
	var angle: float = Vector2(bisector.dot(previous), bisector.cross(previous)).angle()
	var sine: float = Vector2.from_angle(angle).y
	var length: float = 1.0
	if not is_zero_approx(sine) and not segment.is_equal_approx(previous):
		length = clampf(_f32(1.0 / sine), -3.0, 3.0)
	else:
		bisector = segment.orthogonal()
	if bisector.is_zero_approx(): bisector = segment.orthogonal()
	return bisector * length

func _strip(result: Dictionary, points: PackedVector2Array, colors: PackedColorArray) -> void:
	var indices := PackedInt32Array()
	for index: int in range(points.size() - 2):
		indices.append_array(PackedInt32Array([index + index % 2, index + 1 - index % 2, index + 2]))
	_append(result, points, colors, indices)

func _append_polyline(result: Dictionary, path: PackedVector2Array, color: Color, width: float, aa: bool) -> void:
	if path.size() < 2: return
	width = _f32(width)
	assert(width >= 0.0)
	var loop: bool = path[0].is_equal_approx(path[-1])
	var first := Vector2.ZERO
	var last := Vector2.ZERO
	for index: int in range(1, path.size()):
		first = (path[index] - path[index - 1]).normalized()
		if not first.is_zero_approx(): break
	for index: int in range(path.size() - 1, 0, -1):
		last = (path[index] - path[index - 1]).normalized()
		if not last.is_zero_approx(): break
	var count: int = path.size() * 2
	var cap_count: int = 4 if aa and not loop else 0
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	points.resize(count + cap_count)
	colors.resize(points.size())
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var edge_colors := PackedColorArray()
	if aa:
		left.resize(count + (0 if loop else 5))
		right.resize(left.size())
		edge_colors.resize(left.size())
	var previous := Vector2.ZERO
	var feather: float = _f32(FEATHER * width) if width < 1.0 else FEATHER
	var clear := Color(color, 0.0)
	for index: int in range(path.size()):
		var segment: Vector2 = previous if index == path.size() - 1 else (path[index + 1] - path[index]).normalized()
		if segment.is_zero_approx(): segment = previous
		if loop and index == 0: previous = last
		elif loop and index == path.size() - 1: previous = first
		var base: Vector2
		if not loop and index == 0: base = first.orthogonal()
		elif not loop and index == path.size() - 1: base = last.orthogonal()
		else: base = _edge_offset(segment, previous)
		var edge: Vector2 = base * _f32(width * 0.5)
		var border: Vector2 = base * feather
		var pos: Vector2 = path[index]
		var j: int = index * 2 + (2 if aa and not loop else 0)
		points[j] = pos + edge
		points[j + 1] = pos - edge
		colors[j] = color
		colors[j + 1] = color
		if aa:
			left[j] = pos + edge
			left[j + 1] = pos + edge + border
			right[j] = pos - edge
			right[j + 1] = pos - edge - border
			edge_colors[j] = color
			edge_colors[j + 1] = clear
			if not loop and index == 0:
				var cap: Vector2 = -segment * feather
				points[0] = pos + edge + cap
				points[1] = pos - edge + cap
				colors[0] = clear
				colors[1] = clear
				left[0] = pos + edge + cap
				left[1] = pos + edge + cap + border
				right[0] = pos - edge + cap
				right[1] = pos - edge + cap - border
				edge_colors[0] = clear
				edge_colors[1] = clear
			if not loop and index == path.size() - 1:
				var cap: Vector2 = previous * feather
				var end: int = count + 2
				points[end] = pos + edge + cap
				points[end + 1] = pos - edge + cap
				colors[end] = clear
				colors[end + 1] = clear
				left[end] = pos + edge
				left[end + 1] = pos + edge + cap + border
				left[end + 2] = pos + edge + cap
				right[end] = pos - edge
				right[end + 1] = pos - edge + cap - border
				right[end + 2] = pos - edge + cap
				edge_colors[end] = color
				edge_colors[end + 1] = clear
				edge_colors[end + 2] = clear
		previous = segment
	# Native allocates the body command first, then the two feather commands.
	_strip(result, points, colors)
	if aa:
		_strip(result, left, edge_colors)
		_strip(result, right, edge_colors)
