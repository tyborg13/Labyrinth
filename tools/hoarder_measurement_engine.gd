extends "res://scripts/combat_engine.gd"
## Measurement-only observer (spx-09): the frozen policy's last outcome check
## is on its final combat state, so its objective carries the Hoarder result.
## No rule, search or scoring changes.
var final_objective: Dictionary = {}

func combat_outcome(state: Dictionary) -> String:
	final_objective = state.get("objective", {})
	return super(state)
