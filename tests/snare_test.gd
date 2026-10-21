extends SceneTree
const Suite = preload("res://tests/suites/snare_suite.gd")
var failures: Array[String]
func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	if OS.get_cmdline_user_args().has("--feedback-2-only"):
		preload("res://tests/suites/snare_regression_suite.gd").run(_expect)
	else:
		Suite.run(_expect)
	for failure: String in failures: push_error(failure)
	print("Snare suite: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)
func _expect(ok: bool, message: String) -> void:
	if not ok and not failures.has(message): failures.append(message)
