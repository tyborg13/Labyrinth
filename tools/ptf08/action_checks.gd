extends "res://tools/ptf08/focused_tests.gd"

const Presentation = preload("res://scripts/pass_forecast_presentation.gd")
const Rows = preload("res://tools/ptf08/row_tests.gd")
const PanelRows = preload("res://scripts/pass_forecast_focus_tooltip.gd")
const ENEMY_TILE := Vector2i(3, 4)
const HERO_TILE := Vector2i(2, 4)
var scene: Node

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
	root.content_scale_size = root.size
	scene = preload("res://scenes/run_scene.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set("_combat_engine", CountedCombat.new())
	await install("quick_stab", 6)
	var before: Dictionary = scene.call("_pass_preview_summary")
	scene.call("_on_card_pressed", 0)
	var killed: Dictionary = await aim(ENEMY_TILE, "melee kill")
	var source: Dictionary = scene.call("_pass_preview_source_state")
	_assert(int(source["enemies"][0]["hp"]) <= 0 and int(killed["hp_loss"]) == 0 and int(before["hp_loss"]) > 0, "Killed foe contributes no next-turn attack")
	_assert(preload("res://scripts/turn_order_slots.gd").pass_repeat_portraits(scene, {"repeated_enemy_names": ["Tunnel Crawler"]}, source).is_empty(), "A killed actor cannot keep a repeat badge through a shared enemy name")
	_assert(int(source["cards_played_this_turn"]) == 1 and int(source["player_turn_time_spent"]) == 2, "Kill preview includes exactly one card play and printed Time")
	await install("bone_dart", 14)
	scene.call("_on_card_pressed", 0)
	var hit: Dictionary = await aim(ENEMY_TILE, "ranged non-kill")
	source = scene.call("_pass_preview_source_state")
	_assert(int(source["enemies"][0]["hp"]) > 0 and int(source["enemies"][0]["hp"]) < 14 and int(hit["hp_loss"]) > 0, "A surviving ranged target retains its attack")
	await install("updraft", 14)
	scene.call("_on_card_pressed", 0)
	var pushed: Dictionary = await aim(ENEMY_TILE, "push out of reach")
	source = scene.call("_pass_preview_source_state")
	_assert(source["enemies"][0]["pos"] != ENEMY_TILE and int(pushed["hp_loss"]) == 0, "Push displacement removes the now-unreachable attack")
	await install("brace", 14)
	before = scene.call("_pass_preview_summary")
	scene.call("_on_card_pressed", 0)
	scene.call("_refresh_selected_card_forecast")
	_assert(bool(scene.call("_pending_card_requires_confirmation")), "Self-Block waits for confirmation")
	var block: Dictionary = check_panel("Block confirmation")
	source = scene.call("_pass_preview_source_state")
	_assert(int(source["player"]["block"]) == 6 and int(block["hp_loss"]) < int(before["hp_loss"]), "Confirmed Block is included in the smaller Health loss")
	_assert(source == scene.call("_pending_card_known_forecast_state"), "Confirmation uses the board's known, paid card state")
	await install("sidestep_slash", 14)
	scene.call("_on_card_pressed", 0)
	await aim(HERO_TILE, "multi-step first target")
	source = scene.call("_pass_preview_source_state")
	_assert(int(source["cards_played_this_turn"]) == 1 and int(source["player_turn_time_spent"]) == 3, "Hypothetical mid-card ending pays the card once")
	_assert(int(source["enemies"][0]["hp"]) == 14, "Unresolved next strike is not invented")
	await install("nail_parry", 14)
	scene.call("_on_card_pressed", 0)
	_assert(int(scene.get("_pending_action_index")) > 0, "Card has an already-resolved Block prefix")
	await aim(ENEMY_TILE, "multi-step hovered strike")
	source = scene.call("_pass_preview_source_state")
	_assert(int(source["player"]["block"]) == 5 and int(source["enemies"][0]["hp"]) < 14 and int(source["cards_played_this_turn"]) == 1, "Resolved Block prefix plus hovered strike is paid once")
	await install("rimeplate_lock", 14)
	scene.call("_on_card_pressed", 0)
	await aim(ENEMY_TILE, "Stoneskin and surface prefix")
	source = scene.call("_pass_preview_source_state")
	_assert(int(source["player"]["stoneskin"]) == 3 and int(source["player"]["block"]) == 3, "Stoneskin and Block gains survive into the end-now source")
	await install("quick_stab", 14)
	scene.call("_on_card_hover_started", 0, true)
	scene.call("_refresh_selected_card_forecast")
	_assert(not Presentation.preview_active(scene), "Hand hover without selection is not a preview trigger")
	scene.call("_on_card_pressed", 0)
	await aim(ENEMY_TILE, "controller attack", true)
	scene.call("_on_board_tile_hovered", Vector2i(-1, -1))
	scene.call("_refresh_board_hover_presentation")
	_assert(not bool(chip().get_meta("pass_forecast_active", true)), "Invalid tile dismisses selected action forecast")
	scene.call("_cancel_card_selection")
	scene.call("_refresh_selected_card_forecast")
	_assert(not Presentation.preview_active(scene), "Idle hover does not trigger the panel")
	await install("brace", 14)
	var skill_state: Dictionary = scene.get("_combat_state")
	skill_state["skill_ids"] = ["prismatic_instinct"]
	scene.call("_mark_combat_preview_state_changed")
	scene.call("_begin_surface_skill_selection", "prismatic_instinct")
	var surface_tiles: Array = scene.get("_surface_skill_tiles")
	_assert(not surface_tiles.is_empty(), "Surface skill exposes valid board targets")
	if not surface_tiles.is_empty():
		await aim(surface_tiles[0], "surface skill")
		source = scene.call("_pass_preview_source_state")
		_assert(source.get("surfaces", {}) != skill_state.get("surfaces", {}), "Surface skill forecast includes its resolved ground change")
	scene.call("_cancel_surface_skill_selection")
	await install("bone_dart", 14, "defiance_umbra")
	scene.call("_on_card_pressed", 0)
	var targets: Array = scene.get("_pending_target_tiles")
	if not targets.is_empty():
		var hidden: Dictionary = await aim(targets[0], "hidden-info target")
		_assert(bool(hidden.get("umbra_unknown_before_player", false)) and int(hidden.get("projected_hp", -1)) < 0, "Hidden enemy consequences retain unknown projected Health")
	var known: Dictionary = scene.call("_pending_card_known_forecast_state")
	_assert(not known.is_empty(), "Limited-Umbra prefix retains today's known-information path")
	await install("brace", 14, "defiance_umbra")
	scene.call("_on_card_pressed", 0)
	scene.call("_refresh_selected_card_forecast")
	var hidden_block: Dictionary = check_panel("hidden-info Block confirmation")
	source = scene.call("_pass_preview_source_state")
	_assert(int(source["player"]["block"]) == 6 and source["player"]["pos"] == scene.get("_combat_state")["player"]["pos"], "Known Block is retained without granting preview sight")
	_assert(bool(hidden_block["umbra_unknown_before_player"]) and int(hidden_block["projected_hp"]) < 0, "Opaque queued actors keep the existing unknown horizon after confirmation")

	scene.queue_free()
	await process_frame
	for failure: String in _failures: print("FAIL: " + failure)
	print("PTF08 ACTION RESULT: %s (%d assertions, %d failures)" % ["PASS" if _failures.is_empty() else "FAIL", _assertion_count, _failures.size()])
	quit(0 if _failures.is_empty() else 1)

func install(card: String, hp: int, kind: String = "danger") -> void:
	var state: Dictionary = preload("res://tools/ptf07/forecast_cases.gd").fixture(kind)
	state["deck"]["hand"] = [card]
	state["enemies"][0]["hp"] = hp
	state["enemies"][0]["max_hp"] = maxi(hp, 14)
	_install_pass_preview_chip_state(scene, state)
	for _frame: int in range(3): await process_frame

func aim(tile: Vector2i, context: String, controller: bool = false) -> Dictionary:
	if controller: scene.call("_controller_set_board_tile", tile, false)
	else: scene.call("_on_board_tile_hovered", tile)
	scene.call("_refresh_board_hover_presentation")
	var result: Dictionary = check_panel(context)
	var engine: CountedCombat = scene.get("_combat_engine") as CountedCombat
	var count: int = engine.forecasts
	scene.call("_on_board_tile_hovered", tile)
	scene.call("_refresh_board_hover_presentation")
	scene.call("_refresh_selected_card_forecast")
	_assert(engine.forecasts == count, context + ": warm hover adds no simulation")
	await process_frame
	return result

func check_panel(context: String) -> Dictionary:
	var button: Button = chip()
	var panel: Control = button.get_node("PassForecastFocusTooltip") as Control
	var summary: Dictionary = scene.call("_pass_preview_summary")
	_assert(Presentation.preview_active(scene) and bool(button.get_meta("pass_forecast_active", false)) and panel.visible, context + ": panel trigger is active")
	var expected: Array[Dictionary] = PanelRows.rows(summary, button.get_meta("forecast_repeat_portraits", []), Rows.inks(scene))
	_assert(panel.get_meta("forecast_rows", []) == expected, context + ": displayed rows equal post-action summary")
	return summary

func chip() -> Button:
	return scene.find_child("PassPreviewChip", true, false) as Button
