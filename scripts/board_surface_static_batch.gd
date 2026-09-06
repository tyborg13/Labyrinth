extends RefCounted

## Ordered material triangles share one runtime atlas of procedural grain and
## white. This combines submissions, never flattens the shaded floor geometry.
static var _atlas: Texture2D
var _canvas: CanvasItem
var _points := PackedVector2Array()
var _colors := PackedColorArray()
var _uv := PackedVector2Array()
var _indices := PackedInt32Array()

func _init(canvas: CanvasItem, grain: Texture2D) -> void:
	_canvas = canvas
	if _atlas == null:
		var source: Image = grain.get_image()
		var image := Image.create(128, 128, false, Image.FORMAT_RGBA8)
		image.blit_rect(source, Rect2i(0, 0, 64, 64), Vector2i.ZERO)
		# Grain UVs stay below 0.95, so the source's outer filtering never
		# touches another primitive. Powers of two preserve sample arithmetic.
		image.fill_rect(Rect2i(80, 80, 16, 16), Color.WHITE)
		_atlas = ImageTexture.create_from_image(image)

func polygon(points: PackedVector2Array, colors: PackedColorArray, grain_uv: PackedVector2Array = PackedVector2Array()) -> void:
	var triangles: PackedInt32Array = Geometry2D.triangulate_polygon(points)
	assert(not triangles.is_empty(), "Static ground polygon must retain valid triangulation")
	var start: int = _points.size()
	_points.append_array(points)
	for index: int in triangles: _indices.append(start + index)
	for index: int in range(points.size()):
		_colors.append(colors[0] if colors.size() == 1 else colors[index])
		_uv.append(Vector2(0.6875, 0.6875) if grain_uv.is_empty() else grain_uv[index] * 0.5)

func flush() -> void:
	if _points.is_empty(): return
	RenderingServer.canvas_item_add_triangle_array(_canvas.get_canvas_item(), _indices, _points, _colors, _uv, PackedInt32Array(), PackedFloat32Array(), _atlas.get_rid())
	_points.clear()
	_colors.clear()
	_uv.clear()
	_indices.clear()
