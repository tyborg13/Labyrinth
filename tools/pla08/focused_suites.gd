extends SceneTree
## Focused integration coverage for Light and Vision. Run through godot_task_runner.py.
const SUITES: Array = [
	"radiance_package", "skill_combat", "relic", "dragon_boss", "last_light",
	"board_status_plates", "board_status_cache", "glossary_coverage",
]

var _suite: String
var _checks: int = 0
var _failures: int = 0

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	for suite: String in SUITES:
		_suite = suite
		var before: int = _failures
		var script: GDScript = load("res://tests/suites/%s_suite.gd" % suite)
		await script.run(_expect)
		print("SUITE %s: %d failures" % [suite, _failures - before])
	print("PLA08 FOCUSED: %d checks, %d failures" % [_checks, _failures])
	print("TEST RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)

func _expect(condition: bool, message: String = "") -> bool:
	_checks += 1
	if not condition:
		_failures += 1
		print("FAIL %s: %s" % [_suite, message])
	return condition
