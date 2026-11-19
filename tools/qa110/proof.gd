extends SceneTree
## Shared QA-103 result and 1920×1080 capture harness.

const Runtime = preload("res://scripts/parallel_runtime.gd")
const Settings = preload("res://scripts/settings_store.gd")
const SIZE := Vector2i(1920, 1080)
const PROBE_FPS: int = 60

var headless: bool
var output: String
var failures: Array[String]

func _initialize() -> void:
	Runtime.apply_from_environment()
	headless = DisplayServer.get_name() == "headless"
	OS.set_environment("LABYRINTH_PROBE_WINDOW", "1")
	call_deferred("_run")

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): output = arg.trim_prefix("--out=")
	if output.is_empty() or DirAccess.make_dir_recursive_absolute(output) != OK:
		push_error("QA103 needs a writable --out= directory")
		quit(2)
		return
	root.size = SIZE
	root.content_scale_size = SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.notify_mouse_entered()
	var settings: Dictionary = Settings.default_settings()
	settings.merge({"display_mode": "windowed", "ui_scale": 1.0, "reduced_motion": false}, true)
	check(Settings.save_settings(settings), "save isolated settings")
	if headless:
		process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	Engine.max_fps = PROBE_FPS
	await exercise()
	for failure: String in failures: print("QA103 FAIL: " + failure)
	print("QA103 RESULT %s: %s (%d failures)" % [get_script().resource_path.get_file(), "PASS" if failures.is_empty() else "FAIL", failures.size()])
	quit(0 if failures.is_empty() else 1)

func exercise() -> void:
	pass

func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func frames(count: int) -> void:
	for index: int in range(count): await process_frame

func capture(label: String, viewport: Viewport = null) -> void:
	if headless: return
	await RenderingServer.frame_post_draw
	var target: Viewport = root if viewport == null else viewport
	var image: Image = target.get_texture().get_image()
	var path: String = output.path_join(label + ".png")
	if image != null and image.get_size() == SIZE and image.save_png(path) == OK:
		print(path)
	else:
		check(false, "capture " + label + " at 1920×1080")
