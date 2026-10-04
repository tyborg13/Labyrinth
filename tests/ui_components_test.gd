extends SceneTree

const ComponentsSuite = preload("res://tests/suites/ui_components_suite.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")

var _failures := PackedStringArray()

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	await ComponentsSuite.run(self, Callable(self, "_expect"))
	for failure: String in _failures:
		push_error(failure)
	print("TEST RESULT: PASS ui_components" if _failures.is_empty() else "TEST RESULT: FAIL ui_components")
	quit(0 if _failures.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
