extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")
const GameData = preload("res://scripts/game_data.gd")

const OUTPUT_DIR: String = "user://probes/action_step_tracker"
const TRACKER_PATH: String = "UiLayer/UiRoot/ActionStepTracker"
const CHOICE_PATH: String = "UiLayer/UiRoot/Backdrop/Margin/MainVBox/BottomStack/HandRow/LeftActionStack/ChoiceBar"
const PILES_PATH: String = "UiLayer/UiRoot/Backdrop/Margin/MainVBox/BottomStack/HandRow/LeftActionStack/PilesBar"

var _last_statuses: Array = []

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_clear_probe_output(OUTPUT_DIR)
	ProgressionStore.set_storage_path("user://labyrinth_progression_action_step_probe.json")
	ProgressionStore.set_run_storage_path("user://labyrinth_run_action_step_probe.save")
	ProgressionStore.clear_saved_run()
	await _capture_action_step_tracker_frames()
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	quit()

func _capture_action_step_tracker_frames() -> void:
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame

	await _load_combat_fixture(instance, "sidestep_slash", Vector2i(2, 4), [Vector2i(5, 4)], 9711)
	var piles_y_before: float = _control_rect(instance, PILES_PATH).position.y
	instance.call("_on_card_pressed", 0)
	await _settle_ui()
	_assert_tracker_statuses(instance, ["current", "remaining"], "move-attack selection")
	_assert_tracker_copy_is_compact(instance, "move-attack selection")
	_assert_tracker_layout(instance, "move-attack selection", piles_y_before)
	await _save_root_screenshot("%s/move_attack_selected.png" % OUTPUT_DIR)

	instance.call("_on_board_tile_clicked", Vector2i(4, 4))
	await _settle_ui()
	_assert_tracker_statuses(instance, ["done", "current"], "move-attack after move target")
	await _save_root_screenshot("%s/move_attack_after_move.png" % OUTPUT_DIR)

	await _load_combat_fixture(instance, "sidestep_slash", Vector2i(2, 4), [Vector2i(3, 4)], 9712)
	instance.call("_on_card_pressed", 0)
	await _settle_ui()
	instance.call("_on_skip_action_pressed")
	await _settle_ui()
	_assert_tracker_statuses(instance, ["skipped", "current"], "manual skip")
	await _save_root_screenshot("%s/manual_skip_current_attack.png" % OUTPUT_DIR)

	await _load_combat_fixture(instance, "sidestep_slash", Vector2i(2, 4), [Vector2i(3, 4)], 9713, true)
	instance.call("_on_card_pressed", 0)
	await _settle_ui()
	_assert_tracker_statuses(instance, ["skipped", "current"], "auto skip from immobilized move")
	await _save_root_screenshot("%s/auto_skip_current_attack.png" % OUTPUT_DIR)

	await _load_combat_fixture(instance, "guarded_step", Vector2i(2, 4), [Vector2i(5, 5)], 9714)
	piles_y_before = _control_rect(instance, PILES_PATH).position.y
	instance.call("_on_card_pressed", 0)
	await _settle_ui()
	_assert_tracker_statuses(instance, ["current", "remaining", "remaining"], "targetless follow-up selection")
	_assert_tracker_layout(instance, "targetless follow-up selection", piles_y_before)
	await _save_root_screenshot("%s/targetless_followups_selected.png" % OUTPUT_DIR)

	var tracker: Control = instance.get_node_or_null(TRACKER_PATH) as Control
	var tracker_position_before_resolution: Vector2 = tracker.global_position if tracker != null else Vector2.ZERO
	instance.call("_lock_action_step_tracker_position_for_resolution")
	instance.set("_animation_lock", true)
	instance.set("_animating_hand_card_index", 0)
	instance.call("_begin_action_step_resolution_tracker", "guarded_step", (GameData.card_def("guarded_step").get("actions", []) as Array).duplicate(true), [Vector2i(4, 4)])
	instance.call("_refresh_animation_lock_ui")
	await _settle_ui()
	_assert_tracker_statuses(instance, ["current", "remaining", "remaining"], "execution move step")
	_assert_tracker_layout(instance, "execution move step", piles_y_before)
	_assert_tracker_position(instance, tracker_position_before_resolution, "execution move step")
	await _save_root_screenshot("%s/execution_move_current.png" % OUTPUT_DIR)
	instance.call("_set_action_step_resolution_index", 1)
	await _settle_ui()
	_assert_tracker_statuses(instance, ["done", "current", "remaining"], "execution block step")
	_assert_tracker_layout(instance, "execution block step", piles_y_before)
	_assert_tracker_position(instance, tracker_position_before_resolution, "execution block step")
	await _save_root_screenshot("%s/execution_block_current.png" % OUTPUT_DIR)
	instance.call("_set_action_step_resolution_index", 2)
	await _settle_ui()
	_assert_tracker_statuses(instance, ["done", "done", "current"], "execution card-play step")
	_assert_tracker_layout(instance, "execution card-play step", piles_y_before)
	_assert_tracker_position(instance, tracker_position_before_resolution, "execution card-play step")
	await _save_root_screenshot("%s/execution_card_play_current.png" % OUTPUT_DIR)
	instance.call("_clear_action_step_resolution_tracker")
	instance.set("_animation_lock", false)
	instance.set("_animating_hand_card_index", -1)

	instance.queue_free()
	await process_frame

func _load_combat_fixture(instance: Node, card_id: String, player_pos: Vector2i, enemy_positions: Array, seed: int, immobilized: bool = false) -> void:
	instance.call("_cancel_drag_play")
	instance.call("_reset_card_resolution")
	var layout: Dictionary = _tracker_room_layout(player_pos, enemy_positions)
	var combat := CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(seed, layout, {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": [card_id],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = [card_id]
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
	restrictions["immobilized"] = immobilized
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
	instance.call("_refresh_ui")
	await _settle_ui()

func _tracker_room_layout(player_pos: Vector2i, enemy_positions: Array) -> Dictionary:
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
		"name": "Action Step Tracker Probe",
		"coord": Vector2i(4, 2),
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
			if x == 0 or y == 0 or x == 7 or y == 7:
				row.append("wall")
			else:
				row.append("stone")
		grid.append(row)
	return grid

func _assert_tracker_statuses(instance: Node, expected: Array, label: String) -> void:
	var tracker: Control = instance.get_node_or_null(TRACKER_PATH) as Control
	if tracker == null:
		_fail("Missing action step tracker for %s" % label)
		return
	if not tracker.visible:
		_fail("Action step tracker should be visible for %s" % label)
		return
	var statuses: Array = tracker.get_meta("step_statuses", [])
	_last_statuses = statuses.duplicate()
	if statuses.size() != expected.size():
		_fail("%s expected %d statuses, got %d: %s" % [label, expected.size(), statuses.size(), str(statuses)])
		return
	for index: int in range(expected.size()):
		if str(statuses[index]) != str(expected[index]):
			_fail("%s expected statuses %s, got %s" % [label, str(expected), str(statuses)])
			return

func _assert_tracker_layout(instance: Node, label: String, expected_piles_y: float) -> void:
	var tracker: Control = instance.get_node_or_null(TRACKER_PATH) as Control
	var choice: Control = instance.get_node_or_null(CHOICE_PATH) as Control
	var piles: Control = instance.get_node_or_null(PILES_PATH) as Control
	if tracker == null or choice == null or piles == null:
		_fail("Missing controls for tracker layout check: %s" % label)
		return
	if absf(piles.global_position.y - expected_piles_y) > 1.0:
		_fail("%s moved piles from %.1f to %.1f" % [label, expected_piles_y, piles.global_position.y])
		return
	var anchor_y: float = choice.global_position.y if choice.visible and choice.size.y > 0.0 else piles.global_position.y
	if tracker.global_position.y + tracker.size.y > anchor_y + 1.0:
		_fail("%s tracker overlaps controls: tracker bottom %.1f, anchor %.1f" % [label, tracker.global_position.y + tracker.size.y, anchor_y])
		return
	if not bool(tracker.get_meta("position_locked", false)):
		var card_anchor: Rect2 = instance.call("_action_step_tracker_anchor_rect") as Rect2
		var tracker_rect: Rect2 = tracker.get_global_rect()
		if absf(tracker_rect.get_center().x - card_anchor.get_center().x) > 2.0:
			_fail("%s tracker should stay horizontally connected to its active card" % label)
			return
		var card_gap: float = card_anchor.position.y - tracker_rect.end.y
		if card_gap < -1.0 or card_gap > 24.0:
			_fail("%s tracker should sit directly above the hand, got gap %.1f" % [label, card_gap])
			return

func _assert_tracker_position(instance: Node, expected: Vector2, label: String) -> void:
	var tracker: Control = instance.get_node_or_null(TRACKER_PATH) as Control
	if tracker == null:
		_fail("Missing action step tracker for %s position check" % label)
		return
	if not tracker.global_position.is_equal_approx(expected):
		_fail("%s moved tracker from %s to %s during resolution" % [label, str(expected), str(tracker.global_position)])

func _assert_tracker_copy_is_compact(instance: Node, label: String) -> void:
	var detail_row: Control = instance.get("_action_context_detail_row") as Control
	var status_row: Control = instance.get("_action_context_status_row") as Control
	var mode_selector: Control = instance.get("_card_action_mode_selector") as Control
	if detail_row == null or detail_row.visible:
		_fail("%s should omit the redundant action-description row" % label)
		return
	if status_row == null or status_row.visible:
		_fail("%s should omit target-validity and turn-end copy" % label)
		return
	if mode_selector == null or not mode_selector.visible:
		_fail("%s should keep the card-mode selector directly below the title" % label)

func _control_rect(instance: Node, path: String) -> Rect2:
	var control: Control = instance.get_node_or_null(path) as Control
	if control == null:
		return Rect2()
	return Rect2(control.global_position, control.size)

func _settle_ui() -> void:
	await process_frame
	await process_frame

func _save_root_screenshot(output_path: String) -> void:
	var image: Image = null
	if DisplayServer.get_name() != "headless":
		var texture: Texture2D = root.get_viewport().get_texture()
		if texture != null:
			image = texture.get_image()
	if image == null or image.get_width() <= 0 or image.get_height() <= 0:
		image = _fallback_status_image()
	image.save_png(output_path)

func _fallback_status_image() -> Image:
	var image := Image.create(640, 180, false, Image.FORMAT_RGBA8)
	image.fill(Color("17110e"))
	var statuses: Array = _last_statuses.duplicate()
	var chip_width: int = 92
	var gap: int = 18
	var total_width: int = statuses.size() * chip_width + maxi(0, statuses.size() - 1) * gap
	var start_x: int = maxi(20, (640 - total_width) / 2)
	for index: int in range(statuses.size()):
		var status: String = str(statuses[index])
		var rect := Rect2i(start_x + index * (chip_width + gap), 48, chip_width, 84)
		image.fill_rect(rect, _fallback_status_color(status))
		image.fill_rect(Rect2i(rect.position + Vector2i(4, 4), rect.size - Vector2i(8, 8)), Color(0.0, 0.0, 0.0, 0.16))
	return image

func _fallback_status_color(status: String) -> Color:
	match status:
		"current":
			return Color("f4c968")
		"done":
			return Color("87c879")
		"skipped":
			return Color("df8065")
		_:
			return Color("6f6558")

func _fail(message: String) -> void:
	push_error(message)
	quit(1)

func _clear_probe_output(output_dir: String) -> void:
	var absolute_dir: String = ProjectSettings.globalize_path(output_dir)
	_clear_probe_output_absolute(absolute_dir)

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
