extends RefCounted
## Policy v2's run_room loop, accepting the production run's existing battle.
## Decision methods and bounds are called from the byte-frozen policy itself.
const Bot = preload("res://tools/encounter_bot.gd")

static func fight(initial: Dictionary) -> Dictionary:
	var policy := Bot.Policy.new()
	var state: Dictionary = initial
	var turns: int = 1
	var decisions: int = 0
	var search_capped: bool = false
	while policy.engine.combat_outcome(state).is_empty():
		turns = int(state["turn"])
		if turns > Bot.MAX_TURNS:
			break
		var decision: int = 0
		while decision < Bot.MAX_DECISIONS_PER_TURN and policy.engine.combat_outcome(state).is_empty():
			var selected: Dictionary = policy.choose(state)
			if selected.is_empty(): break
			state = selected["state"]
			decision += 1
			decisions += 1
		if decision == Bot.MAX_DECISIONS_PER_TURN: search_capped = true
		if not policy.engine.combat_outcome(state).is_empty(): break
		state = policy.best_dodge(state)["state"]
		if not policy.engine.combat_outcome(state).is_empty(): break
		state = policy.engine.advance_to_next_player_turn_with_steps(policy.engine.finish_player_activation(state))["state"]
	var outcome: String = policy.engine.combat_outcome(state)
	return {"state": state, "won": outcome == "victory", "turn_cap_reached": outcome.is_empty(), "turns": mini(turns, Bot.MAX_TURNS), "decisions": decisions, "search_capped": search_capped}
