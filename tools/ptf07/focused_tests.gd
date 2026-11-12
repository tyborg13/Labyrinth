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
	forecast_scene.free()
	await _test_run_scene_pass_preview_chip_updates()
	await _test_forecast_focus_tooltip()
	for message: String in _failures:
		print("FAIL: " + message)
	print("PTF07 FOCUSED RESULT: %s (%d assertions, %d failures)" % ["PASS" if _failures.is_empty() else "FAIL", _assertion_count, _failures.size()])
	quit(0 if _failures.is_empty() else 1)

func _test_forecast_focus_tooltip() -> void:
	var chip := preload("res://scripts/pass_forecast_tooltip_button.gd").new()
	root.add_child(chip)
	chip.position = Vector2(1650, 870)
	chip.size = Vector2(270, 100)
	chip.tooltip_text = "Before your next turn: no damage"
	var helper = preload("res://scripts/pass_forecast_focus_tooltip.gd")
	helper.refresh(chip, true)
	await process_frame
	var panel: Control = chip.get_node_or_null("PassForecastFocusTooltip") as Control
	_assert(panel != null and str(panel.get_meta("forecast_text", "")) == chip.tooltip_text, "Focus shows the same forecast explanation as hover")
	_assert(is_equal_approx(panel.get_global_rect().end.x, chip.get_global_rect().end.x) and is_equal_approx(panel.get_global_rect().end.y, chip.get_global_rect().position.y), "Every tooltip size opens above PASS and right-aligned")
	_assert(not panel.z_as_relative and panel.z_index == RenderingServer.CANVAS_ITEM_Z_MAX, "Tooltip paints above all HUD peers including piles")
	_assert(str(chip.call("_get_tooltip", Vector2.ZERO)).is_empty(), "PASS suppresses its separate native popup")
	helper.refresh(chip, true)
	_assert(chip.get_node_or_null("PassForecastFocusTooltip") == panel, "Unchanged focus explanation retains its panel")
	chip.tooltip_text = "Before your next turn: −15 Health\nFatigue: lose 15 Health at your next draw."
	helper.refresh(chip, true)
	_assert(chip.get_node("PassForecastFocusTooltip") != panel, "State refresh updates a focused explanation")
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
	_assert(chip.get_node_or_null("PassForecastFocusTooltip") == null, "Last input exit dismisses the shared panel")
	host.free()
	chip.disabled = true
	helper.refresh(chip, true)
	_assert(chip.get_node_or_null("PassForecastFocusTooltip") == null, "Disabled Pass dismisses focus explanation")
	chip.disabled = false
	helper.refresh(chip, true)
	helper.refresh(chip, false)
	_assert(chip.get_node_or_null("PassForecastFocusTooltip") == null, "Focus exit dismisses explanation")
	chip.queue_free()
	await process_frame
