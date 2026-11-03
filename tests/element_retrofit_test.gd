extends SceneTree
const Suite = preload("res://tests/suites/element_retrofit_suite.gd")
var checks: int = 0
var failures: Array[String]
func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	Suite.run(_expect)
	for failure: String in failures: push_error(failure)
	print("ELEMENT RETROFIT TEST RESULT: %s (%d checks, %d failures)" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
