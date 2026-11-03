extends SceneTree
var failures: Array[String]
var checks: int = 0
func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	preload("res://tests/suites/guardian_rules_suite.gd").run(_expect)
	preload("res://tests/suites/guardian_tuning_suite.gd").run(_expect)
	for failure: String in failures: push_error(failure)
	print("GUARDIAN RULES TEST RESULT: %s (%d checks, %d failures)" % ["PASS" if failures.is_empty() else "FAIL",checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
