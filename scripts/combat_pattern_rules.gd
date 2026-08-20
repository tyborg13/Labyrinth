extends RefCounted
class_name CombatPatternRules

const NORTH: Vector2i = Vector2i(0, -1)
const EAST: Vector2i = Vector2i(1, 0)
const SOUTH: Vector2i = Vector2i(0, 1)
const WEST: Vector2i = Vector2i(-1, 0)
const CARDINAL_DIRECTIONS: Array[Vector2i] = [NORTH, EAST, SOUTH, WEST]

const SEGMENT_MOVE: String = "move"
const SEGMENT_ATTACK: String = "attack"
const SEGMENT_FORCE: String = "force"
const SEGMENT_FIELD: String = "field"
const SEGMENT_SURFACE: String = "surface"
const SEGMENT_SUPPORT: String = "support"

static func direction_for_anchor(origin: Vector2i, anchor: Vector2i) -> Vector2i:
	var delta: Vector2i = anchor - origin
	if delta == Vector2i.ZERO:
		return NORTH
	if absi(delta.x) > absi(delta.y):
		return EAST if delta.x > 0 else WEST
	return SOUTH if delta.y > 0 else NORTH

static func rotate_offset(offset: Vector2i, direction: Vector2i) -> Vector2i:
	match normalized_direction(direction):
		EAST:
			return Vector2i(-offset.y, offset.x)
		SOUTH:
			return Vector2i(-offset.x, -offset.y)
		WEST:
			return Vector2i(offset.y, -offset.x)
	return offset

static func normalized_direction(direction: Vector2i) -> Vector2i:
	if direction in CARDINAL_DIRECTIONS:
		return direction
	return direction_for_anchor(Vector2i.ZERO, direction)

static func build_plan(origin: Vector2i, direction: Vector2i, segment_defs: Array, target_key: String = "") -> Dictionary:
	var facing: Vector2i = normalized_direction(direction)
	var segments: Array[Dictionary] = []
	for segment_var: Variant in segment_defs:
		if typeof(segment_var) != TYPE_DICTIONARY:
			continue
		var definition: Dictionary = (segment_var as Dictionary).duplicate(true)
		var offsets: Array[Vector2i] = _offset_array(definition.get("offsets", definition.get("pattern", [])))
		var tiles: Array[Vector2i] = []
		for offset: Vector2i in offsets:
			tiles.append(origin + rotate_offset(offset, facing))
		var vectors: Array[Vector2i] = []
		for vector: Vector2i in _offset_array(definition.get("vectors", [])):
			vectors.append(rotate_offset(vector, facing))
		definition["tiles"] = tiles
		definition["vectors"] = vectors
		definition.erase("offsets")
		definition.erase("pattern")
		segments.append(definition)
	return {
		"origin": origin,
		"direction": facing,
		"target_key": target_key,
		"segments": segments,
		"interrupted": false,
		"contact_tile": Vector2i(-1, -1),
	}

static func translate_plan(plan: Dictionary, new_origin: Vector2i) -> Dictionary:
	var translated: Dictionary = plan.duplicate(true)
	var old_origin: Vector2i = translated.get("origin", new_origin)
	var delta: Vector2i = new_origin - old_origin
	translated["origin"] = new_origin
	var translated_segments: Array[Dictionary] = []
	for segment: Dictionary in _dictionary_array(translated.get("segments", [])):
		segment["tiles"] = _translated_tiles(segment.get("tiles", []), delta)
		segment["cancelled_tiles"] = _translated_tiles(segment.get("cancelled_tiles", []), delta)
		translated_segments.append(segment)
	translated["segments"] = translated_segments
	var contact_tile: Vector2i = translated.get("contact_tile", Vector2i(-1, -1))
	if contact_tile.x >= 0:
		translated["contact_tile"] = contact_tile + delta
	return translated

static func truncate_at_first_contact(plan: Dictionary, contact_tiles: Array) -> Dictionary:
	var contact_lookup: Dictionary = {}
	for tile: Vector2i in _vector2i_array(contact_tiles):
		contact_lookup[tile] = true
	var result: Dictionary = plan.duplicate(true)
	var output_segments: Array[Dictionary] = []
	var interrupted: bool = false
	var contact_tile: Vector2i = Vector2i(-1, -1)
	for segment: Dictionary in _dictionary_array(result.get("segments", [])):
		var tiles: Array[Vector2i] = _vector2i_array(segment.get("tiles", []))
		var cancelled_tiles: Array[Vector2i] = []
		if interrupted:
			cancelled_tiles = tiles.duplicate()
			tiles.clear()
			segment["cancelled"] = true
		elif bool(segment.get("short_circuit", false)):
			var contact_index: int = -1
			for index: int in range(tiles.size()):
				if contact_lookup.has(tiles[index]):
					contact_index = index
					break
			if contact_index >= 0:
				contact_tile = tiles[contact_index]
				var include_contact: bool = bool(segment.get("include_contact", true))
				var kept_count: int = contact_index + (1 if include_contact else 0)
				cancelled_tiles = _slice_tiles(tiles, kept_count, tiles.size())
				tiles = _slice_tiles(tiles, 0, kept_count)
				interrupted = true
		segment["tiles"] = tiles
		segment["cancelled_tiles"] = cancelled_tiles
		output_segments.append(segment)
	result["segments"] = output_segments
	result["interrupted"] = interrupted
	result["contact_tile"] = contact_tile
	return result

static func overlay(plan: Dictionary) -> Dictionary:
	var result: Dictionary = {
		SEGMENT_MOVE: _empty_tiles(),
		SEGMENT_ATTACK: _empty_tiles(),
		SEGMENT_FORCE: _empty_tiles(),
		SEGMENT_FIELD: _empty_tiles(),
		SEGMENT_SURFACE: _empty_tiles(),
		SEGMENT_SUPPORT: _empty_tiles(),
		"cancelled": _empty_tiles(),
	}
	for segment: Dictionary in _dictionary_array(plan.get("segments", [])):
		var kind: String = str(segment.get("kind", ""))
		if result.has(kind):
			_append_unique_tiles(result[kind] as Array[Vector2i], segment.get("tiles", []))
		_append_unique_tiles(result["cancelled"] as Array[Vector2i], segment.get("cancelled_tiles", []))
	return result

static func _append_unique_tiles(target: Array[Vector2i], source_value: Variant) -> void:
	for tile: Vector2i in _vector2i_array(source_value):
		if not target.has(tile):
			target.append(tile)

static func _translated_tiles(value: Variant, delta: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for tile: Vector2i in _vector2i_array(value):
		result.append(tile + delta)
	return result

static func _slice_tiles(value: Array[Vector2i], begin: int, end: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for index: int in range(clampi(begin, 0, value.size()), clampi(end, 0, value.size())):
		result.append(value[index])
	return result

static func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry_var: Variant in value as Array:
		if typeof(entry_var) == TYPE_DICTIONARY:
			result.append((entry_var as Dictionary).duplicate(true))
	return result

static func _offset_array(value: Variant) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for offset_var: Variant in value as Array:
		if typeof(offset_var) == TYPE_VECTOR2I:
			result.append(offset_var as Vector2i)
		elif typeof(offset_var) == TYPE_ARRAY:
			var pair: Array = offset_var as Array
			if pair.size() >= 2:
				result.append(Vector2i(int(pair[0]), int(pair[1])))
	return result

static func _vector2i_array(value: Variant) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for tile_var: Variant in value as Array:
		if typeof(tile_var) == TYPE_VECTOR2I:
			result.append(tile_var as Vector2i)
	return result

static func _empty_tiles() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	return result
