extends SceneTree

const Settings = preload("res://scripts/settings_store.gd")
const VIEWPORT_SIZE := Vector2i(1920, 1080)
const OUTPUT_DIR: String = "user://probes/controller_vibration"

func _initialize() -> void:
	var logic_only: bool = "--logic-only" in OS.get_cmdline_user_args()
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	Settings.set_storage_path("user://controller_vibration_probe_settings.json")
	var profile: Dictionary = Settings.default_settings()
	profile["ui_scale"] = 1.0
	profile["display_mode"] = Settings.DISPLAY_WINDOWED
	if not _check(Settings.normalize_settings({})["controller_vibration"] == true
			and Settings.normalize_settings({"controller_vibration": "Off"})["controller_vibration"] == true,
			"Legacy and invalid profiles default to On"):
		return
	Settings.save_settings(profile)
	root.content_scale_factor = 1.0
	var canvas := SubViewport.new()
	canvas.size = VIEWPORT_SIZE
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	var menu: Node = (load("res://scenes/main_menu.tscn") as PackedScene).instantiate()
	canvas.add_child(menu)
	await process_frame
	menu.call("_on_settings_button_pressed")
	var panel: Control = menu.get_node("SettingsPanel")
	var controls: Dictionary = panel.get("_controls")
	var vibration: Button = controls["controller_vibration"]
	var motion: Button = controls["reduced_motion"]
	await process_frame
	if not _check(vibration.is_visible_in_tree() and vibration.toggle_mode and motion.find_next_valid_focus() == vibration,
			"Controller vibration is available after Reduced motion without requiring a pad"):
		return
	vibration.grab_focus()
	await process_frame
	await process_frame
	if not _check(canvas.gui_get_focus_owner() == vibration and vibration.button_pressed and vibration.text == "On",
			"Controller vibration defaults to On and accepts focus"):
		return
	var scroll: Node = vibration.get_parent()
	while scroll != null and not scroll is ScrollContainer:
		scroll = scroll.get_parent()
	if not _check(scroll is ScrollContainer and (scroll as ScrollContainer).get_global_rect().encloses(vibration.get_global_rect()),
			"Focus scrolls the vibration control fully into view"):
		return
	if not logic_only:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
		if not await _capture(canvas, "settings_vibration_on.png"):
			return
	vibration.button_pressed = false
	await process_frame
	panel.call("refresh_from_disk")
	if not _check(Settings.load_settings()["controller_vibration"] == false and vibration.text == "Off",
			"Controller vibration Off survives a disk reload"):
		return
	if not logic_only:
		if not await _capture(canvas, "settings_vibration_off.png"):
			return
		print(ProjectSettings.globalize_path(OUTPUT_DIR))
	Settings.restore_defaults(root)
	panel.call("refresh_from_disk")
	if not _check(vibration.button_pressed and vibration.text == "On", "Restoring defaults re-enables controller vibration"):
		return
	print("CONTROLLER VIBRATION SETTINGS %s RESULT: PASS" % ("LOGIC" if logic_only else "PROBE"))
	quit()

func _capture(canvas: SubViewport, filename: String) -> bool:
	await RenderingServer.frame_post_draw
	var image: Image = canvas.get_texture().get_image()
	return _check(image != null and image.get_size() == VIEWPORT_SIZE and image.save_png("%s/%s" % [OUTPUT_DIR, filename]) == OK,
		"Saved %s at 1920x1080" % filename)

func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
	return condition
