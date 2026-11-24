extends SceneTree

const SkillRunSuite = preload("res://tests/suites/skill_run_suite.gd")

var _checks: int
var _failures: int


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	SkillRunSuite.run(_expect)
	print("SKILL RUN RULES: %s (%d checks, %d failures)" % [
		"PASS" if _failures == 0 else "FAIL", _checks, _failures])
	quit(int(_failures > 0))


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(message)
