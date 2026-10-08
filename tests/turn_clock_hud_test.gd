extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const Suite = preload("res://tests/suites/turn_clock_hud_suite.gd")
var _failures: Array[String]

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	await Suite.run(self, Callable(self, "_expect"))
	for failure: String in _failures:
		push_error(failure)
	print("TURN CLOCK HUD TEST RESULT: PASS" if _failures.is_empty() else "TURN CLOCK HUD TEST RESULT: FAIL (%d failures)" % _failures.size())
	quit(0 if _failures.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
