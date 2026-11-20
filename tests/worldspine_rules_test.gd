extends SceneTree

const Runtime = preload("res://scripts/parallel_runtime.gd")
const ReviewCases = preload("res://tests/suites/worldspine_feedback_suite.gd")
const Terrain = preload("res://tests/suites/illusion_terrain_suite.gd")
const Surfaces = preload("res://tests/suites/card_mechanics_surfaces_suite.gd")
const Cards = preload("res://tests/suites/card_pool_overhaul_suite.gd")
const Collision = preload("res://tests/suites/relic_u3_suite.gd")
const Feedback = preload("res://tests/suites/combat_outcome_feedback_suite.gd")
const Dragons = preload("res://tests/suites/dragon_element_rules_suite.gd")
const DragonCopy = preload("res://tests/suites/dragon_feedback1_suite.gd")
const Grimoire = preload("res://tests/suites/grimoire_search_suite.gd")

var _checks: int
var _failures: int

func _initialize() -> void:
	Runtime.apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	var suites: Array = [ReviewCases] if OS.get_cmdline_user_args().has("--feedback-only") else [Terrain, Surfaces, Cards, Collision, Feedback, Grimoire, Dragons, DragonCopy, ReviewCases]
	for suite: Script in suites:
		var previous_checks: int = _checks
		var previous_failures: int = _failures
		suite.run(_expect)
		print("%s: %d checks, %d failures" % [suite.resource_path.get_file(), _checks - previous_checks, _failures - previous_failures])
	print("TRN-01 RULES RESULT: %s (%d checks, %d failures)" % ["PASS" if _failures == 0 else "FAIL", _checks, _failures])
	quit(0 if _failures == 0 else 1)

func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(message)
