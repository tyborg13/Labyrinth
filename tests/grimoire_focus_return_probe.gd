extends "res://tests/grimoire_search_probe.gd"

const SettingsStore = preload("res://scripts/settings_store.gd")
const InputRouterScript = preload("res://scripts/input_router.gd")
const ContextualCombatTutorial = preload("res://scripts/contextual_combat_tutorial.gd")

# Uses the live scene and native GUI events. Headless runs exercise the same
# assertions; native runs also capture each returned-focus state at UI100.
func _run_probe() -> void:
	SettingsStore.set_storage_path("user://grimoire_focus_settings.json")
	var settings: Dictionary = SettingsStore.default_settings()
	settings["ui_scale"] = 1.0
	SettingsStore.save_settings(settings)
	SettingsStore.apply_settings(settings, root, false)
	var progression: Dictionary = ContextualCombatTutorial.complete_tutorial(ProgressionStore.default_data())
	ProgressionStore.save_data(progression)
	var router: Node = root.get_node("InputRouter")
	router.call("set_forced_state_for_test", InputRouterScript.MODALITY_POINTER, InputRouterScript.FAMILY_XBOX)
	_capture_viewport = SubViewport.new()
	_capture_viewport.size = VIEWPORT_SIZE
	_capture_viewport.msaa_2d = Viewport.MSAA_4X
	_capture_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_capture_viewport)
	var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
	_capture_viewport.add_child(scene)
	await _settle()
	scene.call("_load_run_state", RunEngine.new().create_new_run(84217, progression))
	scene.call("_close_dialogue")
	await _settle()
	# A fresh run opens its route map; this proof starts at the underlying HUD.
	scene.call("_close_large_map")
	await _settle()
	_expect(not bool(scene.get("_animation_lock")) and not bool(scene.get("_dialogue_active")), "Focus fixture should allow normal HUD input")
	var opener: Button = scene.get("grimoire_button") as Button
	var scrim: Control = scene.get("_grimoire_scrim") as Control
	var close_button: Button
	for candidate: Node in scrim.find_children("*", "Button", true, false):
		if (candidate as Button).text == "Close":
			close_button = candidate as Button
	_expect(close_button != null, "Grimoire should expose its native Close button")
	if close_button == null:
		return

	# The reported regression: a pointer click acquires focus on the opener,
	# then clicking Close must not restore that focus behind the moved pointer.
	await _click(opener.get_global_rect().get_center())
	_expect(scrim.visible, "Pointer activation should open Grimoire")
	await _click(close_button.get_global_rect().get_center())
	await _point(Vector2(960, 940))
	_expect(not scrim.visible, "Pointer Close should dismiss Grimoire")
	_expect(not opener.has_focus() and not opener.is_hovered(), "Pointer Close must leave the unhovered Grimoire opener unfocused")
	await _capture("grimoire_focus_v1_pointer_closed.png")

	await _click(opener.get_global_rect().get_center())
	await _click(Vector2(100, 700))
	_expect(not scrim.visible and not opener.has_focus(), "Pointer scrim dismissal must not restore opener focus")
	await _capture("grimoire_focus_v1_scrim_closed.png")

	# Keyboard dismissal restores a usable return point, even when opened by mouse.
	await _click(opener.get_global_rect().get_center())
	await _point(Vector2(960, 940))
	await _key(KEY_ESCAPE)
	_expect(not scrim.visible and opener.has_focus(), "Keyboard cancel should restore opener focus")
	await _capture("grimoire_focus_v1_keyboard_return.png")
	await _action("ui_accept")
	_expect(scrim.visible, "Returned keyboard focus must be able to reopen Grimoire")
	close_button.grab_focus()
	await _action("ui_accept")
	_expect(not scrim.visible and opener.has_focus(), "Keyboard activation of Close should restore focus")

	# Controller return and controller-to-pointer dismissal remain distinct.
	router.call("set_forced_state_for_test", InputRouterScript.MODALITY_CONTROLLER, InputRouterScript.FAMILY_XBOX)
	await _settle()
	opener.grab_focus()
	scene.call("_open_grimoire_overlay")
	await _settle()
	await _joypad_button(JOY_BUTTON_B)
	_expect(not scrim.visible, "Controller cancel should dismiss Grimoire")
	_expect(opener.has_focus() or not (scene.get("_controller_focus_candidate") as Dictionary).is_empty(), "Controller close should restore a navigable return point")
	await _capture("grimoire_focus_v1_controller_return.png")
	opener.grab_focus()
	scene.call("_open_grimoire_overlay")
	await _settle()
	router.call("set_forced_state_for_test", InputRouterScript.MODALITY_POINTER, InputRouterScript.FAMILY_XBOX)
	await _click(close_button.get_global_rect().get_center())
	await _point(Vector2(960, 940))
	_expect(not scrim.visible and not opener.has_focus(), "Pointer handoff before Close must clear the controller opener highlight")
	await _capture("grimoire_focus_v1_pointer_handoff.png")

	# Hover is still a live pointer cue after closing, not a latched selection.
	await _point(opener.get_global_rect().get_center())
	_expect(opener.is_hovered(), "Pointer can hover the closed Grimoire opener")
	await _capture("grimoire_focus_v1_hover.png")
	await _point(Vector2(960, 940))
	_expect(not opener.is_hovered() and not opener.has_focus(), "Moving off should return the opener to its idle state")
	scene.queue_free()
	await process_frame
	_capture_viewport.queue_free()
	router.call("clear_forced_state_for_test")
	await process_frame

func _point(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	motion.relative = Vector2(10, 10)
	_capture_viewport.push_input(motion, true)
	await _settle()

func _click(point: Vector2) -> void:
	await _point(point)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		_capture_viewport.push_input(event, true)
		await process_frame
	await _settle()

func _action(action: String) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		_capture_viewport.push_input(event, true)
		await process_frame
	await _settle()

func _joypad_button(button: JoyButton) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		_capture_viewport.push_input(event, true)
		await process_frame
	await _settle()

func _key(key: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		event.pressed = pressed
		_capture_viewport.push_input(event, true)
		await process_frame
	await _settle()
