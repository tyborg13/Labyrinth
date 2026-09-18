extends RefCounted

# Ordered translucent quads share an atlas of the original procedural textures.
# Geometry and painter order are unchanged; ribbons/lines remain separate.
static var _atlas: Texture2D
static var _regions: Dictionary = {}
var _canvas: CanvasItem
var _points := PackedVector2Array()
var _colors := PackedColorArray()
var _uvs := PackedVector2Array()
var _indices := PackedInt32Array()

static func prepare(light: Texture2D, clouds: Array[Texture2D]) -> void:
	# Called only when ElementalSpellFx generates a new ingredient set.
	# Rebuild both pixels and identity mapping together after cache resets.
	_regions.clear()
	var image := Image.create(512, 256, false, Image.FORMAT_RGBA8)
	var sources: Array[Texture2D]
	sources.append(light)
	sources.append_array(clouds)
	for index: int in range(sources.size()):
		var source: Image = sources[index].get_image()
		var origin := Vector2i((index % 4) * 128 + 8, (index / 4) * 128 + 8)
		image.blit_rect(source, Rect2i(Vector2i.ZERO, source.get_size()), origin)
		var start: Vector2 = Vector2(origin) / Vector2(512, 256)
		var end: Vector2 = Vector2(origin + source.get_size()) / Vector2(512, 256)
		_regions[sources[index].get_rid()] = PackedVector2Array([start, Vector2(end.x, start.y), end, Vector2(start.x, end.y)])
	_atlas = ImageTexture.create_from_image(image)

func _init(canvas: CanvasItem) -> void:
	_canvas = canvas

func sprite(texture: Texture2D, vertices: PackedVector2Array, tint: Color) -> void:
	var start: int = _points.size()
	_points.append_array(vertices)
	_colors.append_array(PackedColorArray([tint, tint, tint, tint]))
	_uvs.append_array(_regions[texture.get_rid()])
	_indices.append_array(PackedInt32Array([start + 3, start, start + 1, start + 1, start + 2, start + 3]))

func flush() -> void:
	if _points.is_empty():
		return
	RenderingServer.canvas_item_add_triangle_array(_canvas.get_canvas_item(), _indices, _points, _colors, _uvs, PackedInt32Array(), PackedFloat32Array(), _atlas.get_rid())
	_points.clear()
	_colors.clear()
	_uvs.clear()
	_indices.clear()
