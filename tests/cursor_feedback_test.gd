extends SceneTree

const CursorFeedbackSuite = preload("res://tests/suites/cursor_feedback_suite.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")

var _failures: Array[String] = []

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	CursorFeedbackSuite.run(Callable(self, "_expect"))
	if _failures.is_empty():
		print("CURSOR FEEDBACK TEST: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("CURSOR FEEDBACK TEST: FAIL (%d failures)" % _failures.size())
	quit(1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
