extends SceneTree

const Suite = preload("res://tests/suites/section_map_performance_suite.gd")
var failures: Array[String]

func _initialize() -> void:
	var expect: Callable = func(ok: bool, message: String) -> void:
		if not ok and not failures.has(message): failures.append(message)
	if OS.get_cmdline_user_args().has("--logic-only"):
		Suite._test_forward_checks(expect)
		Suite._test_memo_and_cutoff(expect)
	else:
		Suite.run(expect)
	for failure: String in failures: push_error(failure)
	print("Section map performance suite: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)
