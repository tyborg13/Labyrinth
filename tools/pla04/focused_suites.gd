extends SceneTree
## pla-04 focused proof: the existing suites that touch Burst, kegs, traps,
## Discharge, Shatter and the boss Bursts, without the full pass. Each failure
## prints as "FAIL <suite>: <message>". Run:
##   python3 tools/godot_task_runner.py --task-id pla-04 --stream -- \
##     godot --headless --path . --script res://tools/pla04/focused_suites.gd

const SUITES: Array = [
	"card_mechanics_surfaces", "illusion_terrain", "destruction_preview", "board_surface",
	"surface_core_review", "surface_relic", "card_pool_overhaul", "card_noop_legality",
	"dragon_boss", "boss_area_rules", "dragon_pressure_mechanics", "dragon_spire_routes", "enemy_surface_acceptance",
	"guardian", "en06_enemies", "fix_03", "relic_u3", "relic_u6", "relic_u8", "en01_enemies",
	"tooltip_consistency", "glossary_coverage", "inline_icon_description", "cbt_01",
	"ground_targeting", "element_retrofit", "maneuver", "dragon_element_rules",
	"dragon_area_presentation", "dragon_feedback1", "thr01", "black_sun_dial", "attack_sfx", "relic",
	"skill_combat", "reach_rebalance", "en04_enemies", "mim01",
	"destruction_preview_privacy", "relic_u7",
]
const TREE_SUITES: Array = ["card_targeting_audit", "combat_enemy_action_clock", "vyraketh_cutout"]

var _current: String = ""
var _failures: Array[String]
var _checks: int = 0

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	var only: String = OS.get_environment("PLA04_SUITES")
	for suite: String in SUITES + TREE_SUITES:
		if not only.is_empty() and not (only.split(",") as PackedStringArray).has(suite):
			continue
		_current = suite
		var script: GDScript = load("res://tests/suites/%s_suite.gd" % suite)
		var before: int = _failures.size()
		if TREE_SUITES.has(suite):
			await script.run(self, Callable(self, "_expect"))
		else:
			await script.run(Callable(self, "_expect"))
		print("SUITE %s: %d failures" % [suite, _failures.size() - before])
	for failure: String in _failures:
		print("FAIL " + failure)
	print("PLA04 FOCUSED: %d checks, %d failures" % [_checks, _failures.size()])
	print("TEST RESULT: %s" % ("PASS" if _failures.is_empty() else "FAIL"))
	quit(0 if _failures.is_empty() else 1)

func _expect(condition: bool, message: String = "") -> bool:
	_checks += 1
	if not condition:
		_failures.append("%s: %s" % [_current, message])
	return condition
