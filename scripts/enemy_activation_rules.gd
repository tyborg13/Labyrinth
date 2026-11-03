extends RefCounted
## Shared activation gates for resolution and announced on_intent projections.
static func action_allowed(engine: RefCounted, action: Dictionary, restrictions: Dictionary) -> bool:
	if bool(restrictions.get("skip_all", false)): return false
	if bool(restrictions.get("shocked", false)) and not engine._enemy_action_is_movement(action): return false
	# Snuff's move is suppressed by its own resolver; an adjacent rooted Shade still snuffs.
	return not (bool(restrictions.get("immobilized", false)) and engine._enemy_action_is_movement(action) and not engine.SnuffRules.handles(action))

static func empty_intent_allowed(restrictions: Dictionary) -> bool:
	return not bool(restrictions.get("skip_all", false)) and not bool(restrictions.get("shocked", false))

static func forecast(engine: RefCounted, state: Dictionary, index: int) -> Dictionary:
	# Use the complete start-of-turn preparation on a private board, including
	# conditional Block clearing before ground contact and status consumption.
	var prepared: Dictionary = engine._resolve_enemy_start_of_turn(state.duplicate(true), index)
	var trial: Dictionary = prepared["state"]
	var enemy: Dictionary = trial["enemies"][index]
	var intent: Dictionary = engine.WarbandRules.current_intent(trial, enemy, engine._surface_pay_enemy_fuel(trial, enemy, enemy.get("intent", {})))
	var available: bool = false
	var actions: Array = intent.get("actions", [])
	if not intent.is_empty() and actions.is_empty(): available = empty_intent_allowed(prepared)
	for action: Dictionary in actions:
		if action_allowed(engine, action, prepared) and engine.enemy_action_can_resolve(trial, action): available = true
	return {"intent": str(intent.get("id", "")), "available": available}
