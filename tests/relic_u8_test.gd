extends SceneTree
const Suite = preload("res://tests/suites/relic_u8_suite.gd")
var failures: Array[String]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("run")

func run() -> void:
	Suite.run(Callable(self, "expect"))
	for failure: String in failures:
		push_error(failure)
	print("RELIC U8 TEST RESULT: PASS" if failures.is_empty() else "RELIC U8 TEST RESULT: FAIL (%d failures)" % failures.size())
	quit(0 if failures.is_empty() else 1)

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
