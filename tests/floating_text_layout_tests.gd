extends SceneTree
const Suite = preload("res://tests/suites/floating_combat_text_suite.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
var _failures: int = 0
func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	Suite.run(_expect)
	print("FLOATING TEXT LAYOUT TESTS: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)
func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
