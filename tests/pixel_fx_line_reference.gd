extends Node2D

## Frozen round-2 cell renderer for exact optimization A/B proof only.
const Pixel = preload("res://scripts/pixel_fx_layer.gd")
var strokes: Array[Dictionary]

func _draw() -> void:
	for stroke: Dictionary in strokes:
		var cells: Array[Vector2i] = Pixel.line_cells(stroke["vertices"], Transform2D.IDENTITY)
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

static func cells_before_batching(strokes: Array[Dictionary]) -> Dictionary:
	var result: Dictionary = {}
	for stroke: Dictionary in strokes:
		# Re-rasterize the authored vertices, independent of the cached cell list.
		var cells: Array[Vector2i] = Pixel.line_cells(stroke["vertices"], Transform2D.IDENTITY)
		var core_set: Dictionary = {}
		for cell: Vector2i in cells: core_set[cell] = true
		for cell: Vector2i in cells:
			for y: int in range(-1, 2):
				for x: int in range(-1, 2):
					var neighbour := cell + Vector2i(x, y)
					if core_set.has(neighbour): continue
					var color: Color = Pixel.quantize(stroke["halo"], neighbour, stroke["element"])
					if color.a > 0.0: result[neighbour] = color.to_rgba32()
		var core: Color = Pixel.quantize(stroke["core"], Vector2i.ZERO, stroke["element"])
		core.a = 1.0
		for cell: Vector2i in cells: result[cell] = core.to_rgba32()
	return result
