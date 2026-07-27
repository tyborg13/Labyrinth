extends SceneTree

const BalancePacingSuite = preload("res://tests/suites/balance_pacing_suite.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	BalancePacingSuite.run(Callable(self, "_expect"))
	if _failures.is_empty():
		print("BALANCE PACING TEST RESULT: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("BALANCE PACING TEST RESULT: FAIL (%d failure(s))" % _failures.size())
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
