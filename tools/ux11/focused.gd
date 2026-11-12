extends "res://tests/run_tests.gd"

## Invoke existing domains only; this is not the full suite.
func _initialize() -> void:
	_initialize_test_storage(true)
	root.size = Vector2i(1920, 1080)
	await process_frame
	var expect := Callable(self, "_assert")
	preload("res://tests/suites/controller_input_suite.gd").run(expect)
	preload("res://tests/suites/actor_presentation_suite.gd").run(expect)
	preload("res://tests/suites/combat_board_layout_suite.gd").run(expect)
	preload("res://tests/suites/card_drag_play_suite.gd").run(expect)
	await preload("res://tests/suites/card_drag_play_suite.gd").run_live(self, expect)
	await _test_run_scene_action_selection_keeps_hand_layout_stable()
	await _test_run_scene_direct_card_and_player_movement_selection()
	print("UX11 FOCUSED ASSERTIONS: %d" % _assertion_count)
	_finish_test_result()
