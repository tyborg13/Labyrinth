extends SceneTree
## Runs the affected rules suites independently of the full Godot suite.
const Runtime = preload("res://scripts/parallel_runtime.gd")
const Options = preload("res://tools/encounter_sweep.gd")

var failures: Array[String]
var checks: int = 0

func _initialize() -> void:
	Runtime.apply_from_environment()
	var suite: String = Options.option(OS.get_cmdline_user_args(), "--suite", "")
	_run.call_deferred(suite)

func _run(suite: String) -> void:
	match suite:
		"battlefield":
			preload("res://tests/suites/battlefield_rules_suite.gd").run(_expect)
			preload("res://tests/suites/battlefield_fuel_suite.gd").run(_expect)
			preload("res://tests/suites/battlefield_conduction_suite.gd").run(_expect)
		"events":
			preload("res://tests/suites/event_rules_suite.gd").run(_expect)
		_:
			_expect(false, "Unknown focused suite: " + suite)
	for failure: String in failures: push_error(failure)
	print("QA91_FOCUSED %s: %s (%d checks, %d failures)" % [suite, "PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
