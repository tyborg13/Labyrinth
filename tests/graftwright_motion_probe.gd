extends SceneTree
## Native motion proof. Frames are untouched viewport captures with timestamps.

const Parallel = preload("res://scripts/parallel_runtime.gd")
const Suite = preload("res://tests/suites/graftwright_suite.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const OUTPUT := "user://graftwright_motion"
var viewport: SubViewport
var view: Control
var frames: Array[Image]
var timestamps: Array[float]
var failed: bool = false

func _initialize() -> void:
	Parallel.apply_from_environment()
	Engine.max_fps = 30
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1920, 1080)
	Store.set_storage_path("user://motion_profile.json")
	Store.set_run_storage_path("user://motion_run.save")
	Settings.set_storage_path("user://motion_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["display_mode"] = Settings.DISPLAY_WINDOWED
	settings["ui_scale"] = 1.0
	Settings.save_settings(settings)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT.path_join("frames")))
	await process_frame
	viewport = SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
	viewport.add_child(scene)
	await create_timer(0.7).timeout
	scene.call("_load_run_state", Suite.fixture())
	await create_timer(0.5).timeout
	view = scene.find_child("GraftwrightView", true, false) as Control
	view.call("begin_work")
	view.call("select_recipient", "undertaker_plate")
	view.call("select_donor", "patched_cloak")
	# Sample actual idle extremes, then verify the front bench pixels stay fixed
	# while the visible portrait moves behind it. These are real renderer images.
	view.set_process(false)
	view.set("_elapsed", PI / 1.8)
	view.call("_process", 0.0)
	var high: Image = await still("portrait_high.png")
	view.set("_elapsed", PI * 3.0 / 1.8)
	view.call("_process", 0.0)
	var low: Image = await still("portrait_low.png")
	check(high.get_region(Rect2i(0, 795, 470, 160)).get_data() == low.get_region(Rect2i(0, 795, 470, 160)).get_data(), "Portrait never paints over the foreground bench")
	check(high.get_region(Rect2i(178, 749, 34, 41)).get_data() == low.get_region(Rect2i(178, 749, 34, 41)).get_data(), "Purple thread spool stays in front of moving portrait")
	check(high.get_region(Rect2i(232, 747, 37, 43)).get_data() == low.get_region(Rect2i(232, 747, 37, 43)).get_data(), "Silver thread spool stays in front of moving portrait")
	check(high.get_region(Rect2i(90, 200, 300, 570)).get_data() != low.get_region(Rect2i(90, 200, 300, 570)).get_data(), "Visible portrait actually moves behind the fixed bench")
	view.set_process(true)
	await click(view.find_child("SourceCard_1", true, false) as Button)
	await click(view.find_child("TargetCard_1", true, false) as Button)
	await record(15)
	await click(view.find_child("GraftCommit", true, false) as Button)
	await record(135)
	check(bool(view.call("semantic_snapshot")["used"]), "Recorded ritual reaches the committed result")
	var bobbing: TextureRect = view.get("_result_icon") as TextureRect
	var y: float = bobbing.position.y
	await create_timer(0.5).timeout
	check(absf(bobbing.position.y - y) > 0.05, "Result item has visible idle motion")
	var manifest := FileAccess.open(OUTPUT.path_join("timing.json"), FileAccess.WRITE)
	manifest.store_string(JSON.stringify({"size": [1920, 1080], "timestamps_seconds": timestamps}, "\t"))
	manifest.close()
	print("Motion captured; exporting %d full-resolution PNG frames." % frames.size())
	for i: int in range(frames.size()):
		check(frames[i].save_png(OUTPUT.path_join("frames/%04d.png" % i)) == OK, "Motion frame saved")
		frames[i] = null
	print(ProjectSettings.globalize_path(OUTPUT))
	scene.queue_free()
	await process_frame
	quit(1 if failed else 0)

func record(count: int) -> void:
	for i: int in range(count):
		await process_frame
		await RenderingServer.frame_post_draw
		timestamps.append(Time.get_ticks_usec() / 1000000.0)
		frames.append(viewport.get_texture().get_image())

func still(filename: String) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	var result: Image = viewport.get_texture().get_image()
	check(result.get_size() == Vector2i(1920, 1080), "Native proof resolution")
	result.save_png(OUTPUT.path_join(filename))
	return result

func click(button: Button) -> void:
	var point: Vector2 = button.get_global_transform_with_canvas() * (button.size * 0.5)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.pressed = down
		viewport.push_input(event, true)
		await process_frame

func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
