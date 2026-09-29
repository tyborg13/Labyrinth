extends SceneTree
var failures: Array[String]
func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()
func _run() -> void:
	await preload("res://tests/suites/card_targeting_audit_suite.gd").run(self,_expect)
	print("CARD TARGETING AUDIT TEST: ","PASS" if failures.is_empty() else "FAIL", " ",failures)
	quit(0 if failures.is_empty() else 1)
func _expect(ok: bool,message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
