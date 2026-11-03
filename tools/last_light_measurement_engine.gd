extends "res://scripts/combat_engine.gd"
## Offline-only (spx-08 measurement): the production engine, remembering the last
## state whose outcome was asked for. The bot's final question is always about
## its final committed state, so dawn metrics read that state; rules are untouched.
var last_outcome_state: Dictionary = {}

func combat_outcome(state: Dictionary) -> String:
	last_outcome_state = state
	return super.combat_outcome(state)

static func dawn_metrics(engine: RefCounted, result: Dictionary) -> Dictionary:
	var final: Dictionary = engine.last_outcome_state
	var lit: int = preload("res://scripts/last_light_rules.gd").lit_count(final)
	return {"braziers_lit_at_dawn": lit if bool(result["won"]) else 0, "braziers_lit_at_end": lit,
		"brazier_snuffs": int(final.get("objective", {}).get("brazier_snuffs", 0)),
		"reinforcement_waves": int(final.get("objective", {}).get("reinforcement_waves_spawned", 0))}
