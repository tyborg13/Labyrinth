extends SceneTree

const SUITES := {
	"relics": preload("res://tests/suites/relic_suite.gd"),
	"relic_eligibility": preload("res://tests/suites/relic_u1_suite.gd"),
	"relic_force": preload("res://tests/suites/relic_u3_suite.gd"),
	"relic_time": preload("res://tests/suites/relic_u4_suite.gd"),
	"relic_defense": preload("res://tests/suites/relic_u5_suite.gd"),
	"relic_illusion": preload("res://tests/suites/relic_u6_suite.gd"),
	"relic_light": preload("res://tests/suites/relic_u7_suite.gd"),
	"illumination": preload("res://tests/suites/last_light_suite.gd"),
	"illusions": preload("res://tests/suites/illusion_terrain_suite.gd"),
	"force_collision": preload("res://tests/suites/forced_movement_suite.gd"),
	"movement": preload("res://tests/suites/player_movement_suite.gd"),
	"maneuvers": preload("res://tests/suites/maneuver_suite.gd"),
	"retaliate_and_quicken": preload("res://tests/suites/card_keywords_w3_suite.gd"),
	"card_costs_and_stagger": preload("res://tests/suites/card_keywords_suite.gd"),
	"card_surface_selectors": preload("res://tests/suites/card_mechanics_surfaces_suite.gd"),
	"destruction_forecast": preload("res://tests/suites/destruction_preview_privacy_suite.gd"),
}

var _checks := 0
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var selected: PackedStringArray = OS.get_cmdline_user_args()
	for name: String in SUITES:
		if not selected.is_empty() and not selected.has(name):
			continue
		var checked_before: int = _checks
		var failed_before: int = _failures
		var suite: GDScript = SUITES[name]
		suite.run(_expect)
		print("TXT26 focused %s: %d checks, %d failures" % [name, _checks - checked_before, _failures - failed_before])
	print("TXT26 focused suites %s: %d checks, %d failures" % ["PASS" if _failures == 0 else "FAIL", _checks, _failures])
	quit(int(_failures > 0))


func _expect(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error(message)
