extends "res://tools/bot_policy.gd"
## The recorded Guardian must be survivable with the normal starter kit.
## Its multi-activation follow-ups and Upheaval require the full resolution
## when evaluating safety. Every evaluated state is a private simulation.

const Commit = preload("res://scripts/battlefield_rules/committed.gd")

func phase_preview(state: Dictionary) -> Dictionary:
	if state.get("room_type") != "guardian":
		return super.phase_preview(state)
	last_preview_count += 1
	var scheduled: Dictionary = Commit.finish_player_activation(engine, state)
	var next: Dictionary = Commit.advance_to_player(engine, scheduled)["state"]
	var hp: int = int(next["player"]["hp"])
	return {"damage": maxi(0, int(state["player"]["hp"]) - hp), "survives": hp > 0}
