extends RefCounted

const ManeuverRules = preload("res://scripts/maneuver_rules.gd")

# Eligibility belongs to the complete card, including attached conditional
# rewards. Independent movement and illusion movement never acquire Stay.
static func card_offers_stay(actions: Array) -> bool:
	for action: Dictionary in actions:
		if str(action.get("type", "")) not in ["move", "blink"]:
			return true
		if not (action.get("if_started_on_surface", {}) as Dictionary).is_empty():
			return true
		if not (action.get("if_no_adjacent_enemies", []) as Array).is_empty() or int(action.get("block_per_tile", 0)) > 0:
			return true
		if action.has("surface") or action.has("trail_surface") or action.has("origin_surface") or action.has("trail_light") or int(action.get("illuminate_radius", 0)) > 0 or action.has("illusion_at_origin"):
			return true
	return false

static func action_offers_stay(action: Dictionary) -> bool:
	return str(action.get("type", "")) in ["move", "blink"] and bool(action.get("_can_stay", false)) and not bool(action.get("_movement_pool", false)) and not action.has("_illusion_id")

static func is_stay(state: Dictionary, action: Dictionary, target: Vector2i) -> bool:
	return action_offers_stay(action) and target == (state.get("player", {}) as Dictionary).get("pos", Vector2i(-1, -1))

static func apply_starting_state_reward(engine: RefCounted, state: Dictionary, action: Dictionary) -> Dictionary:
	var started: Dictionary = action.get("if_started_on_surface", {}) as Dictionary
	if not started.is_empty() and ManeuverRules.started_activation_on(state, str(started.get("surface", ""))):
		return engine._apply_relic_rewards(state, started.get("rewards", []), {"source_name": engine._action_card_name(action)})
	return state

