extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const PlayerMovementSuite = preload("res://tests/suites/player_movement_suite.gd")

var _failures: Array[String] = []

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	PlayerMovementSuite.run(Callable(self, "_expect"))
	if _failures.is_empty():
		print("PLAYER MOVEMENT TESTS PASSED")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
