extends SceneTree

# Invoke existing focused suites without adding permanent suite guards.
var failures: Array[String]
var checks: int = 0

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	await preload("res://tests/suites/vyraketh_cutout_suite.gd").run(self, _expect)
	preload("res://tests/suites/dragon_area_presentation_suite.gd").run(_expect)
	for failure: String in failures: push_error(failure)
	print("ROAR EXISTING FOCUSED SUITES: %s (%d checks)" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
