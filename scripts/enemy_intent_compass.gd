extends RefCounted
class_name EnemyIntentCompass

const FAMILY_ATTACK := "attack"
const FAMILY_DEFENSE := "defense"
const FAMILY_SUPPORT := "support"

const TEXTURE_PATHS := {
	"base": "res://assets/art/ui/enemy_intent_compass/base.png",
	FAMILY_ATTACK: "res://assets/art/ui/enemy_intent_compass/melee.png",
	FAMILY_DEFENSE: "res://assets/art/ui/enemy_intent_compass/defense.png",
	FAMILY_SUPPORT: "res://assets/art/ui/enemy_intent_compass/support.png",
}

const MELEE_TYPES := ["melee", "pull"]
const RANGED_TYPES := ["ranged"]
const AREA_TYPES := [
	"icefall_mark", "icefall_land", "call_wind", "lob_mark", "lob_land",
	"tether_beam", "burrow", "erupt", "aoe", "detonate", "cinder_marks", "detonate_cinders", "gale_force",
	"lightning_strikes", "terrain_burst", "umbra_eclipse",
]
const DEFENSE_TYPES := ["block", "frost_armor", "guard_ally", "stoneskin"]
const SUPPORT_TYPES := ["grow_bramble", "veil_blink", "kindle", "heal_ally", "heal_self", "raise_terrain", "summon_minions", "surface", "consume_surface", "surface_relocate"]
const MOVEMENT_TYPES := ["move_away", "move_toward"]

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
		intent = preload("res://scripts/enemy_mechanics/bramble.gd").presentation_intent(state, enemy, intent)
		var descriptor: Dictionary = descriptor_for_enemy(intent)
		if str(descriptor.get("action_type", "")) == "lob_mark": descriptor["value"] = preload("res://scripts/enemy_mechanics/lob.gd").landing_action(preload("res://scripts/combat_engine.gd").new(), state, enemy)["center_damage"]
		if str(descriptor.get("action_type", "")) == "tether_beam":
			var engine = preload("res://scripts/combat_engine.gd").new()
			var index: int = engine._enemy_index_for_id(state, enemy_id)
			var plan: Dictionary = engine.enemy_intent_plan(state, index, intent, bool(enemy.get("immobilize", false)), int(enemy.get("freeze", 0)) > 0 or int(enemy.get("shock", 0)) > 0)
			if not bool(plan.get("attack_available", false)): descriptor["value"] = 0
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
	if action_type in MELEE_TYPES or action_type in RANGED_TYPES or action_type in AREA_TYPES:
		return FAMILY_ATTACK
	if action_type in DEFENSE_TYPES:
		return FAMILY_DEFENSE
	if action_type in SUPPORT_TYPES:
		return FAMILY_SUPPORT
	return FAMILY_ATTACK

static func is_supported_action_type(action_type: String) -> bool:
	return action_type in MELEE_TYPES \
		or action_type in RANGED_TYPES \
		or action_type in AREA_TYPES \
		or action_type in DEFENSE_TYPES \
		or action_type in SUPPORT_TYPES \
		or action_type in MOVEMENT_TYPES

static func value_for_action(action: Dictionary) -> int:
	if str(action.get("type", "")) == "lob_mark": return int(action.get("center_damage", 5))
	if str(action.get("type", "")) == "lob_land": return int(action["center_damage"])
	if str(action.get("type", "")) == "grow_bramble": return int(action["rounds"])
	if str(action.get("type", "")) == "icefall_mark": return 5
	if str(action.get("type", "")) == "call_wind": return int(action.get("push", 1))
	for key: String in ["damage", "amount", "count"]:
		if action.has(key):
			return maxi(0, int(action.get(key, 0)))
	return 0

static func texture_path(family: String) -> String:
	return str(TEXTURE_PATHS.get(family, TEXTURE_PATHS[FAMILY_ATTACK]))

static func _primary_action(intent: Dictionary) -> Dictionary:
	var actions: Array = intent.get("actions", []) as Array
	for families: Array in [AREA_TYPES, RANGED_TYPES, MELEE_TYPES, DEFENSE_TYPES, SUPPORT_TYPES, MOVEMENT_TYPES]:
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
