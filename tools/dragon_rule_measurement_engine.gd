extends "res://scripts/combat_engine.gd"
## Offline observer: retain only the last outcome query, which policy v2 makes
## on its committed final state. Speculative states never add global counters.
const COUNTERS: String = "_dragon_measurement"
var final_state: Dictionary = {}

func combat_outcome(state: Dictionary) -> String:
	var counters: Dictionary = state.get(COUNTERS, {"sequence": 0, "beats_fired": 0, "damage_to_player": 0, "damage_to_enemies": 0, "half_health_switches": 0})
	for event: Dictionary in state.get("surface_events", []):
		if int(event["sequence"]) <= int(counters["sequence"]): continue
		assert(int(event["sequence"]) == int(counters["sequence"]) + 1, "Measurement event history was truncated")
		counters["sequence"] = int(event["sequence"])
		if event.get("kind", "") == "battlefield_rule_fired":
			counters["beats_fired"] += 1
			counters["damage_to_player"] += int(event["damage_to_player"])
			counters["damage_to_enemies"] += int(event["damage_to_enemies"])
		elif event.get("kind", "") == "battlefield_rule_switched": counters["half_health_switches"] += 1
	state[COUNTERS] = counters
	final_state = state
	return super.combat_outcome(state)

func dragon_metrics() -> Dictionary:
	var result: Dictionary = final_state.get(COUNTERS, {}).duplicate(true)
	result.erase("sequence")
	result["lieutenant_kills"] = 0
	for enemy: Dictionary in final_state.get("enemies", []):
		if not bool(GameData.enemy_def(str(enemy.get("type", ""))).get("boss_bar", false)) and int(enemy.get("hp", 0)) <= 0 and not bool(enemy.get("objective_cleared", false)):
			result["lieutenant_kills"] += 1
	return result
