extends RefCounted

## Exact replacement for the former per-cell draw_rect loop. Geometry is keyed
## by the authored arc and screen transform; batches also include colour/order.
## The owner keeps this bounded cache across review-toggle viewport recreation.
const MAX_SHAPES: int = 1024
const MAX_BATCHES: int = 32
const MAX_CACHED_QUADS: int = 65536
var _rasterize: Callable
var _quantize: Callable
var _shapes: Dictionary = {}
var _batches: Dictionary = {}
var _next_shape: int = 0
var _cached_quads: int = 0
var rasterizations: int = 0
var mesh_builds: int = 0

func _init(rasterize: Callable, quantize: Callable) -> void:
	_rasterize = rasterize
	_quantize = quantize

func stroke(points: PackedVector2Array, to_cells: Transform2D, core: Color, halo: Color, element: String) -> Dictionary:
	var key: Array = [points, to_cells]
	var shape: Dictionary = _shapes.get(key, {})
	if shape.is_empty():
		var cells: Array[Vector2i] = _rasterize.call(points, to_cells)
		shape = {"id": _next_shape, "cells": cells, "vertices": to_cells * points}
		_next_shape += 1
		rasterizations += 1
		if _shapes.size() == MAX_SHAPES: _shapes.erase(_shapes.keys()[0])
	else:
		_shapes.erase(key)
	_shapes[key] = shape
	return {"shape": shape, "cells": shape["cells"], "vertices": shape["vertices"], "core": core, "halo": halo, "element": element}

func batch(strokes: Array[Dictionary]) -> ArrayMesh:
	if strokes.is_empty(): return null
	var key: Array = []
	for entry: Dictionary in strokes:
		key.append([entry["shape"]["id"], entry["core"], entry["halo"], entry["element"]])
	if _batches.has(key):
		var cached: Dictionary = _batches[key]
		_batches.erase(key)
		_batches[key] = cached
		return cached["mesh"]
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for entry: Dictionary in strokes:
		var shape: Dictionary = entry["shape"]
		var palette := PackedColorArray()
		for index: int in range(16):
			palette.append(_quantize.call(entry["halo"], Vector2i(index % 4, index / 4), entry["element"]))
		if palette[0].a > 0.0:
			# Neighbourhoods depend only on the arc, not its colour or fade.
			if not shape.has("halo"):
				var core_set: Dictionary = {}
				var halo_set: Dictionary = {}
				for cell: Vector2i in shape["cells"]: core_set[cell] = true
				for cell: Vector2i in shape["cells"]:
					for y: int in range(-1, 2):
						for x: int in range(-1, 2):
							var neighbour := cell + Vector2i(x, y)
							if not core_set.has(neighbour): halo_set[neighbour] = true
				shape["halo"] = halo_set.keys()
			for cell: Vector2i in shape["halo"]:
				var color: Color = palette[posmod(cell.y, 4) * 4 + posmod(cell.x, 4)]
				if color.a > 0.0: _quad(vertices, colors, indices, cell, color)
		var core: Color = _quantize.call(entry["core"], Vector2i.ZERO, entry["element"])
		core.a = 1.0
		for cell: Vector2i in shape["cells"]: _quad(vertices, colors, indices, cell, core)
	if vertices.is_empty(): return null
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh_builds += 1
	var quads: int = vertices.size() / 4
	while not _batches.is_empty() and (_batches.size() >= MAX_BATCHES or _cached_quads + quads > MAX_CACHED_QUADS):
		var oldest: Array = _batches.keys()[0]
		_cached_quads -= int(_batches[oldest]["quads"])
		_batches.erase(oldest)
	if quads <= MAX_CACHED_QUADS:
		_batches[key] = {"mesh": mesh, "quads": quads}
		_cached_quads += quads
	return mesh

func _quad(vertices: PackedVector2Array, colors: PackedColorArray, indices: PackedInt32Array, cell: Vector2i, color: Color) -> void:
	var first: int = vertices.size()
	var point := Vector2(cell)
	vertices.append_array(PackedVector2Array([point, point + Vector2.RIGHT, point + Vector2.ONE, point + Vector2.DOWN]))
	colors.append_array(PackedColorArray([color, color, color, color]))
	indices.append_array(PackedInt32Array([first, first + 1, first + 2, first, first + 2, first + 3]))
