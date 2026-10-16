extends "res://tests/run_tests.gd"

const TEST_PROFILE_PATH: String = "user://magic_character_profile.json"
const TEST_RUN_PATH: String = "user://magic_character_run.save"
const TEST_SETTINGS_PATH: String = "user://magic_character_settings.json"

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	ProgressionStore.set_storage_path(TEST_PROFILE_PATH)
	ProgressionStore.set_run_storage_path(TEST_RUN_PATH)
	SettingsStore.set_storage_path(TEST_SETTINGS_PATH)
	SettingsStore.save_settings(SettingsStore.default_settings())
	_suppress_guided_tutorial_for_legacy_live_scene_tests()
	await _test_run_scene_character_stats_overlay_opens()
	await _test_run_scene_reward_decision_support_matches_claims()
	await _test_run_scene_debug_boss_fixture_boots()
	await _test_run_scene_campfire_choices_use_relic_overlay()
	await preload("res://tests/suites/ember_hearth_suite.gd").run(self, Callable(self, "_assert"))
	for failure: String in _failures: push_error(failure)
	print("MAGIC CHARACTER REGRESSION: %s" % ("PASS" if _failures.is_empty() else "FAIL"))
	print("TEST RESULT: %s" % ("PASS" if _failures.is_empty() else "FAIL"))
	quit(0 if _failures.is_empty() else 1)
