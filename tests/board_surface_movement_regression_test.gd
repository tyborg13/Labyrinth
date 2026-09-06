extends SceneTree
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const Suite = preload("res://tests/suites/move_attack_shortcut_suite.gd")
var failures: Array[String]
func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	Suite.run(Callable(self, "_expect"))
	for failure: String in failures:
		push_error(failure)
	print("SURFACE MOVEMENT REGRESSION: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)
func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
