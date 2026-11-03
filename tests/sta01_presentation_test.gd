extends SceneTree
const Clocks = preload("res://tests/suites/combat_enemy_action_clock_suite.gd")
var failures: Array[String]
var checks: int = 0
func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()
func _run() -> void:
	await Clocks.veil_blinks(self, _expect)
	await Clocks.unaligned_dive(self, _expect)
	for failure: String in failures: push_error(failure)
	print("STA01 PRESENTATION: %s (%d checks; %d failures; headless clocks only)" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
