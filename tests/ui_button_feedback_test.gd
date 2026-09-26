extends SceneTree
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
var failed: bool = false
func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	call_deferred("_run")
func _run() -> void:
	await preload("res://tests/suites/ui_button_feedback_suite.gd").run(self, _expect)
	print("TEST RESULT: %s Shared UI hover/focus audio" % ("FAIL" if failed else "PASS"))
	quit(1 if failed else 0)
func _expect(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
