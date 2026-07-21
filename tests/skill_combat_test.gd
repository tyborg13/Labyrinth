extends SceneTree

const SkillCombatSuite = preload("res://tests/suites/skill_combat_suite.gd")

var _failures: Array[String]

func _initialize() -> void:
	SkillCombatSuite.run(Callable(self, "_expect"))
	if _failures.is_empty():
		print("SKILL COMBAT TEST RESULT: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("SKILL COMBAT TEST RESULT: FAIL (%d failure(s))" % _failures.size())
	quit(1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
