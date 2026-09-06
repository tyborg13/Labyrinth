extends SceneTree
const Suite = preload("res://tests/suites/surface_relic_suite.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
var failures: Array[String]
func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	Suite.run(check)
	for failure: String in failures:
		push_error(failure)
	print("Surface relic checks: %s" % ("PASS" if failures.is_empty() else "%d failures" % failures.size()))
	quit(0 if failures.is_empty() else 1)
func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
