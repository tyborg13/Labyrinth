extends SceneTree

const CombatEngine = preload("res://scripts/combat_engine.gd")
const ContextualCombatTutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const InputRouterScript = preload("res://scripts/input_router.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")

const OUTPUT_DIR: String = "user://probes/player_movement_v1"
const VIEWPORT_SIZE: Vector2i = Vector2i(1920, 1080)
const BOARD_PATH: String = "BoardUnderlay/CombatBoard"

var _errors: Array[String] = []

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(VIEWPORT_SIZE)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_size = VIEWPORT_SIZE
	root.size = VIEWPORT_SIZE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_clear_probe_output(ProjectSettings.globalize_path(OUTPUT_DIR))
	ProgressionStore.set_storage_path("user://labyrinth_progression_player_movement_probe.json")
	ProgressionStore.set_run_storage_path("user://labyrinth_run_player_movement_probe.save")
	ProgressionStore.clear_saved_run()

	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await _settle_ui()
	await _load_fixture(instance)

	_assert_movement_hud(instance, 2, 2, "idle")
	_assert(not bool(instance.get("_player_movement_selected")), "Idle fixture should not begin with movement selected")
	await _save_screenshot("%s/01_full_pool_idle.png" % OUTPUT_DIR)

	await instance.call("_on_board_tile_clicked", Vector2i(2, 4))
	instance.call("_on_board_tile_hovered", Vector2i(3, 4))
	await _settle_hand_transition()
	_assert(bool(instance.get("_player_movement_selected")), "Clicking the protagonist should enter movement targeting")
	_assert(_movement_targets(instance).has(Vector2i(3, 4)), "Adjacent movement destination should be legal")
	_assert_movement_hud(instance, 2, 2, "selected movement")
	_assert_board_path(instance, Vector2i(3, 4), "selected movement")
	await _save_screenshot("%s/02_selected_path_hover.png" % OUTPUT_DIR)

	await instance.call("_on_board_tile_clicked", Vector2i(3, 4))
	await _settle_hand_transition()
	_assert_movement_hud(instance, 1, 2, "after one-tile movement")
	_assert(_player_pos(instance) == Vector2i(3, 4), "One-tile movement should commit to the selected destination")
	await _save_screenshot("%s/03_split_pool_one_remaining.png" % OUTPUT_DIR)

	await instance.call("_on_card_pressed", 0)
	await _settle_ui()
	_assert(int(instance.get("_selected_card_index")) == 0, "Card click should enter printed targeting directly")
	_assert(int(instance.get("_card_action_choice_index")) < 0, "Card click should skip the retired mode selector")
	await _save_screenshot("%s/04_direct_printed_card_flow.png" % OUTPUT_DIR)
	await instance.call("_on_board_tile_clicked", Vector2i(3, 4))
	await _settle_hand_transition()
	_assert_movement_hud(instance, 1, 2, "after interleaved card play")
	_assert(int(instance.get("_selected_card_index")) < 0, "Printed card should resolve after its board confirmation")
	await _save_screenshot("%s/05_card_played_movement_preserved.png" % OUTPUT_DIR)

	await instance.call("_on_board_tile_clicked", Vector2i(3, 4))
	instance.call("_on_board_tile_hovered", Vector2i(4, 4))
	await _settle_hand_transition()
	_assert(bool(instance.get("_player_movement_selected")), "Movement should remain selectable after a card play")
	_assert_movement_hud(instance, 1, 2, "post-card movement selection")
	_assert_board_path(instance, Vector2i(4, 4), "post-card movement")
	await _save_screenshot("%s/06_post_card_movement_selected.png" % OUTPUT_DIR)

	await instance.call("_on_board_tile_clicked", Vector2i(4, 4))
	await _settle_ui()
	_assert_movement_hud(instance, 0, 2, "exhausted")
	_assert(_player_pos(instance) == Vector2i(4, 4), "Second split move should reach the selected destination")
	_assert(_movement_targets(instance).is_empty(), "Exhausted movement should expose no legal destinations")
	await _save_screenshot("%s/07_pool_exhausted.png" % OUTPUT_DIR)

	await _load_fixture(instance)
	var state_before_cancel: Dictionary = (instance.get("_combat_state") as Dictionary).duplicate(true)
	await instance.call("_on_board_tile_clicked", Vector2i(2, 4))
	instance.call("_on_board_tile_hovered", Vector2i(3, 4))
	await _settle_ui()
	var router: Node = root.get_node_or_null("InputRouter")
	_assert(router != null, "Controller movement cancellation should have an input router")
	if router != null:
		router.call("set_forced_state_for_test", InputRouterScript.MODALITY_CONTROLLER, InputRouterScript.FAMILY_STEAM_DECK)
		instance.call("_refresh_controller_prompts")
		var prompt_labels: Array[String] = []
		var prompt_bar: Control = instance.get("_controller_prompt_bar") as Control
		for prompt_var: Variant in prompt_bar.call("prompts_snapshot"):
			prompt_labels.append(str((prompt_var as Dictionary).get("label", "")))
		_assert(
			prompt_labels.has("Target") and prompt_labels.has("Cancel"),
			"Movement targeting should advertise controller Target and Cancel; got %s in region %s (movement selected=%s)"
			% [prompt_labels, str(instance.get("_controller_region")), str(instance.get("_player_movement_selected"))]
		)
	var cancel_event := InputEventAction.new()
	cancel_event.action = InputRouterScript.ACTION_CANCEL
	cancel_event.pressed = true
	var controller_cancel_handled: bool = await instance.call("_handle_controller_input", cancel_event)
	await _settle_hand_transition()
	_assert(controller_cancel_handled and not bool(instance.get("_player_movement_selected")), "Controller B should leave movement targeting")
	_assert((instance.get("_combat_state") as Dictionary) == state_before_cancel, "Cancel should not spend movement or mutate combat")
	_assert_movement_hud(instance, 2, 2, "after cancel")
	if router != null:
		router.call("set_forced_state_for_test", InputRouterScript.MODALITY_POINTER, InputRouterScript.FAMILY_STEAM_DECK)
		instance.call("_refresh_controller_interface")
		await _settle_hand_transition()
	_assert_player_health_anchor(instance, "pointer after controller cancellation")
	await _save_screenshot("%s/08_cancel_restores_idle.png" % OUTPUT_DIR)

	await _load_fixture(instance)
	var combat := CombatEngine.new()
	var exhausted_state: Dictionary = (instance.get("_combat_state") as Dictionary).duplicate(true)
	exhausted_state["cards_played_this_turn"] = combat.cards_remaining_this_turn(exhausted_state)
	exhausted_state["player_movement_remaining"] = 1
	var exhausted_run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	exhausted_run_state["combat_state"] = exhausted_state.duplicate(true)
	instance.set("_run_state", exhausted_run_state)
	instance.call("_sync_combat_state_from_run")
	instance.call("_refresh_ui")
	var turn_before_auto_pass: int = int(exhausted_state.get("turn", 0))
	await instance.call("_on_board_tile_clicked", Vector2i(2, 4))
	instance.call("_on_board_tile_hovered", Vector2i(3, 4))
	await instance.call("_on_board_tile_clicked", Vector2i(3, 4))
	await _settle_ui()
	var after_auto_pass: Dictionary = instance.get("_combat_state") as Dictionary
	_assert(int(after_auto_pass.get("turn", 0)) > turn_before_auto_pass, "Spending the last movement after card plays are exhausted should auto-pass into the next activation")
	_assert(combat.is_player_turn(after_auto_pass), "Auto-pass should finish enemy resolution at the next player activation")
	_assert(combat.player_movement_remaining(after_auto_pass) == combat.player_movement_capacity(after_auto_pass), "The activation reached by auto-pass should refill movement")
	_assert(combat.cards_remaining_this_turn(after_auto_pass) > 0, "The activation reached by auto-pass should refill card plays")
	await _save_screenshot("%s/09_auto_pass_next_activation.png" % OUTPUT_DIR)

	instance.queue_free()
	await process_frame
	if router != null and router.has_method("clear_forced_state_for_test"):
		router.call("clear_forced_state_for_test")
	if _errors.is_empty():
		print("PLAYER MOVEMENT VISUAL PROBE: PASS")
		print(ProjectSettings.globalize_path(OUTPUT_DIR))
		quit(0)
		return
	for error: String in _errors:
		push_error(error)
	print("PLAYER MOVEMENT VISUAL PROBE: FAIL (%d errors)" % _errors.size())
	quit(1)

func _load_fixture(instance: Node) -> void:
	instance.call("_cancel_drag_play")
	instance.call("_reset_card_resolution")
	var hand: Array = ["brace", "quick_stab", "sidestep_slash", "bone_dart", "patch_up"]
	var layout: Dictionary = _room_layout()
	var combat := CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(260826, layout, {
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
	combat_state = combat.normalize_player_movement_pool(combat_state)
	var progression: Dictionary = (instance.get("_progression") as Dictionary).duplicate(true)
	for prompt_id: String in ContextualCombatTutorial.prompt_ids():
		progression = ContextualCombatTutorial.resolve_progression(progression, prompt_id)
	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run_state["mode"] = "combat"
	run_state["current_room"] = layout.get("coord", Vector2i.ZERO)
	run_state["current_room_layout"] = layout
	run_state["combat_state"] = combat_state.duplicate(true)
	run_state["progression"] = progression.duplicate(true)
	instance.set("_progression", progression)
	instance.set("_run_state", run_state)
	# Fixture replacement must invalidate the same derived previews as a live commit.
	instance.call("_sync_combat_state_from_run")
	instance.set("_animation_lock", false)
	instance.call("_refresh_ui")
	Input.warp_mouse(Vector2(960.0, 86.0))
	await _settle_hand_transition()

func _room_layout() -> Dictionary:
	return {
		"name": "Independent Movement Probe",
		"coord": Vector2i(4, 3),
		"type": "combat",
		"grid": _simple_grid(),
		"player_start": Vector2i(2, 4),
		"enemies": [{
			"id": 1,
			"type": "crawler",
			"pos": Vector2i(5, 4),
			"hp": 18,
			"max_hp": 18,
			"block": 0
		}],
		"traps": [],
		"terrain": [],
		"element": "none"
	}

func _simple_grid() -> Array:
	var grid: Array = []
	for y: int in range(8):
		var row: Array = []
		for x: int in range(8):
			row.append("wall" if x == 0 or y == 0 or x == 7 or y == 7 else "stone")
		grid.append(row)
	return grid

func _assert_movement_hud(instance: Node, expected_remaining: int, expected_capacity: int, label: String) -> void:
	_assert_player_health_anchor(instance, label)
	var combat := CombatEngine.new()
	var combat_state: Dictionary = instance.get("_combat_state") as Dictionary
	_assert(combat.player_movement_remaining(combat_state) == expected_remaining, "%s should have %d movement remaining" % [label, expected_remaining])
	_assert(combat.player_movement_capacity(combat_state) == expected_capacity, "%s should have movement capacity %d" % [label, expected_capacity])
	var meter: Control = instance.get("_movement_meter") as Control
	var count: Label = instance.get("_movement_meter_count") as Label
	_assert(meter != null and meter.visible, "%s should show the movement HUD" % label)
	_assert(count != null and count.text == "%d / %d movement" % [expected_remaining, expected_capacity], "%s should show the exact movement count" % label)
	var play_meter: Control = instance.get("_play_meter") as Control
	if meter != null and play_meter != null:
		var movement_rect: Rect2 = meter.get_global_rect()
		var play_rect: Rect2 = play_meter.get_global_rect()
		_assert(absf(movement_rect.get_center().x - play_rect.get_center().x) <= 1.0, "%s movement and card-play meters should share one resource column" % label)
		_assert(movement_rect.position.y >= play_rect.end.y + 3.0, "%s movement should stack immediately below card plays" % label)
		var movement_icon: TextureRect = instance.get("_movement_meter_icon") as TextureRect
		var play_icon: TextureRect = instance.get("_play_meter_icon") as TextureRect
		_assert(movement_icon != null and play_icon != null and movement_icon.size.x < play_icon.size.x, "%s movement icon should fit more comfortably inside its frame than the card-play icon" % label)
		var pass_chip: Control = instance.find_child("PassPreviewChip", true, false) as Control
		if pass_chip != null and pass_chip.visible:
			var pass_rect: Rect2 = pass_chip.get_global_rect()
			_assert(absf(pass_rect.get_center().x - movement_rect.get_center().x) <= 1.0 and pass_rect.position.y >= movement_rect.end.y + 5.0, "%s Pass should stack beneath the co-located resource meters" % label)

func _assert_board_path(instance: Node, destination: Vector2i, label: String) -> void:
	var board: Node = instance.get_node(BOARD_PATH)
	var presentation: Dictionary = board.get("presentation") as Dictionary
	var path_tiles: Array = presentation.get("path_tiles", []) as Array
	var target_tiles: Array = board.get("move_tiles") as Array
	_assert(target_tiles.has(destination), "%s should highlight the hovered legal destination" % label)
	_assert(path_tiles.size() >= 2 and path_tiles.back() == destination, "%s should preview a path ending at the destination" % label)

func _assert_player_health_anchor(instance: Node, label: String) -> void:
	var board: Node = instance.get_node(BOARD_PATH)
	for unit: Dictionary in board.call("_hud_layout_units"):
		if str(unit.get("key", "")) != "player":
			continue
		var center: Vector2 = board.call("_unit_center", unit)
		var expected: Rect2 = board.call("_unit_health_bar_rect", unit, center)
		var cached: Dictionary = board.get("_hud_health_rects_cache") as Dictionary
		_assert(cached.get("player", Rect2()) == expected, "%s should keep the cached player health bar anchored to current board geometry" % label)
		return
	_assert(false, "%s should contain the player's visible HUD unit" % label)

func _movement_targets(instance: Node) -> Array[Vector2i]:
	var combat := CombatEngine.new()
	return combat.player_movement_targets(instance.get("_combat_state") as Dictionary)

func _player_pos(instance: Node) -> Vector2i:
	return ((instance.get("_combat_state") as Dictionary).get("player", {}) as Dictionary).get("pos", Vector2i(-1, -1))

func _settle_hand_transition() -> void:
	for _frame: int in range(10):
		await process_frame
	await _settle_ui()

func _settle_ui() -> void:
	await process_frame
	await process_frame
	RenderingServer.force_draw()
	await process_frame

func _save_screenshot(output_path: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var image: Image = root.get_viewport().get_texture().get_image()
	_assert(image != null, "Visual probe should capture a renderer image")
	if image == null:
		return
	var source_size: Vector2i = image.get_size()
	var scale_x: float = float(source_size.x) / float(VIEWPORT_SIZE.x)
	var scale_y: float = float(source_size.y) / float(VIEWPORT_SIZE.y)
	var proportional: bool = is_equal_approx(scale_x, scale_y)
	_assert(proportional, "Visual probe backing should preserve 1920x1080 proportions, got %s" % source_size)
	if not proportional:
		return
	if source_size != VIEWPORT_SIZE:
		image.resize(VIEWPORT_SIZE.x, VIEWPORT_SIZE.y, Image.INTERPOLATE_LANCZOS)
	var error: Error = image.save_png(output_path)
	_assert(error == OK, "Visual probe should save %s" % output_path)

func _clear_probe_output(absolute_dir: String) -> void:
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
			_clear_probe_output(child_path)
			DirAccess.remove_absolute(child_path)
		else:
			DirAccess.remove_absolute(child_path)
	dir.list_dir_end()

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	_errors.append(message)
	push_error(message)
