extends SceneTree

const Suite = preload("res://tests/suites/cbt_01_suite.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const Progression = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
var failures: Array[String]

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	Progression.set_storage_path("user://cbt_01_progression.json")
	Progression.set_run_storage_path("user://cbt_01_run.save")
	Settings.set_storage_path("user://cbt_01_settings.json")
	call_deferred("_run")

func _run() -> void:
	Suite.run(_expect)
	await Suite.run_live(self, _expect)
	for failure: String in failures: push_error(failure)
	print("CBT-01 TESTS: %s (%d failures)" % ["PASS" if failures.is_empty() else "FAIL", failures.size()])
	quit(0 if failures.is_empty() else 1)

func _expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
