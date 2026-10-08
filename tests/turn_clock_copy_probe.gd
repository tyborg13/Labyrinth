extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const Suite = preload("res://tests/suites/turn_clock_copy_suite.gd")
const OUTPUT := "user://probes/turn_clock_copy/1920x1080"
var _failures: Array[String]

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	var capture_dir: String = ""
	if not OS.get_cmdline_user_args().has("--check-fit-only"):
		capture_dir = ProjectSettings.globalize_path(OUTPUT)
		DirAccess.make_dir_recursive_absolute(capture_dir)
	await Suite.run(self, Callable(self, "_expect"), capture_dir)
	for failure: String in _failures:
		push_error(failure)
	if not capture_dir.is_empty():
		print(capture_dir)
	print("TURN CLOCK COPY FIT RESULT: PASS" if _failures.is_empty() else "TURN CLOCK COPY FIT RESULT: FAIL (%d failures)" % _failures.size())
	quit(0 if _failures.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
