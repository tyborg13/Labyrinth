extends SceneTree
const Suite = preload("res://tests/suites/enemy_surface_acceptance_suite.gd")
var failures: Array[String]
func _initialize() -> void:
	Suite.run(func(condition: bool, message: String) -> void:
		if not condition:
			failures.append(message)
	)
	for message: String in failures:
		push_error(message)
	print("ENEMY SURFACE ACCEPTANCE: ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)
