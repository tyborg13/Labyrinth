extends RefCounted
class_name BoardSurfaceRules

const PathUtils = preload("res://scripts/path_utils.gd")
const ELEMENTAL_KINDS: Array = ["fire", "ice", "electrified"]
const RULES_VERSION: int = 4
const EVENT_LIMIT: int = 256

static func kind(value: String) -> String:
	match value:
		"lightning", "charge": return "electrified"
		"earth": return "rubble"
	return value

static func tile_key(tile: Vector2i) -> String:
	return "%d,%d" % [tile.x, tile.y]

static func tile_from_key(key: String) -> Vector2i:
	var parts: PackedStringArray = key.split(",")
	return Vector2i(int(parts[0]), int(parts[1])) if parts.size() == 2 else Vector2i(-1, -1)

static func surface_at(state: Dictionary, tile: Vector2i) -> Dictionary:
	return (state.get("surfaces", {}) as Dictionary).get(tile_key(tile), {}) as Dictionary

static func element_at(state: Dictionary, tile: Vector2i) -> String:
	return kind(str(surface_at(state, tile).get("elemental", "")))

static func has_rubble(state: Dictionary, tile: Vector2i) -> bool:
	return bool(surface_at(state, tile).get("rubble", false))

static func has_surface(state: Dictionary, tile: Vector2i, surface: String) -> bool:
	return has_rubble(state, tile) if kind(surface) == "rubble" else element_at(state, tile) == kind(surface)

static func is_conductive(state: Dictionary, tile: Vector2i) -> bool:
	var element: String = element_at(state, tile)
	return element == "electrified" or (element == "fire" and bool((state.get("surface_rule_overrides", {}) as Dictionary).get("conductive_fire", false)))

static func tiles(state: Dictionary, surface: String = "") -> Array[Vector2i]:
	var result: Array[Vector2i]
	for key: String in (state.get("surfaces", {}) as Dictionary):
		var tile: Vector2i = tile_from_key(key)
		if surface.is_empty() or has_surface(state, tile, surface):
			result.append(tile)
	result.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y if a.y != b.y else a.x < b.x)
	return result

static func can_place(state: Dictionary, tile: Vector2i) -> bool:
	if not PathUtils.is_passable(state.get("grid", []), tile):
		return false
	for terrain: Dictionary in state.get("terrain", []):
		if int(terrain.get("hp", 0)) > 0 and terrain.get("pos", Vector2i(-1, -1)) == tile:
			return false
	return true

static func record_event(state: Dictionary, event: Dictionary) -> void:
	var events: Array = state.get("surface_events", []) as Array
	var entry: Dictionary = event.duplicate(true)
	entry["sequence"] = int(state.get("surface_event_sequence", 0)) + 1
	state["surface_event_sequence"] = entry["sequence"]
	events.append(entry)
	if events.size() > EVENT_LIMIT:
		events.pop_front()
	state["surface_events"] = events

static func place(state: Dictionary, tile: Vector2i, surface: String, source: Dictionary = {}) -> Dictionary:
	var normalized: String = kind(surface)
	if (not ELEMENTAL_KINDS.has(normalized) and normalized != "rubble") or not can_place(state, tile):
		return state
	if has_surface(state, tile, normalized):
		return state
	var surfaces: Dictionary = state.get("surfaces", {}) as Dictionary
	var entry: Dictionary = surface_at(state, tile).duplicate(true)
	var previous: String = ("rubble" if bool(entry.get("rubble", false)) else "") if normalized == "rubble" else str(entry.get("elemental", ""))
	if normalized == "rubble":
		entry["rubble"] = true
		entry["rubble_source"] = source.duplicate(true)
	else:
		entry["elemental"] = normalized
		entry["elemental_source"] = source.duplicate(true)
	surfaces[tile_key(tile)] = entry
	state["surfaces"] = surfaces
	state["surface_revision"] = int(state.get("surface_revision", 0)) + 1
	record_event(state, {"kind": "surface_created" if previous.is_empty() else "surface_replaced", "tile": tile, "surface": normalized, "previous_surface": previous, "source": source})
	sync_chilled(state)
	return state

static func remove(state: Dictionary, tile: Vector2i, surface_or_layer: String = "all", reason: String = "") -> Dictionary:
	var surfaces: Dictionary = state.get("surfaces", {}) as Dictionary
	var entry: Dictionary = surface_at(state, tile).duplicate(true)
	if entry.is_empty():
		return state
	# Consumers need the underlay at this event, after any earlier paid technique.
	var rubble_underlay: bool = bool(entry.get("rubble", false))
	var normalized: String = kind(surface_or_layer)
	var removed: Array[String]
	if normalized in ["all", "rubble"] and bool(entry.get("rubble", false)):
		entry.erase("rubble")
		entry.erase("rubble_source")
		removed.append("rubble")
	var elemental: String = str(entry.get("elemental", ""))
	if not elemental.is_empty() and (normalized in ["all", "elemental"] or normalized == elemental):
		entry.erase("elemental")
		entry.erase("elemental_source")
		removed.append(elemental)
	if removed.is_empty():
		return state
	if entry.is_empty():
		surfaces.erase(tile_key(tile))
	else:
		surfaces[tile_key(tile)] = entry
	state["surfaces"] = surfaces
	state["surface_revision"] = int(state.get("surface_revision", 0)) + 1
	for removed_kind: String in removed:
		record_event(state, {"kind": "surface_removed", "tile": tile, "surface": removed_kind, "reason": reason, "rubble_underlay": rubble_underlay})
	sync_chilled(state)
	return state

static func footprint_tiles(unit: Dictionary, anchor: Vector2i = Vector2i(-99999, -99999)) -> Array[Vector2i]:
	var position: Vector2i = unit.get("pos", Vector2i.ZERO) if anchor == Vector2i(-99999, -99999) else anchor
	var raw: Variant = unit.get("footprint", Vector2i.ONE)
	var size: Vector2i = Vector2i.ONE
	if raw is Vector2i:
		size = raw
	elif raw is Array and raw.size() >= 2:
		size = Vector2i(int(raw[0]), int(raw[1]))
	var result: Array[Vector2i]
	for y: int in range(maxi(1, size.y)):
		for x: int in range(maxi(1, size.x)):
			result.append(position + Vector2i(x, y))
	return result

static func unit_on(state: Dictionary, unit: Dictionary, surface: String) -> bool:
	for tile: Vector2i in footprint_tiles(unit):
		if has_surface(state, tile, surface):
			return true
	return false

static func sync_chilled(state: Dictionary) -> void:
	var player: Dictionary = state.get("player", {}) as Dictionary
	if not player.is_empty() and (int(player.get("freeze", 0)) > 0 or not unit_on(state, player, "ice")):
		player["chilled"] = false
	for collection: String in ["enemies", "illusions"]:
		for unit: Dictionary in state.get(collection, []):
			if int(unit.get("freeze", 0)) > 0 or not unit_on(state, unit, "ice"):
				unit["chilled"] = false

static func entry_cost(state: Dictionary, unit: Dictionary, from: Vector2i, to: Vector2i) -> int:
	var previous: Array[Vector2i] = footprint_tiles(unit, from)
	for tile: Vector2i in footprint_tiles(unit, to):
		if not previous.has(tile) and has_rubble(state, tile):
			return 2
	return 1

static func connected_component(state: Dictionary, start: Vector2i, allowed: Dictionary = {}) -> Array[Vector2i]:
	var result: Array[Vector2i]
	if not is_conductive(state, start) or (not allowed.is_empty() and not allowed.has(start)):
		return result
	var queue: Array[Vector2i]
	queue.append(start)
	var visited: Dictionary = {start: true}
	var index: int = 0
	while index < queue.size():
		var current: Vector2i = queue[index]
		index += 1
		result.append(current)
		for direction: Vector2i in PathUtils.DIRS_4:
			var next: Vector2i = current + direction
			if visited.has(next) or not can_place(state, next) or not is_conductive(state, next):
				continue
			if not allowed.is_empty() and not allowed.has(next):
				continue
			visited[next] = true
			queue.append(next)
	return result
