extends SceneTree

const Suite = preload("res://tests/suites/destruction_preview_suite.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
var failures: Array[String]

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	Suite.run(func(condition: bool, message: String) -> void:
		if not condition: failures.append(message)
	)
	for failure: String in failures: push_error(failure)
	print("DESTRUCTION PREVIEW TEST RESULT: %s (%d failures)" % ["PASS" if failures.is_empty() else "FAIL", failures.size()])
	quit(0 if failures.is_empty() else 1)
