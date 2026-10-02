extends SceneTree
const Suite = preload("res://tests/suites/relic_u7_suite.gd")
var failures: Array[String]
func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	Suite.run(_expect)
	for failure: String in failures: push_error(failure)
	print("RELIC U7 TEST RESULT: ", "PASS" if failures.is_empty() else "FAIL (%d failures)" % failures.size())
	quit(0 if failures.is_empty() else 1)
func _expect(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
