extends SceneTree
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
var _failures: Array[String] = []
func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	await preload("res://tests/suites/protagonist_cutout_suite.gd").run(self, _assert)
	for failure: String in _failures:
		push_error(failure)
	print("PROTAGONIST CUTOUT TEST RESULT: " + ("PASS" if _failures.is_empty() else "FAIL"))
	quit(0 if _failures.is_empty() else 1)
func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
