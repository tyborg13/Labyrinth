extends SceneTree
const Suite = preload("res://tests/suites/board_surface_suite.gd")
var failures: Array[String]
func _initialize() -> void:
	Suite.run(Callable(self,"_expect"))
	for failure: String in failures:
		push_error(failure)
	print("BOARD SURFACE CORE: ", "PASS" if failures.is_empty() else "FAIL", " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
func _expect(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
