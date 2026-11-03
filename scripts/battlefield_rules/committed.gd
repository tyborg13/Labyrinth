extends RefCounted
## The single acceptance point for live action transitions. Resolvers and query
## copies never call it. Switch events join the accepted action's analytics stream.
const Rules = preload("res://scripts/battlefield_rules/dispatcher.gd")
const HalfHealth = preload("res://scripts/battlefield_rules/half_health.gd")
const Keywords = preload("res://scripts/card_keyword_rules.gd")

static func accept(engine: RefCounted, state: Dictionary) -> Dictionary:
	if HalfHealth.check(state): Rules.prepare(engine, state)
	return state

static func callback(engine: RefCounted) -> Callable:
	return func(state: Dictionary) -> Dictionary: return accept(engine, state)

static func player_action(engine: RefCounted, state: Dictionary, action: Dictionary, target: Vector2i = Vector2i(-1, -1)) -> Dictionary:
	return accept(engine, engine.apply_player_action(state, action, target))

static func player_card(engine: RefCounted, before: Dictionary, resolved: Dictionary, hand_index: int, actions: Array, targets: Array[Vector2i], context: Dictionary = {}) -> Dictionary:
	var instance: Dictionary = Rules.active(before)
	var working: Dictionary = resolved
	# A declaration requires accepting intermediate actions.
	# All other cards retain the existing pre-resolved commit path.
	if instance.has("at_half_health"):
		var empowered: bool = bool(resolved.get(Keywords.PLAY_MODIFIERS_KEY, {}).get("empowered", false))
		working = engine.prepare_player_card(before, hand_index, "empower" if empowered else "play")
		var target_index: int = 0
		for action: Dictionary in actions:
			var target := Vector2i(-1, -1)
			if engine.player_action_needs_target(action):
				if target_index < targets.size(): target = targets[target_index]
				target_index += 1
			if not engine.player_action_can_resolve(working, action): continue
			working = player_action(engine, working, action, target)
	return accept(engine, engine.finish_player_card(working, hand_index, engine.card_plays_spent_for_actions(actions), context))

static func finish_player_activation(engine: RefCounted, state: Dictionary) -> Dictionary:
	return engine.finish_player_activation(state, callback(engine))

static func advance_one_activation(engine: RefCounted, state: Dictionary, include_commit_steps: bool = true) -> Dictionary:
	return engine.advance_one_activation_with_steps(state, include_commit_steps, callback(engine))

static func advance_to_player(engine: RefCounted, state: Dictionary) -> Dictionary:
	return engine.advance_to_next_player_turn_with_steps(state, callback(engine))

static func enemy_turn(engine: RefCounted, state: Dictionary, index: int) -> Dictionary:
	return engine.resolve_enemy_turn_with_steps(state, index, true, true, callback(engine))

static func beat(engine: RefCounted, state: Dictionary) -> Dictionary:
	var steps: Array[Dictionary]
	return Rules.fire(engine, state, steps, callback(engine))
