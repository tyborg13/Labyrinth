extends SceneTree

const SUITES: Array = [
	preload("res://tests/suites/surface_relic_suite.gd"),
	preload("res://tests/suites/relic_suite.gd"),
	preload("res://tests/suites/relic_u2_suite.gd"),
	preload("res://tests/suites/black_sun_dial_suite.gd"),
	preload("res://tests/suites/card_keywords_w3_suite.gd"),
	preload("res://tests/suites/card_playability_summary_suite.gd"),
	preload("res://tests/suites/board_surface_suite.gd"),
]

var _checks: int
var _failures: int

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	for suite: GDScript in SUITES:
		var checks_before: int = _checks
		var failures_before: int = _failures
		suite.run(_expect)
		print("TXT43 %s: %d checks, %d failures" % [
			suite.resource_path.get_file(), _checks - checks_before, _failures - failures_before])
	print("TXT43 STORMCOAL FIXTURES: %d checks, %d failures" % [_checks, _failures])
	quit(int(_failures > 0))

func _expect(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error(message)
