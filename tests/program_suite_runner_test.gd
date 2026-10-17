extends SceneTree

## Small orchestration fixture: injected children exercise the real handoff and
## final-result path without running or changing any gameplay assertions.
const Runner = preload("res://tools/program_suite_runner.gd")
var _failures: Array[String]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var options: Dictionary = {"suites": PackedStringArray()}
	for index: int in range(0, arguments.size(), 2):
		var key: String = arguments[index].trim_prefix("--")
		if key == "suite":
			options["suites"].append(arguments[index + 1])
		elif key == "timeout" or key == "budget":
			options[key] = float(arguments[index + 1])
		else:
			options[key] = arguments[index + 1]
	var started: int = Time.get_ticks_usec()
	var handle: Dictionary = Runner.start(options)
	print("MAIN BODY SENTINEL")
	await Runner.finish(self, handle, Callable(self, "_expect"), started)
	for failure: String in _failures:
		push_error(failure)
	print("TEST RESULT: PASS" if _failures.is_empty() else "TEST RESULT: FAIL (%d failure(s))" % _failures.size())
	quit(0 if _failures.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
