extends SceneTree
var checks: int = 0
var failures: Array[String]
func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	preload("res://tests/suites/boss_area_rules_suite.gd").run(expect)
	preload("res://tests/suites/en04_enemies_suite.gd").run(expect)
	preload("res://tests/suites/enemy_intent_continuity_suite.gd").run_thornwall(expect)
	preload("res://tests/suites/element_retrofit_suite.gd").run(expect)
	for failure: String in failures: print("FAIL: "+failure)
	print("AREA01 RULES RESULT: %s (%d checks, %d failures)" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
