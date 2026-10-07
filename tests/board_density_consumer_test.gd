extends SceneTree

const Suite = preload("res://tests/suites/board_density_consumer_suite.gd")
var _failures: Array[String]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	Suite.run(Callable(self, "_expect"))
	for failure: String in _failures:
		push_error(failure)
	print("BOARD DENSITY CONSUMERS: " + ("PASS" if _failures.is_empty() else "FAIL"))
	quit(0 if _failures.is_empty() else 1)

func _expect(ok: bool, message: String) -> void:
	if not ok:
		_failures.append(message)
