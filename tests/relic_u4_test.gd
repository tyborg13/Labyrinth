extends SceneTree
const Suite = preload("res://tests/suites/relic_u4_suite.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
var failures: Array[String] = []
func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	Suite.run(Callable(self, "_expect"))
	for failure: String in failures:
		push_error(failure)
	print("RELIC U4 TEST RESULT: PASS" if failures.is_empty() else "RELIC U4 TEST RESULT: FAIL (%d failures)" % failures.size())
	quit(0 if failures.is_empty() else 1)
func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
