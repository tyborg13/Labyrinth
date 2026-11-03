extends RefCounted

## Exact dependency snapshots. These are source dictionaries, booleans and
## integer rule results, never hashes standing in for equality. Player inputs
## are selected per definition; an unrelated status is not a text dependency.
const Keywords = preload("res://scripts/card_keyword_rules.gd")
const SPATIAL_FIELDS: Array = ["surfaces", "grid", "umbra", "illusions", "surface_rule_overrides"]
const ATTACK_TYPES: Array = ["melee", "ranged", "aoe", "push", "pull", "detonate", "convert_surface", "discharge", "all_enemies", "meteor_marks", "destroy_illusion", "burst_terrain"]
static var _engine := preload("res://scripts/combat_engine.gd").new()

static func context_values(state: Dictionary) -> Dictionary:
	var source: Dictionary = state.duplicate(false)
	var player: Dictionary = state.get("player", {})
	var half_health: bool = int(player.get("hp", 0)) * 2 <= int(player.get("max_hp", 1))
	var unprotected: bool = int(player.get("block", 0)) <= 0 and int(player.get("stoneskin", 0)) <= 0
	source.erase("player")
	source.erase("room_element")
	for field: String in SPATIAL_FIELDS: source.erase(field)
	# state belongs to an immutable context. The retained definition snapshot
	# takes its own deep copy in values(), including nested source dictionaries.
	return {"source": source, "state": state, "half_health": half_health,
		"unprotected": unprotected, "bloodied_glass": half_health and unprotected,
		"room_element": str(state.get("room_element", "none"))}

static func for_definition(card: Dictionary, effects: Array) -> Array:
	var dependencies: Array = [{"input": "source"}]
	var actions: Array = (card.get("actions", []) as Array).duplicate(false)
	# Include possible keyword action edits; activation itself is in source.
	actions.append_array(Keywords.actions_with_modifiers(card, {"follow_up": true, "empowered": true}))
	for original: Dictionary in actions:
		if str(original.get("type", "")) not in ATTACK_TYPES: continue
		var blast: Dictionary = _engine.blast_action_for_player_action(original)
		var action: Dictionary = original if blast.is_empty() else blast
		var scale: Dictionary = action.get("scale_bonus", {})
		if str(scale.get("per", "")) == "stoneskin":
			_add(dependencies, {"input": "scale", "action": {"scale_bonus": scale}})
		var surface: Dictionary = action.get("surface_bonus", {})
		if str(surface.get("subject", "")) == "player":
			_add(dependencies, {"input": "surface", "condition": surface})
		# A supplied action variant can spend Stoneskin to change its attack type.
		if (original.get("_surface_relic_modes", []) as Array).has("cross") or str(original.get("_surface_relic_mode", "")) == "cross":
			_add(dependencies, {"input": "cross", "action": original})
		for effect: Dictionary in effects:
			match str(effect.get("type", "")):
				"glass_attack_bonus": _add(dependencies, {"input": "unprotected"})
				"bloodied_attack_bonus": _add(dependencies, {"input": "half_health"})
				"bloodied_glass_attack_bonus": _add(dependencies, {"input": "bloodied_glass"})
				"room_element_attack_bonus":
					if str(action.get("_card_element", "none")) in ["fire", "ice", "lightning", "air", "earth"]:
						_add(dependencies, {"input": "room_element"})
				"player_state_action_mod":
					var types: Array = effect.get("action_types", [])
					if not types.is_empty() and not types.has(str(action.get("type", ""))): continue
					if effect.has("element") and str(action.get("element", action.get("_card_element", "none"))) != str(effect["element"]): continue
					var required: String = str(effect.get("requires_field", ""))
					if not required.is_empty() and int(action.get(required, 0)) <= 0: continue
					_add(dependencies, {"input": "player_condition", "effect": effect})
	return dependencies

static func _add(dependencies: Array, dependency: Dictionary) -> void:
	if not dependencies.has(dependency): dependencies.append(dependency)

static func values(dependencies: Array, available: Dictionary) -> Array:
	var result: Array = []
	var state: Dictionary = available["state"]
	for dependency: Dictionary in dependencies:
		match str(dependency["input"]):
			"scale": result.append(Keywords.scale_bonus_damage(state, dependency["action"]))
			"surface": result.append(_engine._surface_condition_met(state, dependency["condition"], Vector2i.ZERO))
			"player_condition": result.append(_engine._relic_player_state_condition_met(state, dependency["effect"]))
			"cross": result.append(_engine.SurfaceRelicRules.resolve_action(state, dependency["action"]))
			_: result.append(available[dependency["input"]])
	return result
