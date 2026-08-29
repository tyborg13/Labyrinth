extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")

const PROGRESSION_PATH: String = "user://main_menu_branding_probe_progression.json"
const RUN_PATH: String = "user://main_menu_branding_probe_run.save"
const SETTINGS_PATH: String = "user://main_menu_branding_probe_settings.json"
const OUTPUT_DIR: String = "user://probes/main_menu_branding_20260829_v1"
const CAPTURE_PATH: String = OUTPUT_DIR + "/main_menu_branding_1920x1080_scale100.png"
const CAPTURE_SIZE := Vector2i(1920, 1080)

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	ProgressionStore.set_storage_path(PROGRESSION_PATH)
	ProgressionStore.set_run_storage_path(RUN_PATH)
	SettingsStore.set_storage_path(SETTINGS_PATH)
	ProgressionStore.clear_saved_run()
	SettingsStore.clear_storage()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	await _capture_main_menu()
	_cleanup_storage()
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	quit(0)

func _capture_main_menu() -> void:
	var settings: Dictionary = SettingsStore.default_settings()
	settings["display_mode"] = SettingsStore.DISPLAY_WINDOWED
	settings["ui_scale"] = 1.0
	_require(SettingsStore.save_settings(settings), "Main-menu branding probe settings should save")

	var packed: PackedScene = load("res://scenes/main_menu.tscn")
	_require(packed != null, "Main-menu branding probe should load the production menu")
	var render_viewport := SubViewport.new()
	render_viewport.size = CAPTURE_SIZE
	render_viewport.size_2d_override = CAPTURE_SIZE
	render_viewport.size_2d_override_stretch = true
	render_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(render_viewport)
	var instance: Control = packed.instantiate() as Control
	_require(instance != null, "Main-menu branding probe should instantiate the production menu")
	render_viewport.add_child(instance)
	await process_frame
	await process_frame
	await process_frame
	await process_frame

	_require(Vector2i(render_viewport.get_texture().get_size()) == CAPTURE_SIZE, "Main-menu branding probe should render at exactly 1920x1080")
	_verify_shared_title_gradient(instance)
	var image: Image = render_viewport.get_texture().get_image()
	_require(image.get_size() == CAPTURE_SIZE, "Main-menu branding screenshot should be exactly 1920x1080")
	var error: Error = image.save_png(ProjectSettings.globalize_path(CAPTURE_PATH))
	_require(error == OK, "Main-menu branding screenshot should save")

	var music_player: AudioStreamPlayer = instance.get_node_or_null("MusicPlayer") as AudioStreamPlayer
	if music_player != null:
		music_player.stop()
		music_player.stream = null
	render_viewport.queue_free()
	await process_frame

func _verify_shared_title_gradient(instance: Control) -> void:
	var face_container: Control = instance.get_node("TitleFaceBlend") as Control
	_require(face_container != null, "Main-menu branding probe should find the title face container")
	_require(face_container.get_child_count() == 3, "Main-menu title should render all three branded words")
	var offsets: Array = []
	var heights: Array = []
	for child: Node in face_container.get_children():
		var label := child as Label
		_require(label != null, "Every main-menu title face child should be a label")
		var material := label.material as ShaderMaterial
		_require(material != null, "Every main-menu title word should use the branding shader")
		offsets.append(float(material.get_shader_parameter("gradient_offset")))
		heights.append(float(material.get_shader_parameter("gradient_height")))
	_require(float(offsets[0]) < float(offsets[1]), "The second title row should begin lower in the shared Steam color ramp")
	_require(is_equal_approx(float(offsets[1]), float(offsets[2])), "THE and UMBRA should share one row position in the Steam color ramp")
	_require(float(heights[0]) > 0.0, "The shared title gradient should have a positive height")
	_require(is_equal_approx(float(heights[0]), float(heights[1])) and is_equal_approx(float(heights[1]), float(heights[2])), "Every title word should use the same full-logo gradient height")

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

