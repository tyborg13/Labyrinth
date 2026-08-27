extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")
const MenuRunTransition = preload("res://scripts/menu_run_transition.gd")
const AssetLoader = preload("res://scripts/asset_loader.gd")

const PROGRESSION_PATH: String = "user://main_menu_resume_probe_progression.json"
const RUN_PATH: String = "user://main_menu_resume_probe_run.save"
const OUTPUT_DIR: String = "user://probes/main_menu_resume_safety_20260827_v1"
const VIEWPORT_SIZE: Vector2i = Vector2i(1920, 1080)

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = VIEWPORT_SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.size = VIEWPORT_SIZE
	ProgressionStore.set_storage_path(PROGRESSION_PATH)
	ProgressionStore.set_run_storage_path(RUN_PATH)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_cleanup_storage()
	SettingsStore.set_storage_path("user://menu_loading_probe_settings.json")
	var settings := SettingsStore.default_settings()
	settings["display_mode"] = SettingsStore.DISPLAY_WINDOWED
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = OS.get_cmdline_user_args().has("--reduced-motion")
	SettingsStore.save_settings(settings)
	if OS.get_cmdline_user_args().has("--loading"):
		await _capture_loading_sequence(settings["reduced_motion"])
		return
	await _capture_valid_save_states()
	await _capture_no_save_state()
	await _capture_corrupt_save_state()
	_cleanup_storage()
	await process_frame
	await process_frame
	var steam_service: Node = root.get_node_or_null("SteamService")
	if steam_service != null:
		root.remove_child(steam_service)
		steam_service.free()
	AssetLoader._audio_cache.clear()
	await process_frame
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	quit(0)

func _capture_valid_save_states() -> void:
	var progression: Dictionary = ProgressionStore.default_data()
	progression["embers"] = 91
	progression["level"] = 4
	ProgressionStore.save_data(progression)
	var run_state: Dictionary = RunEngine.new().create_debug_boss_run(progression)
	run_state["debug_boss_run"] = false
	run_state["player_hp"] = 175
	run_state["player_max_hp"] = 260
	run_state["held_embers"] = 74
	run_state["unbanked_embers"] = 74
	var combat_state: Dictionary = (run_state.get("combat_state", {}) as Dictionary).duplicate(true)
	var player: Dictionary = (combat_state.get("player", {}) as Dictionary).duplicate(true)
	player["hp"] = 175
	player["max_hp"] = 260
	combat_state["player"] = player
	run_state["combat_state"] = combat_state
	ProgressionStore.save_run_state(run_state)
	var instance: Node = await _instantiate_menu()
	await _save_screenshot("%s/valid_resume.png" % OUTPUT_DIR)
	instance.call("_on_settings_button_pressed")
	await process_frame
	await process_frame
	await _save_screenshot("%s/settings.png" % OUTPUT_DIR)
	instance.call("_on_settings_back_button_pressed")
	await process_frame
	instance.call("_on_start_button_pressed")
	await process_frame
	await _save_screenshot("%s/replacement_confirmation.png" % OUTPUT_DIR)
	_stop_menu_music(instance)
	instance.queue_free()
	await process_frame

func _capture_no_save_state() -> void:
	ProgressionStore.clear_saved_run()
	var instance: Node = await _instantiate_menu()
	await _save_screenshot("%s/no_save.png" % OUTPUT_DIR)
	_stop_menu_music(instance)
	instance.queue_free()
	await process_frame

func _capture_corrupt_save_state() -> void:
	var file: FileAccess = FileAccess.open(RUN_PATH, FileAccess.WRITE)
	file.store_var({
		"seed": 9081,
		"mode": "combat",
		"current_room": Vector2i.ZERO,
		"current_room_layout": {"width": 9, "height": 9},
		"rooms": {"0,0": {"coord": Vector2i.ZERO, "depth": 0, "type": "combat"}},
		"deck_cards": ["quick_stab"],
		"player_hp": 50,
		"player_max_hp": 100,
		"held_embers": 10,
		"unbanked_embers": 10,
		"combat_state": {}
	}, false)
	file.close()
	var instance: Node = await _instantiate_menu()
	await _save_screenshot("%s/corrupt_save.png" % OUTPUT_DIR)
	_stop_menu_music(instance)
	instance.queue_free()
	await process_frame

func _instantiate_menu() -> Node:
	var packed: PackedScene = load("res://scenes/main_menu.tscn")
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame
	return instance

func _save_screenshot(path: String) -> void:
	await process_frame
	var image: Image = root.get_texture().get_image()
	assert(image.get_size() == VIEWPORT_SIZE, "Proof must be captured at the exact output resolution")
	var error: Error = image.save_png(ProjectSettings.globalize_path(path))
	if error != OK:
		push_error("Could not save %s (error %d)" % [path, error])

func _cleanup_storage() -> void:
	ProgressionStore.clear_saved_run()
	if FileAccess.file_exists(PROGRESSION_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSION_PATH))

func _stop_menu_music(instance: Node) -> void:
	var music_player: AudioStreamPlayer = instance.get_node_or_null("MusicPlayer") as AudioStreamPlayer
	if music_player == null:
		return
	music_player.stop()
	music_player.stream = null

func _capture_loading_sequence(reduced_motion: bool) -> void:
	var resume: bool = OS.get_cmdline_user_args().has("--continue")
	var error_probe: bool = OS.get_cmdline_user_args().has("--load-error")
	var suffix := "continue" if resume else "new"
	if reduced_motion:
		suffix += "_reduced"
	if error_probe:
		suffix += "_error"
	var progression := ProgressionStore.default_data()
	ProgressionStore.save_data(progression)
	if resume:
		var run := RunEngine.new().create_debug_boss_run(progression)
		run["debug_boss_run"] = false
		ProgressionStore.save_run_state(run)
	var menu = await _instantiate_menu()
	current_scene = menu
	var cursor := root.get_node_or_null("CursorFeedback") as CanvasLayer
	if cursor != null:
		cursor.hide()
	await _save_screenshot("%s/%s_menu.png" % [OUTPUT_DIR, suffix])
	if error_probe:
		root.gui_embed_subwindows = true
		menu._using_keyboard_navigation = true
		menu.call("_change_scene_to_file", "res://themes/default_theme.tres", Callable(menu, "_prepare_new_game"))
		while menu._loading_run:
			await process_frame
		assert(menu._loading_error.visible and not root.gui_disable_input, "Load failure must present a dismissible error")
		await _save_screenshot("%s/loading_error.png" % OUTPUT_DIR)
		menu._loading_error.hide()
		menu._loading_error.confirmed.emit()
		await _save_screenshot("%s/loading_error_focus_recovered.png" % OUTPUT_DIR)
		print(ProjectSettings.globalize_path(OUTPUT_DIR))
		_stop_menu_music(menu)
		menu.queue_free()
		await process_frame
		_cleanup_storage()
		SettingsStore.clear_storage()
		quit(0)
		return
	if resume:
		menu.call("_on_continue_button_pressed")
	else:
		menu.call("_on_start_button_pressed")
	var transition = root.get_node("MenuRunTransition")
	transition.phase_changed.connect(func(phase: StringName) -> void:
		if phase == &"revealing":
			assert(transition.destination.initial_presentation_is_ready(), "Reveal must wait for the full room presentation")
			if resume:
				assert(transition.destination.get("_hand_layout_pending_revision") == -1, "The combat hand and Pass must be positioned before reveal")
	)
	var images: Array[Image] = []
	var message_rect := Rect2()
	var phases: Array[String] = []
	var alpha_values: Array[float] = []
	var dot_counts: Array[int] = []
	var started := Time.get_ticks_msec()
	while is_instance_valid(transition) and Time.get_ticks_msec() - started < 15000:
		await RenderingServer.frame_post_draw
		var frame := root.get_texture().get_image()
		assert(frame.get_size() == VIEWPORT_SIZE, "Transition must render at 1920x1080 / 100 percent")
		images.append(frame)
		if is_instance_valid(transition):
			if message_rect == Rect2():
				message_rect = transition.message_label.get_global_rect()
			assert(transition.message_label.get_global_rect() == message_rect, "Dot cycling must keep the message anchored")
			phases.append(str(transition.phase))
			alpha_values.append(transition._surface.modulate.a)
			dot_counts.append(transition.message_label.visible_characters)
		else:
			phases.append("complete")
			alpha_values.append(0.0)
			dot_counts.append(-1)
	assert(not is_instance_valid(transition), "Loading must finish before the probe deadline")
	assert(current_scene != null and current_scene.scene_file_path == "res://scenes/run_scene.tscn", "The real RunScene must be current after loading")
	assert(not root.gui_disable_input, "Input must be restored after loading")
	await RenderingServer.frame_post_draw
	images.append(root.get_texture().get_image())
	phases.append("room")
	alpha_values.append(0.0)
	dot_counts.append(-1)
	var records: Array = []
	var saved_states: Dictionary = {}
	var load_elapsed_ms := Time.get_ticks_msec() - started
	for index: int in range(images.size()):
		var frame: Image = images[index]
		var low: float = 1.0
		var high: float = 0.0
		# Audit every presented frame, not just selected beauty screenshots.
		for y: int in range(24, VIEWPORT_SIZE.y, 36):
			for x: int in range(24, VIEWPORT_SIZE.x, 36):
				var pixel := frame.get_pixel(x, y)
				var luma := pixel.r * 0.2126 + pixel.g * 0.7152 + pixel.b * 0.0722
				low = minf(low, luma)
				high = maxf(high, luma)
		assert(high - low > 0.12, "No presented frame may be blank, black or uniform gray")
		var state_key := "%s_%d" % [phases[index], dot_counts[index] if phases[index] == "loading" else int(alpha_values[index] * 4.0)]
		var path := ""
		if not saved_states.has(state_key):
			path = "%s/%s_frame_%03d_%s.png" % [OUTPUT_DIR, suffix, index, phases[index]]
			assert(frame.save_png(ProjectSettings.globalize_path(path)) == OK, "Representative transition proof frames must save")
			saved_states[state_key] = path
		records.append({"frame": index, "phase": phases[index], "menu_alpha": alpha_values[index], "visible_characters": dot_counts[index], "luma_range": high - low, "path": path})
	var manifest := FileAccess.open("%s/%s_continuity.json" % [OUTPUT_DIR, suffix], FileAccess.WRITE)
	manifest.store_string(JSON.stringify({"flow": suffix, "resolution": [1920, 1080], "ui_scale": 1.0, "elapsed_ms": load_elapsed_ms, "frames": records}, "  "))
	manifest.close()
	print("CONTINUITY PASS: %s, %d presented frames; real room ready, input restored, no blank/gray frame" % [suffix, images.size()])
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	current_scene.queue_free()
	await process_frame
	await process_frame
	_cleanup_storage()
	SettingsStore.clear_storage()
	quit(0)
