extends SceneTree

const Suite = preload("res://tests/suites/relic_u1_suite.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
var _failures: Array[String]

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	Suite.run(Callable(self, "_expect"))
	if _failures.is_empty():
		print("RELIC U1 TEST RESULT: PASS")
		quit(0)
		return
	for failure: String in _failures: push_error(failure)
	print("RELIC U1 TEST RESULT: FAIL (%d failure(s))" % _failures.size())
	quit(1)

func _expect(condition: bool, message: String) -> void:
	if not condition: _failures.append(message)
