extends SceneTree

const Dragon = preload("res://tests/suites/dragon_feedback1_suite.gd")
const Enemies = preload("res://tests/suites/en02_enemies_suite.gd")
const Mechanics = preload("res://tests/suites/sta01_mechanics_suite.gd")

var _checks: int
var _failures: int

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	Dragon.run(_expect)
	Enemies.run(_expect)
	Mechanics.run(_expect)
	print("TXT43 STRING FIXTURES: %d checks, %d failures" % [_checks, _failures])
	quit(int(_failures > 0))

func _expect(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error(message)
