extends RefCounted
## Once per atlas load, index the authored texels used by ground animation.

const ICE: int = 2
const ELECTRIFIED: int = 3
const TABLE_WIDTH: int = 256

static func prepare(kind: int, atlas: Dictionary, config: Dictionary) -> void:
	if kind != ICE and kind != ELECTRIFIED:
		return
	var source: Texture2D = atlas["texture"]
	var image: Image = source.get_image()
	assert(image != null and not image.is_empty())
	image.convert(Image.FORMAT_RGBA8)
	var width: int = image.get_width()
	var pixels: PackedByteArray = image.get_data()
	var rects: Array[Rect2i] = atlas["rects"]
	var records: Dictionary = {}
	var sparkles := PackedVector2Array()
	for rect: Rect2i in rects:
		if kind == ELECTRIFIED:
			records[rect] = _electrified_record(pixels, width, rect)
		else:
			var first: int = sparkles.size()
			var visible: int = _index_ice(pixels, width, rect, int(config["rim_depth_texels"]), sparkles)
			records[rect] = Color(first, sparkles.size() - first, visible, 0)
	atlas["motion_records"] = records
	if kind == ICE:
		var indexed: Image = Image.create_from_data(width, image.get_height(), false, Image.FORMAT_RGBA8, pixels)
		atlas["texture"] = ImageTexture.create_from_image(indexed)
		atlas["sparkles"] = _sparkle_texture(sparkles)

static func _electrified_record(pixels: PackedByteArray, width: int, rect: Rect2i) -> Color:
	var distance: int = 0
	var sectors: int = 0
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			var offset: int = (y * width + x) * 4
			if pixels[offset + 3] == 0:
				continue
			var path: int = pixels[offset + 1]
			if path > 0:
				sectors |= 1 << (pixels[offset + 2] >> 5)
				distance = maxi(distance, path)
	return Color(distance, sectors, 0, 0)

static func _index_ice(pixels: PackedByteArray, width: int, rect: Rect2i, depth: int,
		sparkles: PackedVector2Array) -> int:
	var first: int = sparkles.size()
	var bright := PackedVector2Array()
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			var offset: int = (y * width + x) * 4
			if pixels[offset + 3] == 0:
				continue
			if pixels[offset] == 191:
				sparkles.append(Vector2(x, y))
			elif pixels[offset] == 255:
				bright.append(Vector2(x, y))
			# The outer two texel layers are within two texels of transparent space.
			pixels[offset + 1] = 255 if _near_alpha_edge(pixels, width, rect, Vector2i(x, y), depth) else 0
	var visible: int = sparkles.size() - first
	sparkles.append_array(bright)
	return visible

static func _near_alpha_edge(pixels: PackedByteArray, width: int, rect: Rect2i, point: Vector2i, depth: int) -> bool:
	if not rect.grow(-depth).has_point(point):
		return true
	for dy: int in range(-depth, depth + 1):
		for dx: int in range(-depth, depth + 1):
			if dx * dx + dy * dy <= depth * depth and pixels[((point.y + dy) * width + point.x + dx) * 4 + 3] == 0:
				return true
	return false

static func _sparkle_texture(points: PackedVector2Array) -> ImageTexture:
	var width: int = clampi(points.size(), 1, TABLE_WIDTH)
	var image: Image = Image.create_empty(width, maxi(1, ceili(float(points.size()) / width)), false, Image.FORMAT_RGF)
	@warning_ignore("integer_division")
	for i: int in points.size():
		image.set_pixel(i % width, i / width, Color(points[i].x, points[i].y, 0, 0))
	return ImageTexture.create_from_image(image)
