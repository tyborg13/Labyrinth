extends "res://tools/ptf08/focused_tests.gd"
## atk-02 trigger (c) logic checks (proof tool, headless, not in default groups).
## Debug fixtures cover what real saves rarely line up: pointer and controller
## focus, held cards (aimed and targetless), targetless confirmation, a winning
## kill, free Rites, and the no-new-simulation rule on warm hovers.
const Presentation = preload("res://scripts/pass_forecast_presentation.gd")
const PanelRows = preload("res://scripts/pass_forecast_focus_tooltip.gd")
const Rows = preload("res://tools/ptf08/row_tests.gd")
const ENEMY_TILE := Vector2i(3, 4)
var scene: Node

class CountedCombat extends CombatEngine:
	var forecasts: int = 0
	func begin_revealed_enemy_actions_preview(state: Dictionary, losses_only: bool = false) -> Dictionary:
		forecasts += 1
		return super.begin_revealed_enemy_actions_preview(state, losses_only)
	func preview_revealed_enemy_actions_before_player_turn_with_steps(state: Dictionary, losses_only: bool = false) -> Dictionary:
		forecasts += 1
		return super.preview_revealed_enemy_actions_before_player_turn_with_steps(state, losses_only)

func _initialize() -> void:
	_initialize_test_storage()
	root.mode = Window.MODE_WINDOWED
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = root.size
	scene = preload("res://scenes/run_scene.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set("_combat_engine", CountedCombat.new())
	# 1-3: the last card play with no movement left, pointer then controller focus.
	await install(["bone_dart"], 14, 1, 0)
	scene.call("_on_card_pressed", 0)
	await aim(ENEMY_TILE, "final pointer target", true)
	var engine: CountedCombat = scene.get("_combat_engine") as CountedCombat
	var count: int = engine.forecasts
	for tile: Vector2i in [ENEMY_TILE, Vector2i(3, 3), ENEMY_TILE]:
		scene.call("_on_board_tile_hovered", tile)
		scene.call("_refresh_board_hover_presentation")
	_assert(engine.forecasts == count, "Returning to a warm final target adds no simulation")
	scene.call("_on_board_tile_hovered", Vector2i(0, 0))
	scene.call("_refresh_board_hover_presentation")
	_assert(not bool(chip().get_meta("pass_forecast_active", true)), "Invalid tile closes the final-action panel")
	await aim(ENEMY_TILE, "final controller target", true, true)
	scene.call("_cancel_card_selection")
	# 4: plays or movement remain: today's panel, no header.
	await install(["bone_dart"], 14, 2, 2)
	scene.call("_on_card_pressed", 0)
	await aim(ENEMY_TILE, "card play left", false)
	scene.call("_cancel_card_selection")
	await install(["bone_dart"], 14, 1, 1)
	scene.call("_on_card_pressed", 0)
	await aim(ENEMY_TILE, "movement left", false)
	scene.call("_cancel_card_selection")
	# 5: a winning kill ends the fight, not the turn.
	await install(["bone_dart"], 3, 1, 0)
	scene.call("_on_card_pressed", 0)
	await aim(ENEMY_TILE, "winning kill", false)
	_assert(str(scene.get("_combat_engine").combat_outcome(scene.call("_pass_preview_source_state"))) == "victory", "Winning kill fixture ends the fight")
	scene.call("_cancel_card_selection")
	# 6: targetless confirmation of the last play.
	await install(["brace"], 14, 1, 0)
	scene.call("_on_card_pressed", 0)
	scene.call("_refresh_selected_card_forecast")
	_assert(bool(scene.call("_pending_card_requires_confirmation")), "Brace awaits confirmation")
	var confirmation: Dictionary = check_panel("final confirmation", true)
	scene.call("_cancel_card_selection")
	# 7: free Rites (Liturgy of Ash): one in hand keeps the turn; the last one ends it.
	await install(["rite_of_noon", "bone_dart"], 14, 1, 0, ["liturgy_of_ash"])
	scene.call("_on_card_pressed", 0)
	scene.call("_refresh_selected_card_forecast")
	check_panel("free Rite while a play remains", false)
	scene.call("_cancel_card_selection")
	scene.call("_on_card_pressed", 1)
	await aim(ENEMY_TILE, "last play while a free Rite remains", false)
	scene.call("_cancel_card_selection")
	await install(["rite_of_noon"], 14, 0, 0, ["liturgy_of_ash"])
	scene.call("_on_card_pressed", 0)
	scene.call("_refresh_selected_card_forecast")
	check_panel("last free Rite", true)
	scene.call("_cancel_card_selection")
	# 8: a held targetless card over the board forecasts its click confirmation.
	await install(["brace"], 14, 1, 0)
	await hold(0, ENEMY_TILE)
	var held: Dictionary = check_panel("held final targetless card", true)
	_assert(held == confirmation, "Held targetless play forecasts the same turn as its click confirmation")
	await release_hold()
	_assert(not bool(chip().get_meta("pass_forecast_active", true)), "Releasing the held card ends its preview")
	await install(["brace"], 14, 2, 0)
	await hold(0, ENEMY_TILE)
	_assert(not bool(chip().get_meta("pass_forecast_active", true)), "Held card with a play left keeps today's hidden panel")
	await release_hold()
	# 10: hero movement: a walk that spends the last movement with no play left
	# ends the turn; a walk that leaves movement, or with a play left, does not.
	await install(["bone_dart"], 14, 0, 2)
	scene.call("_begin_player_movement_selection")
	var engine_now: RefCounted = scene.get("_combat_engine")
	var final_tile := Vector2i(-1, -1)
	var partial_tile := Vector2i(-1, -1)
	for tile: Vector2i in scene.get("_player_movement_target_tiles"):
		# The committed walk (apply_player_movement) is the ground truth for cost.
		var left: int = engine_now.player_movement_remaining(engine_now.apply_player_movement(scene.get("_combat_state"), tile))
		if left == 0 and final_tile.x < 0: final_tile = tile
		if left > 0 and partial_tile.x < 0: partial_tile = tile
	_assert(final_tile.x >= 0 and partial_tile.x >= 0, "Fixture offers a last-movement and a partial walk")
	await aim(final_tile, "final walk", true)
	await aim(partial_tile, "walk with movement left", false)
	await aim(final_tile, "final walk under controller focus", true, true)
	var hero: Vector2i = scene.get("_combat_state")["player"]["pos"]
	scene.call("_on_board_tile_hovered", hero)
	scene.call("_refresh_board_hover_presentation")
	_assert(not Presentation.ends_turn(scene) and not bool(chip().get_meta("pass_ends_turn_preview", true)), "Staying put on the hero tile ends nothing")
	scene.call("_cancel_player_movement_selection")
	await install(["bone_dart"], 14, 1, 2)
	scene.call("_begin_player_movement_selection")
	await aim(final_tile, "last movement with a play left", false)
	scene.call("_cancel_player_movement_selection")
	# 9: a held aimed card on a final target shows it; a non-final one stays hidden.
	await install(["bone_dart"], 14, 1, 0)
	await hold(0, ENEMY_TILE)
	_assert(bool(scene.get("_drag_targeting_active")), "Held attack enters drag targeting")
	check_panel("held final attack", true)
	scene.call("_set_drag_hover_tile", Vector2i(0, 0))
	_assert(not bool(chip().get_meta("pass_forecast_active", true)), "Held attack off target closes the panel")
	await release_hold()
	await install(["bone_dart"], 14, 2, 0)
	await hold(0, ENEMY_TILE)
	_assert(not bool(chip().get_meta("pass_forecast_active", true)), "Held attack with a play left keeps today's hidden panel")
	await release_hold()
	scene.queue_free()
	await process_frame
	for failure: String in _failures: print("FAIL: " + failure)
	print("ATK02 CHECKS RESULT: %s (%d assertions, %d failures)" % ["PASS" if _failures.is_empty() else "FAIL", _assertion_count, _failures.size()])
	quit(0 if _failures.is_empty() else 1)

func install(hand: Array, hp: int, plays_left: int, movement: int, relics: Array = []) -> void:
	var state: Dictionary = preload("res://tools/ptf07/forecast_cases.gd").fixture("danger")
	state["deck"]["hand"] = hand.duplicate()
	state["enemies"][0]["hp"] = hp
	state["enemies"][0]["max_hp"] = maxi(hp, 14)
	state["relics"] = relics.duplicate()
	var engine: RefCounted = scene.get("_combat_engine")
	state["cards_played_this_turn"] = engine._card_play_capacity(state) - plays_left
	state["player_movement_remaining"] = movement
	_install_pass_preview_chip_state(scene, state)
	for _frame: int in range(3): await process_frame

func aim(tile: Vector2i, context: String, final: bool, controller: bool = false) -> Dictionary:
	if controller: scene.call("_controller_set_board_tile", tile, false)
	else: scene.call("_on_board_tile_hovered", tile)
	scene.call("_refresh_board_hover_presentation")
	var result: Dictionary = check_panel(context, final)
	var engine: CountedCombat = scene.get("_combat_engine") as CountedCombat
	var count: int = engine.forecasts
	scene.call("_on_board_tile_hovered", tile)
	scene.call("_refresh_board_hover_presentation")
	scene.call("_refresh_selected_card_forecast")
	_assert(engine.forecasts == count, context + ": warm hover adds no simulation")
	await process_frame
	return result

func check_panel(context: String, final: bool) -> Dictionary:
	var button: Button = chip()
	var panel: Control = button.get_node("PassForecastFocusTooltip") as Control
	var summary: Dictionary = scene.call("_pass_preview_summary")
	var source: Dictionary = scene.call("_pass_preview_source_state")
	_assert(Presentation.ends_turn(scene) == final and bool(button.get_meta("pass_ends_turn_preview", false)) == final, "%s: trigger (c) is %s" % [context, str(final)])
	_assert(bool(button.get_meta("pass_forecast_active", false)) and panel.visible, context + ": panel is active")
	var expected: Array[Dictionary] = PanelRows.rows(summary, button.get_meta("forecast_repeat_portraits", []), Rows.inks(scene))
	if final: expected.push_front(PanelRows.ends_turn_row())
	_assert(panel.get_meta("forecast_rows", []) == expected, context + ": rows are the post-action summary%s" % (" under the Ends turn header" if final else ""))
	if final:
		var header: Dictionary = expected[0]["parts"][0]
		_assert(header["icon"] == "turn_clock" and header["text"] == "Ends turn" and header["color"] == preload("res://scripts/ui_palette.gd").GOLD_BRIGHT, context + ": header is the turn clock and gold Ends turn")
		# A walk's preview leaves movement unpaid; its click commits apply_player_movement.
		if bool(scene.get("_player_movement_selected")): source = scene.get("_combat_engine").apply_player_movement(scene.get("_combat_state"), scene.get("_hovered_board_tile"))
		_assert(scene.get("_combat_engine").player_turn_resources_exhausted(source), context + ": the previewed state would auto-pass")
	return summary

func hold(index: int, tile: Vector2i) -> void:
	var board: Control = scene.get("board_view") as Control
	var point: Vector2 = board.get_global_transform_with_canvas() * (board.call("_tile_center", tile) as Vector2)
	await scene.call("_on_card_drag_started", index, (scene.call("_hand_card_control", index) as Control).get_global_rect().get_center())
	await scene.call("_update_card_drag", point)
	await process_frame
	await scene.call("_update_card_drag", point)
	scene.call("_refresh_selected_card_forecast")

func release_hold() -> void:
	scene.call("_cancel_drag_play")
	if int(scene.get("_selected_card_index")) >= 0: scene.call("_cancel_card_selection")
	scene.call("_refresh_selected_card_forecast")
	await process_frame

func chip() -> Button:
	return scene.find_child("PassPreviewChip", true, false) as Button
