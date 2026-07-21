extends SceneTree

const SkillTreeSuite = preload("res://tests/suites/skill_tree_suite.gd")

var _failures: Array[String]

func _initialize() -> void:
	SkillTreeSuite.run(Callable(self, "_expect"))
	if _failures.is_empty():
		print("SKILL TREE TEST RESULT: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("SKILL TREE TEST RESULT: FAIL (%d failure(s))" % _failures.size())
	quit(1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
