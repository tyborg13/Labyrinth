extends SceneTree

var checks: int = 0
var failures: Array[String]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _run() -> void:
	preload("res://tests/suites/en04_enemies_suite.gd").run(check)
	preload("res://tests/suites/contextual_cutout_suite.gd")._check_routing(check)
	for failure: String in failures: push_error(failure)
	print("RR22 AFFECTED SUITES: %s (%d checks)" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)
