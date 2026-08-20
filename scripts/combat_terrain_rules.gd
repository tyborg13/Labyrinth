extends RefCounted
class_name CombatTerrainRules

const PathUtils = preload("res://scripts/path_utils.gd")

const FIELD_NEUTRAL: String = "neutral"
const FIELD_CORRUPTION: String = "corruption"
const FIELD_RADIANCE: String = "radiance"

const SURFACE_NONE: String = ""
const SURFACE_BRAMBLE: String = "bramble"
const SURFACE_POISON: String = "poison"
const SURFACE_ICE: String = "ice"
const SURFACE_SNOWDRIFT: String = "snowdrift"
const SURFACE_ELECTRIFIED: String = "electrified"

const VALID_FIELDS: Array[String] = [FIELD_CORRUPTION, FIELD_RADIANCE]
const VALID_SURFACES: Array[String] = [
	SURFACE_BRAMBLE,
	SURFACE_POISON,
	SURFACE_ICE,
	SURFACE_SNOWDRIFT,
	SURFACE_ELECTRIFIED,
]

const TEAM_PLAYER: String = "player"
const TEAM_ENEMY: String = "enemy"

const DEFAULT_FIELD_DURATION: int = 18
const DEFAULT_SURFACE_DURATION: int = 18
const FIELD_TRAVERSAL_DAMAGE: int = 1
const FIELD_ACTIVATION_DAMAGE: int = 1
const CORRUPTION_ENEMY_HEAL: int = 1
const POISON_TRAVERSAL_DAMAGE: int = 1
const SNOWDRIFT_ATTACK_BONUS: int = 2
const COMBUST_ATTACK_BONUS: int = 2
const COLLISION_DAMAGE: int = 2

static func ensure_state(state: Dictionary) -> Dictionary:
	var source: Dictionary = state.get("tile_effects", {}) as Dictionary
	var normalized: Dictionary = {
		"fields": _normalized_entries(source.get("fields", []), VALID_FIELDS),
		"surfaces": _normalized_entries(source.get("surfaces", []), VALID_SURFACES),
	}
	state["tile_effects"] = normalized
	return normalized

static func field_at(state: Dictionary, tile: Vector2i) -> Dictionary:
	var effects: Dictionary = ensure_state(state)
	return _entry_at(effects.get("fields", []) as Array, tile)

static func surface_at(state: Dictionary, tile: Vector2i) -> Dictionary:
	var effects: Dictionary = ensure_state(state)
	return _entry_at(effects.get("surfaces", []) as Array, tile)

static func field_kind_at(state: Dictionary, tile: Vector2i) -> String:
	return str(field_at(state, tile).get("kind", FIELD_NEUTRAL))

static func surface_kind_at(state: Dictionary, tile: Vector2i) -> String:
	return str(surface_at(state, tile).get("kind", SURFACE_NONE))

static func place_field(state: Dictionary, tiles: Array, kind: String, expires_at: int) -> Array[Dictionary]:
	if kind not in VALID_FIELDS:
		return []
	var effects: Dictionary = ensure_state(state)
	var entries: Array[Dictionary] = _dictionary_array(effects.get("fields", []))
	var changes: Array[Dictionary] = []
	for tile: Vector2i in _vector2i_array(tiles):
		changes.append(_replace_entry(entries, tile, kind, expires_at))
	effects["fields"] = entries
	state["tile_effects"] = effects
	return changes

static func place_surface(state: Dictionary, tiles: Array, kind: String, expires_at: int) -> Array[Dictionary]:
	if kind not in VALID_SURFACES:
		return []
	var effects: Dictionary = ensure_state(state)
	var entries: Array[Dictionary] = _dictionary_array(effects.get("surfaces", []))
	var changes: Array[Dictionary] = []
	for tile: Vector2i in _vector2i_array(tiles):
		changes.append(_replace_entry(entries, tile, kind, expires_at))
	effects["surfaces"] = entries
	state["tile_effects"] = effects
	return changes

static func clear_field(state: Dictionary, tile: Vector2i) -> Dictionary:
	var effects: Dictionary = ensure_state(state)
	var entries: Array[Dictionary] = _dictionary_array(effects.get("fields", []))
	var removed: Dictionary = _remove_entry(entries, tile)
	effects["fields"] = entries
	state["tile_effects"] = effects
	return removed

static func clear_surface(state: Dictionary, tile: Vector2i) -> Dictionary:
	var effects: Dictionary = ensure_state(state)
	var entries: Array[Dictionary] = _dictionary_array(effects.get("surfaces", []))
	var removed: Dictionary = _remove_entry(entries, tile)
	effects["surfaces"] = entries
	state["tile_effects"] = effects
	return removed

static func expire_at_clock(state: Dictionary, clock: int) -> Dictionary:
	var effects: Dictionary = ensure_state(state)
	var expired_fields: Array[Dictionary] = []
	var expired_surfaces: Array[Dictionary] = []
	var active_fields: Array[Dictionary] = []
	var active_surfaces: Array[Dictionary] = []
	for entry: Dictionary in _dictionary_array(effects.get("fields", [])):
		if int(entry.get("expires_at", 0)) <= clock:
			expired_fields.append(entry.duplicate(true))
		else:
			active_fields.append(entry.duplicate(true))
	for entry: Dictionary in _dictionary_array(effects.get("surfaces", [])):
		if int(entry.get("expires_at", 0)) <= clock:
			expired_surfaces.append(entry.duplicate(true))
		else:
			active_surfaces.append(entry.duplicate(true))
	effects["fields"] = active_fields
	effects["surfaces"] = active_surfaces
	state["tile_effects"] = effects
	return {
		"fields": expired_fields,
		"surfaces": expired_surfaces,
	}

static func entry_effect(state: Dictionary, tile: Vector2i, team: String, poison_armed: bool = false) -> Dictionary:
	var damage: int = POISON_TRAVERSAL_DAMAGE if poison_armed else 0
	var field_kind: String = field_kind_at(state, tile)
	if team == TEAM_PLAYER and field_kind == FIELD_CORRUPTION:
		damage += FIELD_TRAVERSAL_DAMAGE
	elif team == TEAM_ENEMY and field_kind == FIELD_RADIANCE:
		damage += FIELD_TRAVERSAL_DAMAGE
	var surface_kind: String = surface_kind_at(state, tile)
	return {
		"tile": tile,
		"damage": damage,
		"stop_movement": surface_kind == SURFACE_BRAMBLE,
		"poison_armed": poison_armed or surface_kind == SURFACE_POISON,
		"slide": surface_kind == SURFACE_ICE,
		"attacks_suppressed": surface_kind == SURFACE_ELECTRIFIED,
		"consume_surface": surface_kind == SURFACE_ELECTRIFIED,
		"field": field_kind,
		"surface": surface_kind,
	}

static func activation_start_effect(state: Dictionary, tile: Vector2i, team: String) -> Dictionary:
	var field_kind: String = field_kind_at(state, tile)
	var surface_kind: String = surface_kind_at(state, tile)
	var damage: int = 0
	var healing: int = 0
	if team == TEAM_PLAYER and field_kind == FIELD_CORRUPTION:
		damage = FIELD_ACTIVATION_DAMAGE
	elif team == TEAM_ENEMY:
		if field_kind == FIELD_RADIANCE:
			damage = FIELD_ACTIVATION_DAMAGE
		elif field_kind == FIELD_CORRUPTION:
			healing = CORRUPTION_ENEMY_HEAL
	return {
		"tile": tile,
		"damage": damage,
		"healing": healing,
		"attacks_suppressed": surface_kind == SURFACE_ELECTRIFIED,
		"consume_surface": surface_kind == SURFACE_ELECTRIFIED,
		"field": field_kind,
		"surface": surface_kind,
	}

static func attack_bonus_at(state: Dictionary, tile: Vector2i) -> int:
	return SNOWDRIFT_ATTACK_BONUS if surface_kind_at(state, tile) == SURFACE_SNOWDRIFT else 0

static func combust_at(state: Dictionary, tile: Vector2i) -> Dictionary:
	var surface: Dictionary = surface_at(state, tile)
	if surface.is_empty():
		return {"bonus_damage": 0, "consume_surface": false, "surface": SURFACE_NONE}
	return {
		"bonus_damage": COMBUST_ATTACK_BONUS,
		"consume_surface": true,
		"surface": str(surface.get("kind", SURFACE_NONE)),
	}

static func route_with_ice(state: Dictionary, grid: Array, authored_path: Array, blocking_tiles: Dictionary = {}) -> Dictionary:
	var path: Array[Vector2i] = _vector2i_array(authored_path)
	if path.size() <= 1:
		return {"path": path, "collision_tile": Vector2i(-1, -1), "slid": false}
	var resolved: Array[Vector2i] = _vector2i_array([path[0]])
	for index: int in range(1, path.size()):
		var previous: Vector2i = resolved[resolved.size() - 1]
		var tile: Vector2i = path[index]
		resolved.append(tile)
		if surface_kind_at(state, tile) != SURFACE_ICE:
			continue
		var direction: Vector2i = tile - previous
		if absi(direction.x) + absi(direction.y) != 1:
			return {"path": resolved, "collision_tile": Vector2i(-1, -1), "slid": false}
		var cursor: Vector2i = tile
		while surface_kind_at(state, cursor) == SURFACE_ICE:
			var candidate: Vector2i = cursor + direction
			if not PathUtils.is_passable(grid, candidate) or blocking_tiles.has(candidate):
				return {"path": resolved, "collision_tile": candidate, "slid": true}
			resolved.append(candidate)
			cursor = candidate
		return {"path": resolved, "collision_tile": Vector2i(-1, -1), "slid": true}
	return {"path": resolved, "collision_tile": Vector2i(-1, -1), "slid": false}

static func _normalized_entries(value: Variant, valid_kinds: Array[String]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry_var: Variant in value as Array:
		if typeof(entry_var) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_var as Dictionary
		var tile: Vector2i = entry.get("pos", Vector2i(-1, -1))
		var kind: String = str(entry.get("kind", ""))
		if tile.x < 0 or tile.y < 0 or kind not in valid_kinds:
			continue
		_replace_entry(result, tile, kind, int(entry.get("expires_at", 0)))
	return result

static func _replace_entry(entries: Array[Dictionary], tile: Vector2i, kind: String, expires_at: int) -> Dictionary:
	var previous: Dictionary = _remove_entry(entries, tile)
	var entry: Dictionary = {
		"pos": tile,
		"kind": kind,
		"expires_at": maxi(0, expires_at),
	}
	entries.append(entry)
	entries.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		var first_tile: Vector2i = first.get("pos", Vector2i.ZERO)
		var second_tile: Vector2i = second.get("pos", Vector2i.ZERO)
		return first_tile.y < second_tile.y or (first_tile.y == second_tile.y and first_tile.x < second_tile.x)
	)
	return {
		"pos": tile,
		"before": previous,
		"after": entry.duplicate(true),
	}

static func _remove_entry(entries: Array[Dictionary], tile: Vector2i) -> Dictionary:
	for index: int in range(entries.size() - 1, -1, -1):
		var entry: Dictionary = entries[index]
		if entry.get("pos", Vector2i(-1, -1)) == tile:
			entries.remove_at(index)
			return entry.duplicate(true)
	return {}

static func _entry_at(value: Array, tile: Vector2i) -> Dictionary:
	for entry: Dictionary in _dictionary_array(value):
		if entry.get("pos", Vector2i(-1, -1)) == tile:
			return entry.duplicate(true)
	return {}

static func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry_var: Variant in value as Array:
		if typeof(entry_var) == TYPE_DICTIONARY:
			result.append((entry_var as Dictionary).duplicate(true))
	return result

static func _vector2i_array(value: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for tile_var: Variant in value:
		if typeof(tile_var) == TYPE_VECTOR2I:
			result.append(tile_var as Vector2i)
	return result
