extends SceneTree
const Runtime = preload("res://scripts/parallel_runtime.gd")
var _errors: Array[String]

func _initialize() -> void:
	Runtime.apply_from_environment()
	await preload("res://tests/suites/strike_trail_suite.gd").run(self, _expect)
	for error: String in _errors:
		push_error(error)
	print("STRIKE TRAIL TEST RESULT: " + ("PASS" if _errors.is_empty() else "FAIL"))
	quit(0 if _errors.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	if not condition and not _errors.has(message):
		_errors.append(message)
