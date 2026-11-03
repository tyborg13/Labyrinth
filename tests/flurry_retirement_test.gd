extends "res://tests/run_tests.gd"

## Focused card, keyword, Grimoire and tooltip proof; never invokes the full suite.
func _initialize() -> void:
	_run_flurry_checks.call_deferred()

func _run_flurry_checks() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_initialize_test_storage()
	_test_flurry_repeats_and_spends_snapshotted_card_plays()
	_test_grimoire_data_and_unlocks(ProgressionStore.default_data())
	_test_equipment_data_rarity_and_starter_deck()
	_test_keyword_icon_library_surfaces_tooltips()
	preload("res://tests/suites/glossary_coverage_suite.gd").run(Callable(self, "_assert"))
	TooltipConsistencySuite.run(Callable(self, "_assert"))
	preload("res://tests/suites/relic_u2_suite.gd").run(Callable(self, "_assert"))
	preload("res://tests/suites/relic_u4_suite.gd").run(Callable(self, "_assert"))
	preload("res://tests/suites/card_playability_summary_suite.gd")._test_flurry_and_health_costs(Callable(self, "_assert"))
	preload("res://tests/suites/move_attack_shortcut_suite.gd")._test_every_card_has_one_player_target_decision(Callable(self, "_assert"))
	await _test_run_scene_flurry_utility_resolves_without_attack_target()
	await _test_card_widget_flurry_icon_uses_wide_slot()
	for failure: String in _failures: push_error(failure)
	print("FLURRY RETIREMENT TEST RESULT: %s (%d checks, %d failures)" % ["PASS" if _failures.is_empty() else "FAIL", _assertion_count, _failures.size()])
	quit(0 if _failures.is_empty() else 1)
