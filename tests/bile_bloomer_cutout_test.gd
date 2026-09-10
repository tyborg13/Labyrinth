extends SceneTree

var _errors: Array[String]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	await preload("res://tests/suites/bile_bloomer_cutout_suite.gd").run(self, _assert)
	for error: String in _errors:
		push_error(error)
	print("BILE BLOOMER CUTOUT TEST RESULT: " + ("PASS" if _errors.is_empty() else "FAIL"))
	quit(0 if _errors.is_empty() else 1)

func _assert(value: bool, message: String) -> void:
	if not value and not _errors.has(message):
		_errors.append(message)
