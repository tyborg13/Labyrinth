extends "res://tests/aoe_targeting_preview_probe.gd"

# Reusable native reference for capture/export changes. Calibration patches are
# proof-only UI and must never be used as gameplay marketing footage.
const COLOR_OUTPUT := "user://probes/steam_media_color"

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	ProgressionStore.set_storage_path("user://media_color_progression.json")
	ProgressionStore.set_run_storage_path("user://media_color_run.save")
	SettingsStore.set_storage_path("user://media_color_settings.json")
	ProgressionStore.clear_saved_run()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(COLOR_OUTPUT))
	call_deferred("_capture_native_color")

func _capture_native_color() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(VIEWPORT_SIZE)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_size = VIEWPORT_SIZE
	_expect(RenderingServer.get_current_rendering_method() == "mobile", "Use the production Mobile renderer")
	_capture_viewport = SubViewport.new()
	_capture_viewport.size = VIEWPORT_SIZE
	_capture_viewport.msaa_2d = root.msaa_2d
	_capture_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_capture_viewport)
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	var instance: Node = packed.instantiate()
	_capture_viewport.add_child(instance)
	var display := TextureRect.new()
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	display.stretch_mode = TextureRect.STRETCH_SCALE
	display.texture = _capture_viewport.get_texture()
	root.add_child(display)
	await _settle()
	var settings: Dictionary = SettingsStore.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = true
	instance.set("_settings", settings)
	_resolve_contextual_prompts(instance)
	await _install_combat_fixture(instance, "cinderburst", 9905)
	var layer := CanvasLayer.new()
	layer.layer = 128
	_capture_viewport.add_child(layer)
	var values: Array[int] = _gray_values()
	for index: int in range(values.size()):
		var patch := ColorRect.new()
		var value := float(values[index]) / 255.0
		patch.color = Color(value, value, value, 1.0)
		patch.position = Vector2(30 + index * 120, 1010)
		patch.size = Vector2(110, 50)
		layer.add_child(patch)
	await _settle()
	instance.process_mode = Node.PROCESS_MODE_DISABLED
	await _capture_reference("reference-1080.png", 1)
	_capture_viewport.size_2d_override = VIEWPORT_SIZE
	_capture_viewport.size_2d_override_stretch = true
	_capture_viewport.size = VIEWPORT_SIZE * 2
	await _settle()
	await _capture_reference("reference-4k.png", 2)
	print("STEAM MEDIA COLOR SETTINGS renderer=%s root_msaa_2d=%d capture_msaa_2d=%d ui_scale=1.0" % [
		RenderingServer.get_current_rendering_method(), root.msaa_2d, _capture_viewport.msaa_2d
	])
	print(ProjectSettings.globalize_path(COLOR_OUTPUT))
	display.queue_free()
	_capture_viewport.queue_free()
	await process_frame
	if _failures.is_empty():
		print("STEAM MEDIA COLOR PROBE: PASS")
		quit(0)
	else:
		for failure: String in _failures:
			push_error(failure)
		print("STEAM MEDIA COLOR PROBE: FAIL")
		quit(1)

func _capture_reference(file_name: String, render_scale: int) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = _capture_viewport.get_texture().get_image()
	_expect(image.get_size() == VIEWPORT_SIZE * render_scale, "Reference must have the genuine requested raster size")
	var values: Array[int] = _gray_values()
	for index: int in range(values.size()):
		var pixel: Color = image.get_pixel((60 + index * 120) * render_scale, 1030 * render_scale)
		_expect(
			roundi(pixel.r * 255.0) == values[index]
			and roundi(pixel.g * 255.0) == values[index]
			and roundi(pixel.b * 255.0) == values[index],
			"Native grayscale %d must preserve its exact RGB code value at %dx" % [values[index], render_scale]
		)
	_expect(image.save_png("%s/%s" % [COLOR_OUTPUT, file_name]) == OK, "Native reference PNG must save")
	await process_frame

func _gray_values() -> Array[int]:
	var values: Array[int]
	values.assign([0, 8, 16, 24, 32, 48, 64, 96, 128, 192, 255])
	return values

func _room_layout() -> Dictionary:
	var layout: Dictionary = super._room_layout()
	layout["name"] = "Native Media Color Reference"
	return layout
