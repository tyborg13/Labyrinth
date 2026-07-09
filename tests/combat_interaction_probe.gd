extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")

const OUTPUT_DIR: String = "user://probes/combat_interaction_context_v2"
const BOARD_PATH: String = "Backdrop/Margin/MainVBox/StageRoot/CombatBoard"
const HAND_PATH: String = "Backdrop/Margin/MainVBox/BottomStack/HandRow/HandScroll/HandCenter/HandBox"
const MINI_MAP_PATH: String = "Backdrop/Margin/MainVBox/StageRoot/MiniMapOverlay"
const LOG_PATH: String = "Backdrop/Margin/MainVBox/StageRoot/LogOverlay"

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
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
	_assert(not (instance.get("_action_step_tracker") as Control).visible, "Idle hand should not show action context")
	await _save_root_screenshot("%s/idle_hand.png" % OUTPUT_DIR)

	instance.call("_on_card_drag_started", 1)
	await _settle_ui()
	var board: Control = instance.get_node(BOARD_PATH) as Control
	var drag_position: Vector2 = board.get_global_rect().get_center() + Vector2(-120.0, -40.0)
	instance.call("_update_drag_proxy_position", drag_position)
	instance.call("_update_drag_overlay_hover", instance.call("_drag_zone_at", drag_position))
	await _settle_ui()
	_assert_drag_state(instance)
	await _save_root_screenshot("%s/drag_full_card.png" % OUTPUT_DIR)

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
	await instance.call("_on_card_pressed", 0)
	await _settle_ui()
	context = instance.get("_action_step_tracker") as Control
	_assert(_button_with_text(context, "Skip") != null, "Optional step should compose Skip into the action context")
	_assert_context(instance, "MOVE", "STEP 1/2", "optional step")
	await _save_root_screenshot("%s/optional_step.png" % OUTPUT_DIR)

	await _load_combat_fixture(instance, ["thunderline"], Vector2i(2, 4), [Vector2i(4, 4), Vector2i(4, 2), Vector2i(6, 4)], 9803)
	await instance.call("_on_card_pressed", 0)
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
	await instance.call("_on_card_pressed", 1)
	await _settle_ui()
	_assert_context(instance, "MOVE", "STEP 1/2", "HUD stress")
	_assert_hud_collision_free(instance)
	await _save_root_screenshot("%s/hud_stress.png" % OUTPUT_DIR)

	instance.queue_free()
	await process_frame

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
	await _settle_ui()

func _assert_drag_state(instance: Node) -> void:
	var overlay: Control = instance.get("_drag_overlay") as Control
	var context: Control = instance.get("_action_step_tracker") as Control
	_assert(overlay.visible and overlay.get_child_count() == 1, "Drag layer should contain only the held card proxy")
	_assert(context.visible and str(context.get_meta("context_mode", "")) == "drag", "Drag should use the compact action context")
	_assert(str(context.get_meta("drag_hover_zone", "")) == "play", "Battlefield drag should default to full-card play")
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
	var verb_label: Label = instance.get("_action_context_verb_label") as Label
	_assert(context.visible, "%s should show action context" % label)
	_assert(str(context.get_meta("action_verb", "")).contains(verb_fragment), "%s should show verb %s" % [label, verb_fragment])
	_assert(_label_text_fits(verb_label), "%s action instruction should fit without ellipsis" % label)
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
	_assert(not context_rect.intersects(mini_map.get_global_rect()), "Action context should not collide with the minimap")
	_assert(not context_rect.intersects(log_overlay.get_global_rect()), "Action context should not collide with combat log")
	var board_overlap: Rect2 = context_rect.intersection(board_rect)
	_assert(board_overlap.get_area() <= board_rect.get_area() * 0.12, "Action context should preserve at least 88% of the battlefield control area")
	var selected_card: Control = _hand_card_control(hand_box, int(instance.get("_selected_card_index")))
	var hand_visual_top: float = _hand_visual_top(hand_box)
	_assert(selected_card != null and context_rect.end.y <= hand_visual_top + 1.0, "Action context should sit above the entire rendered hand, including rotated card titles and ornaments")

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
			row.append("wall" if x == 0 or y == 0 or x == 7 or y == 7 else "ash")
		grid.append(row)
	return grid

func _settle_ui() -> void:
	await process_frame
	await process_frame

func _save_root_screenshot(output_path: String) -> void:
	var texture: Texture2D = root.get_viewport().get_texture()
	var image: Image = texture.get_image()
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
