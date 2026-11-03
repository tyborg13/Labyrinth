extends RefCounted

## Compile immutable float64 operands once. Groups change traversal between
## independent vertices, never the original bone accumulation order within one.
## Cache ownership is per rig mesh; one actor cannot evict another's poses.
const CACHE_CAPACITY: int = 16
const SUBPIXEL_SCALE: float = 256.0
var offsets := PackedInt32Array()
var bones := PackedInt32Array()
var weights := PackedFloat64Array()
var dx := PackedFloat64Array()
var dy := PackedFloat64Array()
var names: Array[String]
var singles: Array[Dictionary]
var blended := PackedInt32Array()
var pairs: Array[Dictionary]
var cache: Dictionary = {}
var hits: int = 0
var misses: int = 0
var cache_enabled: bool = true
var idle_cache: Dictionary = {}
# Both modes retain whole vertex buffers. Share the 16-entry LRU budget so
# switching between motion and idle cannot double the per-view payload.
# PackedFloat64Array motion keys and Vector2 idle keys are distinct types.
var cache_order: Dictionary = {}

func _remember(key: Variant) -> void:
	cache_order.erase(key)
	cache_order[key] = true
	if cache_order.size() > CACHE_CAPACITY:
		var oldest: Variant = cache_order.keys()[0]
		cache_order.erase(oldest)
		if oldest is Vector2: idle_cache.erase(oldest)
		else: cache.erase(oldest)


func idle(original: PackedVector2Array, offset: Vector2) -> PackedVector2Array:
	if cache_enabled and idle_cache.has(offset):
		hits += 1
		var found: PackedVector2Array = idle_cache[offset]
		idle_cache.erase(offset)
		idle_cache[offset] = found
		_remember(offset)
		return found
	misses += 1
	var result := PackedVector2Array()
	for point: Vector2 in original: result.append(point + offset)
	if cache_enabled:
		idle_cache[offset] = result
		_remember(offset)
	return result

func _init(data: Dictionary, joints: Dictionary) -> void:
	for name: String in data["weights"]: names.append(name)
	for _name: String in names: singles.append({"indices": PackedInt32Array(), "dx": PackedFloat64Array(), "dy": PackedFloat64Array()})
	for point: Array in data["vertices"]:
		var vertex: int = offsets.size()
		offsets.append(bones.size())
		for b: int in range(names.size()):
			var weight: float = float(data["weights"][names[b]][vertex])
			if weight == 0.0: continue
			var bind: Array = joints[names[b]]["position"]
			bones.append(b * 6)
			weights.append(weight)
			dx.append(float(point[0]) - float(bind[0]))
			dy.append(float(point[1]) - float(bind[1]))
	offsets.append(bones.size())
	var pair_groups: Dictionary = {}
	for vertex: int in range(offsets.size() - 1):
		var start: int = offsets[vertex]
		if offsets[vertex + 1] - start == 1 and weights[start] == 1.0:
			var group: Dictionary = singles[bones[start] / 6]
			group["indices"].append(vertex)
			group["dx"].append(dx[start])
			group["dy"].append(dy[start])
		elif offsets[vertex + 1] - start == 2:
			var key: Vector2i = Vector2i(bones[start], bones[start + 1])
			if not pair_groups.has(key):
				pair_groups[key] = {"bones": key, "indices": PackedInt32Array(), "dx1": PackedFloat64Array(), "dy1": PackedFloat64Array(), "w1": PackedFloat64Array(), "dx2": PackedFloat64Array(), "dy2": PackedFloat64Array(), "w2": PackedFloat64Array()}
			var group: Dictionary = pair_groups[key]
			group["indices"].append(vertex)
			for field: String in ["dx", "dy", "weights"]:
				var source: PackedFloat64Array = get(field)
				var target: String = "w" if field == "weights" else field
				group[target + "1"].append(source[start])
				group[target + "2"].append(source[start + 1])
		else: blended.append(vertex)
	for group: Dictionary in pair_groups.values(): pairs.append(group)

func submit(poses: PackedFloat64Array) -> PackedVector2Array:
	if cache_enabled and cache.has(poses):
		hits += 1
		var found: PackedVector2Array = cache[poses]
		cache.erase(poses)
		cache[poses] = found
		_remember(poses)
		return found
	misses += 1
	var result := PackedVector2Array()
	result.resize(offsets.size() - 1)
	for b: int in range(singles.size()):
		var group: Dictionary = singles[b]
		var indices: PackedInt32Array = group["indices"]
		var xs: PackedFloat64Array = group["dx"]
		var ys: PackedFloat64Array = group["dy"]
		var a: float = poses[b * 6]
		var bb: float = poses[b * 6 + 1]
		var c: float = poses[b * 6 + 2]
		var d: float = poses[b * 6 + 3]
		var tx: float = poses[b * 6 + 4]
		var ty: float = poses[b * 6 + 5]
		for i: int in range(indices.size()):
			# Unit weight and the initial +0 are exact no-ops. Inline the same
			# snap_point expression, with no float32 Vector2 intermediate.
			result[indices[i]] = Vector2(floorf((xs[i] * a + ys[i] * c + tx) * SUBPIXEL_SCALE + 0.5) / SUBPIXEL_SCALE,
				floorf((xs[i] * bb + ys[i] * d + ty) * SUBPIXEL_SCALE + 0.5) / SUBPIXEL_SCALE)
	for group: Dictionary in pairs:
		var indices: PackedInt32Array = group["indices"]
		var x1: PackedFloat64Array = group["dx1"]
		var y1: PackedFloat64Array = group["dy1"]
		var w1: PackedFloat64Array = group["w1"]
		var x2: PackedFloat64Array = group["dx2"]
		var y2: PackedFloat64Array = group["dy2"]
		var w2: PackedFloat64Array = group["w2"]
		var b1: int = group["bones"].x
		var b2: int = group["bones"].y
		var a1: float = poses[b1]
		var bb1: float = poses[b1 + 1]
		var c1: float = poses[b1 + 2]
		var d1: float = poses[b1 + 3]
		var tx1: float = poses[b1 + 4]
		var ty1: float = poses[b1 + 5]
		var a2: float = poses[b2]
		var bb2: float = poses[b2 + 1]
		var c2: float = poses[b2 + 2]
		var d2: float = poses[b2 + 3]
		var tx2: float = poses[b2 + 4]
		var ty2: float = poses[b2 + 5]
		for i: int in range(indices.size()):
			var x: float = w1[i] * (x1[i] * a1 + y1[i] * c1 + tx1) + w2[i] * (x2[i] * a2 + y2[i] * c2 + tx2)
			var y: float = w1[i] * (x1[i] * bb1 + y1[i] * d1 + ty1) + w2[i] * (x2[i] * bb2 + y2[i] * d2 + ty2)
			result[indices[i]] = Vector2(floorf(x * SUBPIXEL_SCALE + 0.5) / SUBPIXEL_SCALE, floorf(y * SUBPIXEL_SCALE + 0.5) / SUBPIXEL_SCALE)
	var local_offsets: PackedInt32Array = offsets
	var local_bones: PackedInt32Array = bones
	var local_weights: PackedFloat64Array = weights
	var local_dx: PackedFloat64Array = dx
	var local_dy: PackedFloat64Array = dy
	for vertex: int in blended:
		var x: float = 0.0
		var y: float = 0.0
		for i: int in range(local_offsets[vertex], local_offsets[vertex + 1]):
			var b: int = local_bones[i]
			x += local_weights[i] * (local_dx[i] * poses[b] + local_dy[i] * poses[b + 2] + poses[b + 4])
			y += local_weights[i] * (local_dx[i] * poses[b + 1] + local_dy[i] * poses[b + 3] + poses[b + 5])
		result[vertex] = Vector2(floorf(x * SUBPIXEL_SCALE + 0.5) / SUBPIXEL_SCALE, floorf(y * SUBPIXEL_SCALE + 0.5) / SUBPIXEL_SCALE)
	if cache_enabled:
		cache[poses] = result
		_remember(poses)
	return result
