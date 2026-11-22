extends "res://tests/card_draw_hand_flow_test.gd"
## Unit-local assertions run on the same boundaries as the native capture.

const OUTPUT_DIR: String = "user://gfix26"
const TOOLTIP_SURFACE: String = "fire"
const FIRST_CARD: int = 0 # Shadow Step in the shared fixture.
const SECOND_CARD: int = 1 # Brace, with a different Time cost.
const AIM_CARD: int = 2
const REPLACEMENT_CARD_ID: String = "patch_up"
const FRAME_LIMIT: int = 120
const REPLACEMENT_SAMPLE_FRAMES: int = 12
const DRAG_SAMPLE_FRAMES: int = 4
const AIM_SAMPLE_FRAMES: int = 12
const POINTER_PARK := Vector2(960, 480)
var _capture_host: Node
var _scene: Control
var _board: Control
var _headless: bool
var _checks: int
var _failures: int
var _pointer: Vector2 = POINTER_PARK

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	_headless = DisplayServer.get_name() == "headless"
	call_deferred("_run")

func _run() -> void:
	Engine.max_fps = KEYWORD_SAMPLE_FPS
	ProgressionStore.set_storage_path(OUTPUT_DIR.path_join("progression.json"))
	ProgressionStore.set_run_storage_path(OUTPUT_DIR.path_join("current_run.save"))
	SettingsStore.set_storage_path(OUTPUT_DIR.path_join("settings.json"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var settings: Dictionary = SettingsStore.default_settings()
	settings["ui_scale"] = 1.0
	settings["display_mode"] = SettingsStore.DISPLAY_WINDOWED
	SettingsStore.save_settings(settings)
	SettingsStore.apply_settings(settings, root, false)
	root.size = HUD_FIXTURE_SIZE
	root.content_scale_size = HUD_FIXTURE_SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	_capture_host = preload("res://tests/helpers/ui03_capture_viewport.gd").new()
	root.add_child(_capture_host)
	_capture_host.setup(root)
	_scene = preload("res://scenes/run_scene.tscn").instantiate()
	_capture_host.viewport.add_child(_scene)
	await _frame()
	await _frame()
	_scene.call("_close_dialogue")
	_scene._progression = preload("res://scripts/contextual_combat_tutorial.gd").dismiss_tutorial(_scene._progression)
	var router: Node = root.get_node("InputRouter")
	router.call("set_forced_state_for_test", "pointer", "xbox")
	await _load_combat_fixture(_scene)
	_scene._combat_state["deck"]["hand"][AIM_CARD] = "lantern_shot"
	var enemy_tile: Vector2i = _scene._combat_state["enemies"][0]["pos"]
	preload("res://scripts/board_surface_rules.gd").place(_scene._combat_state, enemy_tile, TOOLTIP_SURFACE)
	_scene.call("_mark_combat_preview_state_changed")
	_scene.call("_refresh_ui")
	var original: Dictionary = _scene._combat_state.duplicate(true)
	_board = _scene.board_view
	await _frame()
	await _check_rail()
	await _check_cross_drag()
	router.call("set_forced_state_for_test", "controller", "xbox")
	await _check_board()
	_check(_scene._combat_state == original, "Focus and hover preserve committed combat state")
	router.call("set_forced_state_for_test", "pointer", "xbox")
	await _check_hand_replacement()
	router.call("clear_forced_state_for_test")
	_scene.queue_free()
	_capture_host.close()
	_capture_host.queue_free()
	await process_frame
	print("GFIX-26 DISPLAY TRUTH: %s (%d checks, %d failures)" % ["PASS" if _failures == 0 else "FAIL", _checks, _failures])
	quit(0 if _failures == 0 else 1)

func _check_rail() -> void:
	var baseline: Array[Dictionary] = _rail_for_card(-1)
	var first: Array[Dictionary] = _rail_for_card(FIRST_CARD)
	var second: Array[Dictionary] = _rail_for_card(SECOND_CARD)
	_check(first != second and first != baseline and second != baseline, "Rail fixture distinguishes both projections and the unmodified schedule")
	await _focus_pointer_card(FIRST_CARD)
	_check(_scene._turn_order_rendered_entries == first, "First card publishes a visible rail projection")
	_move_pointer(_card_point(SECOND_CARD))
	var resting: bool = await _frame()
	_check(_scene._hovered_card_index == SECOND_CARD and resting, "One-frame crossing focuses the second card during dwell")
	_expect_rail(second, "One-frame crossing uses the second card's numbers immediately")
	_capture("rail_focus_change")
	_move_pointer(_card_point(FIRST_CARD))
	await _frame()
	_check(_scene._hovered_card_index == FIRST_CARD, "Rapid mouse return focuses the first card")
	_expect_rail(first, "Rapid mouse return has no neutral frame")
	_capture("rail_focus_return")

	_move_pointer(_card_point(SECOND_CARD))
	var settled: bool = false
	for frame: int in range(FRAME_LIMIT):
		resting = await _frame()
		_check(_scene._hovered_card_index == SECOND_CARD, "Sustained crossing keeps the second card focused")
		_expect_rail(second, "Sustained crossing frame %d uses the second card's numbers" % frame)
		if not resting and not _scene._hand_hover_refresh_pending:
			settled = true
			_capture("rail_focus_settled")
			break
	_check(settled, "Hover dwell completes after the rapid return")

func _check_cross_drag() -> void:
	await _focus_pointer_card(SECOND_CARD)
	var baseline: Array[Dictionary] = _rail_for_card(-1)
	var dragged: Array[Dictionary] = _rail_for_card(SECOND_CARD)
	_press_pointer(_card_point(SECOND_CARD), true)
	_move_pointer(_card_point(FIRST_CARD), MOUSE_BUTTON_MASK_LEFT)
	for frame: int in range(DRAG_SAMPLE_FRAMES):
		await _frame()
		_check(_scene._drag_card_index == SECOND_CARD and is_instance_valid(_scene._drag_card_proxy), "Cross-card motion starts the Brace proxy")
		var entries: Array[Dictionary] = _scene._turn_order_rendered_entries
		_check(entries == dragged or entries == baseline, "Cross-drag frame %d shows the dragged card or unprojected schedule (card: %s)" % [frame, _projection_name(entries)])
		if frame == 0:
			_capture("rail_cross_drag")
	_press_pointer(_pointer, false)
	for frame: int in range(FRAME_LIMIT):
		await _frame()
		if _scene._drag_card_index < 0:
			break
	_check(_scene._drag_card_index < 0, "Outside release ends the drag")
	_move_pointer(POINTER_PARK)
	await _frame()

func _check_hand_replacement() -> void:
	await _focus_pointer_card(SECOND_CARD)
	var baseline: Array[Dictionary] = _rail_for_card(-1)
	_expect_rail(_rail_for_card(SECOND_CARD), "Replacement fixture starts with Brace projected")
	_scene._combat_state["deck"]["hand"][SECOND_CARD] = REPLACEMENT_CARD_ID
	_scene._mark_combat_preview_state_changed()
	_scene._refresh_ui()
	var replacement: Array[Dictionary] = _rail_for_card(SECOND_CARD)
	_check(replacement != baseline, "Replacement fixture distinguishes a Patch Up projection")
	_check(_scene._hovered_card_index == -1, "Hand rebuild retires the prior card's hover")
	_expect_rail(baseline, "The refresh does not project the unfocused replacement")
	for frame: int in range(REPLACEMENT_SAMPLE_FRAMES):
		await _frame()
		var forecast: Array[Dictionary] = replacement if _scene._hovered_card_index == SECOND_CARD else baseline
		_expect_rail(forecast, "Replacement frame %d projects only a focused card" % frame)
		if frame == 0:
			_capture("rail_hand_replacement")

func _expect_rail(expected: Array[Dictionary], message: String) -> void:
	var entries: Array[Dictionary] = _scene._turn_order_rendered_entries
	_check(entries == expected and _rail_clocks_match(entries), "%s (card: %s)" % [message, _projection_name(entries)])

func _focus_pointer_card(index: int) -> void:
	_move_pointer(_card_point(index))
	for frame: int in range(FRAME_LIMIT):
		await _frame()
		if _scene._hovered_card_index == index and not _scene._hand_hover_rest_pending and not _scene._hand_hover_refresh_pending:
			return
	_check(false, "Pointer focus on card %d did not settle" % index)

func _card_point(index: int) -> Vector2:
	var card: Control = _scene._hand_card_control(index)
	return card.get_global_transform_with_canvas() * Vector2(card.size.x * 0.5, card.size.y * 0.66)

func _move_pointer(point: Vector2, button_mask: int = 0) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.relative = point - _pointer
	event.button_mask = button_mask
	_pointer = point
	_capture_host.route(event)

func _press_pointer(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	_pointer = point
	_capture_host.route(event)

func _rail_for_card(index: int) -> Array[Dictionary]:
	var state: Dictionary = _scene._combat_state.duplicate()
	if index >= 0:
		var card_id: String = state["deck"]["hand"][index]
		var card: Dictionary = _scene._card_def(card_id, state)
		state["turn_order_preview_time_delta"] = _scene._combat_engine.card_time_cost_from_def(card)
		state["turn_order_preview_card_name"] = card["name"]
		state["turn_order_preview_plays_spent"] = _scene._combat_engine.card_plays_spent(card_id, state)
	return _scene._combat_engine.current_turn_order(state, _scene.TURN_ORDER_DISCLOSURE_LIMIT)

func _projection_name(entries: Array[Dictionary]) -> String:
	for entry: Dictionary in entries:
		if entry.has("projected_card_name"):
			return str(entry["projected_card_name"])
	return ""

func _rail_clocks_match(entries: Array[Dictionary]) -> bool:
	var slots: Array[Node] = _scene._turn_order_bar.get_children()
	var checked_slots: int = 0
	for slot: Node in slots:
		var index: int = slot.get_meta("turn_order_rail_index", -1)
		if index < 0 or index >= entries.size() or not slot.has_meta("turn_order_projection_card_name"):
			continue
		var entry: Dictionary = entries[index]
		if slot.get_meta("turn_order_projection_card_name") != str(entry.get("projected_card_name", "")):
			return false
		var numeral: Label = slot.get_node_or_null("TurnOrderTimeNumeral") as Label
		if numeral == null or not numeral.is_visible_in_tree() or numeral.text != _scene._turn_order_clock_badge_text(entry):
			return false
		checked_slots += 1
	return checked_slots > 0

func _check_board() -> void:
	_scene.call("_controller_enter_board", false)
	await _frame()
	var tile: Vector2i = _scene._combat_state["player"]["pos"]
	_check(_scene._controller_board_tile == tile, "Board entry stores the player tile")
	# Leave and re-enter through the real hand toggle, without moving the stick.
	_toggle_hand()
	await _frame()
	_check(_scene._controller_region == "hand" and _scene._controller_board_tile == tile, "Hand focus retains the logical tile")
	_check(_board._controller_focus_tile == _scene.INVALID_TARGET_TILE, "Hand focus retires the rendered board cursor")
	_toggle_hand()
	_check(_scene._controller_region == "board" and _scene._hovered_board_tile == tile and _scene._board_hover_refresh_pending, "Re-entering the board publishes the stored tile through the shared hover handler")
	await _frame()
	_capture("board_reentry")

	_joy(JOY_BUTTON_X)
	_joy(JOY_BUTTON_RIGHT_SHOULDER)
	_joy(JOY_BUTTON_RIGHT_SHOULDER)
	_check(_scene._controller_hand_index == AIM_CARD, "Controller focuses Lantern Shot")
	for frame: int in range(FRAME_LIMIT):
		await _frame()
		if not _scene._hand_hover_rest_pending and not _scene._hand_hover_refresh_pending:
			break
	_joy(JOY_BUTTON_A)
	for frame: int in range(AIM_SAMPLE_FRAMES):
		await _frame()
	var enemy_tile: Vector2i = _scene._combat_state["enemies"][0]["pos"]
	_check(_scene._selected_card_index == AIM_CARD and _scene._controller_board_tile == enemy_tile, "A aims Lantern Shot at the enemy")
	_joy(JOY_BUTTON_B)
	await _frame()
	var canceled: Dictionary = _board_receipt()
	_check(_scene._selected_card_index == -1 and _board._controller_focus_tile == enemy_tile, "B cancels aim while holding the enemy tile")
	_capture("board_reentry_enemy")
	_joy(JOY_BUTTON_DPAD_LEFT)
	await _frame()
	_check(_scene._controller_board_tile != enemy_tile, "D-pad moves away from the enemy tile")
	_joy(JOY_BUTTON_DPAD_RIGHT)
	await _frame()
	var moved: Dictionary = _board_receipt()
	_check(moved["tile"] == enemy_tile and not (moved["intents"] as Array).is_empty(), "Moving onto the enemy tile publishes its expanded intent")
	_check(not (moved["preview"] as Array).is_empty(), "Moving onto the enemy tile isolates its preview")
	_check(not str(moved["detail"]).is_empty() and not str(moved["detail_key"]).is_empty(), "Moving onto the enemy tile opens its surface tooltip")
	_capture("board_move_enemy")
	_check(canceled == moved, "B publishes the same hover, intent, preview and tooltip as movement (%s vs %s)" % [canceled, moved])
	_scene.call("_controller_set_board_tile", enemy_tile)
	_check(not _scene._board_hover_refresh_pending, "Refreshing a continuously focused tile does not publish another hover")

func _board_receipt() -> Dictionary:
	var cursor: Control = _scene._controller_analog_cursor
	return {
		"tile": _board.presentation.get("hover_owner_tile", _scene.INVALID_TARGET_TILE),
		"intents": _board.presentation.get("expanded_enemy_actor_keys", []),
		"preview": _board.presentation.get("isolated_enemy_actor_keys", []),
		"detail": cursor.get("_detail_text"),
		"detail_key": cursor.get("_detail_key"),
	}

func _toggle_hand() -> void:
	_joy(JOY_BUTTON_X)

func _joy(button: int) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		_capture_host.route(event)

func _frame() -> bool:
	await process_frame
	if _headless:
		# Drain deferred input/presentation before simulating the render boundary.
		await create_timer(0.0).timeout
		var resting: bool = _scene._hand_hover_rest_pending
		RenderingServer.frame_post_draw.emit()
		return resting
	await RenderingServer.frame_pre_draw
	var resting: bool = _scene._hand_hover_rest_pending
	await RenderingServer.frame_post_draw
	return resting

func _capture(label: String) -> void:
	if _headless:
		return
	var image: Image = _capture_host.viewport.get_texture().get_image()
	var path: String = ProjectSettings.globalize_path(OUTPUT_DIR.path_join(label + ".png"))
	_check(image.get_size() == HUD_FIXTURE_SIZE and image.save_png(path) == OK, "Save 1920x1080 capture " + label)
	print(path)

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		print("GFIX-26 FAIL: " + message)
