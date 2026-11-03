extends RefCounted
## Route geometry is shared by direct hops and conductive relay searches.
static func size(unit: Dictionary) -> Vector2i:
	var raw: Variant = unit.get("footprint", Vector2i.ONE)
	var result: Vector2i = Vector2i.ONE
	if raw is Vector2i:
		result = raw
	elif raw is Array and raw.size() >= 2:
		result = Vector2i(int(raw[0]), int(raw[1]))
	return Vector2i(maxi(1, result.x), maxi(1, result.y))

static func nearest_pair(source: Dictionary, target: Dictionary) -> Dictionary:
	# Rectangles' nearest tiles are axis clamps. Clamping the target's minimum
	# first also preserves row-major ties where their x/y projections overlap.
	# No tile arrays are allocated in this hot path.
	var source_min: Vector2i = source.get("pos", Vector2i.ZERO)
	var source_max: Vector2i = source_min + size(source) - Vector2i.ONE
	var target_min: Vector2i = target.get("pos", Vector2i.ZERO)
	var target_max: Vector2i = target_min + size(target) - Vector2i.ONE
	var from := Vector2i(clampi(target_min.x, source_min.x, source_max.x), clampi(target_min.y, source_min.y, source_max.y))
	var to := Vector2i(clampi(from.x, target_min.x, target_max.x), clampi(from.y, target_min.y, target_max.y))
	return {"from": from, "to": to, "distance": absi(from.x - to.x) + absi(from.y - to.y)}
