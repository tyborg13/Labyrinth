extends SceneTree

const MusicLibrary = preload("res://scripts/music_library.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")

const PROGRESSION_PATH: String = "user://main_menu_input_test_progression.json"
const RUN_PATH: String = "user://main_menu_input_test_run.save"

var _failures: Array[String] = []

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	ProgressionStore.set_storage_path(PROGRESSION_PATH)
	ProgressionStore.set_run_storage_path(RUN_PATH)
	ProgressionStore.clear_saved_run()
	await _test_hover_and_press_same_frame_activates_once()
	SettingsStore.set_storage_path("user://startup_input_test_settings.json")
	await _test_startup_sequence(false)
	await _test_startup_sequence(true)
	await _test_startup_interruption_restores_input()
	SettingsStore.clear_storage()
	_cleanup_storage()
	if _failures.is_empty():
		print("TEST RESULT: PASS — main menu input and startup transitions")
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
	_expect(music_player != null, "Main menu should create its dedicated music player")
	if music_player != null:
		var entry: Dictionary = MusicLibrary.entry(MusicLibrary.OLD_CASTLE_MENU_TRACK_ID)
		_expect(music_player.bus == SettingsStore.MUSIC_BUS, "Main-menu music should use the Music bus")
		_expect(music_player.playing, "The Old Castle main-menu track should start automatically")
		_expect(is_equal_approx(music_player.volume_db, float(entry.get("volume_db", 0.0))), "Main-menu playback should use the authored track volume")
		_expect(music_player.stream is AudioStreamOggVorbis, "The Old Castle main-menu track should use the promoted Ogg")
		if music_player.stream is AudioStreamOggVorbis:
			var ogg_stream: AudioStreamOggVorbis = music_player.stream as AudioStreamOggVorbis
			_expect(ogg_stream.loop, "The Old Castle main-menu Ogg should loop natively")
			_expect(ogg_stream.get_length() > 131.5 and ogg_stream.get_length() < 131.6, "The Old Castle main-menu Ogg should retain its verified duration")
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

func _test_startup_sequence(reduced_motion: bool) -> void:
	var settings: Dictionary = SettingsStore.default_settings()
	settings["reduced_motion"] = reduced_motion
	_expect(SettingsStore.save_settings(settings), "Startup test settings should save")
	var packed: PackedScene = load("res://scenes/startup.tscn")
	var startup = packed.instantiate()
	var phase_times: Dictionary = {}
	var result: Array[Control] = []
	startup.phase_changed.connect(func(value: StringName): phase_times[str(value)] = Time.get_ticks_msec())
	startup.finished.connect(func(value: Control): result.append(value))
	var cursor := root.get_node_or_null("CursorFeedback") as CanvasLayer
	var cursor_was_visible: bool = cursor.visible if cursor != null else false
	root.add_child(startup)
	_expect(root.gui_disable_input, "Startup should gate hidden GUI input")
	if cursor != null:
		_expect(not cursor.visible and not cursor.is_processing_input(), "Startup should hide the cursor and suppress click feedback")
	while startup.phase != &"hold":
		await process_frame
	_expect(is_equal_approx(startup.seal.modulate.a, 1.0), "The two-second hold should be fully opaque")
	while result.is_empty() and startup.phase != &"menu_fade_in":
		await process_frame
	if not reduced_motion:
		var gated_menu: Control = startup.menu
		var button: Button = gated_menu.get_node("MenuColumn/SettingsButton")
		button.grab_focus()
		await _click_after_hover(gated_menu, button)
		await _send_accept(KEY_ENTER)
		await _send_accept(0, JOY_BUTTON_A)
		_expect(not gated_menu.get_node("SettingsPanel").visible, "Pointer, keyboard and controller must not activate the fading menu")
	while result.is_empty():
		await process_frame
	var menu: Control = result[0]
	_expect(phase_times["fade_out"] - phase_times["hold"] >= 2000, "The seal should remain fully visible for at least two seconds")
	if not reduced_motion:
		_expect(phase_times["hold"] - phase_times["fade_in"] >= 350, "Normal startup should fade the seal in")
		_expect(phase_times["menu_black"] - phase_times["fade_out"] >= 300, "Normal startup should fade the seal out")
		_expect(phase_times["complete"] - phase_times["menu_fade_in"] >= 350, "Normal startup should fade the menu in")
	else:
		_expect(phase_times["menu_black"] - phase_times["fade_out"] < 50, "Reduced motion should omit the seal fade-out")
		_expect(phase_times["complete"] - phase_times["menu_fade_in"] < 50, "Reduced motion should omit the menu fade")
	_expect(not root.gui_disable_input, "Finished startup should restore GUI input")
	_expect(current_scene == menu and is_equal_approx(menu.modulate.a, 1.0), "The existing menu should become the fully visible current scene")
	if cursor != null:
		_expect(cursor.visible == cursor_was_visible and cursor.is_processing_input(), "Startup should restore the cursor and its input")
	var settings_button: Button = menu.get_node("MenuColumn/SettingsButton")
	var settings_panel: PanelContainer = menu.get_node("SettingsPanel")
	await _click_after_hover(menu, settings_button)
	_expect(settings_panel.visible, "The first pointer click after startup should work")
	settings_panel.call("back_button").pressed.emit()
	await process_frame
	settings_button.grab_focus()
	await _send_accept(KEY_ENTER)
	_expect(settings_panel.visible, "Keyboard activation should work after startup")
	settings_panel.call("back_button").pressed.emit()
	await process_frame
	settings_button.grab_focus()
	await _send_accept(0, JOY_BUTTON_A)
	_expect(settings_panel.visible, "Controller activation should work after startup")
	print("Startup timing reduced_motion=%s: %s" % [reduced_motion, JSON.stringify(phase_times)])
	_stop_menu_music(menu)
	menu.queue_free()
	await process_frame
	# Normal return paths load this scene directly and must never replay startup.
	var returning_menu: Control = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(returning_menu)
	await process_frame
	_expect(not root.gui_disable_input and is_equal_approx(returning_menu.modulate.a, 1.0), "Returning to the menu should not replay the intro")
	_stop_menu_music(returning_menu)
	returning_menu.queue_free()
	await process_frame

func _test_startup_interruption_restores_input() -> void:
	var startup = load("res://scenes/startup.tscn").instantiate()
	root.add_child(startup)
	_expect(root.gui_disable_input, "Startup interruption test should begin locked")
	startup.queue_free()
	await process_frame
	_expect(not root.gui_disable_input, "Interrupted startup should not strand the input lock")

func _send_accept(key: int, joy_button: int = -1) -> void:
	for pressed: bool in [true, false]:
		var event: InputEvent
		if joy_button >= 0:
			var joy := InputEventJoypadButton.new()
			joy.button_index = joy_button
			joy.pressed = pressed
			event = joy
		else:
			var keyboard := InputEventKey.new()
			keyboard.keycode = key
			keyboard.pressed = pressed
			event = keyboard
		root.push_input(event, true)
		await process_frame

func _stop_menu_music(menu: Control) -> void:
	var music := menu.get_node_or_null("MusicPlayer") as AudioStreamPlayer
	if music != null:
		music.stop()
		music.stream = null

func _cleanup_storage() -> void:
	ProgressionStore.clear_saved_run()
	if FileAccess.file_exists(PROGRESSION_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSION_PATH))

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
