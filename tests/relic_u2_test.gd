extends SceneTree

const Suite = preload("res://tests/suites/relic_u2_suite.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
var _failures: Array[String]

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	Suite.run(Callable(self, "_expect"))
	for failure: String in _failures:
		push_error(failure)
	print("RELIC U2 TEST RESULT: PASS" if _failures.is_empty() else "RELIC U2 TEST RESULT: FAIL (%d failures)" % _failures.size())
	quit(0 if _failures.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
