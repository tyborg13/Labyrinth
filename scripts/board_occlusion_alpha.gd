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

func mask_for(source: Dictionary) -> Dictionary:
	var texture: Texture2D = source.get("mask_texture")
	if texture == null: return {}
	var region: Rect2i = source.get("mask_region", Rect2i())
	var pose: String = str(source.get("mask_pose", "rest"))
	var key: String = "%d:%s:%s" % [texture.get_instance_id(), str(region), pose]
	if masks.has(key): return masks[key]
	var image: Image = texture.get_image()
	if image == null or image.is_empty(): return {}
	image = image.duplicate() as Image
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
	var mask: Dictionary = {"texture": texture, "key": key, "size": dimensions, "bits": bits, "points": points}
	masks[key] = mask
	builds += 1
	return mask

func prepare(sources: Array[Dictionary]) -> void:
	for source: Dictionary in sources:
		source["mask"] = mask_for(source)

static func blocks(target: Dictionary, blocker: Dictionary) -> bool:
	return str(blocker["kind"]) == "unit" or (str(target["kind"]) == "unit" and str(blocker["kind"]) in ["prop", "terrain"])

func coverage_for(sources: Array[Dictionary], index: int, prop_kind: String = "", unit_type: String = "") -> float:
	var target: Dictionary = sources[index]
	var blockers: Array[Dictionary]
	for later: int in range(index + 1, sources.size()):
		var blocker: Dictionary = sources[later]
		if not blocks(target, blocker): continue
		if not prop_kind.is_empty() and str(blocker.get("prop_kind", "")) != prop_kind: continue
		if not unit_type.is_empty() and (str(blocker["kind"]) != "unit" or str((blocker.get("data", {}) as Dictionary).get("type", "")) != unit_type): continue
		if (target["rect"] as Rect2).intersects(blocker["rect"]): blockers.append(blocker)
	var signature: Array = [_geometry(target)]
	for blocker: Dictionary in blockers: signature.append(_geometry(blocker))
	var key: String = str(target.get("key", index)) + ":" + prop_kind + ":" + unit_type
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
