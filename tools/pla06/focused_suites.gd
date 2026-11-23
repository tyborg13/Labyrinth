extends SceneTree
## pla-06 focused proof: the existing suites that touch Ice, Freeze, Chilled,
## Petrify, Frost Armor, Frostbite or the Ice relics, without the full pass.
## Each failure prints as "FAIL <suite>: <message>". PLA06_SUITES=a,b limits
## the run. Run:
##   python3 tools/godot_task_runner.py --task-id pla-06 --stream -- \
##     godot --headless --path . --script res://tools/pla06/focused_suites.gd

const SUITES: Array = [
	"battlefield_fuel", "battlefield_rules", "board_surface",
	"card_noop_legality", "dragon_boss", "boss_area_rules", "en04_enemies", "en05_enemies", "relic", "surface_relic",
]

var _current: String = ""
var _failures: Array[String]
var _checks: int = 0

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	var only: String = OS.get_environment("PLA06_SUITES")
	for suite: String in SUITES:
		if not only.is_empty() and not (only.split(",") as PackedStringArray).has(suite):
			continue
		_current = suite
		var script: GDScript = load("res://tests/suites/%s_suite.gd" % suite)
		var before: int = _failures.size()
		await script.run(Callable(self, "_expect"))
		print("SUITE %s: %d failures" % [suite, _failures.size() - before])
	print("PLA06 FOCUSED: %d checks, %d failures" % [_checks, _failures.size()])
	print("TEST RESULT: %s" % ("PASS" if _failures.is_empty() else "FAIL"))
	quit(0 if _failures.is_empty() else 1)

func _expect(condition: bool, message: String = "") -> bool:
	_checks += 1
	if not condition:
		_failures.append("%s: %s" % [_current, message])
		print("FAIL " + _failures.back())
	return condition
