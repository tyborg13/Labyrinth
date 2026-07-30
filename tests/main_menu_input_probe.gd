extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")

const PROGRESSION_PATH: String = "user://main_menu_input_probe_progression.json"
const RUN_PATH: String = "user://main_menu_input_probe_run.save"
const SETTINGS_PATH: String = "user://main_menu_input_probe_settings.json"
const OUTPUT_DIR: String = "user://probes/main_menu_first_click_20260729_v1"

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	ProgressionStore.set_storage_path(PROGRESSION_PATH)
	ProgressionStore.set_run_storage_path(RUN_PATH)
	SettingsStore.set_storage_path(SETTINGS_PATH)
	ProgressionStore.clear_saved_run()
	SettingsStore.clear_storage()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	await _capture_configuration(Vector2i(1920, 1080), 1.00, "1920x1080_scale100")
	await _capture_configuration(Vector2i(1280, 800), 1.25, "1280x800_scale125")
	_cleanup_storage()
	await process_frame
	await process_frame
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	quit(0)

func _capture_configuration(resolution: Vector2i, ui_scale: float, suffix: String) -> void:
	var settings: Dictionary = SettingsStore.default_settings()
	settings["display_mode"] = SettingsStore.DISPLAY_WINDOWED
	settings["ui_scale"] = ui_scale
	_require(SettingsStore.save_settings(settings), "%s settings should save" % suffix)
	var packed: PackedScene = load("res://scenes/main_menu.tscn")
	_require(packed != null, "%s main menu scene should load" % suffix)
	var render_viewport := SubViewport.new()
	render_viewport.size = resolution
	render_viewport.size_2d_override = Vector2i(
		roundi(float(resolution.x) / ui_scale),
		roundi(float(resolution.y) / ui_scale)
	)
	render_viewport.size_2d_override_stretch = true
	render_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(render_viewport)
	var instance: Node = packed.instantiate()
	render_viewport.add_child(instance)
	await process_frame
	await process_frame
	await process_frame
	await process_frame
	_require(Vector2i(render_viewport.get_texture().get_size()) == resolution, "%s viewport should render at exact size" % suffix)

	var start_button: Button = instance.get_node("MenuColumn/StartButton")
	var settings_button: Button = instance.get_node("MenuColumn/SettingsButton")
	var settings_panel: PanelContainer = instance.get_node("SettingsPanel")
	_require(not start_button.has_focus() and not settings_button.has_focus(), "%s pointer-ready menu should begin without keyboard focus" % suffix)
	await _save_screenshot(render_viewport, "%s/pointer_ready_%s.png" % [OUTPUT_DIR, suffix], resolution)

	var navigation_event := InputEventKey.new()
	navigation_event.keycode = KEY_DOWN
	navigation_event.pressed = true
	instance.call("_unhandled_input", navigation_event)
	_require(start_button.has_focus(), "%s keyboard navigation should focus the default enabled action" % suffix)
	await _save_screenshot(render_viewport, "%s/keyboard_focus_%s.png" % [OUTPUT_DIR, suffix], resolution)

	settings_button.set_meta("probe_press_count", 0)
	settings_button.pressed.connect(func() -> void:
		settings_button.set_meta("probe_press_count", int(settings_button.get_meta("probe_press_count", 0)) + 1)
	)
	var settings_center: Vector2 = settings_button.get_global_rect().get_center()
	var hover_event := InputEventMouseMotion.new()
	hover_event.position = settings_center
	hover_event.global_position = settings_center
	instance.call("_input", hover_event)
	_require(not start_button.has_focus(), "%s pointer handoff should clear keyboard focus synchronously" % suffix)
	settings_button.pressed.emit()
	await process_frame
	await process_frame
	_require(settings_panel.visible, "%s activated Settings state should be visible" % suffix)
	_require(int(settings_button.get_meta("probe_press_count", 0)) == 1, "%s Settings activation should occur exactly once" % suffix)
	await _save_screenshot(render_viewport, "%s/settings_open_pointer_handoff_%s.png" % [OUTPUT_DIR, suffix], resolution)

	var music_player: AudioStreamPlayer = instance.get_node_or_null("MusicPlayer") as AudioStreamPlayer
	if music_player != null:
		music_player.stop()
		music_player.stream = null
	render_viewport.queue_free()
	await process_frame

func _save_screenshot(render_viewport: SubViewport, path: String, expected_size: Vector2i) -> void:
	await process_frame
	await process_frame
	var image: Image = render_viewport.get_texture().get_image()
	_require(image.get_size() == expected_size, "%s should capture at %s" % [path, str(expected_size)])
	var error: Error = image.save_png(ProjectSettings.globalize_path(path))
	_require(error == OK, "Screenshot should save: %s" % path)

func _cleanup_storage() -> void:
	ProgressionStore.clear_saved_run()
	SettingsStore.clear_storage()
	if FileAccess.file_exists(PROGRESSION_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSION_PATH))

func _require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
