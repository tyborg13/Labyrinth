extends SceneTree

const EnemyIntentPreviewSuite = preload("res://tests/suites/enemy_intent_preview_suite.gd")

var _failures: Array[String]

func _initialize() -> void:
	EnemyIntentPreviewSuite.run(Callable(self, "_expect"))
	if _failures.is_empty():
		print("ENEMY INTENT PREVIEW TEST RESULT: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	push_error("ENEMY INTENT PREVIEW TEST RESULT: FAIL (%d failure(s))" % _failures.size())
	quit(1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
