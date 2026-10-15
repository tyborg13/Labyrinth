extends SceneTree

const Suite = preload("res://tests/suites/fix_03_suite.gd")
var _failures: Array[String]

func _initialize() -> void:
	Suite.run(_expect)
	for failure: String in _failures:
		push_error(failure)
	print("FIX-03 TEST RESULT: %s (%d failures)" % ["PASS" if _failures.is_empty() else "FAIL", _failures.size()])
	quit(0 if _failures.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
