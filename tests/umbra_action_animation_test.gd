extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const UmbraActionAnimationSuite = preload("res://tests/suites/umbra_action_animation_suite.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	UmbraActionAnimationSuite.run(Callable(self, "_expect"))
	if _failures.is_empty():
		print("UMBRA ACTION ANIMATION TEST: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("UMBRA ACTION ANIMATION TEST: FAIL (%d)" % _failures.size())
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
