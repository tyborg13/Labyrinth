extends "res://tools/inspection_fixture.gd"
## Reuse the maintained fixture builders without invoking their save/quit entry point.
const CombatStops = preload("res://tools/hitch_census/combat_stops.gd")
var census_error: String = ""

func _initialize() -> void:
	pass

func make(kind: String, seed_value: int, extra: Dictionary = {}) -> Dictionary:
	_failed = false
	census_error = ""
	var scenario: String = kind
	if CombatStops.CASES.has(kind):
		extra = CombatStops.CASES[kind].merged(extra, true)
		scenario = extra["scenario"]
	_options = {"scenario": scenario, "seed": seed_value, "hero_facing": "persist"}
	_options.merge(extra, true)
	if CombatStops.BOSS_CYCLES.has(kind):
		_options["player_hp"] = CombatStops.FIXTURE_HEALTH
		_options["player_max_hp"] = CombatStops.FIXTURE_HEALTH
	var progression: Dictionary = _build_progression()
	progression = preload("res://scripts/contextual_combat_tutorial.gd").complete_tutorial(progression)
	var state: Dictionary = _build_run_state(scenario, progression)
	return {} if _failed else state

func _fail(message: String) -> void:
	_failed = true
	census_error = message
