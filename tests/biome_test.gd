extends SceneTree

const Suite = preload("res://tests/suites/biome_suite.gd")
var _failures: Array[String]
var _checks: int = 0

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	Suite.run(Callable(self, "_expect"))
	Suite.run_live(self, Callable(self, "_expect"))
	await process_frame
	for failure: String in _failures:
		push_error(failure)
	print("BIOME RESULT: %s (%d checks, %d failures)" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)

func _expect(ok: bool, message: String) -> void:
	_checks += 1
	if not ok: _failures.append(message)
