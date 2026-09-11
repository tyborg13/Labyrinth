extends SceneTree
var errors: Array[String]
func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	preload("res://tests/suites/actor_presentation_suite.gd").run(Callable(self, "_expect"))
	for error: String in errors: push_error(error)
	print("ACTOR PRESENTATION TEST: " + ("PASS" if errors.is_empty() else "FAIL"))
	quit(0 if errors.is_empty() else 1)
func _expect(condition: bool, message: String) -> void:
	if not condition: errors.append(message)
