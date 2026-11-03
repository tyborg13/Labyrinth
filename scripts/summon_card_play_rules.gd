extends RefCounted

const PENDING_FIELD: String = "pending_summon_card_plays"
const TOOLTIP: String = "You gain +1 Card Play next turn."
const LOG_LINE: String = "Gained 1 Card Play for your next turn."
const Data = preload("res://scripts/game_data.gd")

static var _forecast_memo := preload("res://scripts/combat_preview_memo.gd").new()

static func eligible(action: Dictionary, _enemy: Dictionary = {}) -> bool:
	# All remaining summon moves are authored. Guardian replacement injection
	# retired in bos-03; saved replacements are removed at the load boundary.
	return str(action.get("type", "")) == "summon_minions"

static func grant(engine: RefCounted, state: Dictionary, action: Dictionary, enemies_before: int) -> void:
	# Count arrivals, including an arrival killed by a surface. Pay once per move.
	var index: int = engine._enemy_index_for_id(state, int(action.get("_enemy_id", -1)))
	var enemy: Dictionary = state["enemies"][index] if index >= 0 else {}
	if not eligible(action, enemy) or (state.get("enemies", []) as Array).size() <= enemies_before: return
	state[PENDING_FIELD] = int(state.get(PENDING_FIELD, 0)) + 1
	engine._log(state, LOG_LINE)

static func decorate_step(before: Dictionary, after: Dictionary, action: Dictionary, step: Dictionary, context: Dictionary = {}) -> void:
	if str(action.get("type", "")) != "summon_minions": return
	step["summon_action_index"] = int(context.get("action_index", -1))
	step["granted_card_play"] = int(after.get(PENDING_FIELD, 0)) > int(before.get(PENDING_FIELD, 0))

static func forecast_options(engine: RefCounted, state: Dictionary, unit: Dictionary, action: Dictionary, action_index: int = -1) -> Dictionary:
	if not eligible(action, unit) or unit.is_empty() or int(unit.get("hp", 0)) <= 0: return {}
	var index: int = engine._enemy_index_for_id(state, int(unit.get("id", -1)))
	if index < 0: return {}
	if action_index < 0: action_index = ((unit.get("intent", {}) as Dictionary).get("actions", []) as Array).find(action)
	if action_index < 0: return {}
	var grants: Dictionary = _forecast_memo.resolve([state, index, engine.get_script(), Data.enemies()], func() -> Dictionary:
		return _forecast_grants(engine, state, index))
	return {"granted_card_play": bool(grants.get(action_index, false))}

static func _forecast_grants(engine: RefCounted, state: Dictionary, index: int) -> Dictionary:
	# The production resolver owns a private copy. It runs shared activation-start
	# preparation, status/fuel gates and preceding actions, without choosing a new
	# intent. Only an actual arrival by this particular move promises a play.
	var result: Dictionary = engine.resolve_enemy_turn_with_steps(state, index, true, false)
	var grants: Dictionary = {}
	var actor_key: String = engine._enemy_key(state["enemies"][index])
	for step: Dictionary in result.get("steps", []):
		if str(step.get("actor_key", "")) == actor_key and step.has("summon_action_index"):
			grants[int(step["summon_action_index"])] = bool(step.get("granted_card_play", false))
	return grants

static func presentation(scene: Control, state: Dictionary, step: Dictionary) -> Dictionary:
	if not bool(step.get("granted_card_play", false)): return {}
	# Reuse the existing positive heal float's colour, placement and timing.
	var floats: Array = scene._floating_texts_for_step({"kind": "heal", "amount": 1, "tile": state["player"]["pos"]})
	floats[0]["text"] = "+1 Card Play"
	return {"floating_texts": floats}

static func present(scene: Control, state: Dictionary, step: Dictionary) -> void:
	var feedback: Dictionary = presentation(scene, state, step)
	if not feedback.is_empty(): await scene._animate_floating_text_presentation(state, feedback)

static func turn_start_events(phase: Dictionary, context: Dictionary) -> Array[Dictionary]:
	var events: Array[Dictionary]
	var before: Dictionary = phase.get("player_turn_before_state", {})
	if before.is_empty(): return events
	events.append({"event_type": "player_turn_started", "context": context, "payload": {
		"summon_card_plays": maxi(0, int(before.get(PENDING_FIELD, 0)))
	}})
	return events
