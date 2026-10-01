extends SceneTree
const Suite = preload("res://tests/suites/card_pool_overhaul_suite.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
var failures: Array[String]
func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	_run.call_deferred()
func _run() -> void:
	var expect := func(ok: bool, message: String) -> void:
		if not ok: failures.append(message)
	Suite.run(expect)
	await Suite.run_live(self, expect)
	for failure: String in failures: push_error(failure)
	print("CARD POOL OVERHAUL: %s" % ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
