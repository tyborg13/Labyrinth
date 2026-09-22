extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	await preload("res://tests/suites/contextual_cutout_suite.gd").run(self, _check)
	for failure: String in failures:
		push_error(failure)
	print("CONTEXTUAL CUTOUT TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
func _check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
