extends SceneTree
var failures: Array[String]
func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
func _run() -> void:
	preload("res://tests/suites/grimoire_search_suite.gd").run(check)
	preload("res://tests/suites/inline_icon_description_suite.gd").run(check)
	for failure: String in failures: push_error(failure)
	print("PTF06 affected search and inline suites: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)
