extends RefCounted

# Windows requires a typed value at assignment/return boundaries. Preserve an
# already typed array's identity: callers may mutate a cached/shared array.
# Otherwise assign into an explicitly typed temporary without filtering values.

static func dictionaries(values: Array) -> Array[Dictionary]:
	var result: Array[Dictionary]
	if values.is_same_typed(result):
		return values
	result.assign(values)
	return result

static func polygons(values: Array) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array]
	if values.is_same_typed(result):
		return values
	result.assign(values)
	return result

static func rects(values: Array) -> Array[Rect2]:
	var result: Array[Rect2]
	if values.is_same_typed(result):
		return values
	result.assign(values)
	return result

static func strings(values: Array) -> Array[String]:
	var result: Array[String]
	if values.is_same_typed(result):
		return values
	result.assign(values)
	return result

static func textures(values: Array) -> Array[Texture2D]:
	var result: Array[Texture2D]
	if values.is_same_typed(result):
		return values
	result.assign(values)
	return result

static func vector2(values: Array) -> Array[Vector2]:
	var result: Array[Vector2]
	if values.is_same_typed(result):
		return values
	result.assign(values)
	return result

static func vector2i(values: Array) -> Array[Vector2i]:
	var result: Array[Vector2i]
	if values.is_same_typed(result):
		return values
	result.assign(values)
	return result

static func booleans(values: Array) -> Array[bool]:
	var result: Array[bool]
	if values.is_same_typed(result):
		return values
	result.assign(values)
	return result

static func floats(values: Array) -> Array[float]:
	var result: Array[float]
	if values.is_same_typed(result):
		return values
	result.assign(values)
	return result

static func integers(values: Array) -> Array[int]:
	var result: Array[int]
	if values.is_same_typed(result):
		return values
	result.assign(values)
	return result
