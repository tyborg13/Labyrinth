extends SceneTree
## Capture the engine's native boot renderer, not a TextureRect recreation.
## Screen capture is supported on macOS/Windows. Run via visual_probe_runner.py.

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")
const SIZE := Vector2i(1920, 1080)
const OUTPUT_DIR := "user://probes/boot_splash_makers_seal_20260827_v1"
const APPROVED_SHA256 := "a2fea0706c12f6e9e066e5b3f54d2660423d42d733975a110f0ffe45b79f211c"


func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	ProgressionStore.set_storage_path("user://boot_splash_probe_progression.json")
	ProgressionStore.set_run_storage_path("user://boot_splash_probe_run.save")
	SettingsStore.set_storage_path("user://boot_splash_probe_settings.json")
	call_deferred("_capture")


func _capture() -> void:
	assert(DisplayServer.get_name() != "headless", "Native splash proof needs a real renderer.")
	var splash_path: String = ProjectSettings.get_setting("application/boot_splash/image")
	assert(FileAccess.get_sha256(splash_path) == APPROVED_SHA256, "Approved splash pixels changed.")
	assert(ProjectSettings.get_setting("application/boot_splash/minimum_display_time") == 0)
	assert(ProjectSettings.get_setting("application/boot_splash/show_image"))
	var stretch_mode: int = ProjectSettings.get_setting("application/boot_splash/stretch_mode")
	assert(stretch_mode == RenderingServer.SPLASH_STRETCH_MODE_KEEP)
	var splash := Image.new()
	assert(splash.load_png_from_buffer(FileAccess.get_file_as_bytes(splash_path)) == OK)
	assert(splash != null and not splash.is_empty())
	assert(splash.get_size() == Vector2i(1672, 941))
	var settings: Dictionary = SettingsStore.default_settings()
	settings["display_mode"] = SettingsStore.DISPLAY_WINDOWED
	settings["ui_scale"] = 1.0
	assert(SettingsStore.save_settings(settings))
	root.mode = Window.MODE_WINDOWED
	root.borderless = true
	root.size = SIZE
	root.position = DisplayServer.screen_get_position() + Vector2i(100, 100)
	root.grab_focus()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	var cursor := root.get_node_or_null("CursorFeedback")
	if cursor != null:
		cursor.set_process(false)
		cursor.hide()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	await process_frame
	await process_frame
	# Let macOS finish leaving the project's default fullscreen window.
	await create_timer(1.0).timeout
	root.size = SIZE
	root.position = DisplayServer.screen_get_position() + Vector2i(100, 100)
	await process_frame
	await process_frame
	RenderingServer.render_loop_enabled = false
	# Reissue the same native API/settings after sizing the proof window. The
	# short hold is probe-only; production startup has no delay or extra scene.
	RenderingServer.set_boot_image_with_stretch(
		splash,
		ProjectSettings.get_setting("application/boot_splash/bg_color"),
		stretch_mode,
		ProjectSettings.get_setting("application/boot_splash/use_filter")
	)
	await create_timer(0.5).timeout
	# Use native bounds: Window.position can stay stale during macOS transitions.
	var capture_rect := Rect2i(DisplayServer.window_get_position(), DisplayServer.window_get_size())
	var capture: Image = DisplayServer.screen_get_image_rect(capture_rect)
	assert(capture != null and not capture.is_empty(), "Could not capture the native splash window.")
	print("Native boot: root=%s native_rect=%s capture=%s" % [root.size, capture_rect, capture.get_size()])
	if capture.get_size() != SIZE:
		push_error("Native splash capture must be exactly 1920x1080.")
		quit(1)
		return
	assert(capture.save_png(ProjectSettings.globalize_path(OUTPUT_DIR.path_join("native_boot_1920x1080.png"))) == OK)
	RenderingServer.render_loop_enabled = true
	var main_scene_path: String = ProjectSettings.get_setting("application/run/main_scene")
	assert(main_scene_path == "res://scenes/main_menu.tscn")
	var packed: PackedScene = load(main_scene_path)
	var menu := packed.instantiate()
	root.add_child(menu)
	await process_frame
	await process_frame
	await process_frame
	root.size = SIZE
	await RenderingServer.frame_post_draw
	assert(menu.get_node("MenuColumn/StartButton").visible, "Startup must reach the existing menu.")
	var menu_capture: Image = root.get_texture().get_image()
	assert(menu_capture.get_size() == SIZE)
	assert(menu_capture.save_png(ProjectSettings.globalize_path(OUTPUT_DIR.path_join("main_menu_1920x1080.png"))) == OK)
	var music := menu.get_node_or_null("MusicPlayer")
	if music != null:
		music.stop()
		music.stream = null
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	print("TEST RESULT: PASS (native boot splash and main-menu handoff)")
	menu.queue_free()
	await process_frame
	menu = null
	packed = null
	splash = null
	capture = null
	menu_capture = null
	await process_frame
	quit(0)
