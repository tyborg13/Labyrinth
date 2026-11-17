extends SceneTree
## Invokes existing affected suites without loading the full test program.
var failures: Array[String]
var checks: int = 0
func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok and not failures.has(message): failures.append(message)
func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var selected: String = preload("res://tools/encounter_sweep.gd").option(OS.get_cmdline_user_args(), "--suite", "")
	match selected:
		"enemy-count": preload("res://tests/suites/encounter_tables_suite.gd").run(_expect)
		"guardian": preload("res://tests/suites/guardian_suite.gd").run(_expect)
		"dragon": preload("res://tests/suites/dragon_boss_suite.gd").run(_expect)
		_: _expect(false, "Unknown focused suite: " + selected)
	for failure: String in failures: push_error(failure)
	print("TUNE01_FOCUSED %s: %s (%d checks, %d failures)" % [selected, "PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
