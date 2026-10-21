extends SceneTree
const Suite = preload("res://tests/suites/warband_suite.gd")
var failures: Array[String]
func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	Suite.run(_expect)
	for failure: String in failures: push_error(failure)
	print("Warband suite: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)
func _expect(ok: bool, message: String) -> void:
	if not ok and not failures.has(message): failures.append(message)
