extends SceneTree

const AudioRoutingSuite = preload("res://tests/suites/audio_routing_suite.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")

var _failures: Array[String] = []

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	AudioRoutingSuite.run(Callable(self, "_expect"))
	if _failures.is_empty():
		print("AUDIO ROUTING TEST: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("AUDIO ROUTING TEST: FAIL (%d failures)" % _failures.size())
	quit(1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
