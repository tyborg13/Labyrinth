extends SceneTree

const Suite = preload("res://tests/suites/en04_enemies_suite.gd")
const MINIMUM_CHECK_COUNT: int = 454
var _failures: Array[String]
var _checks: int = 0

func _initialize() -> void:
	Suite.run(Callable(self, "_expect"))
	if _checks < MINIMUM_CHECK_COUNT: _failures.append("Suite did not finish its minimum check count")
	for failure: String in _failures: push_error(failure)
	print("EN04 ENEMIES TEST RESULT: %s (%d checks, %d failures)" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition: _failures.append(message)
