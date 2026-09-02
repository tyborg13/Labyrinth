extends SceneTree
## Exercise the real startup scene, including its hold, fades and menu handoff.

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")
const SIZE := Vector2i(1920, 1080)
const OUTPUT_DIR := "user://probes/boot_splash_makers_seal_20260827_v3"
const APPROVED_SHA256 := "a2fea0706c12f6e9e066e5b3f54d2660423d42d733975a110f0ffe45b79f211c"

var _recording: bool = false
var _record_start_ms: int
var _last_frame_ms: int = -1000
var _frames: Array[Dictionary] = []


func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	ProgressionStore.set_storage_path("user://boot_splash_probe_progression.json")
	ProgressionStore.set_run_storage_path("user://boot_splash_probe_run.save")
	SettingsStore.set_storage_path("user://boot_splash_probe_settings.json")
	call_deferred("_run")


func _run() -> void:
	assert(DisplayServer.get_name() != "headless", "Startup visual proof needs a real renderer.")
	assert(FileAccess.get_sha256("res://assets/art/ui/boot_splash_makers_seal.png") == APPROVED_SHA256)
	assert(ProjectSettings.get_setting("application/boot_splash/minimum_display_time") == 0)
	assert(not ProjectSettings.get_setting("application/boot_splash/show_image"))
	assert(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/startup.tscn")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR.path_join("motion")))
	var settings := SettingsStore.default_settings()
	settings["display_mode"] = SettingsStore.DISPLAY_WINDOWED
	settings["ui_scale"] = 1.0
	root.mode = Window.MODE_WINDOWED
	root.borderless = true
	root.size = SIZE
	root.grab_focus()
	await create_timer(1.0).timeout
	root.size = SIZE
	RenderingServer.frame_post_draw.connect(_record_frame)
	await _capture_sequence(settings, false)
	await _capture_sequence(settings, true)
	await _capture_motion(settings)
	RenderingServer.frame_post_draw.disconnect(_record_frame)
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	print("TEST RESULT: PASS (startup fades, two-second hold, reduced motion and menu handoff)")
	quit()


func _capture_sequence(settings: Dictionary, reduced: bool) -> void:
	settings["reduced_motion"] = reduced
	assert(SettingsStore.save_settings(settings))
	var startup = load("res://scenes/startup.tscn").instantiate()
	var phase_times: Dictionary = {}
	var completed_menu: Array[Control] = []
	startup.phase_changed.connect(func(value: StringName): phase_times[str(value)] = Time.get_ticks_msec())
	startup.finished.connect(func(value: Control): completed_menu.append(value))
	root.add_child(startup)
	current_scene = startup
	root.size = SIZE
	if not reduced:
		await _capture_black()
		while startup.phase != &"fade_in":
			await process_frame
		await create_timer(0.19).timeout
		assert(startup.seal.modulate.a > 0.1 and startup.seal.modulate.a < 0.9)
		await _capture("normal_01_seal_fade_in")
	while startup.phase != &"hold":
		await process_frame
	assert(is_equal_approx(startup.seal.modulate.a, 1.0))
	assert(root.gui_disable_input)
	await _capture("reduced_01_seal" if reduced else "normal_02_seal_opaque")
	if not reduced:
		while startup.phase != &"fade_out":
			await process_frame
		await create_timer(0.16).timeout
		assert(startup.seal.modulate.a > 0.1 and startup.seal.modulate.a < 0.9)
		await _capture("normal_03_seal_fade_out")
		while startup.phase != &"menu_fade_in":
			await process_frame
		await create_timer(0.18).timeout
		assert(startup.menu.modulate.a > 0.1 and startup.menu.modulate.a < 0.9)
		assert(root.gui_disable_input)
		await _capture("normal_04_menu_fade_in")
	while completed_menu.is_empty():
		await process_frame
	var menu: Control = completed_menu[0]
	assert(phase_times["fade_out"] - phase_times["hold"] >= 2000)
	assert(not root.gui_disable_input and current_scene == menu)
	assert(is_equal_approx(menu.modulate.a, 1.0))
	assert(menu.get_node("MenuColumn/StartButton").visible)
	await _capture("reduced_02_menu" if reduced else "normal_05_menu_ready")
	print("Startup phases reduced_motion=%s: %s" % [reduced, JSON.stringify(phase_times)])
	_dispose_menu(menu)
	await process_frame
	await process_frame


func _capture_motion(settings: Dictionary) -> void:
	# Separate pass: PNG snapshot compression must not add hitches to the clip.
	settings["reduced_motion"] = false
	assert(SettingsStore.save_settings(settings))
	var startup = load("res://scenes/startup.tscn").instantiate()
	var completed_menu: Array[Control] = []
	startup.finished.connect(func(value: Control): completed_menu.append(value))
	_recording = true
	_record_start_ms = Time.get_ticks_msec()
	root.add_child(startup)
	current_scene = startup
	while completed_menu.is_empty():
		await process_frame
	await create_timer(0.25).timeout
	_recording = false
	var file := FileAccess.open(OUTPUT_DIR.path_join("motion/frames.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(_frames, "\t"))
	file.close()
	_dispose_menu(completed_menu[0])
	await process_frame
	await process_frame


func _dispose_menu(menu: Control) -> void:
	var music := menu.get_node_or_null("MusicPlayer") as AudioStreamPlayer
	if music != null:
		music.stop()
		music.stream = null
	menu.queue_free()


func _capture_black() -> void:
	await RenderingServer.frame_post_draw
	var screenshot := root.get_texture().get_image()
	assert(screenshot.get_size() == SIZE)
	screenshot.convert(Image.FORMAT_RGB8)
	var bytes := screenshot.get_data()
	assert(bytes.count(0) == bytes.size(), "The initial transition frame must be solid black.")
	# The generic PNG quality gate intentionally rejects blank frames. Validate
	# every black pixel above and keep this special transition proof as JPEG.
	assert(screenshot.save_jpg(ProjectSettings.globalize_path(OUTPUT_DIR.path_join("normal_00_black_1920x1080.jpg")), 1.0) == OK)


func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var screenshot := root.get_texture().get_image()
	assert(screenshot.get_size() == SIZE)
	assert(screenshot.save_png(ProjectSettings.globalize_path(OUTPUT_DIR.path_join(label + "_1920x1080.png"))) == OK)


func _record_frame() -> void:
	if not _recording:
		return
	var elapsed_ms := Time.get_ticks_msec() - _record_start_ms
	if elapsed_ms - _last_frame_ms < 50:
		return
	_last_frame_ms = elapsed_ms
	var filename := "frame_%04d.jpg" % _frames.size()
	var capture := root.get_texture().get_image()
	assert(capture.save_jpg(ProjectSettings.globalize_path(OUTPUT_DIR.path_join("motion").path_join(filename)), 0.92) == OK)
	_frames.append({"file": filename, "elapsed_ms": elapsed_ms})
