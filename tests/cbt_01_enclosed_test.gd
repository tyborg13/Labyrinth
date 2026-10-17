extends "res://tests/run_tests.gd"

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	ProgressionStore.set_storage_path("user://cbt_01_enclosed_progression.json")
	ProgressionStore.set_run_storage_path("user://cbt_01_enclosed_run.save")
	SettingsStore.set_storage_path("user://cbt_01_enclosed_settings.json")
	call_deferred("_run_enclosed")

func _run_enclosed() -> void:
	await _test_run_scene_block_card_offers_stay_when_enclosed()
	for failure: String in _failures: push_error(failure)
	print("CBT-01 ENCLOSED TEST: %s (%d failures)" % ["PASS" if _failures.is_empty() else "FAIL", _failures.size()])
	quit(0 if _failures.is_empty() else 1)
