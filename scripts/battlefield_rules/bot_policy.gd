extends "res://tools/encounter_bot.gd".Policy
## Keep the historical policy-v2 file byte-frozen. This companion retains its
## decisions and scores while accepting only the selected action transitions.
## Selected targets live in decision metadata, never in combat/save dictionaries.
const TypedArrays = preload("res://scripts/typed_arrays.gd")
const Frozen = preload("res://tools/encounter_bot.gd")
const Committed = preload("res://scripts/battlefield_rules/committed.gd")

func planned_branches(state: Dictionary, actions: Array, index: int, effect: bool, targets_taken: Array = []) -> Array[Dictionary]:
	var result: Array[Dictionary]
	if index >= actions.size():
		if effect: result.append({"state": state, "targets": targets_taken})
		return result
	if expanded >= Frozen.MAX_EXPANDED_ACTION_STATES: return result
	var action: Dictionary = actions[index]
	if not engine.player_action_can_resolve(state, action):
		var skipped_targets: Array = targets_taken.duplicate()
		if engine.player_action_needs_target(action): skipped_targets.append(Vector2i(-1, -1))
		return planned_branches(state, actions, index + 1, effect, skipped_targets)
	if not engine.player_action_needs_target(action) or (str(action.get("type", "")) == "aoe" and int(action.get("range", 0)) <= 0):
		expanded += 1
		return planned_branches(engine.apply_player_action(state, action), actions, index + 1, true, targets_taken)
	var targets: Array[Vector2i] = engine.valid_targets_for_player_action(state, action)
	var candidates: Array[Dictionary]
	for target: Vector2i in targets:
		if expanded >= Frozen.MAX_EXPANDED_ACTION_STATES: break
		expanded += 1
		var after: Dictionary = engine.apply_player_action(state, action, target)
		var next_targets: Array = targets_taken.duplicate()
		next_targets.append(target)
		candidates.append({"state": after, "gain": gain(state, after), "order": candidates.size(), "targets": next_targets})
	# Stable ordering is the engine's target order on equal gain.
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if float(a["gain"]) != float(b["gain"]): return float(a["gain"]) > float(b["gain"])
		return int(a["order"]) < int(b["order"]))
	for candidate: Dictionary in candidates.slice(0, Frozen.MAX_ACTION_TARGETS):
		result.append_array(planned_branches(candidate["state"], actions, index + 1, true, candidate["targets"]))
		if result.size() >= Frozen.MAX_CARD_BRANCHES: break
	return TypedArrays.dictionaries(result.slice(0, Frozen.MAX_CARD_BRANCHES))

func choose(state: Dictionary) -> Dictionary:
	last_preview_count = 0
	var baseline: Dictionary = best_dodge(state)
	if engine.combat_outcome(baseline["state"]) == "victory": return {}
	var origins: Array[Dictionary]
	origins.append({"state": state, "order": 0})
	var movements: Array[Dictionary]
	for tile: Vector2i in engine.player_movement_targets(state):
		var moved: Dictionary = engine.apply_player_movement(state, tile)
		movements.append({"state": moved, "distance": objective_distance(moved), "remaining": engine.player_movement_remaining(moved), "order": movements.size() + 1})
	movements.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["remaining"] != b["remaining"]: return a["remaining"] > b["remaining"]
		if a["distance"] != b["distance"]: return a["distance"] < b["distance"]
		return int(a["order"]) < int(b["order"]))
	origins.append_array(movements.slice(0, Frozen.MAX_MOVE_OPTIONS))
	var options: Array[Dictionary]
	for origin: Dictionary in origins:
		var base: Dictionary = origin["state"]
		var hand: Array = base["deck"]["hand"]
		for hand_index: int in range(hand.size()):
			if not engine.hand_card_has_play_budget(base, hand_index): continue
			expanded = 0
			var prepared: Dictionary = engine.prepare_player_card(base, hand_index)
			var card_actions: Array = engine.card_play_actions(str(hand[hand_index]), prepared)
			for branch: Dictionary in planned_branches(prepared, card_actions, 0, false):
				var resolved: Dictionary = branch["state"]
				var after: Dictionary = engine.finish_player_card(resolved, hand_index, engine.card_plays_spent_for_actions(card_actions), {"play_mode": "play"})
				var defense: int = maxi(0, int(after["player"].get("block", 0)) + int(after["player"].get("stoneskin", 0)) - int(state["player"].get("block", 0)) - int(state["player"].get("stoneskin", 0)))
				var potential: float = gain(state, after) + Frozen.INCOMING_DAMAGE_WEIGHT * mini(defense, int(baseline["damage"]))
				potential += Frozen.HEALING_WEIGHT * (int(after["player"]["hp"]) - int(state["player"]["hp"]))
				options.append({"state": after, "card": hand[hand_index], "potential": potential, "remaining": engine.player_movement_remaining(after), "order": options.size(), "commit": {"before": base, "resolved": resolved, "index": hand_index, "actions": card_actions, "targets": branch["targets"]}})
	options.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if float(a["potential"]) != float(b["potential"]): return float(a["potential"]) > float(b["potential"])
		if a["remaining"] != b["remaining"]: return a["remaining"] > b["remaining"]
		return int(a["order"]) < int(b["order"]))
	var best: Dictionary = {}
	var score: float = 0.0
	var survives: bool = bool(baseline["survives"])
	for option: Dictionary in options.slice(0, Frozen.MAX_PREVIEW_OPTIONS):
		var dodge: Dictionary = best_dodge(option["state"])
		var value: float = option_score(state, option["state"], baseline, dodge)
		if survives and not bool(dodge["survives"]): continue
		if (bool(dodge["survives"]) and not survives) or value > score:
			survives = bool(dodge["survives"])
			score = value
			best = {"state": option["state"], "score": score, "card": option["card"], "dodge": dodge["state"]["player"]["pos"], "predicted_damage": dodge["damage"], "commit": option["commit"]}
	return best

func run_room(seed_value: int, layout: Dictionary, deck: Array) -> Dictionary:
	var state: Dictionary = engine.create_combat(seed_value, layout, {"hp": Frozen.MAX_HP, "max_hp": Frozen.MAX_HP, "deck_cards": deck, "equipped_equipment": Frozen.Game.starting_equipped_equipment(), "relics": []})
	var first_death: Variant = null
	var kills: int = 0
	var turns: int = 1
	var actions: int = 0
	var previews: int = 0
	var capped: bool = false
	while engine.combat_outcome(state).is_empty():
		turns = int(state["turn"])
		if turns > Frozen.MAX_TURNS:
			capped = true
			turns = Frozen.MAX_TURNS
			break
		var decision: int = 0
		while decision < Frozen.MAX_DECISIONS_PER_TURN and engine.combat_outcome(state).is_empty():
			var selected: Dictionary = choose(state)
			previews += last_preview_count
			if selected.is_empty(): break
			if trace: print("BOT CARD: ", Frozen.Store._sanitize_variant({"turn": turns, "before": state["player"], "remaining": engine.player_movement_remaining(state), "card": selected["card"], "after": selected["state"]["player"], "dodge": selected["dodge"], "predicted_damage": selected["predicted_damage"], "score": selected["score"]}))
			var plan: Dictionary = selected["commit"]
			var accepted_origin: Dictionary = Committed.accept(engine, plan["before"])
			state = Committed.player_card(engine, accepted_origin, plan["resolved"], int(plan["index"]), plan["actions"], engine._vector2i_values(plan["targets"]), {"play_mode": "play"})
			if kill_count(state) > kills and first_death == null: first_death = turns
			kills = kill_count(state)
			decision += 1
			actions += 1
		if decision == Frozen.MAX_DECISIONS_PER_TURN: capped = true
		if not engine.combat_outcome(state).is_empty(): break
		last_preview_count = 0
		var dodge: Dictionary = best_dodge(state)
		state = Committed.accept(engine, dodge["state"])
		if trace: print("BOT DODGE: ", Frozen.Store._sanitize_variant({"turn": turns, "player": state["player"], "predicted_damage": dodge["damage"], "enemies": state["enemies"]}))
		if kill_count(state) > kills and first_death == null: first_death = turns
		kills = kill_count(state)
		previews += last_preview_count
		if not engine.combat_outcome(state).is_empty(): break
		state = Committed.advance_to_player(engine, Committed.finish_player_activation(engine, state))["state"]
		if trace: print("BOT PHASE: ", Frozen.Store._sanitize_variant({"turn": turns, "player": state["player"], "outcome": engine.combat_outcome(state)}))
		if kill_count(state) > kills and first_death == null: first_death = turns
		kills = kill_count(state)
	var outcome: String = engine.combat_outcome(state)
	return {"policy_version": Frozen.POLICY_VERSION, "seed": seed_value, "objective": layout["objective"]["type"], "outcome": outcome if not outcome.is_empty() else "lost", "won": outcome == "victory", "turns": turns, "hp_lost": int(state.get("run_stats", {}).get("damage_received", 0)), "net_hp_lost": Frozen.MAX_HP - int(state["player"]["hp"]), "kills": kills, "first_enemy_death_turn": first_death, "search_capped": capped, "turn_cap_reached": outcome.is_empty(), "decisions": actions, "intent_previews": previews}
