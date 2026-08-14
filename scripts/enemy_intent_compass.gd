extends RefCounted
class_name EnemyIntentCompass

const INVALID_TILE := Vector2i(-999, -999)

const FAMILY_MELEE := "melee"
const FAMILY_RANGED := "ranged"
const FAMILY_DEFENSE := "defense"
const FAMILY_SUPPORT := "support"

const TEXTURE_PATHS := {
	"base": "res://assets/art/ui/enemy_intent_compass/base.png",
	FAMILY_MELEE: "res://assets/art/ui/enemy_intent_compass/melee.png",
	FAMILY_RANGED: "res://assets/art/ui/enemy_intent_compass/ranged.png",
	FAMILY_DEFENSE: "res://assets/art/ui/enemy_intent_compass/defense.png",
	FAMILY_SUPPORT: "res://assets/art/ui/enemy_intent_compass/support.png",
}

const MELEE_TYPES := ["melee", "pull"]
const RANGED_TYPES := ["ranged"]
const AREA_TYPES := [
	"aoe", "cinder_marks", "detonate_cinders", "gale_force",
	"lightning_strikes", "terrain_burst", "umbra_eclipse",
]
const DEFENSE_TYPES := ["block", "frost_armor", "guard_ally", "stoneskin"]
const SUPPORT_TYPES := ["heal_ally", "heal_self", "raise_terrain", "summon_minions"]
const MOVEMENT_TYPES := ["move_away", "move_toward"]
const INTENSITY_TYPES := ["intensity"]

static func descriptors_for_state(state: Dictionary, plans_by_enemy_id: Dictionary, visible_enemy_ids: Array = []) -> Dictionary:
	var result: Dictionary = {}
	var filter_visibility: bool = not visible_enemy_ids.is_empty() or state.has("umbra")
	for enemy_var: Variant in state.get("enemies", []):
		if typeof(enemy_var) != TYPE_DICTIONARY:
			continue
		var enemy: Dictionary = enemy_var as Dictionary
		var enemy_id: int = int(enemy.get("id", -1))
		if enemy_id < 0 or int(enemy.get("hp", 0)) <= 0:
			continue
		if filter_visibility and not visible_enemy_ids.has(enemy_id):
			continue
		var intent: Dictionary = enemy.get("intent", {}) as Dictionary
		if intent.is_empty():
			continue
		var plan: Dictionary = plans_by_enemy_id.get(enemy_id, {}) as Dictionary
		var descriptor: Dictionary = descriptor_for_enemy(state, enemy, intent, plan)
		if not descriptor.is_empty():
			result["enemy_%d" % enemy_id] = descriptor
	return result

static func descriptor_for_enemy(state: Dictionary, enemy: Dictionary, intent: Dictionary, plan: Dictionary) -> Dictionary:
	var primary_action: Dictionary = _primary_action(intent)
	if primary_action.is_empty():
		return {}
	var family: String = family_for_action(primary_action)
	var action_type: String = str(primary_action.get("type", ""))
	var origin: Vector2i = enemy.get("pos", Vector2i.ZERO)
	var destination: Vector2i = plan.get("destination", origin)
	var target_tile: Vector2i = INVALID_TILE
	var direction_reason: String = "fallback"
	if destination != origin:
		target_tile = destination
		direction_reason = "movement"
	else:
		if action_type in INTENSITY_TYPES:
			target_tile = origin + Vector2i(1, 1)
			direction_reason = "self"
		elif family == FAMILY_SUPPORT or action_type == "guard_ally":
			target_tile = plan.get("support_target_tile", INVALID_TILE)
			if target_tile == INVALID_TILE:
				target_tile = _support_target_tile(state, enemy, primary_action)
			if target_tile != INVALID_TILE:
				direction_reason = "support"
		elif family == FAMILY_DEFENSE:
			target_tile = (state.get("player", {}) as Dictionary).get("pos", INVALID_TILE)
			if target_tile != INVALID_TILE:
				direction_reason = "threat"
		elif action_type in AREA_TYPES and not (plan.get("projected_attack", []) as Array).is_empty():
			target_tile = _projected_target_tile(plan.get("projected_attack", []) as Array, origin)
			direction_reason = "pattern"
		else:
			var planned_target: Variant = plan.get("target_tile", INVALID_TILE)
			if typeof(planned_target) == TYPE_VECTOR2I and planned_target != INVALID_TILE:
				target_tile = planned_target
				direction_reason = "target"
	if target_tile == INVALID_TILE or target_tile == origin:
		target_tile = origin + Vector2i(1, 1)
		direction_reason = "fallback"
	return {
		"family": family,
		"action_type": action_type,
		"value": value_for_action(primary_action),
		"origin_tile": origin,
		"target_tile": target_tile,
		"direction_reason": direction_reason,
		"intent_name": str(intent.get("name", "")),
		"footprint": _footprint(enemy),
	}

static func family_for_action(action: Dictionary) -> String:
	var action_type: String = str(action.get("type", ""))
	if action_type in MELEE_TYPES:
		return FAMILY_MELEE
	if action_type in RANGED_TYPES:
		return FAMILY_RANGED
	if action_type in AREA_TYPES:
		return FAMILY_RANGED
	if action_type in DEFENSE_TYPES:
		return FAMILY_DEFENSE
	if action_type in SUPPORT_TYPES:
		return FAMILY_SUPPORT
	if action_type in INTENSITY_TYPES:
		return FAMILY_SUPPORT
	return FAMILY_MELEE

static func is_supported_action_type(action_type: String) -> bool:
	return action_type in MELEE_TYPES \
		or action_type in RANGED_TYPES \
		or action_type in AREA_TYPES \
		or action_type in DEFENSE_TYPES \
		or action_type in SUPPORT_TYPES \
		or action_type in MOVEMENT_TYPES \
		or action_type in INTENSITY_TYPES

static func value_for_action(action: Dictionary) -> int:
	for key: String in ["damage", "amount", "count"]:
		if action.has(key):
			return maxi(0, int(action.get(key, 0)))
	return 0

static func texture_path(family: String) -> String:
	return str(TEXTURE_PATHS.get(family, TEXTURE_PATHS[FAMILY_MELEE]))

static func direction_angle(origin_world: Vector2, target_world: Vector2, isometric_y_scale: float = 0.5) -> float:
	var screen_delta: Vector2 = target_world - origin_world
	if screen_delta.length_squared() <= 0.001:
		return PI * 0.25
	var unsquashed_delta := Vector2(screen_delta.x, screen_delta.y / maxf(0.01, isometric_y_scale))
	return unsquashed_delta.angle()

static func _primary_action(intent: Dictionary) -> Dictionary:
	var actions: Array = intent.get("actions", []) as Array
	for families: Array in [AREA_TYPES, RANGED_TYPES, MELEE_TYPES, INTENSITY_TYPES, DEFENSE_TYPES, SUPPORT_TYPES, MOVEMENT_TYPES]:
		for action_var: Variant in actions:
			if typeof(action_var) != TYPE_DICTIONARY:
				continue
			var action: Dictionary = action_var as Dictionary
			if str(action.get("type", "")) in families:
				return action
	for action_var: Variant in actions:
		if typeof(action_var) == TYPE_DICTIONARY:
			return action_var as Dictionary
	return {}

static func _support_target_tile(state: Dictionary, source: Dictionary, action: Dictionary) -> Vector2i:
	if str(action.get("type", "")) == "heal_self":
		return source.get("pos", INVALID_TILE)
	var allow_self: bool = bool(action.get("allow_self", true))
	var max_range: int = int(action.get("range", 99)) if action.has("range") else 99
	var source_pos: Vector2i = source.get("pos", Vector2i.ZERO)
	var best_tile: Vector2i = INVALID_TILE
	var best_score: int = -999999
	for candidate_var: Variant in state.get("enemies", []):
		if typeof(candidate_var) != TYPE_DICTIONARY:
			continue
		var candidate: Dictionary = candidate_var as Dictionary
		if int(candidate.get("hp", 0)) <= 0:
			continue
		if int(candidate.get("id", -1)) == int(source.get("id", -1)) and not allow_self:
			continue
		var tile: Vector2i = candidate.get("pos", Vector2i.ZERO)
		var distance: int = absi(tile.x - source_pos.x) + absi(tile.y - source_pos.y)
		if distance > max_range:
			continue
		var score: int = -distance * 100 - int(candidate.get("id", 0))
		if str(action.get("type", "")) == "heal_ally":
			var missing_hp: int = maxi(0, int(candidate.get("max_hp", 1)) - int(candidate.get("hp", 0)))
			if missing_hp <= 0:
				continue
			score += missing_hp * 10000
		if score > best_score:
			best_score = score
			best_tile = tile
	return best_tile

static func _projected_target_tile(projected_tiles: Array, origin: Vector2i) -> Vector2i:
	var best_tile: Vector2i = INVALID_TILE
	var best_distance: int = -1
	for tile_var: Variant in projected_tiles:
		if typeof(tile_var) != TYPE_VECTOR2I:
			continue
		var tile: Vector2i = tile_var as Vector2i
		var distance: int = absi(tile.x - origin.x) + absi(tile.y - origin.y)
		var precedes_tie: bool = best_tile == INVALID_TILE or tile.y < best_tile.y or (tile.y == best_tile.y and tile.x < best_tile.x)
		if distance > best_distance or (distance == best_distance and precedes_tie):
			best_distance = distance
			best_tile = tile
	return best_tile

static func _footprint(enemy: Dictionary) -> Vector2i:
	var footprint: Variant = enemy.get("footprint", Vector2i.ONE)
	if typeof(footprint) == TYPE_VECTOR2I:
		var typed: Vector2i = footprint
		return Vector2i(maxi(1, typed.x), maxi(1, typed.y))
	if typeof(footprint) == TYPE_ARRAY and (footprint as Array).size() >= 2:
		return Vector2i(maxi(1, int((footprint as Array)[0])), maxi(1, int((footprint as Array)[1])))
	return Vector2i.ONE
