extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const Suite = preload("res://tests/suites/sfx_bank_suite.gd")
var failures: Array[String] = []

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	Suite.run(_expect)
	await preload("res://tests/suites/run_sfx_suite.gd").run(self, _expect)
	for failure: String in failures: push_error(failure)
	print("SFX BANK TEST RESULT: %s (%d failures)" % ["PASS" if failures.is_empty() else "FAIL", failures.size()])
	quit(0 if failures.is_empty() else 1)

func _expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
