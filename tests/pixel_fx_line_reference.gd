extends Node2D

## Frozen round-2/3 cell renderer for same-frame GPU comparison only.
const Pixel = preload("res://scripts/pixel_fx_layer.gd")
var strokes: Array[Dictionary]

class Capture extends Pixel.Drawing:
	var strokes: Array[Dictionary]
	func _pixel_line(points: PackedVector2Array, core: Color, halo: Color) -> bool:
		# Replays the pre-round-4 rule, including cores below the new floor.
		if core.a > 0.0:
			strokes.append({"vertices": cell_transform * command_transform * points, "core": core, "halo": halo, "element": element})
		return true

func _draw() -> void:
	for stroke: Dictionary in strokes:
		var cells: Array[Vector2i] = line_cells(stroke["vertices"], Transform2D.IDENTITY)
		var core_set: Dictionary = {}
		var halo_set: Dictionary = {}
		for cell: Vector2i in cells: core_set[cell] = true
		for cell: Vector2i in cells:
			for y: int in range(-1, 2):
				for x: int in range(-1, 2):
					var neighbour := cell + Vector2i(x, y)
					if not core_set.has(neighbour): halo_set[neighbour] = true
		for cell: Vector2i in halo_set:
			var color: Color = Pixel.quantize(stroke["halo"], cell, stroke["element"])
			if color.a > 0.0: draw_rect(Rect2(Vector2(cell), Vector2.ONE), color)
		var core: Color = Pixel.quantize(stroke["core"], Vector2i.ZERO, stroke["element"])
		core.a = 1.0
		for cell: Vector2i in cells: draw_rect(Rect2(Vector2(cell), Vector2.ONE), core)

## One-cell Bresenham path through every authored vertex, including endpoints.
## Floor in screen-cell coordinates keeps adjacent tile owners on the same grid.
static func line_cells(points: PackedVector2Array, to_cells: Transform2D) -> Array[Vector2i]:
	var result: Array[Vector2i]
	for index: int in range(1, points.size()):
		var cell := Vector2i((to_cells * points[index - 1]).floor())
		var end := Vector2i((to_cells * points[index]).floor())
		var delta := Vector2i(absi(end.x - cell.x), -absi(end.y - cell.y))
		var step := Vector2i(1 if cell.x < end.x else -1, 1 if cell.y < end.y else -1)
		var error: int = delta.x + delta.y
		while true:
			if result.is_empty() or result[-1] != cell: result.append(cell)
			if cell == end: break
			var twice: int = error * 2
			if twice >= delta.y:
				error += delta.y
				cell.x += step.x
			if twice <= delta.x:
				error += delta.x
				cell.y += step.y
	return result
