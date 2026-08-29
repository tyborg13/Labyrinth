extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")
const UiSkin = preload("res://scripts/ui_skin.gd")

const PROGRESSION_PATH: String = "user://main_menu_umbra_button_probe_progression.json"
const RUN_PATH: String = "user://main_menu_umbra_button_probe_run.save"
const SETTINGS_PATH: String = "user://main_menu_umbra_button_probe_settings.json"
const OUTPUT_DIR: String = "user://probes/main_menu_umbra_buttons_20260829_v1"
const CAPTURE_SIZE := Vector2i(1920, 1080)

var _ui_skin := UiSkin.new()

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	ProgressionStore.set_storage_path(PROGRESSION_PATH)
	ProgressionStore.set_run_storage_path(RUN_PATH)
	SettingsStore.set_storage_path(SETTINGS_PATH)
	ProgressionStore.clear_saved_run()
	SettingsStore.clear_storage()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	await _capture_main_menu_states()
	_ui_skin = null
	_cleanup_storage()
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	quit(0)

func _capture_main_menu_states() -> void:
	var settings: Dictionary = SettingsStore.default_settings()
	settings["display_mode"] = SettingsStore.DISPLAY_WINDOWED
	settings["ui_scale"] = 1.0
	_require(SettingsStore.save_settings(settings), "Umbra button probe settings should save")

	var packed: PackedScene = load("res://scenes/main_menu.tscn")
	_require(packed != null, "Umbra button probe should load the production main menu")
	var render_viewport := SubViewport.new()
	render_viewport.size = CAPTURE_SIZE
	render_viewport.size_2d_override = CAPTURE_SIZE
	render_viewport.size_2d_override_stretch = true
	render_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(render_viewport)
	var instance: Control = packed.instantiate() as Control
	_require(instance != null, "Umbra button probe should instantiate the production main menu")
	render_viewport.add_child(instance)
	await _settle_frames()
	_require(Vector2i(render_viewport.get_texture().get_size()) == CAPTURE_SIZE, "Umbra button probe should render at exactly 1920x1080")

	var continue_button: Button = instance.get_node("MenuColumn/ContinueButton")
	var start_button: Button = instance.get_node("MenuColumn/StartButton")
	var settings_button: Button = instance.get_node("MenuColumn/SettingsButton")
	var quit_button: Button = instance.get_node("MenuColumn/QuitButton")
	_verify_umbra_construction(instance)
	_require(continue_button.disabled, "Continue should remain disabled without a saved run")
	_require(not _any_button_has_focus(instance), "Pointer-ready main menu should not fabricate keyboard focus")
	_verify_exclusive_selection(instance, start_button, "idle default")
	await _save_screenshot(render_viewport, "idle_default_new_game")

	settings_button.mouse_entered.emit()
	settings_button.set_meta("button_gallery_state", UiSkin.STATE_HOVER)
	settings_button.add_theme_stylebox_override("normal", _ui_skin.make_button_style(UiSkin.VARIANT_UMBRA, UiSkin.STATE_HOVER))
	settings_button.queue_redraw()
	_verify_exclusive_selection(instance, settings_button, "pointer hover")
	await _save_screenshot(render_viewport, "pointer_hover_settings")

	_reset_forced_state(instance, settings_button)
	instance.call("_restore_default_umbra_selection")
	settings_button.grab_focus()
	await _settle_frames()
	_require(settings_button.has_focus(), "Keyboard/controller focus should reach Settings")
	_verify_focus_styles(settings_button)
	_verify_exclusive_selection(instance, settings_button, "keyboard/controller focus")
	await _save_screenshot(render_viewport, "keyboard_controller_focus_settings")

	settings_button.release_focus()
	start_button.button_down.emit()
	start_button.set_meta("button_gallery_state", UiSkin.STATE_PRESSED)
	start_button.add_theme_stylebox_override("normal", _ui_skin.make_button_style(UiSkin.VARIANT_UMBRA, UiSkin.STATE_PRESSED))
	start_button.queue_redraw()
	_verify_exclusive_selection(instance, start_button, "pressed New Game")
	await _save_screenshot(render_viewport, "pressed_new_game")

	var music_player: AudioStreamPlayer = instance.get_node_or_null("MusicPlayer") as AudioStreamPlayer
	if music_player != null:
		music_player.stop()
		music_player.stream = null
	render_viewport.queue_free()
	await _settle_frames()

func _verify_umbra_construction(instance: Control) -> void:
	for button: Button in _menu_buttons(instance):
		_require(str(button.get_meta("button_variant", "")) == UiSkin.VARIANT_UMBRA, "%s should use the Umbra Obsidian variant" % button.name)
		_require(button.get_node_or_null(UiSkin.BUTTON_ORNAMENT_NAME) != null, "%s should retain the shared scalable button ornament" % button.name)
		for state_name: String in ["normal", "hover", "pressed", "focus", "disabled"]:
			_require(button.get_theme_stylebox(state_name) is StyleBoxFlat, "%s %s should remain code-native" % [button.name, state_name])

func _verify_exclusive_selection(instance: Control, expected: Button, state_label: String) -> void:
	var selected_count: int = 0
	for button: Button in _menu_buttons(instance):
		if bool(button.get_meta("umbra_selected", false)):
			selected_count += 1
			_require(button == expected, "%s should not light fractures on %s" % [state_label, button.name])
	_require(selected_count == 1, "%s should light fractures on exactly one button" % state_label)

func _verify_focus_styles(button: Button) -> void:
	var normal_style: StyleBoxFlat = button.get_theme_stylebox("normal") as StyleBoxFlat
	var focus_style: StyleBoxFlat = button.get_theme_stylebox("focus") as StyleBoxFlat
	_require(normal_style != null and normal_style.bg_color == Color("13141a"), "Focused Umbra buttons should retain the selected obsidian base")
	_require(focus_style != null and focus_style.bg_color == Color.TRANSPARENT, "Umbra focus should use a transparent overlay instead of a generic filled box")
	_require(not button.button_pressed, "Focus should not silently toggle the menu action")

func _any_button_has_focus(instance: Control) -> bool:
	for button: Button in _menu_buttons(instance):
		if button.has_focus():
			return true
	return false

func _menu_buttons(instance: Control) -> Array[Button]:
	var buttons: Array[Button]
	buttons.append(instance.get_node("MenuColumn/ContinueButton") as Button)
	buttons.append(instance.get_node("MenuColumn/StartButton") as Button)
	buttons.append(instance.get_node("MenuColumn/SettingsButton") as Button)
	buttons.append(instance.get_node("MenuColumn/QuitButton") as Button)
	return buttons

func _reset_forced_state(instance: Control, button: Button) -> void:
	button.remove_meta("button_gallery_state")
	instance.call("_apply_menu_button_style", button)
	button.queue_redraw()

func _save_screenshot(render_viewport: SubViewport, name: String) -> void:
	await _settle_frames()
	var image: Image = render_viewport.get_texture().get_image()
	_require(image.get_size() == CAPTURE_SIZE, "%s should capture at exactly 1920x1080" % name)
	var path: String = "%s/%s_1920x1080_scale100.png" % [OUTPUT_DIR, name]
	var error: Error = image.save_png(ProjectSettings.globalize_path(path))
	_require(error == OK, "Umbra button screenshot should save: %s" % path)

func _settle_frames() -> void:
	await process_frame
	await process_frame
	await process_frame

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
