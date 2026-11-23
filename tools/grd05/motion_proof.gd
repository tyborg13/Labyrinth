extends RefCounted
## Headless checks for the approved atlas data.

const Layer = preload("res://scripts/board_pixel_surface_layer.gd")
const Field = preload("res://scripts/board_pixel_surface_field.gd")
const ELECTRIFIED: int = 3
const ICE: int = 2

static func check_atlases(layer: Layer) -> PackedStringArray:
	return PackedStringArray([_check_electrified_atlas(layer), _check_ice_atlas(layer)])

static func _check_electrified_atlas(layer: Layer) -> String:
	var config: Dictionary = layer._style["electrified"]
	var atlas: Dictionary = layer._atlases[ELECTRIFIED]
	var spec: Dictionary = config["fixture_atlas"] if atlas["fixture"] else config["atlas"]
	var texture: Texture2D = atlas["texture"]
	var image: Image = texture.get_image()
	image.convert(Image.FORMAT_RGBA8)
	assert(Layer.ramp_id("electrified") == "lightning")
	var rects: Array[Rect2i] = atlas["rects"]
	assert(rects.size() == spec["rects"].size() and not rects.is_empty())
	var opaque: int = 0
	for rect: Rect2i in rects:
		var pixels: PackedByteArray = image.get_region(rect).get_data()
		var max_path: int = 0
		var mask: int = 0
		var cores: int = 0
		var opaque_before: int = opaque
		for y: int in rect.size.y:
			for x: int in rect.size.x:
				var address: int = (y * rect.size.x + x) * 4
				assert(pixels[address + 3] in [0, 255])
				if pixels[address + 3] == 0:
					continue
				var index: int = pixels[address]
				var distance: int = pixels[address + 1]
				var sector: int = pixels[address + 2]
				assert(index in [0, 64, 128, 191, 255])
				assert(sector % 32 == 0 and sector < 32 * int(config["sector_count"]))
				assert(index != 255 or distance == 0)
				if distance == 0:
					cores += 1
				else:
					_check_path_neighbors(pixels, rect.size, Vector2i(x, y), distance)
					mask |= 1 << (sector >> 5)
					max_path = maxi(max_path, distance)
				opaque += 1
		assert(opaque > opaque_before and cores > 0 and max_path > 0)
		assert(atlas["motion_records"][rect] == Color(max_path, mask, 0, 0))
	return "GRD-05 ELECTRIFIED ATLAS: PASS (%d rects, %d indexed texels, 8-connected path distance and sectors 0–7)" % [rects.size(), opaque]

static func _check_path_neighbors(pixels: PackedByteArray, size: Vector2i, point: Vector2i, distance: int) -> void:
	var bounds := Rect2i(Vector2i.ZERO, size)
	var can_reach_core: bool = false
	for delta: Vector2i in Field.NEIGHBORS:
		var neighbor: Vector2i = point + delta
		if not bounds.has_point(neighbor):
			continue
		var address: int = (neighbor.y * size.x + neighbor.x) * 4
		if pixels[address + 3] > 0:
			var next: int = pixels[address + 1]
			assert(absi(next - distance) <= 1)
			can_reach_core = can_reach_core or next < distance or distance == 255
	assert(can_reach_core)

static func _check_ice_atlas(layer: Layer) -> String:
	var atlas: Dictionary = layer._atlases[ICE]
	var texture: Texture2D = atlas["texture"]
	var image: Image = texture.get_image()
	var sparkle_lookup: Texture2D = atlas["sparkles"]
	var sparkle_texels: Image = sparkle_lookup.get_image()
	var rim_count: int = 0
	var count: int = 0
	for rect: Rect2i in atlas["rects"]:
		var record: Color = atlas["motion_records"][rect]
		assert(int(record.r) == count and int(record.g) > 1)
		var candidates: Dictionary = {}
		for i: int in range(count, count + int(record.g)):
			@warning_ignore("integer_division")
			var lookup: Color = sparkle_texels.get_pixel(i % sparkle_texels.get_width(), i / sparkle_texels.get_width())
			var point := Vector2i(lookup.r, lookup.g)
			var texel: Color = image.get_pixelv(point)
			var authored: int = 3 if i - count < int(record.b) else 4
			assert(rect.has_point(point) and texel.a == 1.0 and roundi(texel.r * 4.0) == authored)
			assert(not candidates.has(point))
			candidates[point] = true
		count += candidates.size()
		for y: int in range(rect.position.y, rect.end.y):
			for x: int in range(rect.position.x, rect.end.x):
				var texel: Color = image.get_pixel(x, y)
				if texel.a == 0.0:
					continue
				assert(candidates.has(Vector2i(x, y)) == (roundi(texel.r * 4.0) >= 3))
				var edge: bool = _has_transparent_neighbor(image, rect, Vector2i(x, y))
				assert(texel.g == float(edge))
				rim_count += int(edge)
	assert(rim_count > 0)
	return "GRD-05 ICE ATLAS: PASS (%d eligible sparkle texels, %d texels in the two-texel alpha rim)" % [count, rim_count]

static func _has_transparent_neighbor(image: Image, rect: Rect2i, point: Vector2i) -> bool:
	for direction: Vector2i in Field.NEIGHBORS:
		var neighbor: Vector2i = point + direction
		if not rect.has_point(neighbor) or image.get_pixelv(neighbor).a == 0.0:
			return true
	for i: int in 4:
		var neighbor: Vector2i = point + Field.NEIGHBORS[i] * 2
		if not rect.has_point(neighbor) or image.get_pixelv(neighbor).a == 0.0:
			return true
	return false
