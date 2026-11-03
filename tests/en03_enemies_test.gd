extends SceneTree

const Suite = preload("res://tests/suites/en03_enemies_suite.gd")
var _failures: Array[String]
var _checks: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var selector: int = args.find("--thr01-case")
	if selector >= 0 and selector + 1 < args.size():
		var selected: String = args[selector + 1]
		if selected == "save": preload("res://tests/suites/thr01_suite.gd")._legacy_save(Callable(self, "_expect"))
		else: await preload("res://tests/suites/thr01_suite.gd").run_live(self, Callable(self, "_expect"), selected)
		_finish()
		return
	Suite.run(Callable(self, "_expect"))
	await preload("res://tests/helpers/fix_11_callout_clock_suite.gd").run(self, Callable(self, "_expect"))
	await Suite.run_live(self, Callable(self, "_expect"))
	await preload("res://tests/suites/thr01_suite.gd").run_live(self, Callable(self, "_expect"))
	_finish()

func _finish() -> void:
	for failure: String in _failures: push_error(failure)
	print("EN03 ENEMIES TEST RESULT: %s (%d checks, %d failures)" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition: _failures.append(message)
