extends SceneTree

var _checks: int = 0
var _failures: Array[String]

func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition: _failures.append(message)

func _finish(label: String) -> void:
	for failure: String in _failures: push_error(failure)
	print("%s: %s (%d checks, %d failures)" % [label, "PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)
