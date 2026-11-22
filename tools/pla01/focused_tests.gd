extends "res://tests/run_tests.gd"

# pla-01 focused runner: executes only the named suites (user args after --),
# each through its static run(expect). Example:
#   godot --headless --path . -s tools/pla01/focused_tests.gd -- res://tests/suites/forced_movement_suite.gd
func _initialize() -> void:
	_initialize_test_storage()
	for path: String in OS.get_cmdline_user_args():
		if not path.begins_with("res://"): continue
		var suite: GDScript = load(path)
		if suite == null:
			_assert(false, "Could not load " + path)
			continue
		await suite.run(Callable(self, "_assert"))
		print("PLA01 SUITE DONE: %s (%d assertions so far, %d failures)" % [path, _assertion_count, _failures.size()])
	for message: String in _failures:
		print("FAIL: " + message)
	print("PLA01 FOCUSED RESULT: %s (%d assertions, %d failures)" % ["PASS" if _failures.is_empty() else "FAIL", _assertion_count, _failures.size()])
	quit(0 if _failures.is_empty() else 1)
