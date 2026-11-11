extends SceneTree
var failures: Array[String]
var checks: int = 0
func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	preload("res://tests/suites/enemy_intent_continuity_suite.gd").run(_expect)
	for failure: String in failures: push_error(failure)
	print("PTF06 enemy intent continuity: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
