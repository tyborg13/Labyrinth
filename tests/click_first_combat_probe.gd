extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")
const GameData = preload("res://scripts/game_data.gd")
const ContextualCombatTutorial = preload("res://scripts/contextual_combat_tutorial.gd")

const OUTPUT_DIR: String = "user://probes/ui_stable_tutorial_click_fallbacks_v2"
const STABLE_PROOF_DIR_ENV: String = "LABYRINTH_CLICK_PROOF_DIR"
const STORAGE_PATH: String = "user://click_first_combat_probe_progression.json"
const RUN_STORAGE_PATH: String = "user://click_first_combat_probe_run.save"
const SETTINGS_PATH: String = "user://click_first_combat_probe_settings.json"
const INVALID_TARGET_TILE: Vector2i = Vector2i(-1, -1)

var _failed: bool = false
var _stable_proof_dir: String = ""

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	ProgressionStore.set_storage_path(STORAGE_PATH)
	ProgressionStore.set_run_storage_path(RUN_STORAGE_PATH)
	SettingsStore.set_storage_path(SETTINGS_PATH)
	_stable_proof_dir = OS.get_environment(STABLE_PROOF_DIR_ENV).strip_edges()
	var settings: Dictionary = SettingsStore.default_settings()
	settings["display_mode"] = SettingsStore.DISPLAY_WINDOWED
	SettingsStore.save_settings(settings)
	root.mode = Window.MODE_WINDOWED
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_clear_probe_output(OUTPUT_DIR)
	var requested_state: String = OS.get_environment("LABYRINTH_CLICK_PROOF_STATE").strip_edges()
	if not requested_state.is_empty():
		var requested_size := Vector2i(
			maxi(640, int(OS.get_environment("LABYRINTH_CLICK_PROOF_WIDTH"))),
			maxi(480, int(OS.get_environment("LABYRINTH_CLICK_PROOF_HEIGHT")))
		)
		await _capture_single_state(requested_size, requested_state)
		print(ProjectSettings.globalize_path(OUTPUT_DIR))
		quit(1 if _failed else 0)
		return
	for viewport_size: Vector2i in _proof_viewports():
		await _capture_resolution(viewport_size)
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	quit(1 if _failed else 0)

func _proof_viewports() -> Array:
	var result: Array = []
	result.append(Vector2i(1280, 720))
	result.append(Vector2i(1920, 1080))
	return result

func _capture_single_state(viewport_size: Vector2i, proof_state: String) -> void:
	_remove_if_present(STORAGE_PATH)
	_remove_if_present(RUN_STORAGE_PATH)
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	if packed == null:
		_fail("Run scene should load for %s proof" % proof_state)
		return
	var capture_viewport := SubViewport.new()
	capture_viewport.name = "ClickFirstProofViewport"
	capture_viewport.size = viewport_size
	capture_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(capture_viewport)
	var instance: Node = packed.instantiate()
	capture_viewport.add_child(instance)
	await _settle_ui()
	_assert(instance.get_viewport().get_visible_rect().size == Vector2(viewport_size), "%s proof viewport should settle at exact logical size %s, got %s" % [proof_state, viewport_size, instance.get_viewport().get_visible_rect().size])
	var output_dir: String = "%s/%dx%d" % [OUTPUT_DIR, viewport_size.x, viewport_size.y]
	var stable_dir: String = "" if _stable_proof_dir.is_empty() else "%s/%dx%d" % [_stable_proof_dir, viewport_size.x, viewport_size.y]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	if not stable_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(stable_dir))
	var file_name: String = ""
	match proof_state:
		"idle_tutorial":
			await _load_combat_fixture(instance, ["sidestep_slash", "quick_stab", "patch_up"], Vector2i(2, 4), [Vector2i(3, 4)], 17201, true)
			await _assert_tutorial_geometry_stable(instance, "%s idle tutorial" % viewport_size)
			_assert_tutorial_clear_of_play(instance, "%s idle tutorial" % viewport_size)
			_assert_idle_tutorial_pass_preview_clear(instance, "%s idle tutorial" % viewport_size)
			file_name = "01_idle_tutorial.png"
		"clicked_card_choices":
			await _load_combat_fixture(instance, ["sidestep_slash", "quick_stab", "patch_up"], Vector2i(2, 4), [Vector2i(3, 4)], 17202, true)
			instance.call("_on_card_pressed", 0)
			await _settle_ui()
			_assert_choice_state(instance, 0, "%s clicked choices" % viewport_size)
			_assert_tutorial_clear_of_play(instance, "%s clicked choices" % viewport_size)
			file_name = "02_clicked_card_choices.png"
		"attack_target":
			await _load_combat_fixture(instance, ["guarded_step", "quick_stab", "patch_up"], Vector2i(2, 4), [Vector2i(3, 4)], 17203, false)
			await _choose_clicked_action(instance, 1, "attack")
			_assert_board_usable_and_visible(instance, "%s attack target" % viewport_size)
			file_name = "03_attack_target.png"
		"move_target":
			await _load_combat_fixture(instance, ["guarded_step", "quick_stab", "patch_up"], Vector2i(2, 4), [Vector2i(6, 4)], 17204, false)
			await _choose_clicked_action(instance, 1, "move")
			_assert_board_usable_and_visible(instance, "%s move target" % viewport_size)
			file_name = "04_move_target.png"
		"compound_target":
			await _load_combat_fixture(instance, ["sidestep_slash", "quick_stab", "patch_up"], Vector2i(2, 4), [Vector2i(3, 4)], 17205, true)
			await _choose_clicked_action(instance, 0, "play")
			await instance.call("_on_skip_action_pressed")
			await _settle_ui()
			_assert_board_usable_and_visible(instance, "%s compound target" % viewport_size)
			_assert_tutorial_clear_of_play(instance, "%s compound target" % viewport_size)
			file_name = "05_compound_target.png"
		"drag_play_state":
			await _load_combat_fixture(instance, ["sidestep_slash", "quick_stab"], Vector2i(2, 4), [Vector2i(5, 4)], 17206, false)
			instance.call("_on_card_drag_started", 0)
			await _settle_ui()
			instance.set("_drag_card_grab_offset", Vector2(125.0, 176.0))
			var drag_position := Vector2(float(viewport_size.x) - 140.0, float(viewport_size.y) - 180.0)
			instance.call("_update_drag_proxy_position", drag_position)
			instance.call("_update_drag_overlay_hover", "play")
			await _settle_ui()
			_assert_board_usable_and_visible(instance, "%s drag play" % viewport_size)
			file_name = "06_drag_play_state.png"
		_:
			_fail("Unknown click-first proof state %s" % proof_state)
	if not file_name.is_empty():
		_hide_fixture_debug_ui(instance)
		await _settle_ui()
		var stable_output_path: String = "" if stable_dir.is_empty() else "%s/%s" % [stable_dir, file_name]
		await _save_screenshot(instance, "%s/%s" % [output_dir, file_name], viewport_size, stable_output_path)
	instance.queue_free()
	await process_frame
	capture_viewport.queue_free()
	await process_frame

func _capture_resolution(viewport_size: Vector2i) -> void:
	_remove_if_present(STORAGE_PATH)
	_remove_if_present(RUN_STORAGE_PATH)
	root.content_scale_size = viewport_size
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.size = viewport_size
	await process_frame
	await process_frame
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	if packed == null:
		_fail("Run scene should load at %s" % viewport_size)
		return
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	root.size = viewport_size
	await _settle_ui()
	_assert(root.get_viewport().get_visible_rect().size == Vector2(viewport_size), "Viewport should settle at exact proof size %s" % viewport_size)
	var output_dir: String = "%s/%dx%d" % [OUTPUT_DIR, viewport_size.x, viewport_size.y]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))

	await _load_combat_fixture(instance, ["sidestep_slash", "quick_stab", "patch_up"], Vector2i(2, 4), [Vector2i(3, 4)], 17101, true)
	_assert(str(instance.get("_active_contextual_combat_prompt_id")) == ContextualCombatTutorial.FULL_CARD_FALLBACK, "Idle proof should begin on the full-card tutorial note")
	await _assert_tutorial_geometry_stable(instance, "%s idle tutorial" % viewport_size)
	_assert_tutorial_clear_of_play(instance, "%s idle tutorial" % viewport_size)
	_assert_idle_tutorial_pass_preview_clear(instance, "%s idle tutorial" % viewport_size)
	await _save_screenshot(instance, "%s/01_idle_tutorial.png" % output_dir, viewport_size)

	var idle_hand: Array = _hand(instance)
	var idle_risk: Dictionary = instance.call("_pass_preview_summary")
	instance.call("_on_card_pressed", 0)
	await _settle_ui()
	_assert_choice_state(instance, 0, "%s clicked choices" % viewport_size)
	_assert(_hand(instance) == idle_hand, "Opening choices must not consume or reorder the hand")
	_assert((instance.call("_pass_preview_summary") as Dictionary) == idle_risk, "Opening choices must not change pass-risk forecasting")
	_assert_tutorial_clear_of_play(instance, "%s clicked choices" % viewport_size)
	await _save_screenshot(instance, "%s/02_clicked_card_choices.png" % output_dir, viewport_size)
	instance.call("_on_cancel_requested")
	await _settle_ui()
	_assert(int(instance.get("_card_action_choice_index")) == -1 and int(instance.get("_selected_card_index")) == -1, "Cancel should close clicked choices to idle")
	_assert(_hand(instance) == idle_hand, "Canceling clicked choices must preserve the hand")

	instance = await _replace_instance(instance, packed, viewport_size)
	await _load_combat_fixture(instance, ["sidestep_slash", "quick_stab", "patch_up"], Vector2i(2, 4), [Vector2i(3, 4)], 17107, true)
	await _choose_clicked_action(instance, 0, "play")
	var compound_actions: Array = instance.get("_pending_actions")
	_assert(compound_actions.size() == 2, "Clicked Full Card should preserve both printed compound steps")
	_assert(str((compound_actions[0] as Dictionary).get("type", "")) == "move" and str((compound_actions[1] as Dictionary).get("type", "")) == "melee", "Clicked Full Card should preserve printed move-then-melee order")
	_assert(bool(instance.call("_current_action_can_skip")), "Compound fixture should expose its optional first step")
	await instance.call("_on_skip_action_pressed")
	await _settle_ui()
	_assert(int(instance.get("_pending_action_index")) == 1, "Skip should advance the clicked full card to its second step")
	var compound_targets: Array = instance.get("_pending_selected_targets") as Array
	_assert(not compound_targets.is_empty() and compound_targets[0] == INVALID_TARGET_TILE, "Skip should preserve the optional-step placeholder")
	await _save_screenshot(instance, "%s/05_compound_target.png" % output_dir, viewport_size)
	instance.call("_on_cancel_requested")
	await _settle_ui()
	_assert(_hand(instance) == idle_hand, "Canceling compound targeting must leave the selected card unconsumed")

	instance = await _replace_instance(instance, packed, viewport_size)
	await _load_combat_fixture(instance, ["guarded_step", "quick_stab", "patch_up"], Vector2i(2, 4), [Vector2i(3, 4)], 17102, false)
	await _choose_clicked_action(instance, 1, "attack")
	_assert(int(instance.get("_selected_card_index")) == 1, "Clicked Basic Attack should retain the exact source-card index")
	_assert(str(instance.get("_selected_card_label_override")) == "20 Attack", "Clicked Basic Attack should be clearly identified as a fallback")
	var attack_actions: Array = instance.get("_pending_actions")
	_assert(attack_actions.size() == 1 and int((attack_actions[0] as Dictionary).get("damage", 0)) == int(instance.call("_fallback_attack_damage")), "Clicked Basic Attack should use fallback damage, not printed damage")
	var attack_targets: Array = instance.get("_pending_target_tiles") as Array
	_assert(attack_targets.has(Vector2i(3, 4)), "Clicked Basic Attack should preserve legal adjacent targets")
	var attack_state_before_invalid: Dictionary = (instance.get("_combat_state") as Dictionary).duplicate(true)
	await instance.call("_on_board_tile_clicked", Vector2i(0, 0))
	_assert((instance.get("_combat_state") as Dictionary) == attack_state_before_invalid and int(instance.get("_selected_card_index")) == 1, "Invalid Basic Attack targets must not mutate or cancel selection")
	await _save_screenshot(instance, "%s/03_attack_target.png" % output_dir, viewport_size)
	instance.call("_on_cancel_requested")
	await _settle_ui()
	_assert(_hand(instance) == ["guarded_step", "quick_stab", "patch_up"], "Canceling Basic Attack targeting should preserve the exact hand")

	instance = await _replace_instance(instance, packed, viewport_size)
	await _load_combat_fixture(instance, ["guarded_step", "quick_stab", "patch_up"], Vector2i(2, 4), [Vector2i(6, 4)], 17103, false)
	await _choose_clicked_action(instance, 1, "move")
	_assert(int(instance.get("_selected_card_index")) == 1, "Clicked Basic Move should retain the exact source-card index")
	_assert(str(instance.get("_selected_card_label_override")) == "2 Move", "Clicked Basic Move should be clearly identified as a fallback")
	var move_actions: Array = instance.get("_pending_actions")
	_assert(move_actions.size() == 1 and str((move_actions[0] as Dictionary).get("type", "")) == "move", "Clicked Basic Move should use the one-step fallback move")
	var move_targets: Array = instance.get("_pending_target_tiles") as Array
	_assert(not move_targets.is_empty(), "Clicked Basic Move should preserve legal board targets")
	await _save_screenshot(instance, "%s/04_move_target.png" % output_dir, viewport_size)
	instance.call("_on_cancel_requested")
	await _settle_ui()
	_assert(_hand(instance) == ["guarded_step", "quick_stab", "patch_up"], "Canceling Basic Move targeting should preserve the exact hand")

	instance = await _replace_instance(instance, packed, viewport_size)
	await _load_combat_fixture(instance, ["sidestep_slash", "quick_stab"], Vector2i(2, 4), [Vector2i(5, 4)], 17104, false)
	instance.call("_on_card_drag_started", 0)
	await _settle_ui()
	var board: Control = instance.get("board_view") as Control
	var drag_position: Vector2 = board.get_global_rect().get_center()
	instance.call("_update_drag_proxy_position", drag_position)
	instance.call("_update_drag_overlay_hover", instance.call("_drag_zone_at", drag_position))
	await _settle_ui()
	_assert(int(instance.get("_drag_card_index")) == 0 and int(instance.get("_card_action_choice_index")) == -1, "Dragging should bypass clicked choices and retain the exact source card")
	_assert(str(instance.call("_drag_zone_at", drag_position)) == "play", "Dragging over the board should remain the direct Full Card path")
	await _save_screenshot(instance, "%s/06_drag_play_state.png" % output_dir, viewport_size)
	await instance.call("_commit_drag_drop", "play")
	await _settle_ui()
	var drag_actions: Array = instance.get("_pending_actions")
	_assert(int(instance.get("_selected_card_index")) == 0 and str(instance.get("_selected_card_label_override")).is_empty(), "Drag Full Card should enter printed targeting without a fallback label")
	_assert(drag_actions.size() == 2 and str((drag_actions[0] as Dictionary).get("type", "")) == "move" and str((drag_actions[1] as Dictionary).get("type", "")) == "melee", "Drag Full Card should preserve printed compound actions")
	instance.call("_on_cancel_requested")
	await _settle_ui()
	await _assert_clicked_fallback_consumption(instance, "attack", 17105)
	await _assert_clicked_fallback_consumption(instance, "move", 17106)

	instance.queue_free()
	await process_frame
	await process_frame

func _replace_instance(current: Node, packed: PackedScene, viewport_size: Vector2i) -> Node:
	if current != null and is_instance_valid(current):
		current.queue_free()
		await process_frame
		await process_frame
	var next_instance: Node = packed.instantiate()
	root.add_child(next_instance)
	root.content_scale_size = viewport_size
	root.size = viewport_size
	await _settle_ui()
	return next_instance

func _load_combat_fixture(instance: Node, hand: Array, player_pos: Vector2i, enemy_positions: Array, seed: int, fresh_tutorial: bool) -> void:
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
	combat_state["log"] = []
	var restrictions: Dictionary = (combat_state.get("player_turn_restrictions", {}) as Dictionary).duplicate(true)
	restrictions["immobilized"] = false
	restrictions["frozen"] = false
	restrictions["shocked"] = false
	combat_state["player_turn_restrictions"] = restrictions
	var progression: Dictionary = ProgressionStore.default_data()
	progression["run_counter"] = 1
	if not fresh_tutorial:
		var states: Dictionary = {}
		for prompt_id: String in ContextualCombatTutorial.prompt_ids():
			states[prompt_id] = ContextualCombatTutorial.STATUS_COMPLETED
		progression[ContextualCombatTutorial.PROGRESSION_KEY] = states
	instance.set("_progression", progression)
	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run_state["mode"] = "combat"
	run_state["current_room"] = layout.get("coord", Vector2i.ZERO)
	run_state["current_room_layout"] = layout
	run_state["combat_state"] = combat_state
	run_state["progression"] = progression
	run_state["notice"] = ""
	instance.call("_load_run_state", run_state)
	instance.set("_animation_lock", false)
	await _settle_ui()

func _choose_clicked_action(instance: Node, hand_index: int, play_kind: String) -> void:
	instance.call("_on_card_pressed", hand_index)
	await _settle_ui()
	_assert(int(instance.get("_card_action_choice_index")) == hand_index, "Click should expose play-mode options for exact hand index %d" % hand_index)
	_assert(str(instance.get("_card_action_choice_mode")) == "play", "Click should default to the card's printed mode")
	if play_kind != "play":
		await instance.call("_on_card_action_choice_pressed", play_kind)
		await _settle_ui()
	_assert(str(instance.get("_card_action_choice_mode")) == play_kind, "Requested %s mode should remain active" % play_kind)
	var context: Control = instance.get("_action_step_tracker") as Control
	var active_button_name: String = "CardActionChoice%s" % play_kind.capitalize()
	var active_button: Button = context.find_child(active_button_name, true, false) as Button
	_assert(active_button != null and active_button.toggle_mode and active_button.button_pressed, "Requested %s mode should be the selected exclusive option" % play_kind)

func _assert_clicked_fallback_consumption(instance: Node, play_kind: String, seed: int) -> void:
	var enemy_positions: Array = [Vector2i(3, 4)] if play_kind == "attack" else [Vector2i(6, 4)]
	await _load_combat_fixture(instance, ["guarded_step", "quick_stab", "patch_up"], Vector2i(2, 4), enemy_positions, seed, false)
	var hand_before: Array = _hand(instance)
	await _choose_clicked_action(instance, 1, play_kind)
	var target: Vector2i = Vector2i(3, 4)
	if play_kind == "move":
		var move_targets: Array = instance.get("_pending_target_tiles") as Array
		_assert(not move_targets.is_empty(), "Basic Move consumption proof needs a legal target")
		if move_targets.is_empty():
			return
		target = move_targets[0]
	await instance.call("_on_board_tile_clicked", target)
	await _settle_ui()
	var hand_after: Array = _hand(instance)
	_assert(not hand_after.has("quick_stab") and hand_after.has("guarded_step") and hand_after.has("patch_up"), "Basic %s must consume the exact clicked card and preserve its neighbors" % play_kind.capitalize())
	_assert(hand_after.size() == hand_before.size() - 1, "Basic %s must spend exactly one card" % play_kind.capitalize())
	var state_after: Dictionary = instance.get("_combat_state")
	_assert(int(state_after.get("cards_played_this_turn", 0)) == 1, "Basic %s should spend one card play" % play_kind.capitalize())
	_assert(int(state_after.get("player_turn_time_spent", 0)) == int(GameData.card_def("quick_stab").get("time", 0)), "Basic %s should keep the consumed card's turn-clock cost" % play_kind.capitalize())
	if play_kind == "move":
		_assert((state_after.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO) == target, "Basic Move should resolve to the clicked legal tile")

func _assert_choice_state(instance: Node, hand_index: int, label: String) -> void:
	var context: Control = instance.get("_action_step_tracker") as Control
	_assert(context != null and context.visible and str(context.get_meta("context_mode", "")) == "choice", "%s should show the play-mode rail" % label)
	_assert(int(context.get_meta("choice_card_index", -1)) == hand_index, "%s should retain exact source-card metadata" % label)
	_assert(int(instance.get("_selected_card_index")) == hand_index, "%s should enter printed targeting immediately without another click" % label)
	_assert(str(instance.get("_card_action_choice_mode")) == "play", "%s should select As Written by default" % label)
	var shared_group: ButtonGroup = null
	var pressed_count: int = 0
	for button_name: String in ["CardActionChoicePlay", "CardActionChoiceAttack", "CardActionChoiceMove"]:
		var button: Button = context.find_child(button_name, true, false) as Button
		_assert(button != null and button.visible, "%s should expose mode option %s" % [label, button_name])
		if button != null:
			_assert(button.get_global_rect().size.x >= 88.0 and button.get_global_rect().size.y >= 36.0 and button.get_global_rect().size.y <= 44.0, "%s should render %s as a compact mode option" % [label, button_name])
			_assert(button.toggle_mode and button.button_group != null, "%s should make %s part of an exclusive selector" % [label, button_name])
			if shared_group == null:
				shared_group = button.button_group
			else:
				_assert(button.button_group == shared_group, "%s mode options should share one ButtonGroup" % label)
			if button.button_pressed:
				pressed_count += 1
	var printed_tab: Button = context.find_child("CardActionChoicePlay", true, false) as Button
	_assert(pressed_count == 1, "%s should show exactly one selected mode" % label)
	_assert(printed_tab != null and printed_tab.button_pressed and bool(printed_tab.get_meta("active", false)), "%s should visibly mark As Written as the selected mode" % label)
	var board_bounds: Rect2 = instance.call("_contextual_combat_rendered_board_bounds")
	_assert(not context.get_global_rect().intersects(board_bounds), "%s play-mode rail %s should leave tactical board %s visible" % [label, context.get_global_rect(), board_bounds])

func _assert_tutorial_geometry_stable(instance: Node, label: String) -> void:
	var host: Control = instance.get("_contextual_combat_prompt_host") as Control
	var prompt: Control = instance.get("_contextual_combat_prompt") as Control
	var active_id: String = str(instance.get("_active_contextual_combat_prompt_id"))
	prompt.call("clear_prompt")
	host.visible = false
	await _settle_ui()
	var before: Dictionary = _combat_geometry(instance)
	_assert_board_usable_and_visible(instance, "%s hidden-note baseline" % label)
	for prompt_id: String in ContextualCombatTutorial.prompt_ids():
		prompt.call("configure", ContextualCombatTutorial.prompt_definition(prompt_id))
		host.visible = true
		instance.call("_layout_contextual_combat_prompt_overlay")
		await _settle_ui()
		var during: Dictionary = _combat_geometry(instance)
		_assert(host.get_parent() == instance.get("ui_root"), "%s %s should use a fixed UI overlay" % [label, prompt_id])
		_assert(bool(host.get_meta("safe_layout_found", false)), "%s %s should place prompt size %s in non-interactive overlay space within %s around %s" % [label, prompt_id, host.get_meta("prompt_size", Vector2.ZERO), host.get_meta("safe_area", Rect2()), host.get_meta("protected_rects", [])])
		var prompt_size: Vector2 = host.get_meta("prompt_size", Vector2.ZERO)
		_assert(prompt_size.x >= 299.0 and prompt_size.y >= 103.0, "%s %s should retain the full readable prompt geometry, got %s" % [label, prompt_id, prompt_size])
		_assert_board_usable_and_visible(instance, "%s %s visible note" % [label, prompt_id])
		_assert_tutorial_clear_of_play(instance, "%s %s" % [label, prompt_id])
		_assert_geometry_equal(before, during, "%s showing %s" % [label, prompt_id])
		prompt.call("clear_prompt")
		host.visible = false
		await _settle_ui()
		_assert_geometry_equal(before, _combat_geometry(instance), "%s hiding %s" % [label, prompt_id])
	instance.call("_refresh_contextual_combat_tutorial")
	await _settle_ui()
	_assert(str(instance.get("_active_contextual_combat_prompt_id")) == active_id, "%s should restore the same note after all geometry cycles" % label)

func _combat_geometry(instance: Node) -> Dictionary:
	var pass_button: Button = _button_with_text(instance.get("_choice_button_overlay") as Node, "Pass")
	var pass_preview: Control = instance.get("_pass_preview_overlay") as Control
	var geometry: Dictionary = {
		"board": (instance.get("board_view") as Control).get_global_rect(),
		"rendered_board": instance.call("_contextual_combat_rendered_board_bounds"),
		"hand": (instance.get("hand_row") as Control).get_global_rect(),
		"pass": pass_button.get_global_rect() if pass_button != null else Rect2(-1.0, -1.0, 0.0, 0.0),
		"pass_preview": pass_preview.get_global_rect() if pass_preview != null and pass_preview.visible else Rect2(-1.0, -1.0, 0.0, 0.0),
		"draw": (instance.get("draw_pile") as Control).get_global_rect(),
		"discard": (instance.get("discard_pile") as Control).get_global_rect(),
		"timeline": (instance.get("_turn_order_panel") as Control).get_global_rect(),
		"combat_widget": (instance.get("_play_meter") as Control).get_global_rect(),
		"minimap": (instance.get("mini_map_overlay") as Control).get_global_rect()
	}
	var hand: Array = _hand(instance)
	for index: int in range(hand.size()):
		var card_control: Control = instance.call("_hand_card_control", index) as Control
		if card_control != null and card_control.is_visible_in_tree():
			geometry["card_%d" % index] = instance.call("_control_visual_global_rect", card_control)
	return geometry

func _assert_geometry_equal(expected: Dictionary, actual: Dictionary, label: String) -> void:
	_assert(expected.size() == actual.size(), "%s must keep the same protected geometry keys: %s != %s" % [label, expected.keys(), actual.keys()])
	for key: String in expected.keys():
		_assert(actual.has(key), "%s must retain protected geometry for %s" % [label, key])
		var expected_rect: Rect2 = expected.get(key, Rect2())
		var actual_rect: Rect2 = actual.get(key, Rect2())
		_assert(expected_rect == actual_rect, "%s must keep %s exactly identical: %s != %s" % [label, key, expected_rect, actual_rect])

func _assert_tutorial_clear_of_play(instance: Node, label: String) -> void:
	var host: Control = instance.get("_contextual_combat_prompt_host") as Control
	if host == null or not host.visible:
		return
	var prompt: Control = instance.get("_contextual_combat_prompt") as Control
	var context: Control = instance.get("_action_step_tracker") as Control
	var board: Control = instance.get("board_view") as Control
	var prompt_rect: Rect2 = prompt.get_global_rect()
	var viewport_bounds := Rect2(Vector2.ZERO, instance.get_viewport().get_visible_rect().size).grow(1.0)
	for tile_var: Variant in board.call("_rendered_tiles_in_draw_order") as Array:
		if typeof(tile_var) != TYPE_VECTOR2I:
			continue
		var tile: Vector2i = tile_var
		var polygon: PackedVector2Array = board.call("_tile_polygon", tile)
		var tile_bounds: Rect2 = _polygon_bounds(polygon)
		var global_tile_bounds: Rect2 = Rect2(board.global_position + tile_bounds.position, tile_bounds.size)
		_assert(viewport_bounds.encloses(global_tile_bounds), "%s must keep rendered tile %s visible inside the viewport" % [label, tile])
		_assert(not prompt_rect.intersects(global_tile_bounds), "%s must not cover legal board tile %s" % [label, tile])
	var hand: Array = _hand(instance)
	for index: int in range(hand.size()):
		var card_control: Control = instance.call("_hand_card_control", index) as Control
		if card_control != null and card_control.visible:
			var card_rect: Rect2 = instance.call("_control_visual_global_rect", card_control)
			_assert(not prompt_rect.intersects(card_rect), "%s must not cover hand card %d" % [label, index])
	for key: String in ["pass", "pass_preview", "draw", "discard", "timeline", "combat_widget", "minimap"]:
		var protected_rect: Rect2 = _combat_geometry(instance).get(key, Rect2())
		if protected_rect.size.x > 0.0 and protected_rect.size.y > 0.0:
			_assert(not prompt_rect.intersects(protected_rect), "%s must not cover %s" % [label, key])
	if context != null and context.visible:
		_assert(not prompt_rect.intersects(context.get_global_rect()), "%s must not overlap action choices" % label)

func _assert_idle_tutorial_pass_preview_clear(instance: Node, label: String) -> void:
	var host: Control = instance.get("_contextual_combat_prompt_host") as Control
	var prompt: Control = instance.get("_contextual_combat_prompt") as Control
	var pass_preview: Control = instance.get("_pass_preview_overlay") as Control
	_assert(host != null and host.visible and prompt != null and prompt.visible, "%s must keep the tutorial visible" % label)
	_assert(pass_preview != null and pass_preview.visible, "%s must keep the Pass-risk preview visible" % label)
	if prompt == null or pass_preview == null or not prompt.visible or not pass_preview.visible:
		return
	var prompt_rect: Rect2 = prompt.get_global_rect()
	var pass_preview_rect: Rect2 = pass_preview.get_global_rect()
	_assert(pass_preview_rect.size.x > 0.0 and pass_preview_rect.size.y > 0.0, "%s Pass-risk preview must have settled geometry" % label)
	_assert(not prompt_rect.intersects(pass_preview_rect), "%s tutorial %s must be disjoint from Pass-risk preview %s" % [label, prompt_rect, pass_preview_rect])

func _assert_board_usable_and_visible(instance: Node, label: String) -> void:
	var board: Control = instance.get("board_view") as Control
	var rendered_bounds: Rect2 = instance.call("_contextual_combat_rendered_board_bounds")
	_assert(board != null and board.visible, "%s should keep the tactical board visible" % label)
	_assert(rendered_bounds.size.x >= 520.0 and rendered_bounds.size.y >= 250.0, "%s should preserve a readable rendered board, got %s" % [label, rendered_bounds])
	var context: Control = instance.get("_action_step_tracker") as Control
	if context != null and context.visible:
		_assert(not context.get_global_rect().intersects(rendered_bounds), "%s action rail %s should stay clear of tactical board %s" % [label, context.get_global_rect(), rendered_bounds])
	var first_tile_width: float = 0.0
	for tile_var: Variant in board.call("_rendered_tiles_in_draw_order") as Array:
		if typeof(tile_var) != TYPE_VECTOR2I:
			continue
		var tile: Vector2i = tile_var
		first_tile_width = _polygon_bounds(board.call("_tile_polygon", tile) as PackedVector2Array).size.x
		break
	_assert(first_tile_width >= 89.0, "%s should preserve baseline tile scale, got %.2f" % [label, first_tile_width])

func _polygon_bounds(polygon: PackedVector2Array) -> Rect2:
	if polygon.is_empty():
		return Rect2()
	var min_point: Vector2 = polygon[0]
	var max_point: Vector2 = polygon[0]
	for point: Vector2 in polygon:
		min_point.x = minf(min_point.x, point.x)
		min_point.y = minf(min_point.y, point.y)
		max_point.x = maxf(max_point.x, point.x)
		max_point.y = maxf(max_point.y, point.y)
	return Rect2(min_point, max_point - min_point)

func _hand(instance: Node) -> Array:
	return ((((instance.get("_combat_state") as Dictionary).get("deck", {}) as Dictionary).get("hand", []) as Array).duplicate())

func _button_with_text(root_node: Node, text: String) -> Button:
	if root_node == null:
		return null
	for node: Node in root_node.find_children("*", "Button", true, false):
		var button: Button = node as Button
		if button != null and button.text == text:
			return button
	return null

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
		"name": "Ashen Crossing",
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
			row.append("wall" if x == 0 or y == 0 or x == 7 or y == 7 else "ash")
		grid.append(row)
	return grid

func _settle_ui() -> void:
	await process_frame
	await process_frame
	await process_frame
	await create_timer(0.16).timeout
	RenderingServer.force_draw()
	await process_frame

func _save_screenshot(instance: Node, output_path: String, expected_size: Vector2i, stable_output_path: String = "") -> void:
	if DisplayServer.get_name() == "headless":
		return
	_remove_if_present(output_path)
	if not stable_output_path.is_empty():
		_remove_if_present(stable_output_path)
	await create_timer(0.50).timeout
	await process_frame
	await process_frame
	RenderingServer.force_draw()
	var capture_viewport: Viewport = instance.get_viewport()
	var logical_viewport_size: Vector2 = capture_viewport.get_visible_rect().size
	_assert(logical_viewport_size == Vector2(expected_size), "%s logical viewport should be %s before capture, got %s" % [output_path, expected_size, logical_viewport_size])
	if logical_viewport_size != Vector2(expected_size):
		return
	var image: Image = capture_viewport.get_texture().get_image()
	_assert(image != null, "%s should produce a renderer frame" % output_path)
	if image == null:
		return
	_assert(image.get_size() == expected_size, "%s captured texture should be exact size %s without scaling, got %s" % [output_path, expected_size, image.get_size()])
	if image.get_size() != expected_size:
		return
	var frame_coverage: float = _non_black_frame_coverage(image)
	_assert(frame_coverage >= 0.95, "%s should have a complete renderer frame, got %.3f non-black coverage" % [output_path, frame_coverage])
	_assert_scene_regions_rendered(instance, image, output_path)
	if _failed:
		return
	image.save_png(output_path)
	if not stable_output_path.is_empty():
		image.save_png(stable_output_path)

func _non_black_frame_coverage(image: Image) -> float:
	if image == null or image.is_empty():
		return 0.0
	var sampled: int = 0
	var non_black: int = 0
	for y: int in range(0, image.get_height(), 12):
		for x: int in range(0, image.get_width(), 12):
			sampled += 1
			var pixel: Color = image.get_pixel(x, y)
			if maxf(pixel.r, maxf(pixel.g, pixel.b)) > 0.015:
				non_black += 1
	return float(non_black) / float(maxi(1, sampled))

func _assert_scene_regions_rendered(instance: Node, image: Image, label: String) -> void:
	var regions: Array = []
	_append_capture_region(regions, "room title", instance.get("title_box") as Control, 0.12, 0.012)
	_append_capture_region(regions, "turn clock", instance.get("_turn_order_panel") as Control, 0.12, 0.006)
	_append_capture_region(regions, "minimap", instance.get("mini_map_overlay") as Control, 0.08, 0.003)
	var board_rect: Rect2 = instance.call("_contextual_combat_rendered_board_bounds")
	regions.append({"name": "board", "rect": board_rect, "min_range": 0.12, "min_edge_ratio": 0.012})

	_append_capture_region(regions, "draw pile", instance.get("draw_pile") as Control, 0.08, 0.005)
	_append_capture_region(regions, "discard pile", instance.get("discard_pile") as Control, 0.08, 0.005)

	var visible_card_count: int = 0
	var hand: Array = _hand(instance)
	for index: int in range(hand.size()):
		var card_control: Control = instance.call("_hand_card_control", index) as Control
		if card_control == null or not card_control.is_visible_in_tree():
			continue
		var card_rect: Rect2 = instance.call("_control_visual_global_rect", card_control)
		regions.append({"name": "hand card %d" % index, "rect": card_rect, "min_range": 0.16, "min_edge_ratio": 0.010})
		visible_card_count += 1
	_assert(visible_card_count > 0, "%s should expose at least one independently checked hand card region" % label)

	if int(instance.get("_drag_card_index")) >= 0:
		_append_capture_region(regions, "drag card proxy", instance.get("_drag_card_proxy") as Control, 0.16, 0.010)

	var image_bounds := Rect2(Vector2.ZERO, Vector2(image.get_size()))
	for region_var: Variant in regions:
		var region: Dictionary = region_var as Dictionary
		var region_name: String = str(region.get("name", "region"))
		var region_rect: Rect2 = region.get("rect", Rect2())
		var visible_rect: Rect2 = region_rect.intersection(image_bounds)
		var region_area: float = maxf(1.0, region_rect.size.x * region_rect.size.y)
		var visible_fraction: float = maxf(0.0, visible_rect.size.x * visible_rect.size.y) / region_area
		_assert(visible_fraction >= 0.90, "%s %s region %s must remain at least 90%% visible inside captured image %s, got %.3f" % [label, region_name, region_rect, image_bounds, visible_fraction])
		var metrics: Dictionary = _image_region_detail_metrics(image, region_rect)
		var sample_count: int = int(metrics.get("samples", 0))
		var luma_range: float = float(metrics.get("luma_range", 0.0))
		var edge_ratio: float = float(metrics.get("edge_ratio", 0.0))
		_assert(sample_count >= 40, "%s %s region %s should have enough captured pixels, got %d" % [label, region_name, region_rect, sample_count])
		_assert(luma_range >= float(region.get("min_range", 0.08)), "%s %s region should contain rendered detail, got luminance range %.4f" % [label, region_name, luma_range])
		_assert(edge_ratio >= float(region.get("min_edge_ratio", 0.004)), "%s %s region should contain scene edges, got ratio %.4f" % [label, region_name, edge_ratio])

func _append_capture_region(regions: Array, name: String, control: Control, min_range: float, min_edge_ratio: float) -> void:
	if control == null or not control.is_visible_in_tree():
		_fail("Screenshot completeness region %s should be visible" % name)
		return
	regions.append({
		"name": name,
		"rect": control.get_global_rect(),
		"min_range": min_range,
		"min_edge_ratio": min_edge_ratio
	})

func _image_region_detail_metrics(image: Image, region: Rect2) -> Dictionary:
	if image == null or image.is_empty() or region.size.x <= 0.0 or region.size.y <= 0.0:
		return {"samples": 0, "luma_range": 0.0, "edge_ratio": 0.0}
	var image_bounds := Rect2(Vector2.ZERO, Vector2(image.get_size()))
	var clipped: Rect2 = region.intersection(image_bounds)
	if clipped.size.x <= 1.0 or clipped.size.y <= 1.0:
		return {"samples": 0, "luma_range": 0.0, "edge_ratio": 0.0}
	var start_x: int = maxi(0, int(floor(clipped.position.x)))
	var start_y: int = maxi(0, int(floor(clipped.position.y)))
	var end_x: int = mini(image.get_width(), int(ceil(clipped.end.x)))
	var end_y: int = mini(image.get_height(), int(ceil(clipped.end.y)))
	var step: int = clampi(int(floor(minf(clipped.size.x, clipped.size.y) / 48.0)), 1, 4)
	var min_luma: float = INF
	var max_luma: float = -INF
	var samples: int = 0
	var comparisons: int = 0
	var edges: int = 0
	for y: int in range(start_y, end_y, step):
		for x: int in range(start_x, end_x, step):
			var luma: float = image.get_pixel(x, y).get_luminance()
			min_luma = minf(min_luma, luma)
			max_luma = maxf(max_luma, luma)
			samples += 1
			if x - step >= start_x:
				comparisons += 1
				if absf(luma - image.get_pixel(x - step, y).get_luminance()) >= 0.035:
					edges += 1
			if y - step >= start_y:
				comparisons += 1
				if absf(luma - image.get_pixel(x, y - step).get_luminance()) >= 0.035:
					edges += 1
	return {
		"samples": samples,
		"luma_range": maxf(0.0, max_luma - min_luma),
		"edge_ratio": float(edges) / float(maxi(1, comparisons))
	}

func _hide_fixture_debug_ui(instance: Node) -> void:
	var log: Control = instance.get("log_overlay") as Control
	if log != null:
		log.visible = false

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)

func _fail(message: String) -> void:
	push_error(message)
	_failed = true

func _remove_if_present(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

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
