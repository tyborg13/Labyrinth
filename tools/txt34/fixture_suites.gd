extends SceneTree
## Run the remaining fixture consumers without booting the full Godot suite.

const SUITES: Array = [
	preload("res://tests/suites/relic_u1_suite.gd"),
	preload("res://tests/suites/inline_icon_description_suite.gd"),
]
var _checks: int
var _failures: int

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	for suite: Script in SUITES:
		var first: int = _checks
		var first_failure: int = _failures
		suite.run(_expect)
		print("TXT34 FIXTURES %s: %d checks, %d failures" %
			[suite.resource_path.get_file(), _checks - first, _failures - first_failure])
	quit(int(_failures != 0))

func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(message)
