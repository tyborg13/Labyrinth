extends SceneTree
## Only the existing dragon/Guardian suites, plus the affected surface rules.
var checks: int = 0
var failures: Array[String]
func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()
func _run() -> void:
	preload("res://tests/suites/dragon_boss_suite.gd").run(expect)
	preload("res://tests/suites/dragon_element_rules_suite.gd").run(expect)
	preload("res://tests/suites/dragon_spire_routes_suite.gd").run(expect)
	preload("res://tests/suites/dragon_pressure_mechanics_suite.gd").run(expect)
	preload("res://tests/suites/dragon_feedback1_suite.gd").run(expect)
	preload("res://tests/suites/dragon_area_presentation_suite.gd").run(expect)
	await preload("res://tests/suites/dragon_exchange_presentation_suite.gd").run_live(self, expect)
	preload("res://tests/suites/guardian_suite.gd").run(expect)
	preload("res://tests/suites/guardian_rules_suite.gd").run(expect)
	preload("res://tests/suites/guardian_tuning_suite.gd").run(expect)
	preload("res://tests/suites/enemy_surface_acceptance_suite.gd").run(expect)
	for failure: String in failures: print("FAIL: "+failure)
	print("AREA01 EXISTING SUITES RESULT: %s (%d checks, %d failures)" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
