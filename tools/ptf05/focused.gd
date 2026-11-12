extends SceneTree
## Focused invocation; production suite assertions remain unchanged.
var failures: Array[String]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	var mode: String = OS.get_cmdline_user_args()[0]
	var expect := Callable(self, "_check")
	if mode == "shortcut":
		var suite = preload("res://tests/suites/move_attack_shortcut_suite.gd")
		suite.run(expect)
		await suite.run_live(self, expect)
	elif mode == "audit":
		await preload("res://tests/suites/card_targeting_audit_suite.gd").run(self, expect)
	else:
		_check(false, "Unknown focused mode: " + mode)
	print("PTF05 FOCUSED %s: %s (%d failures)" % [mode, "PASS" if failures.is_empty() else "FAIL", failures.size()])
	quit(0 if failures.is_empty() else 1)

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
