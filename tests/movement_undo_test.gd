extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const Suite = preload("res://tests/suites/movement_undo_suite.gd")
var failures: Array[String]

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	Suite.run(Callable(self, "_expect"))
	await Suite.run_live(self, Callable(self, "_expect"))
	for failure: String in failures: push_error(failure)
	print("MOVEMENT UNDO RESULT: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
