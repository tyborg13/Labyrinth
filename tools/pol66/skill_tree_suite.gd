extends SceneTree

const Suite = preload("res://tests/suites/skill_tree_suite.gd")
const Runtime = preload("res://scripts/parallel_runtime.gd")

var _checks: int
var _failures: int

func _initialize() -> void:
	Runtime.apply_from_environment()
	Suite.run(_expect)
	print("SKILL TREE SUITE: %s (%d checks, %d failures)" % ["PASS" if _failures == 0 else "FAIL", _checks, _failures])
	quit(int(_failures > 0))

func _expect(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		printerr(message)
