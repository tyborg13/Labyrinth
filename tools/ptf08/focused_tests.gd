extends "res://tests/run_tests.gd"

# Override the full-suite entry point; execute only affected forecast suites.
func _initialize() -> void:
	_initialize_test_storage()
	preload("res://tests/suites/turn_clock_wait_suite.gd").run(Callable(self, "_assert"))
	preload("res://tests/suites/enemy_intent_preview_suite.gd").run(Callable(self, "_assert"))
	preload("res://tests/suites/lethal_preview_suite.gd").run(Callable(self, "_assert"))
	var forecast_scene: Node = preload("res://scripts/run_scene.gd").new()
	preload("res://tests/suites/turn_clock_hud_suite.gd")._test_forecasts(forecast_scene, Callable(self, "_assert"))
	preload("res://tests/suites/turn_clock_hud_review_suite.gd")._test_forecast_copy(forecast_scene, Callable(self, "_assert"))
	preload("res://tools/ptf08/row_tests.gd").run(forecast_scene, Callable(self, "_assert"))
	forecast_scene.free()
	await _test_run_scene_pass_preview_chip_updates()
	await _test_forecast_focus_tooltip()
	await _test_rail_forecast()
	for message: String in _failures:
		print("FAIL: " + message)
	print("PTF08 FOCUSED RESULT: %s (%d assertions, %d failures)" % ["PASS" if _failures.is_empty() else "FAIL", _assertion_count, _failures.size()])
	quit(0 if _failures.is_empty() else 1)

func _test_forecast_focus_tooltip() -> void:
	var chip := preload("res://scripts/pass_forecast_tooltip_button.gd").new()
	root.add_child(chip)
	chip.position = Vector2(1650, 870)
	chip.size = Vector2(270, 100)
	chip.tooltip_text = "Before your next turn: no damage"
	var helper = preload("res://scripts/pass_forecast_focus_tooltip.gd")
	var inks: Dictionary = {"block": Color.WHITE, "health": Color.WHITE, "defiance": Color.WHITE, "unknown": Color.WHITE}
	helper.configure(chip, helper.rows({}, [], inks))
	helper.refresh(chip, true)
	await process_frame
	var panel: Control = chip.get_node_or_null("PassForecastFocusTooltip") as Control
	_assert(panel != null and panel.get_meta("forecast_rows", []) == chip.get_meta("forecast_rows", []), "Focus shows current icon rows")
	_assert(is_equal_approx(panel.get_global_rect().end.x, chip.get_global_rect().end.x) and is_equal_approx(panel.get_global_rect().end.y, chip.get_global_rect().position.y), "Every tooltip size opens above PASS and right-aligned")
	_assert(not panel.z_as_relative and panel.z_index == RenderingServer.CANVAS_ITEM_Z_MAX, "Tooltip paints above all HUD peers including piles")
	_assert(str(chip.call("_get_tooltip", Vector2.ZERO)).is_empty(), "PASS suppresses its separate native popup")
	helper.configure(chip, helper.rows({}, [], inks))
	helper.refresh(chip, true)
	_assert(chip.get_node_or_null("PassForecastFocusTooltip") == panel, "Unchanged focus explanation retains its panel")
	chip.tooltip_text = "Before your next turn: −15 Health\nFatigue: lose 15 Health at your next draw."
	helper.configure(chip, helper.rows({"hp_loss": 15, "fatigue_loss": 15}, [], inks))
	helper.refresh(chip, true)
	_assert(chip.get_node("PassForecastFocusTooltip") == panel and panel.get_meta("forecast_rows", []) == chip.get_meta("forecast_rows", []), "State refresh updates rows in the retained panel")
	var host: Node = preload("res://scripts/run_scene.gd").new()
	var art := TextureRect.new()
	var content := Control.new()
	var edge := PanelContainer.new()
	chip.add_child(art)
	chip.add_child(content)
	chip.add_child(edge)
	helper.refresh(chip, false)
	host.call("_set_pass_preview_pointer_hover", chip, art, content, edge, Color.WHITE)
	_assert(chip.get_node_or_null("PassForecastFocusTooltip") != null, "Actual pointer-enter handler opens the same in-scene panel")
	host.call("_set_pass_preview_focus_entered", chip, art, content, edge, Color.WHITE)
	var shared: Node = chip.get_node("PassForecastFocusTooltip")
	host.call("_set_pass_preview_pointer_exit", chip, art, content, edge, Color.WHITE)
	_assert(chip.get_node_or_null("PassForecastFocusTooltip") == shared, "Pointer exit retains the focused panel")
	host.call("_set_pass_preview_focus_exited", chip, art, content, edge, Color.WHITE)
	_finish_forecast_fade(chip)
	_assert(not (chip.get_node("PassForecastFocusTooltip") as Control).visible, "Last input exit dismisses the shared panel")
	host.free()
	chip.disabled = true
	helper.refresh(chip, false)
	_finish_forecast_fade(chip)
	_assert(not (chip.get_node("PassForecastFocusTooltip") as Control).visible, "Inactive Pass dismisses focus explanation")
	chip.disabled = false
	helper.refresh(chip, true)
	helper.refresh(chip, false)
	_finish_forecast_fade(chip)
	_assert(not (chip.get_node("PassForecastFocusTooltip") as Control).visible, "Focus exit dismisses explanation")
	chip.queue_free()
	await process_frame

func _test_rail_forecast() -> void:
	var scene: Node = preload("res://scenes/run_scene.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var engine := preload("res://scripts/run_engine.gd").new()
	var run_state: Dictionary = engine.create_new_run(123, preload("res://scripts/progression_store.gd").default_data())
	for coord: Vector2i in engine.available_moves(run_state):
		if str(engine.room_metadata(run_state, coord).get("type", "")) == "combat":
			run_state = engine.move_to_room(run_state, coord)
			break
	run_state["mode"] = "combat"
	run_state["combat_state"] = preload("res://tools/ptf07/forecast_cases.gd").fixture("second_move")
	scene.call("_load_run_state", run_state)
	scene.set("_animation_lock", false)
	scene.call("_reset_card_resolution")
	scene.call("_mark_combat_preview_state_changed")
	scene.call("_refresh_ui")
	await scene.call("_await_pass_preview_cache_warm")
	scene.call("_refresh_selected_card_forecast")
	var chip: Button = scene.find_child("PassPreviewChip", true, false) as Button
	var portraits: Array = chip.get_meta("forecast_repeat_portraits", [])
	_assert(portraits.size() == 1, "Second-move fixture resolves one exact repeating rail actor")
	var badge: Control = scene.find_child("PassForecastDoubleTurnBadge", true, false) as Control
	_assert(badge != null and not badge.visible, "Repeating rail badge is retained and hidden at rest")
	chip.emit_signal("mouse_entered")
	_assert(badge != null and badge.visible, "PASS hover shows the rail ×2 badge")
	var panel: Control = chip.get_node("PassForecastFocusTooltip") as Control
	_assert(panel.visible, "PASS hover shows icon panel")
	chip.emit_signal("focus_entered")
	chip.emit_signal("mouse_exited")
	_assert(badge.visible and panel.visible, "Focus retains panel and badge after pointer exit")
	chip.emit_signal("focus_exited")
	_finish_forecast_fade(chip)
	_assert(not badge.visible and not panel.visible, "Last input exit hides both cues")
	chip.emit_signal("mouse_entered")
	_assert(chip.get_node("PassForecastFocusTooltip") == panel and scene.find_child("PassForecastDoubleTurnBadge", true, false) == badge, "Input changes reuse panel and badge controls")
	scene.call("_refresh_selected_card_forecast")
	_assert(chip.get_node("PassForecastFocusTooltip") == panel, "Unchanged forecast summary retains panel")
	if not portraits.is_empty():
		var found: bool = false
		for row: Dictionary in chip.get_meta("forecast_rows", []):
			if row.has("portrait"):
				found = row["portrait"] == portraits[0]
		_assert(found, "Panel portrait uses the same actor identity and art path as the rail")
	scene.queue_free()
	await process_frame

func _finish_forecast_fade(chip: Button) -> void:
	var fade: Node = chip.get_node("PassForecastFocusTooltip/ForecastFade")
	fade.call("sample", int(fade.get("started_usec")) + 120000)
