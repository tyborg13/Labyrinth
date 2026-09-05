extends SceneTree
var failures: Array[String]
func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	preload("res://tests/suites/chain_attack_suite.gd").run(func(ok: bool, message: String) -> void:
		if not ok:
			failures.append(message)
	)
	for message: String in failures:
		push_error(message)
	print("CHAIN ATTACK TEST: %s" % ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
