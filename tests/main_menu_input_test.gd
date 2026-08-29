extends SceneTree

const RunEngine = preload("res://scripts/run_engine.gd")
const MenuRunTransition = preload("res://scripts/menu_run_transition.gd")

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
	await _test_empty_space_pointer_motion_preserves_navigation_focus()
	SettingsStore.set_storage_path("user://startup_input_test_settings.json")
	await _test_startup_sequence(false)
	await _test_startup_sequence(true)
	await _test_startup_interruption_restores_input()
	await _test_run_entry("new", false)
	await _test_run_entry("continue", false)
	await _test_run_entry("replace", false)
	await _test_run_entry("new", true)
	await _test_run_entry("continue", true)
	await _test_loading_failure_preserves_save_and_recovers_focus()
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
	_expect(settings_button.has_focus(), "Keyboard navigation should resume at the last Settings selection after Settings closes")
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

func _test_empty_space_pointer_motion_preserves_navigation_focus() -> void:
	var saved := RunEngine.new().create_new_run(82273, ProgressionStore.default_data())
	ProgressionStore.save_run_state(saved)
	var menu = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	await process_frame
	var continue_button: Button = menu.get_node("MenuColumn/ContinueButton")
	var start_button: Button = menu.get_node("MenuColumn/StartButton")
	var settings_button: Button = menu.get_node("MenuColumn/SettingsButton")
	continue_button.grab_focus()
	await process_frame
	_expect(continue_button.has_focus(), "Valid-save navigation should begin on Continue Run")

	var empty_motion := InputEventMouseMotion.new()
	empty_motion.position = Vector2(1700.0, 920.0)
	empty_motion.global_position = empty_motion.position
	menu.call("_input", empty_motion)
	await process_frame
	_expect(continue_button.has_focus(), "Pointer motion over empty space must not clear Continue Run focus")

	await _push_navigation_down(menu.get_viewport())
	menu.call("_input", empty_motion)
	await process_frame
	_expect(start_button.has_focus(), "Empty-space pointer motion must preserve New Game focus during sequential navigation")
	_expect(bool(start_button.get_meta("umbra_selected", false)) and not bool(continue_button.get_meta("umbra_selected", false)), "Empty-space pointer motion must not snap the molten selection back to Continue Run")

	await _push_navigation_down(menu.get_viewport())
	menu.call("_input", empty_motion)
	await process_frame
	_expect(settings_button.has_focus(), "Empty-space pointer motion must preserve Settings focus farther down the list")
	_expect(bool(settings_button.get_meta("umbra_selected", false)) and not bool(continue_button.get_meta("umbra_selected", false)), "Sequential navigation must retain the last focused Umbra selection")

	settings_button.mouse_entered.emit()
	await process_frame
	settings_button.mouse_exited.emit()
	await process_frame
	_expect(not settings_button.has_focus() and bool(settings_button.get_meta("umbra_selected", false)), "Pointer movement through an action gap should retain the last hovered selection without fabricating focus")
	var navigation_resume := InputEventKey.new()
	navigation_resume.keycode = KEY_DOWN
	navigation_resume.pressed = true
	menu.call("_unhandled_input", navigation_resume)
	await process_frame
	_expect(settings_button.has_focus() and not continue_button.has_focus(), "Keyboard/controller handoff from a pointer gap must resume at the last selection instead of Continue Run")
	_stop_menu_music(menu)
	menu.queue_free()
	await process_frame
	ProgressionStore.clear_saved_run()

func _push_navigation_down(viewport: Viewport) -> void:
	var down_event := InputEventKey.new()
	down_event.keycode = KEY_DOWN
	down_event.physical_keycode = KEY_DOWN
	down_event.pressed = true
	viewport.push_input(down_event, true)
	await process_frame
	var release_event := InputEventKey.new()
	release_event.keycode = KEY_DOWN
	release_event.physical_keycode = KEY_DOWN
	release_event.pressed = false
	viewport.push_input(release_event, true)
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

func _test_run_entry(mode: String, reduced_motion: bool) -> void:
	var settings := SettingsStore.default_settings()
	settings["reduced_motion"] = reduced_motion
	SettingsStore.save_settings(settings)
	ProgressionStore.clear_saved_run()
	var progression := ProgressionStore.default_data()
	progression["embers"] = 42
	ProgressionStore.save_data(progression)
	var saved: Dictionary = {}
	if mode != "new":
		saved = RunEngine.new().create_debug_boss_run(progression) if mode == "continue" else RunEngine.new().create_new_run(82271, progression)
		saved["debug_boss_run"] = false
		saved["seed"] = 82271
		ProgressionStore.save_run_state(saved)
	var menu = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame
	await process_frame
	var music: AudioStreamPlayer = menu.get_node("MusicPlayer")
	# A nonzero position makes an accidental restart distinguishable from
	# continuous playback across the menu reparent and process lock.
	music.seek(20.0)
	await create_timer(0.06).timeout
	var original_playback := music.get_stream_playback()
	var previous_music_position := music.get_playback_position()
	var music_kept_playing := true
	var room_music_waited := true
	var start_button: Button = menu.get_node("MenuColumn/StartButton")
	if mode == "continue":
		var continue_button: Button = menu.get_node("MenuColumn/ContinueButton")
		continue_button.grab_focus()
		await _send_accept(0, JOY_BUTTON_A)
	elif mode == "replace":
		await _click_after_hover(menu, start_button)
		_expect(menu._replacement_confirmation_open, "New Run with a save must still require confirmation")
		_expect(current_scene == menu and not root.gui_disable_input, "Opening confirmation must not start loading")
		menu.replacement_confirm_button.grab_focus()
		await _send_accept(KEY_ENTER)
	else:
		await _click_after_hover(menu, start_button)
	var transition = root.get_node_or_null("MenuRunTransition")
	_expect(transition != null, "%s should enter the shared loading flow" % mode)
	if transition == null:
		return
	_expect(music.playing and not music.stream_paused, "Locking the menu must not pause its music")
	_expect(menu.is_inside_tree() and menu.is_visible_in_tree(), "The actual main menu must remain visible while loading")
	_expect(root.gui_disable_input and menu.process_mode == Node.PROCESS_MODE_DISABLED, "Loading must block GUI, keyboard and controller input")
	_expect(start_button.disabled and menu.replacement_confirm_button.disabled, "Loading must also guard repeated semantic button activation")
	menu.call("_on_start_button_pressed")
	menu.call("_on_continue_button_pressed")
	menu.call("_on_replacement_confirm_button_pressed")
	menu.call("_on_settings_button_pressed")
	menu.call("_on_replacement_cancel_button_pressed")
	_expect(not menu.settings_panel.visible and current_scene == transition, "Repeated activation and cancel must neither reopen the menu nor create another run")
	_expect(not menu._replacement_confirmation_open, "The replacement prompt must be dismissed under loading")
	transition.set_process(false)
	var counts: Array[int] = []
	var message_size: Vector2 = transition.message_label.get_minimum_size()
	for index: int in range(5):
		transition._elapsed = float(index) * MenuRunTransition.DOT_SECONDS + 0.001
		transition._update_dots()
		counts.append(transition.message_label.visible_characters)
		_expect(transition.message_label.get_minimum_size() == message_size, "Cycling dots must not resize or recenter the message")
	if reduced_motion:
		_expect(counts == [-1, -1, -1, -1, -1], "Reduced motion must keep the complete static loading message")
	else:
		var base: int = MenuRunTransition.MESSAGE.length()
		_expect(counts == [base + 1, base + 2, base + 3, base, base + 1], "Loading dots must cycle 1, 2, 3, none, 1 without rewriting the label")
	var phase_times: Dictionary = {}
	var result: Array[Node] = []
	transition.phase_changed.connect(func(value: StringName):
		phase_times[str(value)] = Time.get_ticks_msec()
		if value == &"complete":
			_expect(music.playing and not music.stream_paused and music.get_parent() == transition.destination, "Menu fade-out must not delay room activation")
		if value == &"revealing":
			_expect(music.playing and not music.stream_paused, "Menu music must continue through the visual reveal")
			_expect(transition.destination.initial_presentation_is_ready(), "Reveal must wait for the complete hand/dock layout, even without a fade")
			if mode == "continue":
				_expect(int(transition.destination.get("_hand_layout_pending_revision")) == -1, "Combat Continue must settle the card hand before revealing")
			_expect(transition.destination.is_node_ready(), "Reveal must wait for the real destination ready lifecycle")
			_expect(not transition.destination.get("_run_state").is_empty(), "Reveal must wait for the room state to exist")
			_expect(transition.destination.process_mode == Node.PROCESS_MODE_DISABLED, "Hidden room input must stay disabled through reveal")
	)
	transition.finished.connect(func(node: Node): result.append(node))
	var deadline := Time.get_ticks_msec() + 15000
	while result.is_empty() and Time.get_ticks_msec() < deadline:
		if transition.phase in [&"loading", &"preparing", &"revealing"]:
			var position := music.get_playback_position()
			music_kept_playing = music_kept_playing and music.playing and not music.stream_paused and music.has_stream_playback() and music.get_stream_playback() == original_playback and position >= previous_music_position
			previous_music_position = position
			if is_instance_valid(transition.destination) and transition.destination.is_inside_tree():
				var room_music := transition.destination.get_node_or_null("MusicPlayer") as AudioStreamPlayer
				room_music_waited = room_music_waited and (room_music == null or not room_music.playing)
		await process_frame
	_expect(music_kept_playing and previous_music_position > 20.06, "Menu music must advance without pausing, stopping or restarting during loading and room preparation")
	_expect(room_music_waited, "Room music must wait for the ready-to-reveal handoff")
	_expect(not result.is_empty(), "%s loading should finish" % mode)
	if result.is_empty():
		return
	var room: Node = result[0]
	var room_music := room.get_node_or_null("MusicPlayer") as AudioStreamPlayer
	var entry: Dictionary = MusicLibrary.entry(str(room.get("_active_music_id")))
	if mode == "continue":
		_expect(not entry.is_empty(), "Combat Continue must retain its existing music selection")
	_expect(room_music == null or not room_music.playing, "Room music must wait while menu music fades out")
	_expect(current_scene == room and not root.gui_disable_input, "The completed room must become current with restored input")
	_expect(room.process_mode == Node.PROCESS_MODE_INHERIT, "The room must resume normal processing")
	await process_frame
	_expect(not is_instance_valid(menu) and not is_instance_valid(transition), "Visual completion must free the menu/helper without waiting for audio")
	var handoff_start: int = int(phase_times["complete"])
	var menu_stopped_ms := -1
	var room_started_ms := -1
	var no_overlap := true
	var menu_faded_down := true
	var previous_volume := music.volume_linear
	var initial_room_volume := -1.0
	while Time.get_ticks_msec() - handoff_start < 1500:
		var outgoing := is_instance_valid(music) and music.playing
		var incoming := room_music != null and room_music.playing
		no_overlap = no_overlap and not (outgoing and incoming)
		var elapsed := Time.get_ticks_msec() - handoff_start
		if outgoing:
			menu_faded_down = menu_faded_down and music.volume_linear <= previous_volume + 0.001 and music.get_stream_playback() == original_playback
			previous_volume = music.volume_linear
		elif menu_stopped_ms < 0:
			menu_stopped_ms = elapsed
		if incoming and room_started_ms < 0:
			room_started_ms = elapsed
			initial_room_volume = room_music.volume_linear
		if not room.get("_initial_music_deferred") and not is_instance_valid(music) and (not incoming or elapsed - room_started_ms > 350):
			break
		await process_frame
	_expect(no_overlap, "Menu and room tracks must never play simultaneously")
	_expect(menu_faded_down and menu_stopped_ms >= 150 and menu_stopped_ms < 450, "Menu audio must fade down over a fraction of a second after room activation")
	_expect(not room.get("_initial_music_deferred"), "Music deferral must clear after the intentional gap, even in unscored rooms")
	_expect(not is_instance_valid(music) and room.get_node_or_null("MenuMusicTail") == null, "Outgoing music must be freed before the new track begins")
	if not entry.is_empty():
		var target_volume := db_to_linear(float(entry.get("volume_db", -12.0)))
		_expect(room_started_ms - menu_stopped_ms >= 60 and room_started_ms - menu_stopped_ms < 250, "A short intentional gap must separate the tracks")
		_expect(initial_room_volume >= 0.0 and initial_room_volume < target_volume, "The room track must begin with a fade-in")
		_expect(is_equal_approx(room_music.volume_linear, target_volume), "The short room fade-in must reach the authored level")
		var playing_track := room_music.get_stream_playback()
		room.call("start_initial_music_after_loading", MenuRunTransition.ROOM_MUSIC_FADE_IN_SECONDS)
		_expect(room_music.get_stream_playback() == playing_track, "Repeated completion must not restart the room track")
	else:
		_expect(room_music == null or not room_music.playing, "Unscored rooms must retain their quiet context")
	print("Music handoff %s: menu stopped=%d ms, room started=%d ms, overlap=%s" % [mode, menu_stopped_ms, room_started_ms, not no_overlap])
	room.call("_play_music", MusicLibrary.entry(MusicLibrary.RELIC_ROOM_TRACK_ID))
	room_music = room.get_node("MusicPlayer")
	_expect(room_music.playing and is_equal_approx(room_music.volume_db, -60.0) and room.get("_music_tween") != null, "Later in-run music changes must retain their existing fade")
	var run_state: Dictionary = room.get("_run_state")
	if mode == "continue":
		_expect(int(run_state.get("seed")) == 82271, "Continue must load the same saved run")
	elif mode == "replace":
		_expect(int(run_state.get("seed")) != 82271 and int(ProgressionStore.load_data().get("embers")) == 0, "Confirmed replacement must create a new run with the established ember reset")
	_expect(not root.has_meta("labyrinth_resume_saved_run"), "Resume metadata must be consumed exactly once")
	var reveal_ms: int = int(phase_times.get("complete", 0)) - int(phase_times.get("revealing", 0))
	_expect(reveal_ms < 50 if reduced_motion else reveal_ms >= 175, "Reveal timing must respect reduced motion")
	print("Run entry PASS: %s reduced_motion=%s reveal_ms=%d" % [mode, reduced_motion, reveal_ms])
	await process_frame
	_expect(not is_instance_valid(menu) and not is_instance_valid(transition), "Completion must free the old menu and loading layer")
	room.queue_free()
	await process_frame
	await process_frame

func _test_loading_failure_preserves_save_and_recovers_focus() -> void:
	var saved := RunEngine.new().create_new_run(82272, ProgressionStore.default_data())
	ProgressionStore.save_run_state(saved)
	var before := FileAccess.get_file_as_bytes(RUN_PATH)
	var menu = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame
	var music: AudioStreamPlayer = menu.get_node("MusicPlayer")
	var original_playback := music.get_stream_playback()
	var original_music_process_mode := music.process_mode
	menu._using_keyboard_navigation = true
	# A valid resource of the wrong type exercises recoverable scene failure
	# without generating an intentional engine missing-resource error.
	menu.call("_change_scene_to_file", "res://themes/default_theme.tres", Callable(menu, "_prepare_new_game"))
	var deadline := Time.get_ticks_msec() + 5000
	while menu._loading_run and Time.get_ticks_msec() < deadline:
		_expect(music.playing and not music.stream_paused, "Music must continue while a failing load is pending")
		await process_frame
	_expect(music.playing and not music.stream_paused and music.get_stream_playback() == original_playback, "Failed loading must preserve the same playing menu track")
	_expect(music.process_mode == original_music_process_mode, "Failure must restore the music processing policy")
	_expect(not menu._loading_run and current_scene == menu, "A failed load must restore the existing menu")
	_expect(not root.gui_disable_input and menu.process_mode == Node.PROCESS_MODE_INHERIT, "A failed load must restore input and processing")
	_expect(FileAccess.get_file_as_bytes(RUN_PATH) == before, "A failed New Run load must leave the previous save byte-for-byte intact")
	_expect(menu._loading_error != null and menu._loading_error.visible, "A failed load must show a recoverable error")
	menu._loading_error.hide()
	menu._loading_error.confirmed.emit()
	await process_frame
	_expect(menu.continue_button.has_focus(), "Dismissing a loading error must recover keyboard/controller focus")
	menu.call("_on_settings_button_pressed")
	_expect(menu.settings_panel.visible, "Menu actions must work again after a failed load")
	_stop_menu_music(menu)
	menu.queue_free()
	await process_frame

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
