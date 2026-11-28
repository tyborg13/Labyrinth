extends RefCounted

# Stable rest-pose occupancy, separate from the live pose used by the rim shader.
# Only mask creation reads texture pixels. Geometry queries reuse these 25% masks.
const MASK_SCALE: float = 0.25
const OPAQUE_ALPHA: float = 0.5
# Filter alpha before thresholding; nearest reduction aliases thin gear edges.
const RESAMPLE: int = Image.INTERPOLATE_BILINEAR
var masks: Dictionary = {}
var builds: int = 0
var queries: int = 0
var _coverage_cache: Dictionary = {}
var _floor_masks: Dictionary = {}
var _sheet_masks: Dictionary = {}
var _fill_sprite_masks: Dictionary = {}

# Each authored sheet row shares one footprint over its animation cycle.
# Palette index zero is transparent in the production GroundFx shader.
func _sheet_mask(part: Dictionary) -> Dictionary:
	var texture: Texture2D = part["mask_texture"]
	var region: Rect2i = part["mask_region"]
	var key: Array = [texture, region]
	if _sheet_masks.has(key): return _sheet_masks[key]
	var image: Image = texture.get_image()
	if image == null or image.is_empty(): return {}
	if image.is_compressed() and image.decompress() != OK: return {}
	var size: Vector2i = part["sheet_cells"]
	var bits := PackedByteArray()
	bits.resize(size.x * size.y)
	for y: int in size.y:
		for x: int in size.x:
			for frame: int in int(part["sheet_frames"]):
				if image.get_pixel(region.position.x + frame * size.x + x, region.position.y + y).r < 0.5 / 255.0: continue
				bits[y * size.x + x] = 1
				break
	var mask: Dictionary = {"size": size, "bits": bits}
	_sheet_masks[key] = mask
	return mask

func floor_mask(source: Dictionary) -> Dictionary:
	var rect: Rect2 = source["rect"]
	var diamond: PackedVector2Array = source["diamond"]
	var parts: Array = source["parts"]
	var key: String = source["key"]
	var signature: Array = [rect, diamond, parts]
	var cached: Dictionary = _floor_masks.get(key, {})
	if cached.get("signature") == signature: return cached["mask"]
	var prepared: Array[Dictionary]
	for part: Dictionary in parts:
		var mask: Dictionary = _sheet_mask(part) if part.has("sheet_cells") else mask_for(part)
		if not mask.is_empty(): prepared.append(part.merged({"mask": mask}))
	var size := Vector2i((rect.size * MASK_SCALE).ceil()).max(Vector2i.ONE)
	var bits := PackedByteArray()
	bits.resize(size.x * size.y)
	var points := PackedVector2Array()
	var center: Vector2 = (diamond[0] + diamond[2]) * 0.5
	var half_size: Vector2 = (diamond[2] - diamond[0] + diamond[1] - diamond[3]) * 0.5
	for y: int in size.y:
		for x: int in size.x:
			var uv := (Vector2(x, y) + Vector2(0.5, 0.5)) / Vector2(size)
			var point: Vector2 = rect.position + rect.size * uv
			var from_center: Vector2 = (point - center).abs() / half_size
			var occupied: bool = from_center.x + from_center.y <= 1.0
			if not occupied:
				for part: Dictionary in prepared:
					if opaque_at(part, point):
						occupied = true
						break
			if not occupied: continue
			bits[y * size.x + x] = 1
			points.append(uv)
	var texture: Texture2D = ImageTexture.create_from_image(Image.create_from_data(size.x, size.y, false, Image.FORMAT_L8, _white_bits(bits)))
	var mask: Dictionary = {"size": size, "bits": bits, "points": points, "key": texture.get_instance_id(), "texture": texture}
	_floor_masks[key] = {"signature": signature, "mask": mask}
	return mask

static func _white_bits(bits: PackedByteArray) -> PackedByteArray:
	var pixels := bits.duplicate()
	for index: int in pixels.size(): pixels[index] *= 255
	return pixels

func mask_for(source: Dictionary) -> Dictionary:
	var texture: Texture2D = source.get("mask_texture")
	if texture == null: return {}
	var region: Rect2i = source.get("mask_region", Rect2i())
	var pose: String = str(source.get("mask_pose", "rest"))
	var key: String = "%d:%s:%s" % [texture.get_instance_id(), str(region), pose]
	if masks.has(key): return masks[key]
	var image: Image = preload("res://scripts/asset_loader.gd").texture_source_image(texture)
	var mask: Dictionary = mask_from_image(image, key, region)
	if not mask.is_empty(): mask["texture"] = texture
	return mask

func mask_from_image(image: Image, key: String, region: Rect2i = Rect2i()) -> Dictionary:
	if masks.has(key): return masks[key]
	if image == null or image.is_empty(): return {}
	image = image.duplicate() as Image
	if image.is_compressed() and image.decompress() != OK: return {}
	if region.has_area(): image = image.get_region(region)
	var dimensions := Vector2i(maxi(1, ceili(image.get_width() * MASK_SCALE)), maxi(1, ceili(image.get_height() * MASK_SCALE)))
	image.resize(dimensions.x, dimensions.y, RESAMPLE)
	image.convert(Image.FORMAT_RGBA8)
	var rgba: PackedByteArray = image.get_data()
	var bits := PackedByteArray()
	bits.resize(dimensions.x * dimensions.y)
	var points := PackedVector2Array()
	for y: int in range(dimensions.y):
		for x: int in range(dimensions.x):
			var index: int = y * dimensions.x + x
			if float(rgba[index * 4 + 3]) / 255.0 > OPAQUE_ALPHA:
				bits[index] = 1
				points.append(Vector2((x + 0.5) / dimensions.x, (y + 0.5) / dimensions.y))
	var mask: Dictionary = {"key": key, "size": dimensions, "bits": bits, "points": points}
	masks[key] = mask
	builds += 1
	return mask

# The reduced rest masks still drive hysteresis and rims. Colour fill uses
# the actual sprite texels and includes the exact half-opacity boundary.
func fill_geometry(source: Dictionary) -> Dictionary:
	if source.has("diamond"):
		var polygon: PackedVector2Array = source["diamond"]
		var bounds := Rect2(polygon[0], Vector2.ZERO)
		for point: Vector2 in polygon: bounds = bounds.expand(point)
		return source.merged({"rect": bounds}, true)
	if source["kind"] not in ["loot", "trap"]: return source
	var texture: Texture2D = source["mask_texture"]
	if not _fill_sprite_masks.has(texture):
		var image: Image = preload("res://scripts/asset_loader.gd").texture_source_image(texture)
		if image == null or image.is_empty(): return source
		image = image.duplicate()
		if image.is_compressed() and image.decompress() != OK: return source
		image.convert(Image.FORMAT_RGBA8)
		var rgba: PackedByteArray = image.get_data()
		var bits := PackedByteArray()
		bits.resize(image.get_width() * image.get_height())
		for index: int in bits.size(): bits[index] = int(rgba[index * 4 + 3] >= 128)
		_fill_sprite_masks[texture] = {"key": texture.get_instance_id(), "size": image.get_size(), "bits": bits}
	return source.merged({"mask": _fill_sprite_masks[texture]}, true)

static func fill_contains(source: Dictionary, point: Vector2) -> bool:
	if source.has("diamond"): return Geometry2D.is_point_in_polygon(point, source["diamond"])
	return opaque_at(source, point)

func prepare(sources: Array[Dictionary]) -> void:
	for source: Dictionary in sources:
		source["mask"] = floor_mask(source) if source.has("diamond") else mask_for(source)

static func blocks(target: Dictionary, blocker: Dictionary) -> bool:
	if str(blocker["kind"]) in ["prop", "terrain"]: return true
	return str(blocker["kind"]) == "unit" and str(target["kind"]) in ["unit", "loot", "trap"]

func coverage_for(sources: Array[Dictionary], index: int, prop_kind: String = "", unit_type: String = "") -> float:
	var target: Dictionary = sources[index]
	var blockers: Array[Dictionary]
	for later: int in range(index + 1, sources.size()):
		var blocker: Dictionary = sources[later]
		if not blocks(target, blocker): continue
		if not prop_kind.is_empty() and str(blocker.get("prop_kind", "")) != prop_kind: continue
		if not unit_type.is_empty() and (str(blocker["kind"]) != "unit" or str((blocker.get("data", {}) as Dictionary).get("type", "")) != unit_type): continue
		if (target["rect"] as Rect2).intersects(blocker["rect"]): blockers.append(blocker)
	return coverage_cached(target, blockers, str(target.get("key", index)) + ":" + prop_kind + ":" + unit_type)

func coverage_cached(target: Dictionary, blockers: Array[Dictionary], key: String) -> float:
	if blockers.is_empty(): return 0.0
	var signature: Array = [_geometry(target)]
	for blocker: Dictionary in blockers: signature.append(_geometry(blocker))
	var cached: Dictionary = _coverage_cache.get(key, {})
	if cached.get("signature", []) == signature: return float(cached["amount"])
	var amount: float = coverage(target, blockers)
	_coverage_cache[key] = {"signature": signature, "amount": amount}
	queries += 1
	return amount

static func _geometry(source: Dictionary) -> Array:
	return [source["rect"], (source.get("mask", {}) as Dictionary).get("key", ""), source.get("mask_flip", false), str(source["kind"]), (source.get("data", {}) as Dictionary).get("footprint", Vector2i.ONE)]

static func coverage(target: Dictionary, blockers: Array[Dictionary]) -> float:
	var mask: Dictionary = target.get("mask", {})
	if mask.is_empty() or (mask["points"] as PackedVector2Array).is_empty(): return 0.0
	var rect: Rect2 = target["rect"]
	if rect.get_area() <= 0.0: return 0.0
	var covered: int = 0
	for point: Vector2 in mask["points"]:
		if bool(target.get("mask_flip", false)): point.x = 1.0 - point.x
		var world: Vector2 = rect.position + point * rect.size
		for blocker: Dictionary in blockers:
			if opaque_at(blocker, world):
				covered += 1
				break # Union: each opaque target sample counts once.
	return float(covered) / float((mask["points"] as PackedVector2Array).size())

static func opaque_at(source: Dictionary, point: Vector2) -> bool:
	var rect: Rect2 = source["rect"]
	var mask: Dictionary = source.get("mask", {})
	if mask.is_empty() or not rect.has_point(point): return false
	var uv: Vector2 = (point - rect.position) / rect.size
	if bool(source.get("mask_flip", false)): uv.x = 1.0 - uv.x
	var dimensions: Vector2i = mask["size"]
	var x: int = clampi(int(uv.x * dimensions.x), 0, dimensions.x - 1)
	var y: int = clampi(int(uv.y * dimensions.y), 0, dimensions.y - 1)
	return (mask["bits"] as PackedByteArray)[y * dimensions.x + x] != 0

# The edge is baked in the source sprite's texel grid. Transparent padding
# gives pixels at a trimmed texture boundary the same eight neighbours.
const EDGE_INK_RGB8 := Vector3i(15, 11, 10) # #0F0B0A
const EDGE_TEXELS := Vector2i.ONE

static func occluder_edge_image(image: Image) -> Image:
	var size: Vector2i = image.get_size()
	var padded: Vector2i = size + EDGE_TEXELS * 2
	var source: PackedByteArray = image.get_data()
	var result := PackedByteArray()
	result.resize(padded.x * padded.y * 4)
	# Stamp the 8-neighbour dilation using alpha 1 as a temporary marker
	# for the solid body. A later stamp cannot overwrite a body marker.
	for y: int in size.y:
		for x: int in size.x:
			if source[(y * size.x + x) * 4 + 3] < 128: continue
			var center: int = ((y + 1) * padded.x + x + 1) * 4 + 3
			result[center] = 1
			for dy: int in range(-1, 2):
				for dx: int in range(-1, 2):
					var neighbor: int = center + (dy * padded.x + dx) * 4
					if result[neighbor] == 0: result[neighbor] = 255
	for alpha: int in range(3, result.size(), 4):
		if result[alpha] == 1:
			result[alpha] = 0
		elif result[alpha] == 255:
			result[alpha - 3] = EDGE_INK_RGB8.x
			result[alpha - 2] = EDGE_INK_RGB8.y
			result[alpha - 1] = EDGE_INK_RGB8.z
	return Image.create_from_data(padded.x, padded.y, false, Image.FORMAT_RGBA8, result)

static func occluder_edge_rect(rect: Rect2, padded_size: Vector2i) -> Rect2:
	var padding: Vector2 = rect.size / Vector2(padded_size - EDGE_TEXELS * 2)
	return Rect2(rect.position - padding, rect.size + 2.0 * padding)
