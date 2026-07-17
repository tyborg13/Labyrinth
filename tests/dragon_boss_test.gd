extends SceneTree

const DragonBossSuite = preload("res://tests/suites/dragon_boss_suite.gd")

var _failures: Array[String] = []

func _initialize() -> void:
	DragonBossSuite.run(Callable(self, "_expect"))
	if _failures.is_empty():
		print("Dragon boss suite passed.")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
