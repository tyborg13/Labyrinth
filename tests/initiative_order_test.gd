extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const InitiativeOrderSuite = preload("res://tests/suites/initiative_order_suite.gd")

var _failures: Array[String]

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	InitiativeOrderSuite.run(Callable(self, "_expect"))
	if _failures.is_empty():
		print("INITIATIVE ORDER TEST RESULT: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("INITIATIVE ORDER TEST RESULT: FAIL (%d failure(s))" % _failures.size())
	quit(1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
