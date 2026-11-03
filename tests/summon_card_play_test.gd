extends SceneTree

var _checks: int = 0
var _failures: Array[String]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	preload("res://tests/suites/summon_card_play_suite.gd").run(_expect)
	await preload("res://tests/suites/summon_card_play_suite.gd").run_dispatch(_expect)
	for failure: String in _failures: push_error(failure)
	print("SUMMON CARD PLAY TEST RESULT: %s (%d checks, %d failures)" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition: _failures.append(message)
