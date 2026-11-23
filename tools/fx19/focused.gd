extends SceneTree
## Run Blink-adjacent suite entry points without invoking the full suite.

const Runtime = preload("res://scripts/parallel_runtime.gd")
const BoardLayout = preload("res://tests/suites/combat_board_layout_suite.gd")
const BoardRules = preload("res://tests/suites/battlefield_rules_suite.gd")
const Cbt = preload("res://tests/suites/cbt_01_suite.gd")
const Skills = preload("res://tests/suites/skill_combat_suite.gd")
const Relics = preload("res://tests/suites/relic_u7_suite.gd")
const Enemies = preload("res://tests/suites/en03_enemies_suite.gd")
const Movement = preload("res://tests/suites/player_movement_suite.gd")

var _checks: int
var _failures: int

func _initialize() -> void:
	Runtime.apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	for suite: Script in [BoardLayout, BoardRules, Cbt, Skills, Relics, Enemies, Movement]:
		suite.run(_expect)
	await Cbt.run_live(self, _expect)
	await Enemies.run_live(self, _expect)
	print("FX-19 FOCUSED %s (%d checks, %d failures)" % ["PASS" if _failures == 0 else "FAIL", _checks, _failures])
	quit(0 if _failures == 0 else 1)

func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition: return
	_failures += 1
	printerr("FAIL: " + message)
