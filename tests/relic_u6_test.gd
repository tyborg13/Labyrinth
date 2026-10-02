extends SceneTree
const Suite = preload("res://tests/suites/relic_u6_suite.gd")
var failures: Array[String]
func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	Suite.run(Callable(self, "expect"))
	for failure: String in failures: push_error(failure)
	print("RELIC U6 TEST RESULT: PASS" if failures.is_empty() else "RELIC U6 TEST RESULT: FAIL (%d failures)" % failures.size())
	quit(0 if failures.is_empty() else 1)
func expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
