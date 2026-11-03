extends SceneTree
const Suite = preload("res://tests/suites/mim01_suite.gd")
var failures: Array[String]
var checks: int = 0
func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()
func _run() -> void:
	Suite.run(_expect)
	await Suite.run_live(self, _expect)
	for failure: String in failures: push_error(failure)
	print("MIM01 TEST RESULT: %s (%d checks, %d failures)" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
