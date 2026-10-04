extends "res://tests/run_tests.gd"

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	ProgressionStore.set_storage_path("user://character_overlay_assertions_progression.json")
	ProgressionStore.set_run_storage_path("user://character_overlay_assertions_run.save")
	ProgressionStore.clear_saved_run()
	SettingsStore.set_storage_path("user://character_overlay_assertions_settings.json")
	SettingsStore.clear_storage()
	AnalyticsStore.set_storage_dir("user://character_overlay_assertions_analytics")
	AnalyticsStore.clear_storage()
	await _test_run_scene_character_stats_overlay_opens()
	for _frame: int in range(4):
		await process_frame
	await create_timer(0.05).timeout
	for failure: String in _failures:
		push_error(failure)
	print("CHARACTER OVERLAY ASSERTIONS: %s" % ("PASS" if _failures.is_empty() else "FAIL (%d)" % _failures.size()))
	quit(0 if _failures.is_empty() else 1)
