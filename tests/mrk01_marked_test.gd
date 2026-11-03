extends SceneTree
const Suite = preload("res://tests/suites/mrk01_marked_suite.gd")
var checks: int = 0
var failures: Array[String]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var mutation: String = ""
	if OS.get_cmdline_user_args().has("--early-hit-mutation"): mutation = "early"
	if OS.get_cmdline_user_args().has("--shape-mutation"): mutation = "shape"
	Suite.run(_expect, mutation)
	for failure: String in failures: push_error(failure)
	print("MRK01 MARKED TEST: %s (%d checks, %d failures)" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
