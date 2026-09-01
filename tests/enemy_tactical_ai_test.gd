extends SceneTree

const EnemyTacticalAiSuite = preload("res://tests/suites/enemy_tactical_ai_suite.gd")

var _failures: Array[String]

func _initialize() -> void:
	EnemyTacticalAiSuite.run(Callable(self, "_expect"))
	if _failures.is_empty():
		print("ENEMY TACTICAL AI TEST RESULT: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("ENEMY TACTICAL AI TEST RESULT: FAIL (%d failures)" % _failures.size())
	quit(1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
