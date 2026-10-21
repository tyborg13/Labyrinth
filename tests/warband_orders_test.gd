extends SceneTree
const Suite = preload("res://tests/suites/warband_orders_suite.gd")
var failures: Array[String]
var checks: int = 0
const MINIMUM_CHECK_COUNT: int = 186
func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	Suite.run(_expect)
	_expect(checks >= MINIMUM_CHECK_COUNT, "All order checks must execute")
	for failure: String in failures: push_error(failure)
	print("WARBAND ORDERS TEST RESULT: %s (%d checks, %d failures)" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
