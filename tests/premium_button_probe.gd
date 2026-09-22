extends "res://tests/button_system_probe.gd"

# Focused premium-material proof stays on the authored 1080p / 100% canvas.
const PREMIUM_OUTPUT_DIR: String = "user://premium_button_polish_v1"

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)
	root.size = Vector2i(1920, 1080)
	SettingsStore.set_storage_path("user://premium_button_polish_v1_settings.json")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PREMIUM_OUTPUT_DIR))
	await _show_gallery(1.0)
	_validate_gallery(1.0)
	await create_timer(0.35).timeout
	await _capture_premium("button_material_states_v1")
	await _exercise_native_engagement()
	print("PREMIUM_BUTTON_PROOF_DIR=%s" % ProjectSettings.globalize_path(PREMIUM_OUTPUT_DIR))
	quit(1 if _failed else 0)

func _capture_premium(stem: String) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.size = Vector2i(1920, 1080)
	await process_frame
	RenderingServer.force_draw(true)
	var image: Image = root.get_texture().get_image()
	_require(image.get_size() == Vector2i(1920, 1080), "Every material/motion state must be rendered at 1920x1080")
	var path: String = "%s/%s.png" % [PREMIUM_OUTPUT_DIR, stem]
	_require(image.save_png(path) == OK, "Premium button proof should save: %s" % path)

func _exercise_native_engagement() -> void:
	var button: Button = _gallery_buttons[1]
	var ornament: Control = button.get_node(UiSkin.BUTTON_ORNAMENT_NAME)
	var original_rect: Rect2 = button.get_global_rect()
	var original_focus_mode: int = button.focus_mode
	var counts: Dictionary = {"activation": 0}
	button.pressed.connect(func() -> void: counts["activation"] = int(counts["activation"]) + 1)
	_require(not ornament.is_processing(), "Idle button ornament should not process frames")

	_focus_sample.release_focus()
	var motion := InputEventMouseMotion.new()
	motion.position = button.get_global_rect().get_center()
	root.push_input(motion)
	await process_frame
	_require(button.is_hovered(), "Native pointer hover should reach the existing button")
	_require(ornament.is_processing(), "Pointer entry should start one bounded engagement glint")
	await create_timer(0.09).timeout
	await _capture_premium("button_hover_glint_v1")
	await create_timer(0.32).timeout
	_require(not ornament.is_processing(), "Pointer engagement should settle without recurring redraw")

	motion = InputEventMouseMotion.new()
	motion.position = Vector2(16.0, 16.0)
	root.push_input(motion)
	button.grab_focus()
	_require(button.has_focus(), "Native keyboard/controller focus should remain on the Button")
	_require(ornament.is_processing(), "Focus entry should receive the same brief engagement response")
	var press := InputEventAction.new()
	press.action = "ui_accept"
	press.pressed = true
	root.push_input(press)
	await process_frame
	_require(button.get_draw_mode() in [BaseButton.DRAW_PRESSED, BaseButton.DRAW_HOVER_PRESSED], "Native ui_accept should expose its held pressed state")
	_require(button.has_focus(), "Held activation must preserve visible focus")
	_require(bool(ornament.call("_material_is_pressed", str(ornament.call("_visual_state")))), "Focused native presses must recess the brass bevel")
	await _capture_premium("button_native_pressed_focus_v1")
	var release := InputEventAction.new()
	release.action = "ui_accept"
	release.pressed = false
	root.push_input(release)
	await process_frame
	_require(int(counts["activation"]) == 1, "Native ui_accept should activate exactly once")
	_require(not ornament.is_processing(), "Press feedback should end the glint immediately")
	_require(button.get_global_rect() == original_rect, "Polish must not move or resize native hit targets")
	_require(button.focus_mode == original_focus_mode, "Polish must preserve native focus configuration")

	var focus_next := InputEventAction.new()
	focus_next.action = "ui_focus_next"
	focus_next.pressed = true
	root.push_input(focus_next)
	await process_frame
	var next_button: Button = root.gui_get_focus_owner() as Button
	_require(next_button != null and next_button != button, "Native focus traversal should reach another action")
	if next_button != null and next_button != button:
		var next_counts: Dictionary = {"activation": 0}
		next_button.pressed.connect(func() -> void: next_counts["activation"] = int(next_counts["activation"]) + 1)
		_require(next_button.get_node(UiSkin.BUTTON_ORNAMENT_NAME).is_processing(), "Traversed focus should receive the same bounded response")
		root.push_input(press)
		root.push_input(release)
		await process_frame
		_require(int(next_counts["activation"]) == 1, "The next action should activate once after native traversal")
		await _capture_premium("button_native_focus_traversal_v1")

	var local_settings: Dictionary = SettingsStore.default_settings()
	local_settings["reduced_motion"] = true
	SettingsStore.save_settings(local_settings)
	_require(not SettingsStore.applied_reduced_motion_enabled(), "Saving a preference must not silently replace the applied runtime preference")
	_require(SettingsStore.reduced_motion_enabled(local_settings), "Instance-local preference queries must remain independent of applied runtime state")
	SettingsStore.apply_settings(local_settings, root, false)
	_require(SettingsStore.applied_reduced_motion_enabled(), "Applying settings should publish reduced motion to shared controls")
	button.release_focus()
	button.grab_focus()
	await process_frame
	_require(not ornament.is_processing(), "Reduced motion must keep focus feedback entirely static")
	await _capture_premium("button_reduced_motion_focus_v1")

	SettingsStore.apply_settings(SettingsStore.default_settings(), root, false)
	button.release_focus()
	button.grab_focus()
	_require(ornament.is_processing(), "Restoring full motion should work without rebuilding the control")
	SettingsStore.apply_settings(local_settings, root, false)
	await process_frame
	await process_frame
	_require(not ornament.is_processing(), "Enabling reduced motion during a glint should stop it immediately")
	SettingsStore.apply_settings(SettingsStore.default_settings(), root, false)
	button.disabled = true
	button.mouse_entered.emit()
	_require(not ornament.is_processing(), "Disabled controls must not start decorative motion")
	button.disabled = false
	button.release_focus()
	button.grab_focus()
	button.hide()
	_require(not ornament.is_processing(), "Hiding a button should discard the engagement animation")
	button.show()

	var umbra: Button = _gallery_button("Umbra", UiSkin.VARIANT_UMBRA, UiSkin.BUTTON_HEIGHT_ACTION, 224.0)
	root.add_child(umbra)
	var umbra_ornament: Control = umbra.get_node(UiSkin.BUTTON_ORNAMENT_NAME)
	_require(not umbra_ornament.is_processing(), "Newly mounted idle ornaments must not acquire an automatic frame callback")
	umbra.grab_focus()
	umbra.mouse_entered.emit()
	_require(not umbra_ornament.is_processing(), "Authored menu Umbra buttons must keep their existing sprite treatment")
	umbra.queue_free()
	if not _failed:
		print("PREMIUM_BUTTON_LOGIC=pointer,focus,native-press,navigation,activation,geometry,idle,disabled,hidden,reduced-motion,runtime-cache,umbra PASS")
