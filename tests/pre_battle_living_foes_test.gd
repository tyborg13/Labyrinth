extends SceneTree

const Suite = preload("res://tests/suites/pre_battle_living_foes_suite.gd")
var failed: bool = false

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	preload("res://tests/suites/combat_objective_suite.gd").run(_expect)
	await Suite.run(_expect)
	print("PB-01 LIVING FOES TEST: %s (43 identities; exact objective copy; reduced-motion rest)" % ("FAIL" if failed else "PASS"))
	print("TEST RESULT: %s" % ("FAIL" if failed else "PASS"))
	quit(1 if failed else 0)

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failed = true
	push_error(message)
