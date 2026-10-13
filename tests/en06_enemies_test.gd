extends SceneTree
const Suite = preload("res://tests/suites/en06_enemies_suite.gd")
var _failures: Array[String]
var _checks: int = 0
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	Suite.run(Callable(self, "_expect"))
	await Suite.run_live(self, Callable(self, "_expect"))
	for failure: String in _failures: push_error(failure)
	print("EN06 ENEMIES TEST RESULT: %s (%d checks, %d failures)" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)
func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition: _failures.append(message)
