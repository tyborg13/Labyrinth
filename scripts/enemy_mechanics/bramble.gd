extends RefCounted
## Thornwall is delayed Upheaval; no separate terrain or collision rules.
const Upheaval = preload("res://scripts/battlefield_rules/upheaval.gd")
static func handles(action: Dictionary) -> bool:
	return str(action.get("type", "")) == "upheaval_mark"
static func instance(enemy: Dictionary, action: Dictionary) -> Dictionary:
	return {"rule": "upheaval", "source": {"kind": "enemy", "id": int(enemy["id"])}, "dials": {"pattern": action["pattern"], "length": int(action["length"]), "health": int(action["health"])}}
static func marking_action(enemy: Dictionary) -> Dictionary:
	for action: Dictionary in enemy.get("intent", {}).get("actions", []):
		if handles(action): return action
	for intent: Dictionary in preload("res://scripts/game_data.gd").enemy_def(str(enemy["type"]))["intents"]:
		for action: Dictionary in intent.get("actions", []):
			if handles(action): return action
	return {}

static func tiles(engine: RefCounted, state: Dictionary, enemy: Dictionary, action: Dictionary = {}) -> Array[Vector2i]:
	var authored: Dictionary = marking_action(enemy) if action.is_empty() else action
	if authored.is_empty(): return engine._vector2i_values([])
	var value: Dictionary = instance(enemy, authored)
	Upheaval.prepare(engine, state, value)
	return engine._vector2i_values(value["marks"])
static func mend_action(engine: RefCounted, state: Dictionary, enemy: Dictionary, action: Dictionary) -> Dictionary:
	var result: Dictionary = action.duplicate(true)
	# An ally is another living enemy; keep existing most-missing-HP tie breaks.
	if str(enemy.get("type", "")) == "briar_weaver" and str(action.get("type", "")) == "heal_ally": result["allow_self"] = false
	return result

static func effective_intent(engine: RefCounted, state: Dictionary, enemy: Dictionary, intent: Dictionary) -> Dictionary:
	if str(enemy.get("type", "")) != "briar_weaver" or str(intent.get("id", "")) != "root_mend": return intent
	var index: int = engine._enemy_index_for_id(state, int(enemy["id"]))
	for action: Dictionary in intent.get("actions", []):
		if engine._enemy_support_target_index(state, index, mend_action(engine, state, enemy, action)) >= 0: return intent
	var intents: Array = engine._scaled_enemy_intents(preload("res://scripts/game_data.gd").enemy_def("briar_weaver")["intents"], int(state.get("room_depth", 1)), state, enemy)
	return engine._intent_by_id(intents, "lash_of_thorns")

static func presentation_intent(state: Dictionary, enemy: Dictionary, intent: Dictionary) -> Dictionary:
	if str(enemy.get("type", "")) != "briar_weaver" or str(intent.get("id", "")) != "root_mend": return intent
	return effective_intent(preload("res://scripts/combat_engine.gd").new(), state, enemy, intent)

static func available(engine: RefCounted, state: Dictionary, enemy: Dictionary, intent: Dictionary) -> bool:
	for action: Dictionary in intent.get("actions", []):
		if handles(action) and tiles(engine, state, enemy, action).is_empty(): return false
		if str(enemy.get("type", "")) == "briar_weaver" and str(action.get("type", "")) == "heal_ally":
			if engine._enemy_support_target_index(state, engine._enemy_index_for_id(state, int(enemy["id"])), mend_action(engine, state, enemy, action)) < 0: return false
	return true

static func plan(engine: RefCounted, state: Dictionary, index: int, intent: Dictionary, disabled: bool) -> Dictionary:
	for action: Dictionary in intent.get("actions", []):
		if not handles(action): continue
		var enemy: Dictionary = state["enemies"][index]
		var affected: Array[Vector2i] = tiles(engine, state, enemy, action)
		if disabled: affected.clear()
		return {"enemy_index": index, "enemy_key": engine._enemy_key(enemy), "path": engine._vector2i_values([enemy["pos"]]), "route": engine._vector2i_values([enemy["pos"]]), "destination": enemy["pos"], "projected_attack": affected, "attack_available": not affected.is_empty(), "attack_action": action, "attack_action_index": 0, "movement_action_index": -1, "target_tile": state["player"]["pos"], "target_key": "player"}
	return {}

static func resolve(engine: RefCounted, state: Dictionary, index: int, action: Dictionary) -> Dictionary:
	var enemy: Dictionary = state["enemies"][index]
	var value: Dictionary = instance(enemy, action)
	Upheaval.prepare(engine, state, value)
	enemy["upheaval_pending"] = value
	return state

static func begin_turn(engine: RefCounted, state: Dictionary, index: int) -> Dictionary:
	var enemy: Dictionary = state["enemies"][index]
	var pending: Dictionary = enemy.get("upheaval_pending", {})
	if pending.is_empty(): return state
	# Several source turns can fit before the next player activation. Preserve
	# the warning when the shared Upheaval fuel boundary postpones its raise.
	if not Upheaval.Fuel.eligible(state, pending.get("marks_source", {})): return state
	enemy.erase("upheaval_pending")
	var previous: Dictionary = state.get("damage_context", {}).duplicate(true)
	state["damage_context"] = {"actor_kind": "enemy", "actor_id": int(enemy["id"]), "source_kind": "direct_attack", "player_card": false}
	state = Upheaval.resolve_beat(engine, state, pending)
	state["damage_context"] = previous
	return state

static func animation_step(engine: RefCounted, before: Dictionary, after: Dictionary, index: int, action: Dictionary) -> Dictionary:
	var enemy: Dictionary = before["enemies"][index]
	return {"kind": "surface", "action_type": "upheaval_mark", "actor_key": engine._enemy_key(enemy), "element": "earth", "tiles": tiles(engine, before, enemy, action), "from": enemy["pos"], "to": before["player"]["pos"], "en04_state_after": after.duplicate(true)}
