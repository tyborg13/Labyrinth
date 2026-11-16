extends "res://tests/run_tests.gd"
var checks: int = 0
var failures: Array[String]
func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_initialize_test_storage()
	_test_boss_room_spawns_zekarion_with_wisps()
	_test_second_sequence_uses_scaled_zekarion_placeholder()
	_test_large_enemy_threat_tiles_use_footprint()
	_test_lightning_strikes_threat_tiles_are_previewed()
	_test_lightning_strikes_damage_incidental_terrain()
	_test_zekarion_overload_preserves_declared_counterplay()
	_test_zekarion_summons_wisps_when_alone()
	_test_summoned_wisps_receive_preview_intents()
	_test_zekarion_ignores_shock_status()
	_test_intermediate_boss_opens_next_sequence()
	await _test_run_scene_debug_boss_fixture_boots()
	preload("res://tests/suites/dragon_boss_suite.gd").run(_expect)
	preload("res://tests/suites/dragon_pressure_mechanics_suite.gd").run(_expect)
	preload("res://tests/suites/dragon_element_rules_suite.gd").run(_expect)
	preload("res://tests/suites/dragon_area_presentation_suite.gd").run(_expect)
	preload("res://tests/suites/battlefield_rules_suite.gd").run(_expect)
	preload("res://tests/suites/battlefield_conduction_suite.gd").run(_expect)
	preload("res://tests/suites/battlefield_fuel_suite.gd").run(_expect)
	checks += _assertion_count
	failures.append_array(_failures)
	for failure: String in failures: print("FAIL: " + failure)
	print("ZEK01 FOCUSED: %s (%d assertions, %d failures)" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
