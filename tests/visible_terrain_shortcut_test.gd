extends SceneTree

const Suite = preload("res://tests/suites/move_attack_shortcut_suite.gd")
var failures: Array[String]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	Suite.run_visible_terrain(_expect)
	await Suite.run_visible_terrain_live(self, _expect)
	print("VISIBLE TERRAIN SHORTCUT TEST: ", "PASS" if failures.is_empty() else "FAIL", " ", failures)
	quit(0 if failures.is_empty() else 1)

func _expect(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
