extends SceneTree

const SUITES: Dictionary = {
	"traps": preload("res://tests/suites/board_surface_suite.gd"),
	"combat skills": preload("res://tests/suites/skill_combat_suite.gd"),
	"run skills and rewards": preload("res://tests/suites/skill_run_suite.gd"),
	"events and rewards": preload("res://tests/suites/event_rules_suite.gd"),
	"event UI": preload("res://tests/suites/event_view_suite.gd"),
	"event previews": preload("res://tests/suites/event_feedback_suite.gd"),
	"enemy intent previews": preload("res://tests/suites/enemy_intent_preview_suite.gd"),
	"enemy intent continuity": preload("res://tests/suites/enemy_intent_continuity_suite.gd"),
	"enemy Burst": preload("res://tests/suites/en01_enemies_suite.gd"),
	"Icefall": preload("res://tests/suites/en02_enemies_suite.gd"),
	"Capacitor": preload("res://tests/suites/en06_enemies_suite.gd"),
	"Marked": preload("res://tests/suites/mrk01_marked_suite.gd"),
	"guardians": preload("res://tests/suites/guardian_suite.gd"),
	"Last Light": preload("res://tests/suites/last_light_suite.gd"),
	"battlefield rules": preload("res://tests/suites/battlefield_rules_suite.gd"),
}
var checks: int
var failures: int

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for suite_name: String in SUITES:
		if not args.is_empty() and not args.has(suite_name): continue
		var previous_checks: int = checks
		var previous_failures: int = failures
		await SUITES[suite_name].run(_check.bind(suite_name))
		print("TXT27 SUITE %s: %d checks, %d failures" % [suite_name, checks - previous_checks, failures - previous_failures])
	print("TXT27 FOCUSED SUITES: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _check(condition: bool, message: String, suite_name: String) -> void:
	checks += 1
	if condition: return
	failures += 1
	print("FAIL [%s] %s" % [suite_name, message])
