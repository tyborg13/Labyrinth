extends SceneTree
const Suite = preload("res://tests/suites/depth_rules_suite.gd")
var failures: Array[String]
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var expect: Callable = func(ok: bool, message: String) -> void:
		if not ok and not failures.has(message): failures.append(message)
	var guardian_only: bool = OS.get_cmdline_user_args().has("--guardian")
	if guardian_only:
		preload("res://tests/suites/guardian_suite.gd").run(expect)
	else:
		await Suite.run(expect)
	for failure: String in failures: push_error(failure)
	print("%s suite: %d failures" % ["Guardian" if guardian_only else "Depth rules", failures.size()])
	quit(0 if failures.is_empty() else 1)
