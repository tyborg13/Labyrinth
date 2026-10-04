extends "res://tests/run_tests.gd"
## Existing merchant and loadout regression cases, callable independently while
## other visual-pass units are being edited in this same worktree.

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	ProgressionStore.set_storage_path("user://scavenger_regression_progression.json")
	ProgressionStore.set_run_storage_path("user://scavenger_regression_run.save")
	SettingsStore.set_storage_path("user://scavenger_regression_settings.json")
	AnalyticsStore.set_storage_dir("user://scavenger_regression_analytics")
	var progression: Dictionary = ProgressionStore.default_data()
	ScavengerShopSuite.run(Callable(self, "_assert"))
	_test_equipment_run_state_and_reward_cards(progression)
	_test_equipment_collection_to_equip_deck_flow(progression)
	_test_merchant_assets_load_for_board()
	_test_run_map_merchant_room_spacing_and_density()
	await _test_run_scene_character_stats_overlay_opens()
	for failure: String in _failures:
		push_error(failure)
	print("SCAVENGER / MERCHANT / LOADOUT REGRESSION: %s" % ("PASS" if _failures.is_empty() else "FAIL (%d failure(s))" % _failures.size()))
	quit(0 if _failures.is_empty() else 1)
