extends SceneTree
const Suite = preload("res://tests/suites/section_map_v7_suite.gd")
var failures: Array[String]
func _initialize() -> void:
	await Suite.run(func(ok: bool, message: String) -> void:
		if not ok and not failures.has(message): failures.append(message)
	)
	for failure: String in failures: push_error(failure)
	print("Section map revision 7 suite: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)
