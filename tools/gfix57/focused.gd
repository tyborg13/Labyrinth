extends SceneTree

# Run the existing focused checks that have no standalone headless entry point.
const Tooltips = preload("res://tests/suites/tooltip_consistency_suite.gd")
const Map = preload("res://tests/suites/section_map_suite.gd")
const Event = preload("res://tests/suites/event_rules_suite.gd")
const Run = preload("res://scripts/run_engine.gd")

var _checks: int
var _failures: int

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	_run_checks("tooltip_consistency", Tooltips.run)
	_run_checks("section_map", Map.run)
	_run_checks("omen_rules", func(expect: Callable) -> void: Event._omens(Run.new(), expect))
	print("GFIX57 FOCUSED: %d checks, %d failures" % [_checks, _failures])
	quit(int(_failures > 0))

func _run_checks(domain: String, suite: Callable) -> void:
	var first_check: int = _checks
	var first_failure: int = _failures
	suite.call(_expect)
	print("GFIX57 FOCUSED %s: %d checks, %d failures" % [domain, _checks - first_check, _failures - first_failure])

func _expect(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error(message)
