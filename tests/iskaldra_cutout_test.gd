extends SceneTree

var failures: Array[String]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	await preload("res://tests/suites/iskaldra_cutout_suite.gd").run(self,Callable(self,"_expect"))
	for failure: String in failures:
		push_error(failure)
	print("ISKALDRA CUTOUT TEST RESULT: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
