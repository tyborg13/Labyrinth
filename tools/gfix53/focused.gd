extends SceneTree
## Run the affected combat and authored-copy suites without the full suite.

const SUITES: Array[Script] = Array([
	preload("res://tests/suites/battlefield_rules_suite.gd"),
	preload("res://tests/suites/guardian_rules_suite.gd"),
	preload("res://tests/suites/last_light_suite.gd"),
	preload("res://tests/suites/player_movement_suite.gd"),
	preload("res://tests/suites/movement_undo_suite.gd"),
	preload("res://tests/suites/skill_combat_suite.gd"),
	preload("res://tests/suites/skill_tree_suite.gd"),
	preload("res://tests/suites/radiance_package_suite.gd"),
	preload("res://tests/suites/fix_03_suite.gd"),
], TYPE_OBJECT, "Script", null)

var _checks: int
var _failures: int

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	for suite: Script in SUITES:
		var first_check: int = _checks
		var first_failure: int = _failures
		suite.run(_expect)
		print("GFIX-53 %s: %d checks, %d failures" %
			[suite.resource_path.get_file(), _checks - first_check, _failures - first_failure])
	print("GFIX-53 FOCUSED: %d checks, %d failures" % [_checks, _failures])
	quit(int(_failures > 0))

func _expect(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error(message)
