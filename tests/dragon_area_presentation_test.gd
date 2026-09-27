extends SceneTree

var failures: Array[String]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	preload("res://tests/suites/dragon_area_presentation_suite.gd").run(func(ok: bool, message: String) -> void:
		if not ok: failures.append(message); push_error(message)
	)
	print("DRAGON CANCELED AREA: ","PASS" if failures.is_empty() else "FAIL",failures)
	quit(0 if failures.is_empty() else 1)
