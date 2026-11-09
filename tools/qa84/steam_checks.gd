extends SceneTree

var _failures: Array[String]
var _assertions: int = 0

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	preload("res://tests/suites/steam_service_suite.gd").run(_check)
	print("QA84 STEAM SERVICE TEST RESULT: %s (%d assertions; %d failures)" % ["PASS" if _failures.is_empty() else "FAIL", _assertions, _failures.size()])
	for failure: String in _failures: push_error(failure)
	quit(0 if _failures.is_empty() else 1)

func _check(ok: bool, message: String) -> void:
	_assertions += 1
	if not ok: _failures.append(message)
