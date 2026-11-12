extends "res://tools/ptf08/focused_tests.gd"

const Forecast = preload("res://scripts/pass_forecast_focus_tooltip.gd")
const Presentation = preload("res://scripts/pass_forecast_presentation.gd")
const HALF_FADE_USEC: int = 60000
const FADE_USEC: int = 120000
var now_usec: int = 1000000

class CountedCombat extends CombatEngine:
	var forecasts: int = 0
	func begin_revealed_enemy_actions_preview(state: Dictionary, losses_only: bool = false) -> Dictionary:
		forecasts += 1
		return super.begin_revealed_enemy_actions_preview(state, losses_only)

func _initialize() -> void:
	_initialize_test_storage()
	root.mode = Window.MODE_WINDOWED
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = Vector2i(1920, 1080)
	var scene: Node = preload("res://scenes/run_scene.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var engine := CountedCombat.new()
	scene.set("_combat_engine", engine)
	var state: Dictionary = preload("res://tools/ptf07/forecast_cases.gd").fixture("second_move")
	state["deck"]["hand"] = ["guarded_step", "shadow_step", "quick_stab"]
	_install_pass_preview_chip_state(scene, state)
	for _frame: int in range(6): await process_frame
	var chip: Button = scene.find_child("PassPreviewChip", true, false) as Button
	var panel: Control = chip.get_node("PassForecastFocusTooltip") as Control
	var pass_rect: Rect2 = chip.get_global_rect()
	var parent_rect: Rect2 = (chip.get_parent() as Control).get_global_rect()
	_assert(scene.find_child("PassPreviewForecastLine", true, false) == null and scene.find_child("PassPreviewDamageRow", true, false) == null, "Redundant strip nodes are absent")
	var fade: Node = panel.get_node("ForecastFade")
	fade.set("clock", func() -> int: return now_usec)
	_assert(not panel.visible, "Idle hover has no forecast panel")
	chip.emit_signal("mouse_entered")
	_assert(panel.visible and is_zero_approx(panel.modulate.a), "Fade starts visible at alpha zero")
	now_usec += HALF_FADE_USEC
	fade.call("sample", now_usec)
	_assert(is_equal_approx(panel.modulate.a, 0.5), "Fade-in alpha is 0.5 at 60 ms")
	now_usec += HALF_FADE_USEC
	fade.call("sample", now_usec)
	_assert(is_equal_approx(panel.modulate.a, 1.0), "Fade-in alpha is 1 at 120 ms")
	chip.emit_signal("mouse_exited")
	now_usec += HALF_FADE_USEC
	fade.call("sample", now_usec)
	_assert(is_equal_approx(panel.modulate.a, 0.5), "Fade-out alpha is 0.5 at 60 ms")
	now_usec += HALF_FADE_USEC
	fade.call("sample", now_usec)
	_assert(not panel.visible and is_zero_approx(panel.modulate.a), "Fade-out hides at 120 ms")
	for reduced: bool in [false, true]:
		var settings: Dictionary = scene.get("_settings")
		settings["reduced_motion"] = reduced
		scene.set("_settings", settings)
		scene.call("_begin_player_movement_selection")
		var targets: Array = scene.get("_player_movement_target_tiles")
		_assert(not targets.is_empty(), "Hero movement has valid destinations")
		if not targets.is_empty():
			await destination(scene, chip, targets[0], engine, "hero")
			var anchor: Vector2 = panel.get_global_rect().end
			var retained_row: Node = panel.get_node("ForecastRows").get_child(0)
			if targets.size() > 1: await destination(scene, chip, targets[1], engine, "hero next")
			_assert(panel == chip.get_node("PassForecastFocusTooltip") and panel.get_global_rect().end.is_equal_approx(anchor), "Destination change retains panel and bottom-right anchor")
			_assert(panel.get_node("ForecastRows").get_child(0) == retained_row, "Rows update in place between destinations")
			_assert(is_equal_approx(panel.modulate.a, 1.0), "Valid-to-valid destination change does not restart fade")
			scene.call("_on_board_tile_hovered", Vector2i(-1, -1))
			scene.call("_refresh_board_hover_presentation")
			_assert(not bool(chip.get_meta("pass_forecast_active", true)), "Invalid destination starts fade-out")
			now_usec += FADE_USEC
			fade.call("sample", now_usec)
			_assert(not panel.visible, "Invalid destination hides the panel")
			await destination(scene, chip, targets[0], engine, "hero reentry")
		scene.call("_cancel_player_movement_selection")
	var stay_seen: bool = false
	for card_index: int in [0, 1]:
		scene.call("_on_card_pressed", card_index)
		for _frame: int in range(3): await process_frame
		var targets: Array = scene.get("_pending_target_tiles")
		_assert(not targets.is_empty(), "Card movement/Blink has valid targets")
		for index: int in range(mini(2, targets.size())):
			await destination(scene, chip, targets[index], engine, "card %d" % card_index)
		var hero: Vector2i = (scene.get("_preview_combat_state") as Dictionary).get("player", {}).get("pos", Vector2i(-1, -1))
		if not targets.is_empty(): await destination(scene, chip, targets[-1], engine, "controller", true)
		if targets.has(hero):
			stay_seen = true
			await destination(scene, chip, hero, engine, "Stay")
			_assert(not (scene.call("_hovered_stay_forecast") as Dictionary).is_empty(), "Stay retains its existing resolved preview")
		scene.call("_cancel_card_selection")
	_assert(stay_seen, "Stay destination was exercised")
	scene.call("_on_card_pressed", 2)
	for _frame: int in range(3): await process_frame
	var attacks: Array = scene.get("_pending_target_tiles")
	if not attacks.is_empty():
		scene.call("_on_board_tile_hovered", attacks[0])
		scene.call("_refresh_board_hover_presentation")
	_assert(not Presentation.movement_active(scene) and bool(chip.get_meta("pass_forecast_active", false)), "Selected attack targeting now triggers the same panel")
	_assert(chip.get_global_rect() == pass_rect and (chip.get_parent() as Control).get_global_rect() == parent_rect, "All preview triggers preserve PASS and parent geometry")
	print("PTF08 RECT after: PASS=%s parent=%s" % [str(pass_rect), str(parent_rect)])
	scene.queue_free()
	await process_frame
	for failure: String in _failures: print("FAIL: " + failure)
	print("PTF08 PREVIEW RESULT: %s (%d assertions, %d failures)" % ["PASS" if _failures.is_empty() else "FAIL", _assertion_count, _failures.size()])
	quit(0 if _failures.is_empty() else 1)

func destination(scene: Node, chip: Button, tile: Vector2i, engine: CountedCombat, context: String, controller: bool = false) -> void:
	var before: int = engine.forecasts
	var key: String = scene.call("_pass_preview_key", tile)
	var warmed: bool = (scene.get("_pass_preview_cache") as Dictionary).has(key)
	if controller:
		scene.call("_controller_set_board_tile", tile, false)
	else:
		scene.call("_on_board_tile_hovered", tile)
	scene.call("_refresh_board_hover_presentation")
	var summary: Dictionary = scene.call("_pass_preview_summary")
	_assert(engine.forecasts - before <= (0 if warmed else 1), context + ": hover starts zero warm simulations or at most one shared cold forecast")
	var previous: int = engine.forecasts
	scene.call("_refresh_selected_card_forecast")
	scene.call("_refresh_selected_card_forecast")
	_assert(engine.forecasts == previous, context + ": publishing/revisiting the cached tile adds no simulations")
	var panel: Control = chip.get_node("PassForecastFocusTooltip") as Control
	_assert(Presentation.movement_active(scene) and bool(chip.get_meta("pass_forecast_active", false)) and panel.visible, context + ": valid self-movement destination shows panel even with disabled PASS")
	var expected: Array[Dictionary] = Forecast.rows(summary, chip.get_meta("forecast_repeat_portraits", []), preload("res://tools/ptf08/row_tests.gd").inks(scene))
	_assert(panel.get_meta("forecast_rows", []) == expected, context + ": rows equal the previewed destination summary")
	var fade: Node = panel.get_node("ForecastFade")
	now_usec += FADE_USEC
	fade.call("sample", now_usec)
	for badge: Control in chip.get_meta("forecast_fade_badges", []):
		_assert(badge.visible and is_equal_approx(badge.modulate.a, panel.modulate.a), context + ": rail badges share panel visibility and alpha")
	await process_frame
