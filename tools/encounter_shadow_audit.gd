extends "res://tools/bot_policy.gd"
## Passive observer for ten replays. The inherited policy chooses and commits
## every transition unchanged; diagnostics run only on copies after each choice.
const HandQuery = preload("res://scripts/run_scene.gd")
var hand_query = HandQuery.new()
var audit_turns: Array[Dictionary]
var choosing: bool = false
var observed_turn: int = -1
var turn_events: Array[Dictionary]

func hand_facts(state: Dictionary) -> Dictionary:
	hand_query._combat_engine = engine
	hand_query._combat_state = state
	var playable: Array[String]
	var visibility_blocked: Array[Dictionary]
	var legal_attacks: Array[Dictionary]
	var hidden: Dictionary = {}
	for enemy: Dictionary in state["enemies"]:
		if int(enemy["hp"]) > 0 and not engine.is_enemy_visible_to_player(state, enemy):
			for tile: Vector2i in engine._enemy_footprint_tiles(enemy): hidden[tile] = int(enemy["id"])
	for index: int in range(state["deck"]["hand"].size()):
		if not engine.hand_card_has_play_budget(state, index): continue
		var card: String = state["deck"]["hand"][index]
		if bool(hand_query._card_playability_for_state(state, index).get("printed_playable", false)): playable.append(card)
		var prepared: Dictionary = engine.prepare_player_card(state, index)
		var clear: Dictionary = prepared.duplicate(true)
		clear["umbra"]["stage"] = engine.UMBRA_STAGE_CLEAR
		for action: Dictionary in engine.card_play_actions(card, prepared):
			if str(action.get("type", "")) not in ["melee", "ranged", "aoe", "push", "pull", "petrify"]: continue
			if not engine.player_action_needs_target(action) or not engine.player_action_can_resolve(prepared, action): continue
			var targets: Array[Vector2i] = engine.valid_targets_for_player_action(prepared, action)
			if not targets.is_empty():
				legal_attacks.append({"card": card, "action": action["type"], "target_count": targets.size()})
				continue
			var hidden_targets: Array[int]
			for target: Vector2i in engine.valid_targets_for_player_action(clear, action):
				if hidden.has(target) and not hidden_targets.has(int(hidden[target])): hidden_targets.append(int(hidden[target]))
			if not hidden_targets.is_empty(): visibility_blocked.append({"card": card, "action": action["type"], "enemy_ids": hidden_targets})
	return {"playable_cards": playable, "visibility_blocked_actions": visibility_blocked, "targeted_actions_with_legal_targets": legal_attacks}

func movement_fact(before: Dictionary, after: Dictionary, kind: String) -> Dictionary:
	var start: Vector2i = before["player"]["pos"]
	var end: Vector2i = after["player"]["pos"]
	var nearest: Dictionary = {}
	var distance: int = 1000000
	for enemy: Dictionary in before["enemies"]:
		if int(enemy["hp"]) <= 0: continue
		var candidate: int = Frozen.Sweep.Paths.manhattan(start, enemy["pos"])
		if candidate < distance:
			distance = candidate
			nearest = enemy
	return {"kind": kind, "from": start, "to": end, "nearest_enemy_id": nearest.get("id", -1),
		"nearest_enemy_pos": nearest.get("pos", start), "before_distance": distance,
		"after_distance": Frozen.Sweep.Paths.manhattan(end, nearest.get("pos", start)),
		"hidden_collisions": maxi(0, int(after.get("umbra", {}).get("movement_interrupted_total", 0)) - int(before.get("umbra", {}).get("movement_interrupted_total", 0))),
		"moved_toward_nearest": start != end and not nearest.is_empty() and Frozen.Sweep.Paths.manhattan(end, nearest["pos"]) < distance}

func choose(state: Dictionary) -> Dictionary:
	choosing = true
	var selected: Dictionary = super.choose(state)
	choosing = false
	if observed_turn != int(state["turn"]):
		observed_turn = int(state["turn"])
		turn_events.clear()
	var event: Dictionary = {"turn": observed_turn, "pos": state["player"]["pos"], "hand": state["deck"]["hand"].duplicate(), "facts": hand_facts(state), "card": selected.get("card", "pass")}
	if not selected.is_empty(): event["movement"] = movement_fact(state, selected["state"], "card")
	turn_events.append(event)
	print("SHADOW AUDIT DECISION: " + JSON.stringify(Frozen.Store._sanitize_variant(event)))
	return selected

func best_dodge(state: Dictionary) -> Dictionary:
	var result: Dictionary = super.best_dodge(state)
	if choosing: return result
	var row: Dictionary = {"turn": int(state["turn"]), "before_dodge": state["player"]["pos"], "end": result["state"]["player"]["pos"],
		"end_nearest_distance": nearest_enemy(result["state"]),
		"facts": hand_facts(result["state"]), "movement": movement_fact(state, result["state"], "dodge"),
		"events": turn_events.duplicate(true), "hp": result["state"]["player"]["hp"], "hand": result["state"]["deck"]["hand"].duplicate()}
	audit_turns.append(Frozen.Store._sanitize_variant(row))
	print("SHADOW AUDIT TURN: " + JSON.stringify(Frozen.Store._sanitize_variant(row)))
	return result

func run_room(seed_value: int, layout: Dictionary, deck: Array) -> Dictionary:
	audit_turns.clear()
	observed_turn = -1
	turn_events.clear()
	var result: Dictionary = super.run_room(seed_value, layout, deck)
	result["audit_turns"] = audit_turns.duplicate(true)
	return result
