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
	_assert_prompt_clear_of_huds(instance, "full-card prompt")
	await _save_root_screenshot("%s/01_full_card_fallback.png" % OUTPUT_DIR)

	var prompt: Node = instance.get("_contextual_combat_prompt") as Node
	prompt.call("_on_completed_pressed")
	await _settle_ui()
	instance.call("_on_card_hover_started", 0)
	await _settle_ui()
	_assert_prompt(instance, ContextualCombatTutorial.TIMELINE_READING, "card hover")
	_assert_prompt_clear_of_huds(instance, "timeline prompt")
	await _save_root_screenshot("%s/02_timeline_reading.png" % OUTPUT_DIR)

	await instance.call("_on_card_pressed", 0)
	await _settle_ui()
	_assert_prompt(instance, ContextualCombatTutorial.SELECT_TARGET, "selected compound card")
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
	_assert_prompt_clear_of_huds(instance, "optional prompt")
	await _save_root_screenshot("%s/04_cancel_optional.png" % OUTPUT_DIR)

	prompt.call("_on_skipped_pressed")
	await _settle_ui()
	_assert_state(instance, ContextualCombatTutorial.CANCEL_OPTIONAL, ContextualCombatTutorial.STATUS_SKIPPED, "prompt skip")
	_assert(str((ContextualCombatTutorial.states_from_progression(ProgressionStore.load_data())).get(ContextualCombatTutorial.CANCEL_OPTIONAL, "")) == ContextualCombatTutorial.STATUS_SKIPPED, "Skipped prompt should be persisted immediately")
	await _save_root_screenshot("%s/05_prompt_skip_persisted.png" % OUTPUT_DIR)

	instance.call("_cancel_card_selection")
	await _settle_ui()
	_assert_prompt(instance, ContextualCombatTutorial.PASS_CONSEQUENCE, "pass choice")
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
	await returning_instance.call("_on_card_pressed", 0)
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
			row.append("wall" if x == 0 or y == 0 or x == 7 or y == 7 else "ash")
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
	if prompt == null or board == null:
		_fail("Missing prompt or board for %s layout check" % label)
		return
	var prompt_rect: Rect2 = prompt.get_global_rect()
	if prompt_rect.intersects(board.get_global_rect()):
		_fail("%s should not block board targets" % label)
	if timeline != null and timeline.visible and prompt_rect.intersects(timeline.get_global_rect()):
		_fail("%s should not obscure the turn timeline" % label)
	if mini_map != null and mini_map.visible and prompt_rect.intersects(mini_map.get_global_rect()):
		_fail("%s should not obscure the minimap" % label)
	if action_context != null and action_context.visible and prompt_rect.intersects(action_context.get_global_rect()):
		_fail("%s should not overlap the active combat action rail" % label)

func _vector2i_array(values: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for value: Variant in values:
		if typeof(value) == TYPE_VECTOR2I:
			result.append(value)
	return result

func _settle_ui() -> void:
	await process_frame
	await process_frame
	await process_frame
	await create_timer(0.16).timeout
	await process_frame

func _save_root_screenshot(output_path: String) -> void:
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
