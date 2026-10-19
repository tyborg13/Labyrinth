extends "res://tests/run_tests.gd"

const TEST_PROFILE_PATH: String = "user://pile_viewer_profile.json"
const TEST_RUN_PATH: String = "user://pile_viewer_run.save"
const TEST_SETTINGS_PATH: String = "user://pile_viewer_settings.json"

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	ProgressionStore.set_storage_path(TEST_PROFILE_PATH)
	ProgressionStore.set_run_storage_path(TEST_RUN_PATH)
	SettingsStore.set_storage_path(TEST_SETTINGS_PATH)
	SettingsStore.save_settings(SettingsStore.default_settings())
	_suppress_guided_tutorial_for_legacy_live_scene_tests()
	await _test_run_scene_discard_pile_uses_distinct_icon_controls()
	for failure: String in _failures: push_error(failure)
	print("PILE VIEWER TEST: %s" % ("PASS" if _failures.is_empty() else "FAIL"))
	print("TEST RESULT: %s" % ("PASS" if _failures.is_empty() else "FAIL"))
	quit(0 if _failures.is_empty() else 1)
