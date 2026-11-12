extends "res://tools/inspection_fixture.gd"
## Reuse the maintained fixture builders without invoking their save/quit entry point.
var census_error: String = ""

func _initialize() -> void:
	pass

func make(kind: String, seed_value: int, extra: Dictionary = {}) -> Dictionary:
	_failed = false
	census_error = ""
	_options = {"scenario": kind, "seed": seed_value, "hero_facing": "persist"}
	_options.merge(extra, true)
	var progression: Dictionary = _build_progression()
	progression = preload("res://scripts/contextual_combat_tutorial.gd").complete_tutorial(progression)
	var state: Dictionary = _build_run_state(kind, progression)
	if _failed: return {}
	return state

func _fail(message: String) -> void:
	_failed = true
	census_error = message
