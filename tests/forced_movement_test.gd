extends SceneTree

const ForcedMovementSuite = preload("res://tests/suites/forced_movement_suite.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")

var _failures: Array[String] = []

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	ForcedMovementSuite.run(Callable(self, "_expect"))
	await ForcedMovementSuite.run_live(self, Callable(self, "_expect"))
	if _failures.is_empty():
		print("FORCED MOVEMENT TEST RESULT: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("FORCED MOVEMENT TEST RESULT: FAIL (%d failures)" % _failures.size())
	quit(1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
