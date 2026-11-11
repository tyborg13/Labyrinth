extends SceneTree
## Only the enemy-tooltip domain reported by the combined main-suite failure.
var failures: Array[String]
var checks: int = 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	preload("res://tests/suites/enemy_intent_continuity_suite.gd").run(check)
	for failure: String in failures: print("FAIL: ", failure)
	print("PTF01 ENEMY INTENT CONTINUITY: %s (%d checks, %d failures)" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
