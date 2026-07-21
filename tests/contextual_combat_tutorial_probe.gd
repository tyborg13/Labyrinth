extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")
const ContextualCombatTutorial = preload("res://scripts/contextual_combat_tutorial.gd")

const OUTPUT_DIR: String = "user://probes/contextual_combat_tutorial"
const STORAGE_PATH: String = "user://contextual_combat_tutorial_probe_progression.json"
const RUN_STORAGE_PATH: String = "user://contextual_combat_tutorial_probe_run.save"

var _failed: bool = false

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_clear_probe_output(OUTPUT_DIR)
	ProgressionStore.set_storage_path(STORAGE_PATH)
	ProgressionStore.set_run_storage_path(RUN_STORAGE_PATH)
	_remove_if_present(STORAGE_PATH)
	_remove_if_present(RUN_STORAGE_PATH)
	await _capture_fresh_sequence_and_returning_profile()
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	quit(1 if _failed else 0)

func _capture_fresh_sequence_and_returning_profile() -> void:
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	if packed == null:
		_fail("Run scene should load for contextual tutorial probe")
		return
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await _settle_ui()
	await _load_combat_fixture(instance, 11601)

	_assert_prompt(instance, ContextualCombatTutorial.FULL_CARD_FALLBACK, "fresh combat")
	await _assert_prompt_geometry_stable(instance, "full-card prompt")
	_assert_prompt_clear_of_huds(instance, "full-card prompt")
	await _save_root_screenshot("%s/01_full_card_fallback.png" % OUTPUT_DIR)

	var prompt: Node = instance.get("_contextual_combat_prompt") as Node
	var before_advance: Dictionary = _combat_geometry(instance)
	prompt.call("_on_completed_pressed")
	await _settle_ui()
	_assert_geometry_equal(before_advance, _combat_geometry(instance), "advancing full-card prompt")
	instance.call("_on_card_hover_started", 0)
	await _settle_ui()
	_assert_prompt(instance, ContextualCombatTutorial.TIMELINE_READING, "card hover")
	await _assert_prompt_geometry_stable(instance, "timeline prompt")
	_assert_prompt_clear_of_huds(instance, "timeline prompt")
	await _save_root_screenshot("%s/02_timeline_reading.png" % OUTPUT_DIR)

	await _choose_clicked_card_action(instance, 0, "play")
	await _settle_ui()
	_assert_prompt(instance, ContextualCombatTutorial.SELECT_TARGET, "selected compound card")
	await _assert_prompt_geometry_stable(instance, "target prompt")
	_assert_prompt_clear_of_huds(instance, "target prompt")
	await _save_root_screenshot("%s/03_select_target.png" % OUTPUT_DIR)

	var first_targets: Array[Vector2i] = _vector2i_array(instance.get("_pending_target_tiles") as Array)
	if first_targets.is_empty():
		_fail("Compound-card fixture should offer a first target")
		instance.queue_free()
		return
	var compound_setup_target: Vector2i = Vector2i(4, 4) if first_targets.has(Vector2i(4, 4)) else first_targets[0]
	await instance.call("_on_board_tile_clicked", compound_setup_target)
	await _settle_ui()
	_assert_prompt(instance, ContextualCombatTutorial.CANCEL_OPTIONAL, "optional compound step")
	await _assert_prompt_geometry_stable(instance, "optional prompt")
	_assert_prompt_clear_of_huds(instance, "optional prompt")
	await _save_root_screenshot("%s/04_cancel_optional.png" % OUTPUT_DIR)

	var before_skip: Dictionary = _combat_geometry(instance)
	prompt.call("_on_skipped_pressed")
	await _settle_ui()
	_assert_geometry_equal(before_skip, _combat_geometry(instance), "skipping optional prompt")
	_assert_state(instance, ContextualCombatTutorial.CANCEL_OPTIONAL, ContextualCombatTutorial.STATUS_SKIPPED, "prompt skip")
	_assert(str((ContextualCombatTutorial.states_from_progression(ProgressionStore.load_data())).get(ContextualCombatTutorial.CANCEL_OPTIONAL, "")) == ContextualCombatTutorial.STATUS_SKIPPED, "Skipped prompt should be persisted immediately")
	await _save_root_screenshot("%s/05_prompt_skip_persisted.png" % OUTPUT_DIR)

	instance.call("_cancel_card_selection")
	await _settle_ui()
	_assert_prompt(instance, ContextualCombatTutorial.PASS_CONSEQUENCE, "pass choice")
	await _assert_prompt_geometry_stable(instance, "pass prompt")
	_assert_prompt_clear_of_huds(instance, "pass prompt")
	await _save_root_screenshot("%s/06_pass_consequence.png" % OUTPUT_DIR)
	prompt.call("_on_completed_pressed")
	await _settle_ui()

	var states: Dictionary = ContextualCombatTutorial.states_from_progression(instance.get("_progression") as Dictionary)
	_assert(states.size() == 5, "Fresh sequence should resolve exactly five prompts")
	instance.queue_free()
	await process_frame
	await process_frame

	var returning_instance: Node = packed.instantiate()
	root.add_child(returning_instance)
	await _settle_ui()
	await _load_combat_fixture(returning_instance, 11602)
	_assert_no_prompt(returning_instance, "returning combat")
	returning_instance.call("_on_card_hover_started", 0)
	await _settle_ui()
	_assert_no_prompt(returning_instance, "returning card hover")
	await _choose_clicked_card_action(returning_instance, 0, "play")
	await _settle_ui()
	_assert_no_prompt(returning_instance, "returning card selection")
	await _save_root_screenshot("%s/07_returning_profile_no_repeat.png" % OUTPUT_DIR)
	returning_instance.queue_free()
	await process_frame

func _load_combat_fixture(instance: Node, seed: int) -> void:
	instance.call("_cancel_drag_play")
	instance.call("_reset_card_resolution")
	var layout: Dictionary = _combat_layout()
	var combat := CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(seed, layout, {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["sidestep_slash"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["sidestep_slash"]
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

	var progression: Dictionary = (instance.get("_progression") as Dictionary).duplicate(true)
	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run_state["mode"] = "combat"
	run_state["current_room"] = layout.get("coord", Vector2i.ZERO)
	run_state["current_room_layout"] = layout
	run_state["combat_state"] = combat_state
	run_state["progression"] = progression
	instance.call("_load_run_state", run_state)
	await _settle_ui()

func _combat_layout() -> Dictionary:
	return {
		"name": "First Combat Lesson",
		"coord": Vector2i(1, 0),
		"type": "combat",
		"grid": _simple_grid(),
		"player_start": Vector2i(2, 4),
		"enemies": [{
			"id": 1,
			"type": "crawler",
			"pos": Vector2i(5, 4),
			"hp": 140,
			"max_hp": 140,
			"block": 0
		}],
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

func _assert_prompt(instance: Node, expected_id: String, label: String) -> void:
	var host: Control = instance.get("_contextual_combat_prompt_host") as Control
	var prompt: Control = instance.get("_contextual_combat_prompt") as Control
	if host == null or prompt == null or not host.visible or not prompt.visible:
		_fail("Expected visible %s prompt for %s" % [expected_id, label])
		return
	var active_id: String = str(instance.get("_active_contextual_combat_prompt_id"))
	if active_id != expected_id or str(prompt.get_meta("prompt_id", "")) != expected_id:
		_fail("Expected %s for %s, got %s" % [expected_id, label, active_id])
	if host.get_child_count() != 1:
		_fail("Fresh profiles should show at most one prompt at a time for %s" % label)
	var message: String = str(prompt.get_meta("prompt_text", ""))
	if message.is_empty() or message.contains("\n"):
		_fail("%s should be one terse sentence" % expected_id)

func _assert_prompt_geometry_stable(instance: Node, label: String) -> void:
	var host: Control = instance.get("_contextual_combat_prompt_host") as Control
	var prompt: Control = instance.get("_contextual_combat_prompt") as Control
	if host == null or prompt == null:
		_fail("Missing contextual tutorial overlay controls for %s" % label)
		return
	var active_id: String = str(instance.get("_active_contextual_combat_prompt_id"))
	prompt.call("clear_prompt")
	host.visible = false
	await _settle_ui()
	var before: Dictionary = _combat_geometry(instance)
	_assert_healthy_board_scale(instance, "%s hidden-note baseline" % label)
	instance.call("_refresh_contextual_combat_tutorial")
	await _settle_ui()
	_assert(str(instance.get("_active_contextual_combat_prompt_id")) == active_id, "%s should restore the same prompt after a visibility cycle" % label)
	var during: Dictionary = _combat_geometry(instance)
	_assert(host.get_parent() == instance.get("ui_root"), "%s should be a fixed UI overlay, not a reflowing container child" % label)
	_assert(bool(host.get_meta("safe_layout_found", false)), "%s should find non-interactive overlay space" % label)
	_assert_healthy_board_scale(instance, "%s visible note" % label)
	prompt.call("clear_prompt")
	host.visible = false
	await _settle_ui()
	var after: Dictionary = _combat_geometry(instance)
	_assert_geometry_equal(before, during, "%s showing" % label)
	_assert_geometry_equal(before, after, "%s hiding" % label)
	instance.call("_refresh_contextual_combat_tutorial")
	await _settle_ui()

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
	var combat_state: Dictionary = instance.get("_combat_state") as Dictionary
	var hand: Array = ((combat_state.get("deck", {}) as Dictionary).get("hand", []) as Array)
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
		_assert(expected_rect == actual_rect, "%s must keep %s rect exactly identical: %s != %s" % [label, key, expected_rect, actual_rect])

func _choose_clicked_card_action(instance: Node, hand_index: int, play_kind: String) -> void:
	instance.call("_on_card_pressed", hand_index)
	await _settle_ui()
	_assert(int(instance.get("_card_action_choice_index")) == hand_index, "Click should open play-mode choices for the exact hand card")
	await instance.call("_on_card_action_choice_pressed", play_kind)
	await _settle_ui()

func _assert_no_prompt(instance: Node, label: String) -> void:
	var host: Control = instance.get("_contextual_combat_prompt_host") as Control
	if host != null and host.visible:
		_fail("Returning profile repeated prompt %s during %s" % [str(instance.get("_active_contextual_combat_prompt_id")), label])

func _assert_state(instance: Node, prompt_id: String, expected: String, label: String) -> void:
	var states: Dictionary = ContextualCombatTutorial.states_from_progression(instance.get("_progression") as Dictionary)
	_assert(str(states.get(prompt_id, "")) == expected, "%s should record %s=%s" % [label, prompt_id, expected])

func _assert_prompt_clear_of_huds(instance: Node, label: String) -> void:
	var prompt: Control = instance.get("_contextual_combat_prompt") as Control
	var board: Control = instance.get("board_view") as Control
	var timeline: Control = instance.get("_turn_order_panel") as Control
	var mini_map: Control = instance.get("mini_map_overlay") as Control
	var action_context: Control = instance.get("_action_step_tracker") as Control
	var pass_preview: Control = instance.get("_pass_preview_overlay") as Control
	if prompt == null or board == null:
		_fail("Missing prompt or board for %s layout check" % label)
		return
	var prompt_rect: Rect2 = prompt.get_global_rect()
	var rendered_board_bounds: Rect2 = instance.call("_contextual_combat_rendered_board_bounds")
	if prompt_rect.intersects(rendered_board_bounds):
		_fail("%s should not block rendered board targets" % label)
	if timeline != null and timeline.visible and prompt_rect.intersects(timeline.get_global_rect()):
		_fail("%s should not obscure the turn timeline" % label)
	if mini_map != null and mini_map.visible and prompt_rect.intersects(mini_map.get_global_rect()):
		_fail("%s should not obscure the minimap" % label)
	if action_context != null and action_context.visible and prompt_rect.intersects(action_context.get_global_rect()):
		_fail("%s should not overlap the active combat action rail" % label)
	if pass_preview != null and pass_preview.visible:
		var pass_preview_rect: Rect2 = pass_preview.get_global_rect()
		_assert(pass_preview_rect.size.x > 0.0 and pass_preview_rect.size.y > 0.0, "%s Pass-risk preview should have settled geometry" % label)
		_assert(not prompt_rect.intersects(pass_preview_rect), "%s should not obscure the visible Pass-risk preview" % label)
	var geometry: Dictionary = _combat_geometry(instance)
	for key: String in ["pass", "pass_preview", "draw", "discard", "combat_widget"]:
		var protected_rect: Rect2 = geometry.get(key, Rect2())
		if protected_rect.size.x > 0.0 and protected_rect.size.y > 0.0 and prompt_rect.intersects(protected_rect):
			_fail("%s should not obscure %s" % [label, key])
	var combat_state: Dictionary = instance.get("_combat_state") as Dictionary
	var hand: Array = ((combat_state.get("deck", {}) as Dictionary).get("hand", []) as Array)
	for index: int in range(hand.size()):
		var card_control: Control = instance.call("_hand_card_control", index) as Control
		if card_control != null and card_control.visible:
			var card_rect: Rect2 = instance.call("_control_visual_global_rect", card_control)
			if prompt_rect.intersects(card_rect):
				_fail("%s should not obscure hand card %d" % [label, index])

func _assert_healthy_board_scale(instance: Node, label: String) -> void:
	var board: Control = instance.get("board_view") as Control
	var rendered_bounds: Rect2 = instance.call("_contextual_combat_rendered_board_bounds")
	_assert(board != null and board.visible, "%s should keep the board visible" % label)
	_assert(rendered_bounds.size.x >= 520.0 and rendered_bounds.size.y >= 250.0, "%s should preserve a readable board, got %s" % [label, rendered_bounds])
	var tile_width: float = 0.0
	for tile_var: Variant in board.call("_rendered_tiles_in_draw_order") as Array:
		if typeof(tile_var) != TYPE_VECTOR2I:
			continue
		var tile: Vector2i = tile_var
		var polygon: PackedVector2Array = board.call("_tile_polygon", tile)
		if not polygon.is_empty():
			var min_x: float = polygon[0].x
			var max_x: float = polygon[0].x
			for point: Vector2 in polygon:
				min_x = minf(min_x, point.x)
				max_x = maxf(max_x, point.x)
			tile_width = max_x - min_x
		break
	_assert(tile_width >= 89.0, "%s should preserve baseline tile scale, got %.2f" % [label, tile_width])

func _vector2i_array(values: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for value: Variant in values:
		if typeof(value) == TYPE_VECTOR2I:
			result.append(value)
	return result

func _button_with_text(root_node: Node, text: String) -> Button:
	if root_node == null:
		return null
	for node: Node in root_node.find_children("*", "Button", true, false):
		var button: Button = node as Button
		if button != null and button.text == text:
			return button
	return null

func _settle_ui() -> void:
	await process_frame
	await process_frame
	await process_frame
	await create_timer(0.16).timeout
	await process_frame

func _save_root_screenshot(output_path: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_viewport().get_texture().get_image()
	image.save_png(output_path)

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
