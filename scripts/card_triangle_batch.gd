extends "res://scripts/board_hud_triangle_batch.gd"

# Polyline tessellation adapted from Godot Engine (MIT):
# Copyright (c) 2014-present Godot Engine contributors (see AUTHORS.md).
# Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

## Card-only extension: the board's proven circle/polygon path stays unchanged.
## Match Godot 4.6.1's canvas_item_add_polyline and CanvasItem::draw_ellipse_arc:
## https://github.com/godotengine/godot/blob/4.6.1-stable/servers/rendering/renderer_canvas_cull.cpp
## https://github.com/godotengine/godot/blob/4.6.1-stable/scene/main/canvas_item.cpp
## Keep the middle/left/right strips, cap degenerates and float32 rounding.
## Single draw_line commands stay native: they use a different primitive path.

# Animated watches retain only a small recent working set, per card.
const CARD_CACHE_CAPACITY: int = 8

func _init() -> void:
	cache_capacity = CARD_CACHE_CAPACITY

func colored_polygon(points: PackedVector2Array, color: Color) -> void:
	polygon(points, PackedColorArray([color]))

func polyline(points: PackedVector2Array, color: Color, width: float, antialiased: bool = true) -> void:
	assert(points.size() >= 2 and width >= 0.0 and antialiased)
	_pending.append(["polyline", points, color, width])

func arc(center: Vector2, radius: float, start: float, end: float, count: int, color: Color, width: float, antialiased: bool = true) -> void:
	assert(count >= 2 and width >= 0.0 and antialiased)
	_pending.append(["arc", center, radius, start, end, count, color, width])

func _build(commands: Array[Array]) -> Dictionary:
	var result: Dictionary = {"points": PackedVector2Array(), "colors": PackedColorArray(), "indices": PackedInt32Array()}
	for command: Array in commands:
		if command[0] is PackedVector2Array:
			_append(result, command[0], command[1], Geometry2D.triangulate_polygon(command[0]))
		elif command[0] is Vector2:
			_append_circle(result, command[0], command[1], command[2], command[3])
		elif command[0] == "polyline":
			_append_polyline(result, command[1], command[2], command[3])
		else:
			_append_polyline(result, _arc_points(command[1], command[2], command[3], command[4], command[5]), command[6], command[7])
	return result

static func _f32(value: float) -> float:
	return Vector2(value, 0.0).x

static func _arc_points(center: Vector2, radius: float, start: float, end: float, count: int) -> PackedVector2Array:
	radius = _f32(radius)
	start = _f32(start)
	end = _f32(end)
	var delta: float = _f32(clampf(_f32(end - start), -TAU, TAU))
	var points := PackedVector2Array()
	for index: int in range(count):
		var theta: float = _f32(_f32(_f32(float(index) / float(count - 1)) * delta) + start)
		points.append(center + Vector2.from_angle(theta) * radius)
	return points

static func _edge_offset(direction: Vector2, previous: Vector2) -> Vector2:
	var bisector: Vector2 = (previous * direction.length() - direction * previous.length()).normalized()
	var angle: float = _f32(atan2(bisector.cross(previous), bisector.dot(previous)))
	var sine: float = Vector2.from_angle(angle).y
	var length: float = 1.0
	if not is_zero_approx(sine) and not direction.is_equal_approx(previous):
		length = clampf(_f32(1.0 / sine), -3.0, 3.0)
	else:
		bisector = direction.orthogonal()
	if bisector.is_zero_approx(): bisector = direction.orthogonal()
	return bisector * length

func _append_strip(result: Dictionary, points: PackedVector2Array, colors: PackedColorArray) -> void:
	var indices := PackedInt32Array()
	for index: int in range(points.size() - 2):
		indices.append_array(PackedInt32Array([index + index % 2, index + 1 - index % 2, index + 2]))
	_append(result, points, colors, indices)

func _append_polyline(result: Dictionary, source: PackedVector2Array, color: Color, width: float) -> void:
	width = _f32(width)
	var loop: bool = source[0].is_equal_approx(source[-1])
	var first := Vector2.ZERO
	var last := Vector2.ZERO
	for index: int in range(1, source.size()):
		first = (source[index] - source[index - 1]).normalized()
		if not first.is_zero_approx(): break
	for index: int in range(source.size() - 1, 0, -1):
		last = (source[index] - source[index - 1]).normalized()
		if not last.is_zero_approx(): break
	var feather: float = CIRCLE_FEATHER if width >= 1.0 else _f32(CIRCLE_FEATHER * width)
	var transparent := Color(color, 0.0)
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	var left := PackedVector2Array()
	var left_colors := PackedColorArray()
	var right := PackedVector2Array()
	var right_colors := PackedColorArray()
	var count: int = source.size() * 2
	points.resize(count + (0 if loop else 4))
	colors.resize(points.size())
	left.resize(count + (0 if loop else 5))
	left_colors.resize(left.size())
	right.resize(left.size())
	right_colors.resize(left.size())
	var previous := Vector2.ZERO
	for index: int in range(source.size()):
		var direction: Vector2 = previous if index == source.size() - 1 else (source[index + 1] - source[index]).normalized()
		if direction.is_zero_approx(): direction = previous
		if index == 0 and loop: previous = last
		elif index == source.size() - 1 and loop: previous = first
		var base: Vector2
		if index == 0 and not loop: base = first.orthogonal()
		elif index == source.size() - 1 and not loop: base = last.orthogonal()
		else: base = _edge_offset(direction, previous)
		var edge: Vector2 = base * _f32(width * 0.5)
		var border: Vector2 = base * feather
		var pos: Vector2 = source[index]
		var j: int = index * 2 + (0 if loop else 2)
		points[j] = pos + edge
		points[j + 1] = pos - edge
		left[j] = pos + edge
		left[j + 1] = pos + edge + border
		right[j] = pos - edge
		right[j + 1] = pos - edge - border
		colors[j] = color
		colors[j + 1] = color
		left_colors[j] = color
		left_colors[j + 1] = transparent
		right_colors[j] = color
		right_colors[j + 1] = transparent
		if index == 0 and not loop:
			var begin: Vector2 = -direction * feather
			points[0] = pos + edge + begin
			points[1] = pos - edge + begin
			left[0] = pos + edge + begin
			left[1] = pos + edge + begin + border
			right[0] = pos - edge + begin
			right[1] = pos - edge + begin - border
			colors[0] = transparent
			colors[1] = transparent
			left_colors[0] = transparent
			left_colors[1] = transparent
			right_colors[0] = transparent
			right_colors[1] = transparent
		if index == source.size() - 1 and not loop:
			var end: Vector2 = previous * feather
			var k: int = count + 2
			points[k] = pos + edge + end
			points[k + 1] = pos - edge + end
			colors[k] = transparent
			colors[k + 1] = transparent
			left[k] = pos + edge
			left[k + 1] = pos + edge + end + border
			left[k + 2] = pos + edge + end
			right[k] = pos - edge
			right[k + 1] = pos - edge + end - border
			right[k + 2] = pos - edge + end
			left_colors[k] = color
			left_colors[k + 1] = transparent
			left_colors[k + 2] = transparent
			right_colors[k] = color
			right_colors[k + 1] = transparent
			right_colors[k + 2] = transparent
		previous = direction
	_append_strip(result, points, colors)
	_append_strip(result, left, left_colors)
	_append_strip(result, right, right_colors)
