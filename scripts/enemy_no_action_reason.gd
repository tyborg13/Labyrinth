extends RefCounted
## Resolver-only explanations. Presentation consumes these fields verbatim.

static func attack_failure(engine: RefCounted, state: Dictionary, enemy: Dictionary, action: Dictionary, context: Dictionary) -> String:
	var targets: Array[Dictionary] = engine._actor_targets(state)
	if targets.is_empty(): return "no_target"
	var blocked_in_range: bool = false
	for target: Dictionary in targets:
		# Includes conductive Lightning reach and the action's authored footprint.
		if engine._enemy_action_reaches_target(state, enemy, action, target): return ""
		var tile: Vector2i = target["pos"]
		var source: Vector2i = engine._closest_enemy_tile_to(enemy, tile)
		var kind: String = str(action.get("type", ""))
		var reach: int = int(action.get("range", 0 if kind == "aoe" else 1))
		if kind in ["ranged", "push", "pull", "aoe"] and reach > 0 and engine._enemy_distance_to_tile(enemy, tile) <= reach and not engine.combat_line_of_sight(state, source, tile):
			blocked_in_range = true
	# A previously selected illusion/actor can disappear between actions. An
	# unreachable surviving actor does not turn that lost target into a range miss.
	if not str(context.get("target_key", "")).is_empty() and engine._current_actor_target_for_plan(state, context).is_empty(): return "no_target"
	return "no_line_of_sight" if blocked_in_range else "out_of_range"

static func status_reasons(engine: RefCounted, state: Dictionary, index: int, frozen: bool, petrified: bool, shocked: bool, immobilized: bool) -> Array[String]:
	var reasons: Array[String]
	if petrified or frozen:
		reasons.append("petrified" if petrified else "frozen")
		return reasons
	var enemy: Dictionary = state["enemies"][index]
	var intent: Dictionary = engine.WarbandRules.current_intent(state, enemy, enemy.get("intent", {}))
	var plan: Dictionary = engine.enemy_intent_plan(state, index, intent, false, false, false)
	var attack: Dictionary = plan.get("attack_action", {})
	var pattern_attack: bool = false
	for action: Dictionary in intent.get("actions", []):
		if str(action.get("type", "")) == "lightning_strikes" or str(action.get("type", "")) in engine.BOSS_PATTERN_ACTION_TYPES: pattern_attack = true
	if shocked and (not attack.is_empty() or pattern_attack): reasons.append("shocked")
	if immobilized:
		# Full plans include pre-intent retreats and movement inside an attack.
		# Keep Shock equal on both sides: a flight already lost to Shock is not
		# movement prevented by Immobilize.
		var unrestricted: Dictionary = engine.enemy_intent_plan(state, index, intent, false, shocked)
		var restricted: Dictionary = engine.enemy_intent_plan(state, index, intent, true, shocked)
		var origin: Vector2i = enemy["pos"]
		if _movement(unrestricted, origin) != _movement(restricted, origin): reasons.append("immobilized")
	return reasons

static func _movement(plan: Dictionary, origin: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i]
	path.append(origin)
	for tile: Vector2i in plan.get("path", []):
		if tile != path.back(): path.append(tile)
	# Dive's path describes its approach; its flight ends at the landing.
	var landing: Vector2i = plan.get("landing", plan.get("destination", path.back()))
	if landing != path.back(): path.append(landing)
	return path
