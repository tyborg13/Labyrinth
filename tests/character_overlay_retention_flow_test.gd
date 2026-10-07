extends "res://tests/run_tests.gd"
# Keep the full integration assertions for tab replacement, drag/equip/stow,
# real named magic slots, inventory and return to Skills in one focused run.
func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	ProgressionStore.set_storage_path("user://character_retention_flow_profile.json")
	ProgressionStore.set_run_storage_path("user://character_retention_flow_run.save")
	SettingsStore.set_storage_path("user://character_retention_flow_settings.json")
	SettingsStore.clear_storage()
	AnalyticsStore.set_storage_dir("user://character_retention_flow_analytics")
	AnalyticsStore.clear_storage()
	await _test_run_scene_character_stats_overlay_opens()
	GuidedCombatTutorialSuite.run(Callable(self, "_assert"))
	print("CHARACTER RETENTION FLOW RESULT: " + JSON.stringify({"errors": _failures}))
	quit(0 if _failures.is_empty() else 1)
