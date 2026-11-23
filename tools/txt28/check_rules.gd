extends SceneTree
## Existing affected suites, independent of tests/run_tests.gd.
const Runtime = preload("res://scripts/parallel_runtime.gd")
const ForcedMovement = preload("res://tests/suites/forced_movement_suite.gd")
const Maneuver = preload("res://tests/suites/maneuver_suite.gd")
const BoardSurface = preload("res://tests/suites/board_surface_suite.gd")
const CardSurfaces = preload("res://tests/suites/card_mechanics_surfaces_suite.gd")

var _checks: int = 0
var _failures: Array[String]

func _initialize() -> void:
	Runtime.apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	for suite: Script in [ForcedMovement, Maneuver, BoardSurface, CardSurfaces]:
		var before: int = _checks
		var failures_before: int = _failures.size()
		suite.run(_expect)
		print("TXT28 SUITE %s: %d checks, %d failures" % [suite.resource_path.get_file(), _checks - before, _failures.size() - failures_before])
	for failure: String in _failures:
		push_error(failure)
	print("TXT28 RULES SUITES: %s (%d checks, %d failures)" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition: _failures.append(message)
