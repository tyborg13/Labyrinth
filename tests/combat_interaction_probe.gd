extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")
const ContextualCombatTutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const HandFanContainerScript = preload("res://scripts/hand_fan_container.gd")
const RoomGenerator = preload("res://scripts/room_generator.gd")

const OUTPUT_DIR: String = "user://probes/combat_interaction_context_v4"
const BOARD_PATH: String = "BoardUnderlay/CombatBoard"
const HAND_PATH: String = "UiLayer/UiRoot/Backdrop/Margin/MainVBox/BottomStack/HandRow/HandScroll/HandCenter/HandTuckMargin/HandBox"
const MINI_MAP_PATH: String = "UiLayer/UiRoot/Backdrop/Margin/MainVBox/StageRoot/MiniMapOverlay"
const LOG_PATH: String = "UiLayer/UiRoot/Backdrop/Margin/MainVBox/StageRoot/LogOverlay"
const PROBE_VIEWPORT: Vector2i = Vector2i(1920, 1080)
const PRODUCTION_VIEWPORT: Vector2i = Vector2i(1920, 1227)

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	# Force a logical Full HD canvas before the scene exists. macOS can return a
	# Retina backing image, which _save_root_screenshot deliberately normalizes.
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(PROBE_VIEWPORT)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_size = PROBE_VIEWPORT
	root.size = PROBE_VIEWPORT
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_clear_probe_output(OUTPUT_DIR)
	ProgressionStore.set_storage_path("user://labyrinth_progression_combat_interaction_probe.json")
	ProgressionStore.set_run_storage_path("user://labyrinth_run_combat_interaction_probe.save")
	ProgressionStore.clear_saved_run()
	await _capture_states()
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	quit()

func _capture_states() -> void:
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await _settle_ui()
	await _load_combat_fixture(
		instance,
		["quick_stab", "sidestep_slash", "thunderline", "guarded_step", "patch_up"],
		Vector2i(2, 4),
		[Vector2i(5, 4), Vector2i(5, 2)],
		9801
	)
	# Fixture refresh owns the live progression snapshot, so resolve all prompts
	# afterwards to prove the normal returning-combat surface is tutorial-free.
	var progression: Dictionary = (instance.get("_progression") as Dictionary).duplicate(true)
	for prompt_id: String in ContextualCombatTutorial.prompt_ids():
		progression = ContextualCombatTutorial.resolve_progression(progression, prompt_id)
	instance.set("_progression", progression)
	instance.call("_refresh_contextual_combat_tutorial")
	await _settle_ui()
	_assert(not (instance.get("_action_step_tracker") as Control).visible, "Idle hand should not show action context")
	_assert_full_hd_normal_hud(instance)
	_assert_pass_meter_layout(instance, "normal")
	await _save_root_screenshot("%s/idle_hand.png" % OUTPUT_DIR)
	await _capture_pile_interaction_states(instance)

	await _load_combat_fixture(
		instance,
		["quick_stab", "sidestep_slash", "thunderline", "guarded_step", "patch_up"],
		Vector2i(2, 4),
		[Vector2i(3, 2), Vector2i(4, 2), Vector2i(5, 2), Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3), Vector2i(5, 3), Vector2i(3, 4), Vector2i(4, 4)],
		9810
	)
	_assert_dense_turn_order_rail(instance)
	await _save_root_screenshot("%s/dense_ten_actor_rail.png" % OUTPUT_DIR)
	await _capture_pass_and_meter_states(instance)

	await _load_combat_fixture(instance, ["stone_plate", "quick_stab"], Vector2i(2, 4), [Vector2i(5, 4)], 9800)
	var targetless_before: Dictionary = (instance.get("_combat_state") as Dictionary).duplicate(true)
	instance.call("_on_card_pressed", 0)
	await _settle_ui()
	var targetless_context: Control = instance.get("_action_step_tracker") as Control
	var targetless_board: Node = instance.get_node(BOARD_PATH)
	var targetless_player_tile: Vector2i = ((targetless_before.get("player", {}) as Dictionary).get("pos", Vector2i(-1, -1)))
	_assert(int(instance.get("_selected_card_index")) == 0, "Targetless card click should arm the exact card")
	_assert((instance.get("_combat_state") as Dictionary) == targetless_before, "Targetless card click should not mutate combat before confirmation")
	_assert(_button_with_text(targetless_context, "Play Card") == null, "Targetless card context should not expose a third confirmation control")
	_assert(((targetless_board.get("presentation") as Dictionary).get("confirmation_target_tiles", []) as Array) == [targetless_player_tile], "Targetless card context should highlight only the protagonist tile")
	_assert(str(targetless_context.get_meta("action_verb", "")) == "READY · CLICK YOUR TILE", "Targetless card context should explain the self click")
	_assert(str(targetless_context.get_meta("target_state", "")) == "SELF", "Targetless card context should identify the protagonist target")
	_assert(targetless_context.find_child("CardActionChoiceMove", true, false) != null, "Targetless confirmation should keep alternate modes available")
	await _save_root_screenshot("%s/targetless_confirmation.png" % OUTPUT_DIR)
	instance.call("_on_cancel_requested")
	await _settle_ui()

	await _load_combat_fixture(
		instance,
		["quick_stab", "sidestep_slash", "thunderline", "guarded_step", "patch_up"],
		Vector2i(2, 4),
		[Vector2i(5, 4), Vector2i(5, 2)],
		9801
	)

	instance.call("_on_card_drag_started", 1)
	await _settle_ui()
	var board: Control = instance.get_node(BOARD_PATH) as Control
	var drag_position: Vector2 = board.get_global_rect().get_center() + Vector2(-120.0, -40.0)
	instance.call("_update_drag_proxy_position", drag_position)
	instance.call("_update_drag_overlay_hover", instance.call("_drag_zone_at", drag_position))
	await _settle_ui()
	_assert_drag_state(instance)
	await _save_root_screenshot("%s/drag_full_card.png" % OUTPUT_DIR)

	var move_panel: Control = (instance.get("_drag_zone_panels") as Dictionary).get("move", null) as Control
	_assert(move_panel != null, "Drag proof should expose the compact Move fallback")
	if move_panel != null:
		var move_hover_position: Vector2 = move_panel.get_global_rect().get_center()
		instance.call("_update_drag_overlay_hover", "move")
		await _settle_ui()
		var proxy: Control = instance.get("_drag_card_proxy") as Control
		var rail: Control = instance.get("_action_step_tracker") as Control
		if proxy != null:
			proxy.global_position = move_hover_position - proxy.size * proxy.scale * 0.5
		await _settle_ui()
		_assert(str(rail.get_meta("drag_hover_zone", "")) == "move", "Fallback-hover proof should enter Move hover state")
		_assert(proxy != null and rail.z_index > proxy.z_index, "Action rail should remain readable above the held card proxy")
		_assert(proxy != null and Rect2(proxy.global_position, proxy.size * proxy.scale).intersects(move_panel.get_global_rect()), "Fallback-hover proof should place the held card directly over the Move command")
		var fallback_verb: Label = instance.get("_action_context_verb_label") as Label
		_assert(fallback_verb != null and fallback_verb.text == "RELEASE · MOVE" and _label_text_fits(fallback_verb), "Move fallback instruction should remain fully readable")
		_assert(str(rail.get_meta("risk_text", "")) == "FALLBACK · MOVE", "Move hover should replace the primary badge with the active fallback context")
		await _save_root_screenshot("%s/drag_fallback_move_hover.png" % OUTPUT_DIR)

	await instance.call("_commit_drag_drop", "play")
	await _settle_ui()
	_assert_context(instance, "MOVE", "STEP 1/2", "move target")
	await _save_root_screenshot("%s/move_target.png" % OUTPUT_DIR)

	instance.call("_on_board_tile_hovered", Vector2i(0, 0))
	await _settle_ui()
	var context: Control = instance.get("_action_step_tracker") as Control
	_assert(str(context.get_meta("target_state", "")) == "INVALID TARGET", "Invalid board hover should surface concise target legality")
	await _save_root_screenshot("%s/invalid_target.png" % OUTPUT_DIR)

	await instance.call("_on_board_tile_clicked", Vector2i(4, 4))
	instance.call("_on_board_tile_hovered", Vector2i(5, 4))
	await _settle_ui()
	_assert_context(instance, "MELEE", "STEP 2/2", "attack target")
	await _save_root_screenshot("%s/attack_target.png" % OUTPUT_DIR)

	instance.call("_on_cancel_requested")
	await _settle_ui()
	_assert(int(instance.get("_selected_card_index")) == -1, "Cancel should clear selection")
	_assert(not (instance.get("_action_step_tracker") as Control).visible, "Cancel should return to the idle hand")
	_assert((((instance.get("_combat_state") as Dictionary).get("deck", {}) as Dictionary).get("hand", []) as Array).size() == 5, "Cancel should not consume a card")
	await _save_root_screenshot("%s/cancel_restored.png" % OUTPUT_DIR)

	await _load_combat_fixture(instance, ["sidestep_slash"], Vector2i(2, 4), [Vector2i(3, 4)], 9802)
	await _choose_clicked_card_action(instance, 0, "play")
	await _settle_ui()
	context = instance.get("_action_step_tracker") as Control
	_assert(_button_with_text(context, "Skip") != null, "Optional step should compose Skip into the action context")
	_assert_context(instance, "MOVE", "STEP 1/2", "optional step")
	await _save_root_screenshot("%s/optional_step.png" % OUTPUT_DIR)

	await _load_combat_fixture(instance, ["thunderline"], Vector2i(2, 4), [Vector2i(4, 4), Vector2i(4, 2), Vector2i(6, 4)], 9803)
	await _choose_clicked_card_action(instance, 0, "play")
	instance.call("_on_board_tile_hovered", Vector2i(5, 4))
	instance.call("_rotate_aoe_aim", -1)
	instance.call("_on_board_tile_hovered", Vector2i(4, 3))
	await _settle_ui()
	context = instance.get("_action_step_tracker") as Control
	_assert(_button_with_text(context, "Rotate") != null, "Rotatable AOE should compose Rotate into the action context")
	_assert(str(context.get_meta("action_verb", "")) == "AIM AREA", "AOE targeting should use concise, non-redundant copy")
	var focus_tiles: Array = (board.get("presentation") as Dictionary).get("focus_tiles", [])
	_assert(focus_tiles.has(Vector2i(4, 2)) and focus_tiles.has(Vector2i(4, 4)) and not focus_tiles.has(Vector2i(6, 4)), "AOE rotation state should show the selected vertical pattern")
	await _save_root_screenshot("%s/aoe_rotation.png" % OUTPUT_DIR)

	await _load_combat_fixture(
		instance,
		["quick_stab", "sidestep_slash", "guarded_step", "thunderline", "bone_dart", "patch_up", "updraft"],
		Vector2i(2, 4),
		[Vector2i(3, 4), Vector2i(5, 2), Vector2i(5, 4)],
		9804
	)
	await _choose_clicked_card_action(instance, 1, "play")
	await _settle_ui()
	_assert_context(instance, "MOVE", "STEP 1/2", "HUD stress")
	_assert_hud_collision_free(instance)
	await _save_root_screenshot("%s/hud_stress.png" % OUTPUT_DIR)
	await _capture_hand_dock_resilience(instance)
	await _capture_top_row_prop_framing(instance)
	await _capture_no_hand_board_framing(instance)
	await _capture_production_aspect_geometry(instance)

	instance.queue_free()
	await process_frame

func _capture_pile_interaction_states(instance: Node) -> void:
	var draw_pile: PanelContainer = instance.get("draw_pile") as PanelContainer
	var pile_scrim: Control = instance.get("_pile_scrim") as Control
	var overlays: Dictionary = instance.get("_pile_state_overlays") as Dictionary
	var draw_overlay: PanelContainer = overlays.get("draw", null) as PanelContainer
	_assert(draw_pile != null and draw_pile.visible, "Draw pile should be available for compact interaction-state proof")
	_assert(draw_overlay != null and draw_overlay.focus_mode == Control.FOCUS_NONE, "Pile state treatment should not introduce an extra keyboard focus stop")
	if draw_pile == null or draw_overlay == null:
		return

	draw_pile.emit_signal("mouse_entered")
	await _settle_ui()
	_assert(str(draw_pile.get_meta("pile_interaction_state", "")) == "hover", "Draw pile pointer hover should expose a visible hover state")
	_assert(draw_overlay.visible, "Draw pile hover should show its tight state outline")
	var hover_style: StyleBoxFlat = draw_overlay.get_theme_stylebox("panel") as StyleBoxFlat
	await _save_root_screenshot("%s/draw_pile_hover.png" % OUTPUT_DIR)
	draw_pile.emit_signal("mouse_exited")

	draw_pile.grab_focus()
	await _settle_ui()
	_assert(str(draw_pile.get_meta("pile_interaction_state", "")) == "focus", "Draw pile keyboard/controller focus should expose a visible focus state")
	_assert(draw_overlay.visible, "Draw pile focus should show its tight card-shaped outline")
	await _save_root_screenshot("%s/draw_pile_focus.png" % OUTPUT_DIR)

	instance.call("_set_pile_pressed", "draw", true)
	await _settle_ui()
	_assert(str(draw_pile.get_meta("pile_interaction_state", "")) == "pressed", "Draw pile pressed state should be explicit in control metadata")
	_assert(draw_overlay.visible and (pile_scrim == null or not pile_scrim.visible), "Pressed proof should not activate or open the draw pile")
	var draw_content: Control = (instance.get("_pile_content_hosts") as Dictionary).get("draw", null) as Control
	var pressed_style: StyleBoxFlat = draw_overlay.get_theme_stylebox("panel") as StyleBoxFlat
	_assert(draw_content != null and draw_content.position.y >= 3.0, "Pressed draw pile should travel a deliberate 3px downward")
	_assert(hover_style != null and pressed_style != null and pressed_style.bg_color.a > hover_style.bg_color.a and pressed_style.shadow_size < hover_style.shadow_size, "Pressed draw pile should be darker and tighter than hover")
	await _save_root_screenshot("%s/draw_pile_pressed.png" % OUTPUT_DIR)
	instance.call("_set_pile_pressed", "draw", false)
	await _settle_ui()

	instance.set("_selected_card_index", 0)
	instance.call("_refresh_pile_interaction_states")
	await _settle_ui()
	_assert(str(draw_pile.get_meta("pile_interaction_state", "")) == "disabled", "Unavailable pile actions should expose a disabled state")
	_assert(draw_pile.focus_mode == Control.FOCUS_ALL, "Unavailable pile actions should preserve the established single focus stop")
	instance.set("_selected_card_index", -1)
	instance.call("_refresh_pile_interaction_states")
	await _settle_ui()
	_assert(draw_pile.focus_mode == Control.FOCUS_ALL, "Available draw pile should restore its single keyboard/controller focus stop")
	var accept := InputEventAction.new()
	accept.action = "ui_accept"
	accept.pressed = true
	instance.call("_on_pile_gui_input", accept, "draw")
	await _settle_ui()
	_assert(pile_scrim != null and pile_scrim.visible, "Draw pile ui_accept should preserve pile inspection activation")
	instance.call("_close_pile_view")
	await _settle_ui()

func _capture_pass_and_meter_states(instance: Node) -> void:
	for state_kind: String in ["safe", "danger", "unknown"]:
		_install_pass_meter_fixture(instance, state_kind)
		await _settle_ui()
		_assert_pass_meter_layout(instance, state_kind)
		await _save_root_screenshot("%s/pass_%s.png" % [OUTPUT_DIR, state_kind])
	var chip: Button = instance.find_child("PassPreviewChip", true, false) as Button
	if chip != null:
		var pass_art: TextureRect = chip.find_child("PassForecastFrameArtHost", true, false) as TextureRect
		var focus_edge: Control = chip.find_child("PassFocusEdgeCue", true, false) as Control
		var pass_content: Control = chip.find_child("PassForecastContent", true, false) as Control
		_assert(pass_art != null and pass_art.texture != null and str(pass_art.get_meta("pass_forecast_art_state", "")) == "normal", "Pass idle proof should use the authored v2 normal frame")
		chip.emit_signal("mouse_entered")
		await _settle_ui()
		_assert(str(chip.get_meta("pass_interaction_state", "")) == "hover", "Pass hover proof should expose its interaction state")
		_assert(pass_art != null and pass_art.texture != null and str(pass_art.get_meta("pass_forecast_art_state", "")) == "hover", "Pass hover proof should use the authored hover frame without a code overlay")
		_assert(focus_edge != null and not focus_edge.visible, "Pass hover should not add a colored focus wash")
		await _save_root_screenshot("%s/pass_hover.png" % OUTPUT_DIR)
		chip.emit_signal("mouse_exited")
		chip.grab_focus()
		await _settle_ui()
		_assert(str(chip.get_meta("pass_interaction_state", "")) == "focus", "Pass focus proof should expose its interaction state")
		_assert(pass_art != null and pass_art.texture != null and str(pass_art.get_meta("pass_forecast_art_state", "")) == "hover", "Pass focus should reuse the authored hover frame")
		var focus_style: StyleBoxFlat = focus_edge.get_theme_stylebox("panel") as StyleBoxFlat if focus_edge != null else null
		_assert(focus_edge != null and focus_edge.visible and focus_style != null and focus_style.bg_color.a <= 0.001 and focus_style.border_width_left <= 2 and focus_style.shadow_size == 0, "Pass focus should add only a narrow shape-aware edge cue")
		await _save_root_screenshot("%s/pass_focus.png" % OUTPUT_DIR)
		chip.emit_signal("button_down")
		await _settle_ui()
		_assert(str(chip.get_meta("pass_interaction_state", "")) == "pressed", "Pass pressed proof should expose its interaction state")
		_assert(pass_art != null and pass_art.texture != null and str(pass_art.get_meta("pass_forecast_art_state", "")) == "pressed", "Pass pressed proof should use the authored pressed frame")
		_assert(pass_content != null and pass_content.position.y >= 0.0 and pass_content.position.y <= 2.0, "Pass pressed travel must remain a subtle one-to-two pixels")
		await _save_root_screenshot("%s/pass_pressed.png" % OUTPUT_DIR)
		chip.emit_signal("button_up")

	_install_pass_meter_fixture(instance, "safe")
	var banked_state: Dictionary = (instance.get("_combat_state") as Dictionary).duplicate(true)
	banked_state["skill_ids"] = ["measured_breath", "borrowed_time"]
	banked_state["banked_play_active"] = 1
	banked_state["banked_play_spent_this_activation"] = 0
	instance.set("_combat_state", banked_state)
	instance.call("_refresh_card_play_meter")
	await _settle_ui()
	var banked_badge: Control = instance.get("_play_meter_banked_badge") as Control
	_assert(banked_badge != null and banked_badge.visible, "Banked meter proof should expose the secondary banked row")
	await _save_root_screenshot("%s/meter_banked.png" % OUTPUT_DIR)

	# The dock is deliberately independent of tutorial placement. Restore a fresh
	# prompt here so the focused interaction proof checks that both surfaces can
	# coexist with the complete five-card hand.
	_install_pass_meter_fixture(instance, "safe")
	await _settle_ui()
	var tutorial_progression: Dictionary = (instance.get("_progression") as Dictionary).duplicate(true)
	tutorial_progression.erase(ContextualCombatTutorial.PROGRESSION_KEY)
	tutorial_progression["run_counter"] = 0
	instance.set("_progression", tutorial_progression)
	instance.call("_refresh_contextual_combat_tutorial")
	await _settle_ui()
	var tutorial: Control = instance.get("_contextual_combat_prompt") as Control
	_assert(tutorial != null and tutorial.visible, "Tutorial-clearance proof should display the contextual combat prompt")
	_assert_pass_meter_layout(instance, "tutorial")
	await _save_root_screenshot("%s/pass_tutorial_clear.png" % OUTPUT_DIR)
	for prompt_id: String in ContextualCombatTutorial.prompt_ids():
		tutorial_progression = ContextualCombatTutorial.resolve_progression(tutorial_progression, prompt_id)
	instance.set("_progression", tutorial_progression)
	instance.call("_refresh_contextual_combat_tutorial")
	await _settle_ui()

func _install_pass_meter_fixture(instance: Node, state_kind: String) -> void:
	var combat := CombatEngine.new()
	var full_hand: Array = ["guarded_step", "quick_stab", "sidestep_slash", "thunderline", "patch_up"]
	var state: Dictionary = combat.create_combat(9821, _room_layout(Vector2i(2, 4), [Vector2i(3, 4)]), {
		"hp": 24, "max_hp": 24, "deck_cards": full_hand, "relics": [], "hand_size": full_hand.size(), "heal_bonus": 0
	})
	var enemy_pos: Vector2i = Vector2i(6, 4) if state_kind in ["safe", "unknown"] else Vector2i(3, 4)
	var enemy_intent: Dictionary = {"name": "Claw", "time": 1, "actions": [{"type": "melee", "damage": 5, "range": 1}]}
	state["player"] = {"pos": Vector2i(2, 4), "hp": 24, "max_hp": 24, "block": 0, "stoneskin": 0}
	state["enemies"] = [{"id": 1, "type": "crawler", "pos": enemy_pos, "hp": 14, "max_hp": 14, "block": 0, "intent": enemy_intent}]
	state["deck"] = {"hand": full_hand, "draw": ["bone_dart"], "discard": ["updraft"], "burned": [], "cycles": 0, "fatigue_base": 15}
	state["cards_per_turn"] = full_hand.size()
	state["draw_per_turn"] = full_hand.size()
	state["cards_played_this_turn"] = 0
	state["death_bonus_card_plays_this_turn"] = 0
	state["card_play_bonus_this_turn"] = 0
	state["player_turn_time_spent"] = 20 if state_kind == "unknown" else 0
	state["player_turn_restrictions"] = {"frozen": false, "shocked": false, "immobilized": false}
	state["initiative_clock"] = 0
	state["current_actor"] = {"kind": "player", "actor_key": "player", "name": "Reaver", "type": "player", "team": "player", "time": 0, "seq": 0}
	state["turn_queue"] = [{"kind": "enemy", "actor_key": "enemy_1", "enemy_id": 1, "type": "crawler", "name": "Tunnel Crawler", "team": "enemy", "time": 1, "seq": 1, "pos": enemy_pos}]
	if state_kind == "unknown":
		var umbra: Dictionary = (state.get("umbra", {}) as Dictionary).duplicate(true)
		umbra["stage"] = "eclipse"
		umbra["stage_reduction"] = 0
		state["umbra"] = umbra
	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run_state["mode"] = "combat"
	run_state["combat_state"] = state.duplicate(true)
	instance.set("_run_state", run_state)
	instance.set("_combat_state", state.duplicate(true))
	instance.set("_animation_lock", false)
	instance.call("_reset_card_resolution")
	instance.call("_refresh_ui")

func _assert_pass_meter_layout(instance: Node, state_kind: String) -> void:
	var chip: Control = instance.find_child("PassPreviewChip", true, false) as Control
	var pass_label: Label = instance.find_child("PassActionLabel", true, false) as Label
	var ribbon: Label = instance.find_child("PassPreviewForecastLine", true, false) as Label
	var meter: Control = instance.get("_play_meter") as Control
	var meter_label: Label = instance.get("_play_meter_count") as Label
	_assert(chip != null and pass_label != null and ribbon != null and meter != null and meter_label != null, "%s pass/meter proof should build all dock controls" % state_kind)
	if chip == null or pass_label == null or ribbon == null or meter == null or meter_label == null:
		return
	_assert(absf(pass_label.get_global_rect().get_center().x - chip.get_global_rect().get_center().x) <= 1.0, "%s PASS label should stay centered" % state_kind)
	_assert(_label_text_fits(ribbon), "%s forecast ribbon should fit its text" % state_kind)
	var ribbon_rect: Rect2 = ribbon.get_global_rect()
	var chip_rect: Rect2 = chip.get_global_rect()
	_assert(ribbon_rect.position.y >= chip_rect.position.y + 71.0 and ribbon_rect.end.y <= chip_rect.position.y + 91.0, "%s TURN END forecast should stay contained in the authored lower ribbon" % state_kind)
	_assert(absf(meter_label.get_global_rect().get_center().y - meter.get_global_rect().get_center().y) <= 1.0, "%s ordinary meter label should stay vertically centered" % state_kind)
	_assert(chip.get_global_rect().position.y >= meter.get_global_rect().end.y + 5.0, "%s pass ribbon should stay below the meter plaque" % state_kind)
	_assert(absf(meter.get_global_rect().get_center().x - chip_rect.get_center().x) <= 1.0, "%s meter should center over the wider Pass control" % state_kind)
	_assert(_rect_is_onscreen(meter.get_global_rect()) and _rect_is_onscreen(chip_rect), "%s action dock should remain wholly on screen" % state_kind)
	_assert(not meter.get_global_rect().intersects(chip_rect), "%s meter and Pass controls should not overlap" % state_kind)
	_assert_combat_dock_clearance(instance, meter.get_global_rect(), chip_rect, state_kind)

func _assert_combat_dock_clearance(instance: Node, meter_rect: Rect2, pass_rect: Rect2, state_kind: String) -> void:
	var dock_rects: Array = [meter_rect, pass_rect]
	var board_rect: Rect2 = instance.call("_contextual_combat_rendered_board_bounds")
	var turn_rail: Control = instance.get("_turn_order_panel") as Control
	var tutorial: Control = instance.get("_contextual_combat_prompt") as Control
	for dock_rect: Rect2 in dock_rects:
		_assert(not dock_rect.intersects(board_rect), "%s action dock should not cover the combat board" % state_kind)
		for pile: Control in [instance.get("draw_pile") as Control, instance.get("discard_pile") as Control]:
			if pile != null and pile.visible:
				_assert(not dock_rect.intersects(pile.get_global_rect()), "%s action dock should stay clear of the %s pile" % [state_kind, pile.name])
		if turn_rail != null and turn_rail.visible:
			_assert(not dock_rect.intersects(turn_rail.get_global_rect()), "%s action dock should stay clear of the turn rail" % state_kind)
		if tutorial != null and tutorial.visible:
			_assert(not dock_rect.intersects(tutorial.get_global_rect()), "%s action dock should stay clear of the contextual tutorial" % state_kind)
	var hand: Array = ((instance.get("_combat_state") as Dictionary).get("deck", {}) as Dictionary).get("hand", []) as Array
	_assert(hand.size() >= 3, "%s fixture should keep a representative playable hand" % state_kind)
	for index: int in range(hand.size()):
		var card: Control = instance.call("_hand_card_control", index) as Control
		if card == null or not card.visible:
			continue
		var card_rect: Rect2 = instance.call("_control_visual_global_rect", card)
		for dock_rect: Rect2 in dock_rects:
			_assert(not dock_rect.intersects(card_rect), "%s action dock should stay left of hand card %d" % [state_kind, index + 1])
	if not hand.is_empty():
		var leftmost_card: Control = instance.call("_hand_card_control", 0) as Control
		if leftmost_card != null and leftmost_card.visible:
			var leftmost_rect: Rect2 = instance.call("_control_visual_global_rect", leftmost_card)
			var minimum_gap: float = 4.0 if hand.size() >= 8 else 20.0
			_assert(pass_rect.end.x <= leftmost_rect.position.x - minimum_gap, "%s Pass dock should keep a visible gap before the leftmost full-hand card" % state_kind)

func _capture_hand_dock_resilience(instance: Node) -> void:
	var hand_sets: Array = [
		["quick_stab", "sidestep_slash", "thunderline", "guarded_step", "patch_up"],
		["quick_stab", "sidestep_slash", "thunderline", "guarded_step", "patch_up", "bone_dart"],
		["quick_stab", "sidestep_slash", "thunderline", "guarded_step", "patch_up", "bone_dart", "updraft"],
		["quick_stab", "sidestep_slash", "thunderline"],
		["quick_stab", "sidestep_slash", "thunderline", "guarded_step", "patch_up", "bone_dart", "updraft", "guarded_step"]
	]
	var stable_seven_meter := Rect2()
	var stable_seven_pass := Rect2()
	for cards_var: Variant in hand_sets:
		var cards: Array = cards_var as Array
		instance.set("_hovered_card_index", -1)
		await _load_combat_fixture(instance, cards, Vector2i(2, 4), [Vector2i(5, 4), Vector2i(5, 2)], 9910 + cards.size())
		var first_card: Control = instance.call("_hand_card_control", 0) as Control
		if first_card != null:
			var rendered_card_width: float = first_card.size.x * first_card.get_global_transform().get_scale().x
			print("HAND GEOMETRY %d-CARD width=%.2f bounds=%s" % [cards.size(), rendered_card_width, instance.call("_combat_hand_resting_visual_bounds")])
			if cards.size() >= 8:
				_assert(rendered_card_width >= 171.5 and rendered_card_width <= 180.5, "Dense eight-card hands should use the readable compact width that preserves focus and dock clearance")
		var meter: Control = instance.get("_play_meter") as Control
		var pass_chip: Control = instance.find_child("PassPreviewChip", true, false) as Control
		_assert(meter != null and pass_chip != null, "%d-card dock proof needs meter and Pass controls" % cards.size())
		if meter == null or pass_chip == null:
			continue
		var resting_meter: Rect2 = meter.get_global_rect()
		var resting_pass: Rect2 = pass_chip.get_global_rect()
		if cards.size() == 7:
			stable_seven_meter = resting_meter
			stable_seven_pass = resting_pass
			print("HAND DOCK 7-CARD BASELINE meter=%s pass=%s" % [stable_seven_meter, stable_seven_pass])
		_assert_pass_meter_layout(instance, "%d-card idle" % cards.size())
		await _save_root_screenshot("%s/dock_%d_card_idle.png" % [OUTPUT_DIR, cards.size()])
		for index: int in range(cards.size()):
			instance.call("_on_card_hover_started", index)
			await process_frame
			_assert(meter.visible and pass_chip.visible, "%d-card hover %d must keep the dock visible on its first transition frame" % [cards.size(), index + 1])
			_assert(_rect_approximately_equal(meter.get_global_rect(), resting_meter), "%d-card hover %d must not move the meter during its transition" % [cards.size(), index + 1])
			_assert(_rect_approximately_equal(pass_chip.get_global_rect(), resting_pass), "%d-card hover %d must not move Pass during its transition" % [cards.size(), index + 1])
			await create_timer(HandFanContainerScript.EMPHASIS_TRANSITION_SECONDS * 0.5).timeout
			_assert(meter.visible and pass_chip.visible, "%d-card hover %d must keep the dock visible through its transition" % [cards.size(), index + 1])
			_assert(_rect_approximately_equal(meter.get_global_rect(), resting_meter), "%d-card hover %d must not move the meter mid-transition" % [cards.size(), index + 1])
			_assert(_rect_approximately_equal(pass_chip.get_global_rect(), resting_pass), "%d-card hover %d must not move Pass mid-transition" % [cards.size(), index + 1])
			await _settle_ui()
			_assert(_rect_approximately_equal(meter.get_global_rect(), resting_meter), "%d-card hover %d must not move the card-play meter (idle=%s hover=%s)" % [cards.size(), index + 1, resting_meter, meter.get_global_rect()])
			_assert(_rect_approximately_equal(pass_chip.get_global_rect(), resting_pass), "%d-card hover %d must not move Pass (idle=%s hover=%s)" % [cards.size(), index + 1, resting_pass, pass_chip.get_global_rect()])
			_assert_pass_meter_layout(instance, "%d-card hover %d" % [cards.size(), index + 1])
			if index == cards.size() - 1:
				await _save_root_screenshot("%s/dock_%d_card_worst_hover.png" % [OUTPUT_DIR, cards.size()])
			instance.call("_on_card_hover_ended", index)
			await _settle_ui()
	# A real draw can change hand size before a hover animation clears. The final
	# dock must become the known seven-card resting geometry, not retain a stale
	# five-card position while the HandFanContainer settles its minimum size/sort.
	_assert(stable_seven_meter.size != Vector2.ZERO and stable_seven_pass.size != Vector2.ZERO, "Seven-card idle proof must establish the final dock baseline")
	var five_cards: Array = hand_sets[0] as Array
	await _load_combat_fixture(instance, five_cards, Vector2i(2, 4), [Vector2i(5, 4)], 9921)
	instance.call("_on_card_hover_started", 3)
	await _settle_ui()
	var changing_state: Dictionary = (instance.get("_combat_state") as Dictionary).duplicate(true)
	var changing_deck: Dictionary = (changing_state.get("deck", {}) as Dictionary).duplicate(true)
	changing_deck["hand"] = hand_sets[2].duplicate()
	changing_state["deck"] = changing_deck
	var changing_run: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	changing_run["combat_state"] = changing_state.duplicate(true)
	instance.set("_combat_state", changing_state)
	instance.set("_run_state", changing_run)
	instance.call("_refresh_ui")
	# Rebuild emphasis before the new fan has settled. This reproduces the real
	# draw-then-hover race: the pending geometry guard must transfer to the newer
	# revision instead of revealing the stale five-card dock.
	await process_frame
	var pending_revision_before: int = int(instance.get("_hand_layout_revision"))
	instance.call("_on_card_hover_started", 1)
	instance.call("_refresh_ui")
	await process_frame
	var pending_revision_after: int = int(instance.get("_hand_layout_revision"))
	_assert(pending_revision_after > pending_revision_before, "Hovering during a pending draw must rebuild the hand at a newer revision")
	_assert(int(instance.get("_hand_layout_pending_revision")) == pending_revision_after, "Hover rebuild must carry the pending fan layout into its newer revision")
	var pending_meter: Control = instance.get("_play_meter") as Control
	var pending_pass_overlay: Control = instance.get("_pass_preview_overlay") as Control
	_assert(pending_meter != null and pending_pass_overlay != null and not pending_meter.visible and not pending_pass_overlay.visible, "Hovering during a pending 5-to-7 draw must keep the stale dock hidden until the seven-card fan settles")
	await _settle_hand_dock_transition()
	var changed_meter: Control = instance.get("_play_meter") as Control
	var changed_pass: Control = instance.find_child("PassPreviewChip", true, false) as Control
	_assert(changed_meter != null and changed_pass != null, "Hovering hand-size-change proof must retain dock controls")
	if changed_meter != null and changed_pass != null:
		print("HAND DOCK 5-TO-7 FINAL meter=%s pass=%s" % [changed_meter.get_global_rect(), changed_pass.get_global_rect()])
		_assert(_rect_approximately_equal(changed_meter.get_global_rect(), stable_seven_meter), "Hovering 5-to-7-card change must settle the card-play meter at the stable seven-card dock (expected=%s actual=%s)" % [stable_seven_meter, changed_meter.get_global_rect()])
		_assert(_rect_approximately_equal(changed_pass.get_global_rect(), stable_seven_pass), "Hovering 5-to-7-card change must settle Pass at the stable seven-card dock (expected=%s actual=%s)" % [stable_seven_pass, changed_pass.get_global_rect()])
		_assert_pass_meter_layout(instance, "hovered 5-to-7-card change")
		await _save_root_screenshot("%s/hovered_hand_size_change.png" % OUTPUT_DIR)
		for hover_index: int in [0, 6]:
			instance.call("_on_card_hover_started", hover_index)
			await _settle_hand_dock_transition()
			_assert(_rect_approximately_equal(changed_meter.get_global_rect(), stable_seven_meter), "Post-draw hover %d must not move the settled seven-card meter" % [hover_index + 1])
			_assert(_rect_approximately_equal(changed_pass.get_global_rect(), stable_seven_pass), "Post-draw hover %d must not move settled seven-card Pass" % [hover_index + 1])
			_assert_pass_meter_layout(instance, "hovered 5-to-7-card post-draw hover %d" % [hover_index + 1])
			instance.call("_on_card_hover_ended", hover_index)
			await _settle_hand_dock_transition()

func _settle_hand_dock_transition() -> void:
	await create_timer(HandFanContainerScript.EMPHASIS_TRANSITION_SECONDS + 0.08).timeout
	await _settle_ui()

func _capture_no_hand_board_framing(instance: Node) -> void:
	for viewport_size: Vector2i in [PROBE_VIEWPORT, PRODUCTION_VIEWPORT]:
		DisplayServer.window_set_size(viewport_size)
		root.content_scale_size = viewport_size
		root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND if viewport_size == PRODUCTION_VIEWPORT else Window.CONTENT_SCALE_ASPECT_KEEP
		root.size = viewport_size
		var room_fixture: Dictionary = _load_room_exit_fixture(instance)
		await _settle_ui()
		var door_tile: Vector2i = room_fixture.get("door_tile", Vector2i(-1, -1))
		var destination: Vector2i = room_fixture.get("destination", Vector2i(-1, -1))
		_assert_room_exit_affordance(instance, viewport_size, door_tile, destination, false)
		var board_bounds: Rect2 = instance.call("_contextual_combat_rendered_board_bounds") as Rect2
		var viewport_rect := Rect2(Vector2.ZERO, Vector2(viewport_size))
		_assert(board_bounds.size.x > viewport_size.x * 0.55 and board_bounds.size.y > viewport_size.y * 0.45, "%s no-hand board should remain prominent" % viewport_size)
		_assert(board_bounds.position.y >= 8.0 and board_bounds.end.y <= viewport_rect.end.y - 12.0, "%s no-hand board visual bounds should stay fully onscreen (board=%s)" % [viewport_size, board_bounds])
		_assert(absf(board_bounds.get_center().y - viewport_rect.get_center().y) <= viewport_size.y * 0.16, "%s no-hand board should be roughly vertically centered (board=%s)" % [viewport_size, board_bounds])
		print("NO-HAND GEOMETRY %s board=%s" % [viewport_size, board_bounds])
		await _save_root_screenshot("%s/no_hand_room_%dx%d.png" % [OUTPUT_DIR, viewport_size.x, viewport_size.y], viewport_size)
		instance.call("_on_board_tile_hovered", door_tile)
		await _settle_ui()
		_assert_room_exit_affordance(instance, viewport_size, door_tile, destination, true)
		await _save_root_screenshot("%s/no_hand_room_exit_hover_%dx%d.png" % [OUTPUT_DIR, viewport_size.x, viewport_size.y], viewport_size)

func _load_room_exit_fixture(instance: Node) -> Dictionary:
	var current_coord := Vector2i(4, 3)
	var destination := Vector2i(4, 2)
	var door_direction := Vector2i(0, -1)
	var door_tile: Vector2i = RoomGenerator.door_tile_for_direction(door_direction)
	var layout: Dictionary = _room_layout(Vector2i(3, 4), [])
	var grid: Array = (layout.get("grid", []) as Array).duplicate(true)
	(grid[door_tile.y] as Array)[door_tile.x] = "door"
	layout["coord"] = current_coord
	layout["name"] = "Doorway Gallery"
	layout["type"] = "combat"
	layout["element"] = "fire"
	layout["grid"] = grid
	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run_state["mode"] = "room"
	run_state["current_room"] = current_coord
	run_state["current_room_layout"] = layout
	run_state["rooms"] = {
		"4,3": {
			"coord": current_coord,
			"name": "Doorway Gallery",
			"depth": 3,
			"type": "combat",
			"element": "fire",
			"revealed": true,
			"visited": true,
			"cleared": true,
			"sealed": false,
			"connections": [{"coord": destination, "door_dir": door_direction}]
		},
		"4,2": {
			"coord": destination,
			"name": "Gale Reliquary",
			"depth": 4,
			"type": "combat",
			"element": "air",
			"revealed": true,
			"visited": false,
			"cleared": false,
			"sealed": false,
			"connections": [{"coord": current_coord, "door_dir": Vector2i(0, 1)}]
		}
	}
	instance.set("_hovered_board_tile", Vector2i(-1, -1))
	instance.set("_run_state", run_state)
	instance.set("_combat_state", {})
	instance.set("_animation_lock", false)
	instance.call("_refresh_ui")
	return {"door_tile": door_tile, "destination": destination}

func _assert_room_exit_affordance(instance: Node, viewport_size: Vector2i, door_tile: Vector2i, destination: Vector2i, hovered: bool) -> void:
	var board: Control = instance.get_node(BOARD_PATH) as Control
	_assert(board != null, "%s room-exit proof needs the board" % viewport_size)
	if board == null:
		return
	var run_engine: Object = instance.get("_run_engine") as Object
	var exits: Array = run_engine.call("exit_options", instance.get("_run_state")) as Array if run_engine != null else []
	_assert(not exits.is_empty(), "%s room fixture must expose a real RunEngine exit" % viewport_size)
	var exit_tiles: Dictionary = board.get("exit_tiles") as Dictionary
	var exit_icons: Dictionary = board.get("exit_icon_ids") as Dictionary
	var destination_lookup: Dictionary = instance.get("_exit_destinations_by_tile") as Dictionary
	_assert(exit_tiles.has(door_tile) and exit_icons.has(door_tile), "%s board must preserve exit direction data and the established floating room icon for %s" % [viewport_size, door_tile])
	_assert(not board.has_method("_draw_exit_marker_for_tile"), "%s room exits should omit the redundant directional badge paint path" % viewport_size)
	_assert(destination_lookup.get(door_tile, Vector2i(-1, -1)) == destination, "%s exit tile must map to the legal destination" % viewport_size)
	var door_center: Vector2 = board.call("_tile_center", door_tile) as Vector2
	_assert(board.call("_tile_at_point", door_center) == door_tile, "%s exit tile must retain board hit-testing for pointer click" % viewport_size)
	var local_status_bounds: Rect2 = board.call("status_text_local_bounds") as Rect2
	var status_global_bounds: Rect2 = _global_rect_for_board_local_rect(board, local_status_bounds)
	print("ROOM EXIT STATUS %s hovered=%s bounds=%s" % [viewport_size, hovered, status_global_bounds])
	_assert(local_status_bounds.size.x > 0.0 and local_status_bounds.size.y > 0.0, "%s room navigation must draw centered status guidance (bounds=%s)" % [viewport_size, local_status_bounds])
	for header_bounds: Dictionary in _room_status_header_painted_bounds(instance):
		var painted_rect: Rect2 = header_bounds.get("rect", Rect2()) as Rect2
		_assert(not status_global_bounds.intersects(painted_rect), "%s drawn board status must clear %s (status=%s header=%s)" % [viewport_size, str(header_bounds.get("name", "header")), status_global_bounds, painted_rect])
	var presentation: Dictionary = board.get("presentation") as Dictionary
	_assert(str(presentation.get("status_typography_role", "")) == "hero", "%s Choose door guidance should use the shared hero typography role" % viewport_size)
	_assert(status_global_bounds.position.y >= 18.0 and status_global_bounds.size.y >= 38.0, "%s Choose door guidance should be prominent and lowered from the screen edge (bounds=%s)" % [viewport_size, status_global_bounds])
	if hovered:
		_assert((presentation.get("focus_tiles", []) as Array).has(door_tile), "%s hovered exit must enter the board focus treatment" % viewport_size)
		_assert(str(board.get("status_detail")) == "Air Combat 4", "%s hovered exit must name its destination in the centered status detail" % viewport_size)
	else:
		_assert(bool(presentation.get("pulse_exit_tiles", false)), "%s idle room must pulse the actual exit tile before it is hovered" % viewport_size)
		_assert(str(board.get("status_label")) == "Choose Door" and str(board.get("status_detail")).is_empty(), "%s idle room status must provide concise door guidance without stale hover detail" % viewport_size)

func _room_status_header_painted_bounds(instance: Node) -> Array[Dictionary]:
	var bounds: Array[Dictionary] = []
	# The header uses expansive containers for flex layout. Those rectangles are
	# deliberately wider than the visible title/depth glyphs, so collision proof
	# must use the actual painted labels plus interactive controls.
	for property_name: String in ["room_title", "room_subtitle", "umbra_subtitle", "stats_label"]:
		var label: Label = instance.get(property_name) as Label
		if label != null and label.visible and not label.text.is_empty():
			bounds.append({"name": label.name, "rect": _painted_label_global_rect(label)})
	for property_name: String in ["relic_bar", "loadout_button", "grimoire_button", "menu_button", "_skill_sigil"]:
		var control: Control = instance.get(property_name) as Control
		if control != null and control.visible:
			bounds.append({"name": control.name, "rect": control.get_global_rect()})
	return bounds

func _painted_label_global_rect(label: Label) -> Rect2:
	var font: Font = label.get_theme_font("font")
	if font == null:
		return label.get_global_rect()
	var font_size: int = label.get_theme_font_size("font_size")
	var text_size: Vector2 = font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var position: Vector2 = label.global_position
	if label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER:
		position.x += (label.size.x - text_size.x) * 0.5
	elif label.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT:
		position.x += label.size.x - text_size.x
	var outline: float = float(label.get_theme_constant("outline_size"))
	return Rect2(position - Vector2(outline, outline), text_size + Vector2(outline * 2.0, outline * 2.0))

func _global_rect_for_board_local_rect(board: Control, local_rect: Rect2) -> Rect2:
	if local_rect.size == Vector2.ZERO:
		return Rect2()
	var transform: Transform2D = board.get_global_transform()
	var global_top_left: Vector2 = transform * local_rect.position
	var global_bottom_right: Vector2 = transform * local_rect.end
	return Rect2(global_top_left, global_bottom_right - global_top_left)

func _capture_top_row_prop_framing(instance: Node) -> void:
	await _load_combat_fixture(instance, ["quick_stab", "sidestep_slash", "thunderline", "guarded_step", "patch_up"], Vector2i(2, 4), [Vector2i(3, 2)], 9931)
	var combat_state: Dictionary = (instance.get("_combat_state") as Dictionary).duplicate(true)
	var grid: Array = (combat_state.get("grid", []) as Array).duplicate(true)
	(grid[1] as Array)[3] = "wall" # Interior walls render as the tall pillar/column prop.
	combat_state["grid"] = grid
	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	var room_layout: Dictionary = (run_state.get("current_room_layout", {}) as Dictionary).duplicate(true)
	room_layout["grid"] = grid.duplicate(true)
	run_state["current_room_layout"] = room_layout
	run_state["combat_state"] = combat_state.duplicate(true)
	instance.set("_combat_state", combat_state)
	instance.set("_run_state", run_state)
	instance.call("_refresh_ui")
	await _settle_ui()
	var board: Control = instance.get_node(BOARD_PATH) as Control
	var local_visual_bounds: Rect2 = board.call("rendered_visual_bounds") as Rect2
	var visual_bounds: Rect2 = instance.call("_contextual_combat_rendered_board_bounds") as Rect2
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(PROBE_VIEWPORT))
	_assert(local_visual_bounds.size.y > 0.0 and visual_bounds.position.y >= 8.0 and visual_bounds.end.y <= viewport_rect.end.y - 12.0, "Top-row pillar/actor fixture must keep actual rendered prop bounds onscreen (bounds=%s)" % visual_bounds)
	_assert(float(board.call("_tile_width")) < 210.0, "Combat default zoom should back off from the old prop-clipping scale (tile_width=%.2f)" % float(board.call("_tile_width")))
	await _save_root_screenshot("%s/top_row_pillar_prop_bounds.png" % OUTPUT_DIR)

func _rect_approximately_equal(first: Rect2, second: Rect2, epsilon: float = 0.25) -> bool:
	return first.position.distance_to(second.position) <= epsilon and first.size.distance_to(second.size) <= epsilon

func _rect_is_onscreen(rect: Rect2) -> bool:
	var viewport := Rect2(Vector2.ZERO, get_root().get_visible_rect().size)
	return rect.position.x >= viewport.position.x and rect.position.y >= viewport.position.y and rect.end.x <= viewport.end.x and rect.end.y <= viewport.end.y

func _load_combat_fixture(instance: Node, hand: Array, player_pos: Vector2i, enemy_positions: Array, seed: int) -> void:
	instance.call("_cancel_drag_play")
	instance.call("_reset_card_resolution")
	var layout: Dictionary = _room_layout(player_pos, enemy_positions)
	var combat := CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(seed, layout, {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": hand.duplicate(),
		"relics": [],
		"hand_size": hand.size(),
		"heal_bonus": 0
	})
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = hand.duplicate()
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	combat_state["deck"] = deck
	combat_state["current_actor"] = {"kind": "player", "key": "player"}
	combat_state["cards_played_this_turn"] = 0
	combat_state["death_bonus_card_plays_this_turn"] = 0
	combat_state["card_play_bonus_this_turn"] = 0
	combat_state["traps"] = []
	combat_state["terrain"] = []
	var restrictions: Dictionary = (combat_state.get("player_turn_restrictions", {}) as Dictionary).duplicate(true)
	restrictions["immobilized"] = false
	restrictions["frozen"] = false
	restrictions["shocked"] = false
	combat_state["player_turn_restrictions"] = restrictions
	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run_state["mode"] = "combat"
	run_state["current_room"] = layout.get("coord", Vector2i.ZERO)
	run_state["current_room_layout"] = layout
	run_state["combat_state"] = combat_state
	instance.set("_run_state", run_state)
	instance.set("_combat_state", combat_state)
	instance.set("_animation_lock", false)
	instance.call("_refresh_ui")
	await _settle_hand_dock_transition()

func _choose_clicked_card_action(instance: Node, hand_index: int, play_kind: String) -> void:
	instance.call("_on_card_pressed", hand_index)
	await _settle_ui()
	_assert(int(instance.get("_card_action_choice_index")) == hand_index, "Click should open play-mode choices for the exact hand card")
	await instance.call("_on_card_action_choice_pressed", play_kind)
	await _settle_ui()

func _assert_drag_state(instance: Node) -> void:
	var overlay: Control = instance.get("_drag_overlay") as Control
	var context: Control = instance.get("_action_step_tracker") as Control
	_assert(overlay.visible and overlay.get_child_count() == 1, "Drag layer should contain only the held card proxy")
	_assert(context.visible and str(context.get_meta("context_mode", "")) == "drag", "Drag should use the compact action context")
	_assert(str(context.get_meta("drag_hover_zone", "")) == "play", "Battlefield drag should default to full-card play")
	var tutorial_host: Control = instance.get("_contextual_combat_prompt_host") as Control
	_assert(tutorial_host == null or not tutorial_host.visible, "Dragging should temporarily hide contextual onboarding so the action rail remains unobstructed")
	var verb_label: Label = instance.get("_action_context_verb_label") as Label
	_assert(verb_label != null and verb_label.text == "RELEASE TO PLAY", "Primary drag copy should stay terse and explicit")
	_assert(_label_text_fits(verb_label), "Primary drag copy should fit without ellipsis")
	var panels: Dictionary = instance.get("_drag_zone_panels")
	_assert(not panels.has("play"), "Full-card play should not create a central drop panel")
	for zone: String in ["attack", "move"]:
		var panel: Control = panels.get(zone, null) as Control
		_assert(panel != null and panel.custom_minimum_size.x <= 200.0 and panel.custom_minimum_size.y <= 64.0, "%s fallback should remain compact" % zone)
	var attack_label: Label = instance.get("_drag_zone_labels").get("attack", null) as Label
	var attack_detail: Label = instance.get("_drag_zone_detail_labels").get("attack", null) as Label
	_assert(attack_label != null and attack_label.text == "BASIC ATTACK", "Fallback attack title should avoid redundant Attack copy")
	var expected_attack_detail: String = str(instance.call("_fallback_command_detail", "attack")).to_upper() if bool(instance.call("_drag_option_valid", "attack")) else "UNAVAILABLE"
	_assert(attack_detail != null and attack_detail.text == expected_attack_detail, "Fallback attack detail should state the amount once")

func _assert_context(instance: Node, verb_fragment: String, step_text: String, label: String) -> void:
	var context: Control = instance.get("_action_step_tracker") as Control
	var step_label: Label = instance.get("_action_context_step_label") as Label
	var detail_row: Control = instance.get("_action_context_detail_row") as Control
	var status_row: Control = instance.get("_action_context_status_row") as Control
	_assert(context.visible, "%s should show action context" % label)
	_assert(str(context.get_meta("action_verb", "")).contains(verb_fragment), "%s should show verb %s" % [label, verb_fragment])
	_assert(detail_row != null and not detail_row.visible, "%s should omit the redundant action-description row" % label)
	_assert(status_row != null and not status_row.visible, "%s should omit target-validity and turn-end copy" % label)
	_assert(step_label != null and step_label.text == step_text, "%s should show %s" % [label, step_text])
	var cancel_button: Button = _button_with_text(context, "Cancel")
	_assert(cancel_button != null, "%s should keep Cancel in context" % label)
	_assert(cancel_button != null and cancel_button.get_global_rect().size.x > 8.0 and cancel_button.get_global_rect().size.y > 8.0, "%s Cancel should have a settled visible layout" % label)

func _assert_hud_collision_free(instance: Node) -> void:
	var context: Control = instance.get("_action_step_tracker") as Control
	var board: Control = instance.get_node(BOARD_PATH) as Control
	var mini_map: Control = instance.get_node(MINI_MAP_PATH) as Control
	var log_overlay: Control = instance.get_node(LOG_PATH) as Control
	var hand_box: Control = instance.get_node(HAND_PATH) as Control
	var context_rect: Rect2 = context.get_global_rect()
	var board_rect: Rect2 = board.get_global_rect()
	var viewport_rect: Rect2 = instance.get_viewport().get_visible_rect()
	_assert(viewport_rect.encloses(context_rect), "Action context should stay inside the viewport under HUD stress")
	_assert(not mini_map.visible, "Combat should hide the compact minimap and reclaim its board corner")
	_assert(not log_overlay.visible, "Normal combat should not reserve a persistent combat-log panel")
	_assert_compact_pile_controls(instance)
	var board_overlap: Rect2 = context_rect.intersection(board_rect)
	_assert(board_overlap.get_area() <= board_rect.get_area() * 0.12, "Action context should preserve at least 88% of the battlefield control area")
	var selected_card: Control = _hand_card_control(hand_box, int(instance.get("_selected_card_index")))
	var hand_visual_top: float = _hand_visual_top(hand_box)
	_assert(selected_card != null and context_rect.end.y <= hand_visual_top + 1.0, "Action context should sit above the entire rendered hand, including rotated card titles and ornaments")
	var card_anchor: Rect2 = instance.call("_action_step_tracker_anchor_rect") as Rect2
	_assert(absf(context_rect.get_center().x - card_anchor.get_center().x) <= 48.0, "Action context should remain visually connected to the active hand card")
	_assert(card_anchor.position.y - context_rect.end.y <= 24.0, "Action context should stay close to the cards instead of floating beside the board")

func _assert_full_hd_normal_hud(instance: Node) -> void:
	var board_bounds: Rect2 = instance.call("_contextual_combat_rendered_board_bounds") as Rect2
	var hand_top: float = float(instance.call("_hand_visual_top"))
	if DisplayServer.get_name() == "headless":
		print("HUD GEOMETRY 1920x1080 (headless layout) board=%s hand_top=%.1f gap=%.1f" % [board_bounds, hand_top, hand_top - board_bounds.end.y])
		return
	var viewport: Vector2 = instance.get_viewport().get_visible_rect().size
	_assert(viewport == Vector2(PROBE_VIEWPORT), "Combat HUD proof must use an exact 1920x1080 logical viewport")
	var tutorial: Control = instance.get("_contextual_combat_prompt_host") as Control
	_assert(tutorial == null or not tutorial.visible, "Normal combat proof must not show the transient COMBAT NOTE tutorial")
	_assert(board_bounds.size.x >= viewport.x * 0.59 and board_bounds.size.y >= viewport.y * 0.52, "Normal combat board should remain the dominant 59%% x 52%% playfield while safely framing tall props (got %.1f%% x %.1f%%)" % [board_bounds.size.x / viewport.x * 100.0, board_bounds.size.y / viewport.y * 100.0])
	_assert(board_bounds.position.y <= viewport.y * 0.15, "Normal combat board should begin within the top 15%% of the viewport after the complete-view correction (got %.1f%% / %.0fpx)" % [board_bounds.position.y / viewport.y * 100.0, board_bounds.position.y])
	var hand_box: Control = instance.get_node(HAND_PATH) as Control
	var hand_bounds := Rect2()
	var has_hand_bounds: bool = false
	var fixture_card_width: float = 0.0
	for index: int in range(hand_box.get_child_count()):
		var card: Control = _hand_card_control(hand_box, index)
		if card == null:
			continue
		fixture_card_width = maxf(fixture_card_width, card.size.x * card.get_global_transform().get_scale().x)
		var rect: Rect2 = card.get_global_rect()
		hand_bounds = rect if not has_hand_bounds else hand_bounds.merge(rect)
		has_hand_bounds = true
	# CardScaleFrame applies a floating-point transform; retain the authored 208px
	# ceiling while allowing sub-pixel transform noise, never a 209px card.
	_assert(fixture_card_width > 203.5 and fixture_card_width <= 208.5, "Five-card combat fixture should use cards just above the original 204px width (got %.2fpx rendered)" % fixture_card_width)
	_assert(has_hand_bounds and hand_bounds.size.y <= viewport.y * 0.36, "Five-card combat fan should stay below 36%% of viewport height (got %.1f%% / %.0fpx)" % [hand_bounds.size.y / viewport.y * 100.0, hand_bounds.size.y])
	_assert(board_bounds.position.y >= 8.0, "Default board framing should not crop the top rendered tiles at 1920x1080 (board=%s hand_top=%.1f)" % [board_bounds, hand_top])
	_assert(hand_top >= board_bounds.end.y + 36.0, "Default board framing should leave at least 36px between the rendered board and hand at 1920x1080 (board=%s hand_top=%.1f)" % [board_bounds, hand_top])
	print("HUD GEOMETRY 1920x1080 board=%s hand_top=%.1f gap=%.1f" % [board_bounds, hand_top, hand_top - board_bounds.end.y])
	var meter: Control = instance.get("_play_meter") as Control
	var pass_chip: Control = instance.find_child("PassPreviewChip", true, false) as Control
	_assert(meter != null and meter.visible and pass_chip != null and pass_chip.visible, "Normal combat should show the separate card-play and Pass forecast dock")
	if meter != null and pass_chip != null:
		_assert(pass_chip.get_global_rect().position.y >= meter.get_global_rect().end.y + 5.0, "Pass forecast must stay separated below the card-play plaque")

func _assert_dense_turn_order_rail(instance: Node) -> void:
	var rail: Control = instance.get("_turn_order_bar") as Control
	var slots: Array[Control] = []
	if rail != null:
		for child: Node in rail.get_children():
			var slot: Control = child as Control
			if slot != null and slot.has_meta("turn_order_rail_index") and slot.find_child("TurnOrderPortraitCrop", true, false) != null:
				slots.append(slot)
	_assert(slots.size() >= 10, "Dense combat proof should expose at least ten individual initiative portraits")
	if rail == null:
		return
	var rail_bottom: float = -INF
	for slot: Control in slots:
		_assert(slot.size.x >= 74.0 and slot.size.y >= 55.0, "Dense initiative entries must remain readable portrait controls")
		var slot_panel: PanelContainer = slot.get_child(0) as PanelContainer if slot.get_child_count() > 0 else null
		var slot_style: StyleBoxFlat = slot_panel.get_theme_stylebox("panel") as StyleBoxFlat if slot_panel != null else null
		var backing: TextureRect = slot.find_child("TurnOrderBrushBacking", true, false) as TextureRect
		_assert(backing != null and str(slot.get_meta("turn_order_art_hook", "")) == "brush_backing_v2", "Dense initiative rail should give every portrait the abstract brush backing")
		_assert(backing == null or (not slot.clip_contents and slot_panel != null and not slot_panel.clip_contents and not backing.clip_contents), "Dense initiative brush backings should not be cut off by a clipping ancestor")
		_assert(slot.find_child("TurnOrderActiveFrameArtHost", true, false) == null and slot.find_child("TurnOrderQueuedFrameArtHost", true, false) == null, "Dense initiative rail should not reintroduce rectangular frame art")
		var team: String = str(slot.get_meta("turn_order_team", "enemy"))
		_assert(backing == null or (team == "player" and backing.modulate.b > backing.modulate.r) or (team != "player" and backing.modulate.r > backing.modulate.b), "Dense initiative backings should distinguish player blue from enemy red without bright saturation")
		_assert(backing == null or backing.modulate.a <= 0.67, "Dense initiative backing tint should remain visually subdued")
		_assert(slot_style != null and slot_style.bg_color.a <= 0.001 and slot_style.border_color.a <= 0.001 and slot_style.shadow_size == 0, "Dense initiative slot surfaces should be transparent and borderless")
		rail_bottom = maxf(rail_bottom, slot.get_global_rect().end.y)
	var meter: Control = instance.get("_play_meter") as Control
	_assert(meter != null and not rail.get_global_rect().intersects(meter.get_global_rect()), "Dense initiative rail should remain separate from the fixed left-side action dock" if meter != null else "Dense initiative rail needs its action dock")
	var utility_bottom: float = float(instance.call("_utility_stack_visible_bottom"))
	if slots.size() > 0 and utility_bottom > -INF:
		_assert(slots[0].get_global_rect().position.y >= utility_bottom + 12.0, "First initiative portrait should clear the actual visible utility buttons and badges")

func _capture_production_aspect_geometry(instance: Node) -> void:
	DisplayServer.window_set_size(PRODUCTION_VIEWPORT)
	root.content_scale_size = PRODUCTION_VIEWPORT
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.size = PRODUCTION_VIEWPORT
	await _settle_ui()
	await _load_combat_fixture(
		instance,
		["quick_stab", "sidestep_slash", "thunderline", "guarded_step", "patch_up"],
		Vector2i(2, 4),
		[Vector2i(3, 2), Vector2i(4, 2), Vector2i(5, 2), Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3), Vector2i(5, 3), Vector2i(3, 4), Vector2i(4, 4)],
		9811
	)
	var live_state: Dictionary = (instance.get("_combat_state") as Dictionary).duplicate(true)
	live_state["skill_ids"] = ["quick_wits"]
	var live_run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	live_run_state["combat_state"] = live_state.duplicate(true)
	instance.set("_combat_state", live_state)
	instance.set("_run_state", live_run_state)
	instance.call("_refresh_ui")
	instance.call("_refresh_relic_bar")
	instance.call("_layout_header_hud")
	await _settle_ui()
	var ability_sigil: Button = instance.get("_skill_sigil") as Button
	var ability_title: Label = ability_sigil.find_child("SkillSigilTitle", true, false) as Label if ability_sigil != null else null
	_assert(ability_sigil != null and ability_sigil.visible and ability_title != null and ability_title.text == "ABILITIES", "Production geometry proof should enable the live ABILITIES header panel")
	var loadout_badge: Control = instance.get("_loadout_badge") as Control
	var grimoire_badge: Control = instance.get("_grimoire_badge") as Control
	if loadout_badge != null:
		loadout_badge.visible = true
	if grimoire_badge != null:
		grimoire_badge.visible = true
	instance.call("_layout_turn_order_anchor")
	await _settle_ui()
	_assert(instance.get_viewport().get_visible_rect().size == Vector2(PRODUCTION_VIEWPORT), "Production geometry proof must use the live 1920x1227 expanded-aspect canvas")
	_assert_dense_turn_order_rail(instance)
	_assert_pass_meter_layout(instance, "production expanded-aspect")
	var board_bounds: Rect2 = instance.call("_contextual_combat_rendered_board_bounds") as Rect2
	var hand_top: float = float(instance.call("_hand_visual_top"))
	await _save_root_screenshot("%s/production_live_1920x1227.png" % OUTPUT_DIR, PRODUCTION_VIEWPORT)
	_assert(board_bounds.position.y >= 120.0 and board_bounds.position.y <= 190.0, "Production board should begin in the complete-view upper framing band (board=%s)" % board_bounds)
	_assert(board_bounds.size.x >= 1320.0 and board_bounds.size.x <= 1420.0 and board_bounds.size.y >= 660.0 and board_bounds.size.y <= 710.0, "Production board should remain dominant while backing off from the former prop-clipping zoom (board=%s)" % board_bounds)
	var production_gap: float = hand_top - board_bounds.end.y
	_assert(production_gap >= 24.0 and production_gap <= 80.0, "Production board should end just above the hand with a clear but compact gap (board=%s hand_top=%.1f gap=%.1f)" % [board_bounds, hand_top, production_gap])
	print("HUD GEOMETRY 1920x1227 board=%s hand_top=%.1f gap=%.1f" % [board_bounds, hand_top, hand_top - board_bounds.end.y])

func _assert_compact_pile_controls(instance: Node) -> void:
	for pile_name: String in ["draw_pile", "discard_pile"]:
		var pile: Control = instance.get(pile_name) as Control
		_assert(pile != null and pile.visible, "%s should remain a visible combat pile control" % pile_name)
		if pile == null:
			continue
		_assert(pile.focus_mode != Control.FOCUS_NONE and pile.mouse_filter == Control.MOUSE_FILTER_STOP, "%s should remain keyboard and pointer accessible" % pile_name)
		_assert(pile.get_combined_minimum_size().x <= 116.0, "%s should stay compact beside the enlarged hand" % pile_name)

func _hand_card_control(hand_box: Control, index: int) -> Control:
	if hand_box == null or index < 0 or index >= hand_box.get_child_count():
		return null
	var slot: Control = hand_box.get_child(index) as Control
	if slot != null and slot.get_child_count() > 0 and slot.get_child(0) is Control:
		return slot.get_child(0) as Control
	return slot

func _hand_visual_top(hand_box: Control) -> float:
	var visual_top: float = INF
	for index: int in range(hand_box.get_child_count()):
		var card: Control = _hand_card_control(hand_box, index)
		if card == null or not card.visible:
			continue
		var transform: Transform2D = card.get_global_transform()
		for corner: Vector2 in [Vector2.ZERO, Vector2(card.size.x, 0.0), card.size, Vector2(0.0, card.size.y)]:
			visual_top = minf(visual_top, (transform * corner).y)
	return visual_top

func _button_with_text(root_node: Node, text: String) -> Button:
	if root_node == null:
		return null
	for node: Node in root_node.find_children("*", "Button", true, false):
		var button: Button = node as Button
		if button != null and button.text == text:
			return button
	return null

func _label_text_fits(label: Label) -> bool:
	if label == null:
		return false
	var font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	return font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x <= label.size.x + 1.0

func _room_layout(player_pos: Vector2i, enemy_positions: Array) -> Dictionary:
	var enemies: Array = []
	for index: int in range(enemy_positions.size()):
		enemies.append({
			"id": index + 1,
			"type": "crawler",
			"pos": enemy_positions[index],
			"hp": 140,
			"max_hp": 140,
			"block": 0
		})
	return {
		"name": "Combat Interaction Probe",
		"coord": Vector2i(4, 3),
		"type": "combat",
		"grid": _simple_grid(),
		"player_start": player_pos,
		"enemies": enemies,
		"traps": [],
		"terrain": [],
		"loot": []
	}

func _simple_grid() -> Array:
	var grid: Array = []
	for y: int in range(8):
		var row: Array = []
		for x: int in range(8):
			row.append("wall" if x == 0 or y == 0 or x == 7 or y == 7 else "stone")
		grid.append(row)
	return grid

func _settle_ui() -> void:
	await process_frame
	await process_frame
	RenderingServer.force_draw()
	await process_frame

func _save_root_screenshot(output_path: String, expected_size: Vector2i = PROBE_VIEWPORT) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var texture: Texture2D = root.get_viewport().get_texture()
	var image: Image = texture.get_image()
	_assert(image != null, "Combat HUD proof should capture a renderer image")
	if image == null:
		return
	var source_size: Vector2i = image.get_size()
	var scale_x: float = float(source_size.x) / float(expected_size.x)
	var scale_y: float = float(source_size.y) / float(expected_size.y)
	var valid_backing_size: bool = is_equal_approx(scale_x, scale_y) and is_equal_approx(float(source_size.x) / float(source_size.y), float(expected_size.x) / float(expected_size.y))
	_assert(valid_backing_size, "Combat HUD proof must preserve the expected proportional backing, got %s for %s (scale %.4f x %.4f)" % [source_size, expected_size, scale_x, scale_y])
	if not valid_backing_size:
		return
	if source_size != expected_size:
		image.resize(expected_size.x, expected_size.y, Image.INTERPOLATE_LANCZOS)
	image.save_png(output_path)

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)

func _clear_probe_output(output_dir: String) -> void:
	_clear_probe_output_absolute(ProjectSettings.globalize_path(output_dir))

func _clear_probe_output_absolute(absolute_dir: String) -> void:
	var dir := DirAccess.open(absolute_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var entry: String = dir.get_next()
		if entry.is_empty():
			break
		if entry in [".", ".."]:
			continue
		var child_path: String = absolute_dir.path_join(entry)
		if dir.current_is_dir():
			_clear_probe_output_absolute(child_path)
			DirAccess.remove_absolute(child_path)
		else:
			DirAccess.remove_absolute(child_path)
	dir.list_dir_end()
