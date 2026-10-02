extends SceneTree
const Suite = preload("res://tests/suites/relic_u3_suite.gd")
const Runtime = preload("res://scripts/parallel_runtime.gd")
var failures: Array[String] = []
func _initialize() -> void:
	Runtime.apply_from_environment()
	_run.call_deferred()
func _run() -> void:
	Suite.run(Callable(self, "_expect"))
	for message: String in failures:
		push_error(message)
	print("RELIC U3 TEST RESULT: PASS" if failures.is_empty() else "RELIC U3 TEST RESULT: FAIL (%d failures)" % failures.size())
	quit(0 if failures.is_empty() else 1)
func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
