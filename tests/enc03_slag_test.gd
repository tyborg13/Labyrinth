extends SceneTree

const Suite = preload("res://tests/suites/enc03_slag_suite.gd")
var checks: int = 0
var failures: Array[String]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	if OS.get_cmdline_user_args().has("--old-data-mutation"):
		preload("res://scripts/game_data.gd").enemies()["slag_mortar"] = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/enc03_slag_before.json"))
	Suite.run(_expect)
	for failure: String in failures: push_error(failure)
	print("ENC03 SLAG TEST: %s (%d checks; %d failures)" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
