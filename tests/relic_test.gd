extends SceneTree

const RelicSuite = preload("res://tests/suites/relic_suite.gd")

var _failures: Array[String] = []

func _initialize() -> void:
	RelicSuite.run(Callable(self, "_expect"))
	if _failures.is_empty():
		print("RELIC TEST RESULT: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("RELIC TEST RESULT: FAIL (%d failure(s))" % _failures.size())
	quit(1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
