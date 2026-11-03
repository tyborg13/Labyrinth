extends RefCounted

# Diff complete per-tile ordered entries, including removals. An unrelated HP or
# lifetime change must not rebuild every retained prop on the board.
static func entries(previous: Array, next: Array, position_key: String) -> Dictionary:
	var old: Dictionary = _by_tile(previous, position_key)
	var current: Dictionary = _by_tile(next, position_key)
	var dirty: Dictionary = {}
	for tile: Vector2i in old:
		if old[tile] != current.get(tile, []): dirty[tile] = true
	for tile: Vector2i in current:
		if current[tile] != old.get(tile, []): dirty[tile] = true
	return dirty

static func _by_tile(source: Array, position_key: String) -> Dictionary:
	var result: Dictionary = {}
	for entry: Variant in source:
		if not entry is Dictionary: continue
		var tile: Vector2i = entry.get(position_key, Vector2i(-1, -1))
		if tile.x < 0: continue
		if not result.has(tile): result[tile] = []
		result[tile].append(entry)
	return result

static func bramble(presentation: Dictionary) -> Dictionary:
	var effect: Dictionary = presentation.get("effect", {})
	var result: Dictionary = {}
	match str(effect.get("en04_mechanic", "")):
		"grow_bramble":
			for tile: Vector2i in effect.get("tiles", []): result[tile] = true
		"bramble_expiry":
			for terrain: Dictionary in effect.get("expired_bramble", []): result[terrain["pos"]] = true
	return result

static func terrain_previews(previous: Dictionary, next: Dictionary, terrain: Array) -> Dictionary:
	var result: Dictionary = {}
	for entry: Dictionary in terrain:
		var key: String = "terrain_%s" % str(entry.get("id", ""))
		if previous.get(key, {}) != next.get(key, {}): result[entry["pos"]] = true
	return result

static func surfaces(previous: Dictionary, next: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: String in previous.keys() + next.keys():
		if previous.get(key, {}) != next.get(key, {}):
			result[preload("res://scripts/board_surface_rules.gd").tile_from_key(key)] = true
	return result

static func terrain_targets(previous: Array, next: Array, terrain: Array) -> Dictionary:
	var result: Dictionary = {}
	for entry: Dictionary in terrain:
		var tile: Vector2i = entry.get("pos", Vector2i(-1, -1))
		if previous.has(tile) != next.has(tile): result[tile] = true
	return result
