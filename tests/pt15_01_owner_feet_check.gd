extends SceneTree
const Suite = preload("res://tests/suites/pt15_01_owner_feet_suite.gd")
var failures: Array[String]
var assertions: int = 0
func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	# Classic board HUD contracts (see tests/helpers/legacy_board_hud.gd).
	preload("res://tests/helpers/legacy_board_hud.gd").pin_always()
	call_deferred("_run")
func _run() -> void:
	Suite.run(_expect)
	for failure: String in failures: push_error(failure)
	print("PT15 OWNER FEET RESULT: %s (%d assertions; %d failures)" % ["PASS" if failures.is_empty() else "FAIL", assertions, failures.size()])
	quit(0 if failures.is_empty() else 1)
func _expect(value: bool, message: String) -> void:
	assertions += 1
	if not value: failures.append(message)
