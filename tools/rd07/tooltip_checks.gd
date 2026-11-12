extends SceneTree
var checks: int = 0
var failures: Array[String]
func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")
func _run() -> void:
	preload("res://tests/suites/tooltip_consistency_suite.gd").run(_check)
	for failure: String in failures: push_error(failure)
	print("RD07 TOOLTIP CONSISTENCY: %s (%d checks, %d failures)" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
