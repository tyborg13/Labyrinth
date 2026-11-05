extends RefCounted
## Retain the canvas polygon path's float colours and original triangulation.
## Unlike ArrayMesh, triangle arrays preserve the native polygon vertex format.
## Explicit seal() calls retain required draw boundaries between gradient rows.

var _points := PackedVector2Array()
var _colours := PackedColorArray()
var _indices := PackedInt32Array()
var _commands: Array[Dictionary]

func polygon(points: PackedVector2Array, colours: PackedColorArray) -> void:
	var offset: int = _points.size()
	_points.append_array(points)
	for index: int in range(points.size()):
		_colours.append(colours[0] if colours.size() == 1 else colours[index])
	for index: int in Geometry2D.triangulate_polygon(points):
		_indices.append(offset + index)

func native_polygon(points: PackedVector2Array, colours: PackedColorArray) -> void:
	seal()
	_commands.append({"native_points": points, "colours": colours})

func seal() -> void:
	if _indices.is_empty(): return
	_commands.append({"points": _points, "colours": _colours, "indices": _indices})
	_points = PackedVector2Array()
	_colours = PackedColorArray()
	_indices = PackedInt32Array()

func draw_on(item: CanvasItem) -> void:
	for command: Dictionary in _commands:
		if command.has("native_points"):
			item.draw_polygon(command["native_points"], command["colours"])
		else:
			RenderingServer.canvas_item_add_triangle_array(item.get_canvas_item(), command["indices"], command["points"], command["colours"])
