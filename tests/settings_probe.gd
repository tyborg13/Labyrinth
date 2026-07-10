extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")

const OUTPUT_DIR: String = "user://settings_foundation_v1"
const SAMPLE_DIALOGUE: String = "The sealed corridor remembers every footstep, but yields to those who move without fear."

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	ProgressionStore.set_storage_path("user://labyrinth_progression_settings_probe.json")
	ProgressionStore.set_run_storage_path("user://labyrinth_run_settings_probe.save")
	SettingsStore.set_storage_path("user://labyrinth_settings_probe.json")
	ProgressionStore.clear_saved_run()
	SettingsStore.clear_storage()

	await _capture_main_menu_settings(1.00, "100")
	await _capture_main_menu_settings(1.25, "125")
	await _capture_run_settings(1.00, "100")
	await _capture_run_settings(1.25, "125")
	await _capture_dialogue_and_motion_proof()

	SettingsStore.save_settings(SettingsStore.default_settings())
	SettingsStore.apply_settings(SettingsStore.default_settings(), root, false)
	print("SETTINGS_PROOF_DIR=%s" % ProjectSettings.globalize_path(OUTPUT_DIR))
	quit()

func _capture_main_menu_settings(scale: float, suffix: String) -> void:
	var settings: Dictionary = _settings_for_scale(scale)
	SettingsStore.save_settings(settings)
	SettingsStore.apply_settings(settings, root, false)
	var packed: PackedScene = load("res://scenes/main_menu.tscn")
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame
	instance.call("_on_settings_button_pressed")
	await process_frame
	await process_frame
	var panel: Control = instance.get_node("SettingsPanel") as Control
	_require(panel != null and panel.visible, "Main-menu settings panel should be visible at %s scale" % suffix)
	_require(is_equal_approx(float((panel.call("current_settings") as Dictionary)["ui_scale"]), scale), "Main-menu panel should read %s UI scale" % suffix)
	_require_centered_settings_controls(panel, "main-menu %s" % suffix)
	await _save_screenshot("%s/main_menu_settings_%s.png" % [OUTPUT_DIR, suffix])
	if suffix == "100":
		var before_restore: Dictionary = panel.call("current_settings") as Dictionary
		var restore_button: Button = _button_with_text(panel, "Restore defaults")
		_require(restore_button != null, "Restore defaults should be present in the settings footer")
		restore_button.pressed.emit()
		await process_frame
		var confirmation: PanelContainer = panel.get("_confirmation_panel") as PanelContainer
		_require(confirmation != null and confirmation.visible, "Restore defaults should open a confirmation step")
		_require((panel.call("current_settings") as Dictionary) == before_restore, "Restore confirmation should not mutate settings before approval")
		await _save_screenshot("%s/restore_defaults_confirmation.png" % OUTPUT_DIR)
	instance.queue_free()
	await process_frame

func _capture_run_settings(scale: float, suffix: String) -> void:
	var settings: Dictionary = _settings_for_scale(scale)
	SettingsStore.save_settings(settings)
	SettingsStore.apply_settings(settings, root, false)
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame
	instance.call("_load_run_state", RunEngine.new().create_new_run(7281, ProgressionStore.default_data()))
	if bool(instance.get("_dialogue_active")):
		instance.call("_close_dialogue")
	instance.call("_open_menu_overlay")
	instance.call("_open_settings_overlay")
	await process_frame
	await process_frame
	var panel: Control = instance.get("_settings_panel") as Control
	_require(panel != null and panel.visible, "In-run settings panel should be visible at %s scale" % suffix)
	_require(is_equal_approx(float((panel.call("current_settings") as Dictionary)["ui_scale"]), scale), "In-run panel should read %s UI scale" % suffix)
	_require_centered_settings_controls(panel, "in-run %s" % suffix)
	await _save_screenshot("%s/run_settings_%s.png" % [OUTPUT_DIR, suffix])
	instance.queue_free()
	await process_frame

func _capture_dialogue_and_motion_proof() -> void:
	var standard: Dictionary = _settings_for_scale(1.0)
	standard["dialogue_speed"] = SettingsStore.DIALOGUE_STANDARD
	SettingsStore.save_settings(standard)
	SettingsStore.apply_settings(standard, root, false)
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame
	instance.call("_load_run_state", RunEngine.new().create_new_run(7282, ProgressionStore.default_data()))
	if bool(instance.get("_dialogue_active")):
		instance.call("_close_dialogue")
	instance.set_process(false)

	instance.set("_settings", standard)
	instance.call("_start_dialogue", _sample_dialogue())
	instance.call("_process", 0.25)
	var standard_chars: int = (instance.get("_dialogue_text_label") as RichTextLabel).visible_characters
	await _save_screenshot("%s/dialogue_standard_partial.png" % OUTPUT_DIR)

	var fast: Dictionary = standard.duplicate(true)
	fast["dialogue_speed"] = SettingsStore.DIALOGUE_FAST
	instance.set("_settings", fast)
	instance.call("_show_dialogue_line", 0)
	instance.call("_process", 0.25)
	var fast_chars: int = (instance.get("_dialogue_text_label") as RichTextLabel).visible_characters
	await _save_screenshot("%s/dialogue_fast_partial.png" % OUTPUT_DIR)

	var instant: Dictionary = standard.duplicate(true)
	instant["dialogue_speed"] = SettingsStore.DIALOGUE_INSTANT
	instance.set("_settings", instant)
	instance.call("_show_dialogue_line", 0)
	var instant_complete: bool = bool(instance.get("_dialogue_text_complete"))
	_require(standard_chars > 0 and fast_chars > standard_chars, "Fast dialogue should reveal more characters than standard over the same interval")
	_require(instant_complete, "Instant dialogue should reveal the complete line immediately")

	var pre_battle_scrim: Control = instance.get("_pre_battle_scrim") as Control
	var pre_battle_panel: Control = instance.get("_pre_battle_panel") as Control
	pre_battle_scrim.visible = true
	instance.set("_settings", standard)
	pre_battle_scrim.modulate = Color.WHITE
	pre_battle_panel.scale = Vector2.ONE
	await instance.call("_animate_pre_battle_entry")
	var normal_entry_scale: Vector2 = pre_battle_panel.scale

	var reduced: Dictionary = standard.duplicate(true)
	reduced["reduced_motion"] = true
	instance.set("_settings", reduced)
	pre_battle_scrim.modulate = Color(1.0, 1.0, 1.0, 0.0)
	pre_battle_panel.scale = Vector2(0.965, 0.965)
	await instance.call("_animate_pre_battle_entry")
	var reduced_entry_scale: Vector2 = pre_battle_panel.scale
	var reduced_entry_alpha: float = pre_battle_scrim.modulate.a
	_require(reduced_entry_scale.is_equal_approx(Vector2.ONE) and is_equal_approx(reduced_entry_alpha, 1.0), "Reduced motion should settle the pre-battle entrance immediately")
	print("DIALOGUE_PROOF standard_chars=%d fast_chars=%d instant_complete=%s" % [standard_chars, fast_chars, str(instant_complete)])
	print("REDUCED_MOTION_PROOF normal_entry_scale=%s reduced_entry_scale=%s reduced_entry_alpha=%.2f" % [str(normal_entry_scale), str(reduced_entry_scale), reduced_entry_alpha])

	instance.queue_free()
	await process_frame

func _settings_for_scale(scale: float) -> Dictionary:
	var settings: Dictionary = SettingsStore.default_settings()
	settings["ui_scale"] = scale
	settings["display_mode"] = SettingsStore.DISPLAY_FULLSCREEN
	return settings

func _sample_dialogue() -> Dictionary:
	return {
		"speaker": "The Ashfarer",
		"accent": "#d8a356",
		"lines": [{"speaker": "The Ashfarer", "text": SAMPLE_DIALOGUE}]
	}

func _save_screenshot(path: String) -> void:
	await process_frame
	await process_frame
	var image: Image = root.get_texture().get_image()
	var error: Error = image.save_png(path)
	_require(error == OK, "Screenshot should save: %s" % path)

func _require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)

func _require_centered_settings_controls(panel: Control, context: String) -> void:
	var centered_controls: Array[Button] = []
	_collect_centered_settings_controls(panel, centered_controls)
	_require(centered_controls.size() >= 7, "%s Settings should expose all centered button-derived controls" % context)
	for button: Button in centered_controls:
		_require(button.alignment == HORIZONTAL_ALIGNMENT_CENTER, "%s %s text should be mathematically centered" % [context, button.text])
		var normal_style: StyleBox = button.get_theme_stylebox("normal")
		_require(normal_style is StyleBoxFlat, "%s %s should use the code-native themed style" % [context, button.text])
		if normal_style is StyleBoxFlat:
			var flat := normal_style as StyleBoxFlat
			_require(is_equal_approx(flat.content_margin_left, flat.content_margin_right), "%s %s should reserve symmetric text margins" % [context, button.text])

func _collect_centered_settings_controls(node: Node, result: Array[Button]) -> void:
	if node is Button and bool(node.get_meta("settings_text_centered", false)):
		result.append(node as Button)
	for child: Node in node.get_children():
		_collect_centered_settings_controls(child, result)

func _button_with_text(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text == text:
		return node as Button
	for child: Node in node.get_children():
		var found: Button = _button_with_text(child, text)
		if found != null:
			return found
	return null
