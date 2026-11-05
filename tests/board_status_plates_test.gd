extends "res://tests/run_tests.gd"

## Focused invocation of existing HUD/status regressions plus sb-01 coverage.
func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	call_deferred("_run_status_checks")

func _run_status_checks() -> void:
	await preload("res://tests/helpers/card_buff_badge_frames.gd").run(_assert)
	if OS.get_cmdline_user_args().has("--badge-landings-only"):
		_finish_status_checks()
		return
	preload("res://tests/suites/board_status_plates_suite.gd").run(_assert)
	preload("res://tests/suites/board_status_feedback_suite.gd").run(_assert)
	await preload("res://tests/suites/board_status_cache_suite.gd").run(_assert)
	preload("res://tests/suites/board_hud_group_suite.gd").run(_assert)
	_test_bleed_status_badges_and_trigger_floats()
	_test_status_badges_surface_countdowns()
	_test_player_restriction_badges_show_turn_lock()
	_test_unit_hud_stacks_above_sprite_art()
	_test_enemy_intent_name_reserves_header_line()
	_test_enemy_intent_contour_expands_on_hover_or_toggle()
	_test_enemy_intent_action_rows_use_readable_scale()
	_test_enemy_intent_shortcut_and_threat_union()
	_test_enemy_intent_contour_uses_right_shoulder()
	_test_enemy_hud_small_top_correction_stays_centered()
	_test_enemy_hud_ignores_subpixel_obstacle_slivers()
	_test_enemy_hud_does_not_duplicate_owning_actor_obstacle()
	_test_enemy_hud_side_offset_clears_only_vertically_overlapping_pieces()
	_test_enemy_hud_layout_offsets_away_from_reserved_ui()
	_test_enemy_intent_contour_stays_anchored_at_top_edge()
	_test_enemy_hud_side_selection_is_stable_during_small_layout_changes()
	preload("res://tests/suites/threats_at_rest_suite.gd").run(_assert)
	_finish_status_checks()

func _finish_status_checks() -> void:
	for failure: String in _failures: push_error(failure)
	print("BOARD STATUS PLATES TEST RESULT: %s (%d assertions; %d failures)" % ["PASS" if _failures.is_empty() else "FAIL", _assertion_count, _failures.size()])
	quit(0 if _failures.is_empty() else 1)
