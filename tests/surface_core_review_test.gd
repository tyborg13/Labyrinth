extends SceneTree
const Suite = preload("res://tests/suites/surface_core_review_suite.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
var failures: Array[String]

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	Suite.run(_check)
	print("Surface core independent review: %s" % ("PASS" if failures.is_empty() else "%d failures" % failures.size()))
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)
