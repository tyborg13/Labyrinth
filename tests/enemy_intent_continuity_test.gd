extends SceneTree

const Suite = preload("res://tests/suites/enemy_intent_continuity_suite.gd")
var _checks: int = 0
var _failures: Array[String]

func _initialize() -> void:
	Suite.run(Callable(self, "_expect"))
	for failure: String in _failures: push_error(failure)
	print("ENEMY INTENT CONTINUITY TEST RESULT: %s (%d checks, %d failures)" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition: _failures.append(message)
