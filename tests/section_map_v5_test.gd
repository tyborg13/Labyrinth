extends SceneTree
const Suite = preload("res://tests/suites/section_map_v5_suite.gd")
var failures: Array[String] = []
func _initialize() -> void:
	var expect: Callable = func(ok: bool, message: String) -> void:
		if not ok and not failures.has(message): failures.append(message)
	if OS.get_cmdline_user_args().has("--regressions-only"):
		Suite.Regression.run(expect)
	elif OS.get_cmdline_user_args().has("--save-only"):
		Suite._test_saved_revision4(expect)
	elif OS.get_cmdline_user_args().has("--knowledge-only"):
		Suite.Legacy._test_knowledge(expect, 5)
	else:
		Suite.run(expect)
	for failure: String in failures: push_error(failure)
	print("Section map v5 suite: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)
