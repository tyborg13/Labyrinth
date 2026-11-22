extends SceneTree

const CursorFeedback = preload("res://scripts/cursor_feedback.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Store = preload("res://scripts/progression_store.gd")
const TEST_VIEWPORT := Vector2i(1920, 1080)
const COMBAT_SEED: int = 123
const CUE_SETTLE_SECONDS: float = (CursorFeedback.FOCUS_COOLDOWN_MSEC + 1) / 1000.0

var _failures: Array[String]
var _feedback: Node

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	Settings.set_storage_path("user://settings_modal_input_settings.json")
	Store.set_storage_path("user://settings_modal_input_progression.json")
	Store.set_run_storage_path("user://settings_modal_input_run.save")
	var settings: Dictionary = Settings.default_settings()
	settings["display_mode"] = Settings.DISPLAY_WINDOWED
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = true
	Settings.save_settings(settings)
	if DisplayServer.get_name() == "headless":
		process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = TEST_VIEWPORT
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.size = TEST_VIEWPORT
	call_deferred("_run")

func _run() -> void:
	_feedback = root.get_node("CursorFeedback")
	await _wait_for_cues()
	root.size = TEST_VIEWPORT
	await process_frame
	root.notify_mouse_entered()
	await _test_title()
	await _test_pause()
	for failure: String in _failures:
		push_error(failure)
	if _failures.is_empty():
		print("TEST RESULT: PASS — Settings modal input")
	else:
		print("TEST RESULT: FAIL — %d Settings modal input failure(s)" % _failures.size())
	quit(0 if _failures.is_empty() else 1)

func _test_title() -> void:
	var menu: Control = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	await _wait_for_cues()
	var opener: Button = menu.get_node("MenuColumn/SettingsButton")
	var background: Button = menu.get("chronicle_button")
	var panel: Control = menu.get_node("SettingsPanel")
	var back: Button = panel.call("back_button")
	await _click(opener.get_global_rect().get_center())
	_expect(panel.visible, "Title: pointer opens Settings")
	await _check_modal("Title (pointer entry)", panel, background)
	await _key(KEY_ESCAPE)
	_expect(not panel.visible, "Title: Esc closes Settings")
	opener.grab_focus()
	await _joy(JOY_BUTTON_A)
	_expect(panel.visible and back.has_focus(), "Title: controller opens Settings and focuses Back")
	await _check_modal("Title (controller entry)", panel, background)
	await _check_confirmation("Title", panel, background)
	await _joy(JOY_BUTTON_B)
	_expect(not panel.visible and opener.has_focus(), "Title: B closes Settings and restores focus to its opener")
	await _click(opener.get_global_rect().get_center())
	await _click(back.get_global_rect().get_center())
	_expect(not panel.visible, "Title: pointer Back closes Settings")
	menu.queue_free()
	await process_frame

func _test_pause() -> void:
	var run: Node = load("res://scenes/run_scene.tscn").instantiate()
	root.add_child(run)
	await process_frame
	await process_frame
	run.call("_close_dialogue")
	var engine = preload("res://scripts/run_engine.gd").new()
	var state: Dictionary = engine.create_new_run(COMBAT_SEED, Store.default_data())
	run.call("_load_run_state", state)
	await process_frame
	await process_frame
	run.call("_close_dialogue")
	for coord: Vector2i in engine.available_moves(state):
		var preview: Dictionary = engine.move_to_room(state.duplicate(true), coord)
		if preview.get("mode") == "combat":
			state = engine.begin_pre_battle_combat(engine.move_to_pre_battle(state, coord))
			break
	_expect(state.get("mode") == "combat", "Pause fixture reaches combat")
	run.call("_load_run_state", state)
	run.call("_close_dialogue")
	await _wait_for_cues()
	run.call("_open_menu_overlay")
	await _wait_for_cues()
	var menu: Control = run.get("_menu_dialog")
	var panel: Control = run.get("_settings_panel")
	var opener: Button = _find_button(menu, "Settings")
	var background: Button = run.get("grimoire_button")
	opener.grab_focus()
	await _joy(JOY_BUTTON_A)
	_expect(panel.is_visible_in_tree() and not menu.visible, "Pause: controller opens Settings and hides the pause buttons")
	await _check_modal("Pause", panel, background)
	await _check_confirmation("Pause", panel, background)
	await _key(KEY_ESCAPE)
	await _wait_for_cues()
	_expect(not panel.visible and menu.visible and opener.has_focus(), "Pause: Esc restores focus to the menu's Settings button")
	await _joy(JOY_BUTTON_A)
	await _joy(JOY_BUTTON_B)
	_expect(not panel.visible and menu.visible, "Pause: B returns to the menu")
	await _joy(JOY_BUTTON_A)
	var back: Button = panel.call("back_button")
	back.grab_focus()
	await _joy(JOY_BUTTON_A)
	_expect(not panel.visible and menu.visible, "Pause: controller Back returns to the menu")
	run.queue_free()
	await process_frame

func _check_confirmation(context: String, panel: Control, background: Button) -> void:
	_find_button(panel, "Restore Defaults").grab_focus()
	await _joy(JOY_BUTTON_A)
	var confirmation: Control = panel.get("_confirmation_panel")
	_expect(confirmation.is_visible_in_tree(), context + ": A opens Restore Defaults confirmation")
	await _check_modal(context + " confirmation", panel, background, confirmation)
	await _joy(JOY_BUTTON_B)
	_expect(panel.visible and not confirmation.visible, context + ": B cancels confirmation and keeps Settings open")

func _check_modal(context: String, panel: Control, background: Button, focus_scope: Control = null) -> void:
	if focus_scope == null: focus_scope = panel
	var counters := {"hover": 0, "focus": 0, "press": 0}
	var hovered := func() -> void: counters["hover"] += 1
	var focused := func() -> void: counters["focus"] += 1
	var pressed := func() -> void: counters["press"] += 1
	background.mouse_entered.connect(hovered)
	background.focus_entered.connect(focused)
	background.pressed.connect(pressed)

	var point: Vector2 = background.get_global_rect().get_center()
	_expect(root.get_visible_rect().has_point(point) and not panel.get_global_rect().has_point(point),
		"%s: %s at %s must be inside the viewport and outside Settings %s" % [context, background.name, point, panel.get_global_rect()])
	await _wait_for_cues()
	var before: Dictionary = _feedback.feedback_counts()
	var focus_before: Control = root.gui_get_focus_owner()
	_move(point)
	await process_frame
	var hover_state: bool = background.is_hovered()
	var highlight: bool = bool(background.get_meta("umbra_selected", false)) or bool(background.get_meta("ui_button_feedback_active", false))
	var hover_cues: int = _feedback.feedback_counts()["focus"] - before["focus"]
	var focus_after_hover: Control = root.gui_get_focus_owner()
	await _click(point)
	var focus_after_click: Control = root.gui_get_focus_owner()
	var click_cues: Dictionary = _feedback.feedback_counts()
	var valid_cues: int = click_cues["valid"] - before["valid"]
	var invalid_cues: int = click_cues["invalid"] - before["invalid"]
	print("%s / %s pointer: hover=%s entered=%d highlight=%s pressed=%d hover_sfx=%d valid_click_sfx=%d invalid_click_sfx=%d focus=%s -> %s -> %s" %
		[context, background.name, hover_state, counters["hover"], highlight, counters["press"], hover_cues, valid_cues,
		invalid_cues, _name(focus_before), _name(focus_after_hover), _name(focus_after_click)])
	_expect(not hover_state and not highlight and counters["hover"] == 0 and counters["press"] == 0 and hover_cues == 0,
		context + ": pointer hover and click must leave the background button inert")
	_expect(valid_cues == 0 and invalid_cues == 0, context + ": outside clicks must be silent")
	_expect(focus_after_hover == focus_before and focus_after_click == focus_before, context + ": outside pointer events must preserve focus")

	var focus_moved: bool = false
	var controller_inside: bool = true
	for button: JoyButton in [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]:
		var previous: Control = root.gui_get_focus_owner()
		await _joy(button)
		var current: Control = root.gui_get_focus_owner()
		focus_moved = focus_moved or (current != null and previous != null and current != previous)
		controller_inside = controller_inside and current != null and focus_scope.is_ancestor_of(current)
	print("%s / %s controller: moved=%s inside=%s background_focus=%d pressed=%d" %
		[context, background.name, focus_moved, controller_inside, counters["focus"], counters["press"]])
	_expect(focus_moved and controller_inside and counters["focus"] == 0 and counters["press"] == 0,
		context + ": controller moves focus within Settings without activating the background")
	background.mouse_entered.disconnect(hovered)
	background.focus_entered.disconnect(focused)
	background.pressed.disconnect(pressed)

func _find_button(scope: Control, label: String) -> Button:
	for button: Button in scope.find_children("*", "Button", true, false):
		if button.text == label: return button
	return null

func _wait_for_cues() -> void:
	await process_frame
	await create_timer(CUE_SETTLE_SECONDS).timeout
	while _feedback.is_loading():
		await process_frame

func _move(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.relative = point - root.get_mouse_position()
	root.push_input(event, true)

func _click(point: Vector2) -> void:
	_move(point)
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	await _press(event)

func _joy(button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	await _press(event)

func _key(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	await _press(event)

func _press(event: InputEvent) -> void:
	event.pressed = true
	root.push_input(event, true)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await process_frame

func _name(control: Control) -> String:
	return str(control.name) if control != null else "none"

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
