extends RefCounted

const Warband = preload("res://scripts/warband_combat_rules.gd")
const Maneuver = preload("res://scripts/maneuver_rules.gd")

static func intent(engine: RefCounted, state: Dictionary, enemy: Dictionary, announced: Dictionary) -> Dictionary:
	if not Warband.active(state) or bool(enemy.get("is_leader", false)): return announced
	var actions: Array = announced.get("actions", [])
	if not actions.any(func(action: Dictionary) -> bool: return action.has("damage")): return announced
	var index: int = engine._enemy_index_for_id(state, int(enemy.get("id", -1)))
	if index < 0: return announced
	var stopped: bool = int(enemy.get("freeze", 0)) > 0 or Maneuver.is_petrified(enemy)
	var plan: Dictionary = engine.enemy_intent_plan(state, index, announced, stopped or bool(enemy.get("immobilize", false)), stopped or int(enemy.get("shock", 0)) > 0)
	var attack: Dictionary = plan.get("attack_action", {})
	if not attack.has("damage"): return announced
	# Composite attacks can supply a projected action without an action index.
	var attack_index: int = int(plan.get("attack_action_index", 0))
	if attack_index < 0 or attack_index >= actions.size(): return announced
	var original: Dictionary = actions[attack_index]
	if str(original.get("type", "")) != str(attack.get("type", "")): return announced
	var shown: Dictionary = announced.duplicate(false)
	shown["actions"] = actions.duplicate()
	# The resolver applies Command again at the attack origin, after movement.
	# Identical consecutive hits share that origin and the same displayed value.
	for action_index: int in range(attack_index, actions.size()):
		if actions[action_index] != original: break
		var action: Dictionary = original.duplicate(false)
		action["damage"] = attack["damage"]
		action["_warband_command_bonus"] = attack.get("_warband_command_bonus", 0)
		shown["actions"][action_index] = action
	return shown
