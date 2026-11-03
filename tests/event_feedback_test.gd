extends SceneTree
const Suite = preload("res://tests/suites/event_feedback_suite.gd")
var failures: Array[String]
func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()
func _run() -> void:
	await Suite.run(func(ok: bool, message: String) -> void:
		if not ok and not failures.has(message): failures.append(message))
	for failure: String in failures: push_error(failure)
	print("Event feedback suite: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)
