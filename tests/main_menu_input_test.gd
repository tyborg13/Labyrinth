extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")

const PROGRESSION_PATH: String = "user://main_menu_input_test_progression.json"
const RUN_PATH: String = "user://main_menu_input_test_run.save"

var _failures: Array[String] = []

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	ProgressionStore.set_storage_path(PROGRESSION_PATH)
	ProgressionStore.set_run_storage_path(RUN_PATH)
	ProgressionStore.clear_saved_run()
	await _test_hover_and_press_same_frame_activates_once()
	_cleanup_storage()
	if _failures.is_empty():
		print("TEST RESULT: PASS — main menu first-click input")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("TEST RESULT: FAIL — %d main menu first-click input failure(s)" % _failures.size())
	quit(1)

func _test_hover_and_press_same_frame_activates_once() -> void:
	var packed: PackedScene = load("res://scenes/main_menu.tscn")
	_expect(packed != null, "Main menu scene should load")
	if packed == null:
		return
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame
	var start_button: Button = instance.get_node("MenuColumn/StartButton")
	var settings_button: Button = instance.get_node("MenuColumn/SettingsButton")
	var settings_panel: PanelContainer = instance.get_node("SettingsPanel")
	var navigation_event := InputEventKey.new()
	navigation_event.keycode = KEY_DOWN
	navigation_event.pressed = true
	instance.call("_unhandled_input", navigation_event)
	_expect(start_button.has_focus(), "Keyboard navigation should focus the default enabled main-menu action")
	var held_motion := InputEventMouseMotion.new()
	held_motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	instance.call("_input", held_motion)
	_expect(start_button.has_focus(), "Mouse movement during a held click should not clear button focus before release")

	await _click_after_hover(instance, settings_button)
	_expect(settings_panel.visible, "Hover followed immediately by a click should open Settings on the first release")
	var settings_back_button: Button = settings_panel.call("back_button") as Button
	settings_back_button.pressed.emit()
	await process_frame
	_expect(not settings_panel.visible, "Settings Back should return to the main menu")
	instance.call("_unhandled_input", navigation_event)
	_expect(start_button.has_focus(), "Keyboard navigation should recover after Settings closes")
	await _click_after_hover(instance, settings_button)
	_expect(settings_panel.visible, "Settings should reopen on the first pointer click after focus recovery")

	var music_player: AudioStreamPlayer = instance.get_node_or_null("MusicPlayer") as AudioStreamPlayer
	if music_player != null:
		music_player.stop()
		music_player.stream = null
	instance.queue_free()
	await process_frame

func _click_after_hover(instance: Node, button: Button) -> void:
	var button_center: Vector2 = button.get_global_rect().get_center()
	var hover_event := InputEventMouseMotion.new()
	hover_event.position = button_center
	hover_event.global_position = button_center
	instance.get_viewport().push_input(hover_event, true)
	var press_event := InputEventMouseButton.new()
	press_event.button_index = MOUSE_BUTTON_LEFT
	press_event.pressed = true
	press_event.position = button_center
	press_event.global_position = button_center
	instance.get_viewport().push_input(press_event, true)
	await process_frame
	var release_event := InputEventMouseButton.new()
	release_event.button_index = MOUSE_BUTTON_LEFT
	release_event.pressed = false
	release_event.position = button_center
	release_event.global_position = button_center
	instance.get_viewport().push_input(release_event, true)
	await process_frame

func _cleanup_storage() -> void:
	ProgressionStore.clear_saved_run()
	if FileAccess.file_exists(PROGRESSION_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSION_PATH))

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
