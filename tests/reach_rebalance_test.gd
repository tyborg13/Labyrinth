extends SceneTree
const Suite = preload("res://tests/suites/reach_rebalance_suite.gd")
var failures: Array[String]
func _initialize() -> void:
	Suite.run(func(ok: bool, message: String) -> void:
		if not ok: failures.append(message))
	for failure: String in failures: push_error(failure)
	print("REACH REBALANCE: %s" % ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
