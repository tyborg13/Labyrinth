extends SceneTree
const MoveAttackSuite = preload("res://tests/suites/move_attack_shortcut_suite.gd")
const InlineIconSuite = preload("res://tests/suites/inline_icon_description_suite.gd")
const EnemyIntentSuite = preload("res://tests/suites/enemy_intent_preview_suite.gd")
var _failures: Array[String]
func _initialize() -> void:
	MoveAttackSuite.run(Callable(self, "_expect"))
	InlineIconSuite.run(Callable(self, "_expect"))
	EnemyIntentSuite.run(Callable(self, "_expect"))
	for failure: String in _failures:
		push_error(failure)
	print("BOARD SURFACE CONTENT REGRESSION: %s" % ("PASS" if _failures.is_empty() else "FAIL"))
	quit(0 if _failures.is_empty() else 1)
func _expect(ok: bool, message: String) -> void:
	if not ok:
		_failures.append(message)
