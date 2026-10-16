extends SceneTree
var failures: int = 0
func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()
func _run() -> void:
	await preload("res://tests/suites/contextual_cutout_suite.gd").run(self, _expect)
	await preload("res://tests/suites/enemy_strike_trail_suite.gd").run(self, _expect)
	await preload("res://tests/suites/pre_battle_ui_suite.gd").run(_expect)
	print("MAQUETTE INTEGRATION: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(0 if failures == 0 else 1)
func _expect(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
