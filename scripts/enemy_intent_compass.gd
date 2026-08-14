extends RefCounted
class_name EnemyIntentCompass

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

static func descriptors_for_state(state: Dictionary, visible_enemy_ids: Array = []) -> Dictionary:
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
		var descriptor: Dictionary = descriptor_for_enemy(intent)
		if not descriptor.is_empty():
			result["enemy_%d" % enemy_id] = descriptor
	return result

static func descriptor_for_enemy(intent: Dictionary) -> Dictionary:
	var primary_action: Dictionary = _primary_action(intent)
	if primary_action.is_empty():
		return {}
	var family: String = family_for_action(primary_action)
	var action_type: String = str(primary_action.get("type", ""))
	return {
		"family": family,
		"action_type": action_type,
		"value": value_for_action(primary_action),
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
