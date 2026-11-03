extends "res://tests/fix_14_test.gd"

const Matrix = preload("res://tests/suites/fix_14_owner_matrix.gd")

func _run() -> void:
	if OS.get_cmdline_user_args().has("--state-only"): Matrix.StateInvariant.run(_expect, Matrix.state_cases())
	else: Matrix.run(_expect)
	if not OS.get_cmdline_user_args().has("--check-only"): await _test_playback()
	for failure: String in _failures: push_error(failure)
	print("FIX-14 MATRIX TEST RESULT: %s (%d checks, %d failures)" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)

func _cascade_playback(scene: Control) -> void:
	var cases: Array[Dictionary] = Matrix.state_cases()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--actor="):
			var type: String = "hollow_mimic" if arg.trim_prefix("--actor=") == "mimic" else "arc_thrall"
			cases = cases.filter(func(case: Dictionary) -> bool: return case["state"]["enemies"][0]["type"] == type)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--case="):
			var names: PackedStringArray = arg.trim_prefix("--case=").split(",")
			cases = cases.filter(func(case: Dictionary) -> bool: return names.has(case["name"]))
	_expect(not cases.is_empty(), "Matrix playback selection contains a real case")
	if cases.is_empty(): return
	await Cascades.run_playback(self, scene, _expect, Callable(), false, cases)
