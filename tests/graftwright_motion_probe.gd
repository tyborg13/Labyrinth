extends SceneTree
## Native motion proof. Viewport captures with timestamps; lossless extrema and
## representative ritual frames plus full-resolution JPEG frames for the reel.

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
var stages: Array[String]
var keyframes: Dictionary = {}
var observations: Array[Dictionary]
var saw_point: bool = false

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
	view.set("_elapsed", 0.0)
	view.call("_process", 0.0)
	var high: Image = await still("portrait_high.png")
	view.set("_elapsed", 1.2)
	view.call("_process", 0.0)
	var low: Image = await still("portrait_low.png")
	check(high.get_region(Rect2i(0, 795, 470, 160)).get_data() == low.get_region(Rect2i(0, 795, 470, 160)).get_data(), "Portrait never paints over the foreground bench")
	check(high.get_region(Rect2i(178, 749, 34, 41)).get_data() == low.get_region(Rect2i(178, 749, 34, 41)).get_data(), "Purple thread spool stays in front of moving portrait")
	check(high.get_region(Rect2i(232, 747, 37, 43)).get_data() == low.get_region(Rect2i(232, 747, 37, 43)).get_data(), "Silver thread spool stays in front of moving portrait")
	check(high.get_region(Rect2i(90, 200, 300, 570)).get_data() != low.get_region(Rect2i(90, 200, 300, 570)).get_data(), "Visible portrait actually moves behind the fixed bench")
	view.set("_ritual_elapsed", 0.43)
	view.call("_process", 0.0)
	await still("needle_point.png")
	view.set("_ritual_elapsed", -1.0)
	view.call("_process", 0.0)
	if "--poses-only" in OS.get_cmdline_user_args():
		print(ProjectSettings.globalize_path(OUTPUT))
		scene.queue_free()
		await process_frame
		quit(1 if failed else 0)
		return
	view.set_process(true)
	await click(view.find_child("SourceCard_1", true, false) as Button)
	await click(view.find_child("TargetCard_1", true, false) as Button)
	await record(75)
	await click(view.find_child("GraftCommit", true, false) as Button)
	await record(165)
	check(stages == ["prepare", "transfer", "unravel", ""], "Needle preparation, transfer, dissolution, then result occur in order")
	check(saw_point, "Needle arm has a visible articulated point before transfer")
	check(bool(view.call("semantic_snapshot")["used"]), "Recorded ritual reaches the committed result")
	var completed: Control = view.get("_result_mount") as Control
	var y: float = completed.position.y
	await create_timer(0.5).timeout
	check(is_equal_approx(completed.position.y, y), "Result item remains stationary")
	await still("result_stationary.png")
	var rig: Node = view.get("_portrait")
	check((rig.get_node("Skin_needle_hand") as CanvasItem).z_index == 0, "Recovery restores ordinary portrait layering")
	var accepted = preload("res://experiments/cutouts/graftwright/v01/motion.gd")
	var current = preload("res://scripts/graftwright_cutout/motion.gd")
	for step: int in range(49):
		var phase: float = float(step) / 48.0
		check(accepted.sample_pose("idle", phase, rig.get("layout"), "front") == current.sample_pose("idle", phase, rig.get("layout"), "front"), "Accepted idle is unchanged")
	# Real saved transaction also resolves without spectacle in reduced motion.
	scene.call("_load_run_state", Suite.fixture())
	await create_timer(0.3).timeout
	view = scene.find_child("GraftwrightView", true, false)
	view.call("configure", view.get("state"), true)
	view.call("begin_work")
	view.call("select_recipient", "undertaker_plate")
	view.call("select_donor", "patched_cloak")
	view.call("select_source", 1)
	view.call("select_target", 1)
	await click(view.find_child("GraftCommit", true, false))
	await still("reduced_commit.png")
	check(view.get("_ritual_elapsed") == -1.0 and view.get("_effect") == null, "Reduced motion omits gesture and travel")
	await create_timer(0.35).timeout
	check(bool(view.call("semantic_snapshot")["used"]) and not bool(view.get("busy")), "Reduced-motion transaction finishes once without waiting for spectacle")
	await still("reduced_result.png")
	var manifest := FileAccess.open(OUTPUT.path_join("timing.json"), FileAccess.WRITE)
	manifest.store_string(JSON.stringify({"size": [1920, 1080], "timestamps_seconds": timestamps, "observations": observations, "keyframes": keyframes}, "\t"))
	manifest.close()
	print("Motion captured; exporting %d full-resolution frames." % frames.size())
	for i: int in range(frames.size()):
		check(frames[i].save_jpg(OUTPUT.path_join("frames/%04d.jpg" % i), 0.98) == OK, "Motion frame saved")
		if i in [0, 30, 60, 239] or keyframes.has(i):
			check(frames[i].save_png(OUTPUT.path_join("keyframe_%04d.png" % i)) == OK, "Lossless motion keyframe saved")
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
		var stage: String = str(view.get("_ritual_stage"))
		var action_time: float = float(view.get("_ritual_elapsed"))
		observations.append({"stage": stage, "ritual_seconds": action_time})
		if action_time >= 0.0 or not stages.is_empty():
			if stages.is_empty() or stages.back() != stage:
				stages.append(stage)
				keyframes[frames.size()-1] = "stage_" + stage
			if stage == "prepare" and action_time > 0.37:
				var rig: Node = view.get("_portrait")
				saw_point = saw_point or rig.get("bones")["needle_hand"].rotation > 0.34
				check((rig.get_node("Skin_needle_hand") as CanvasItem).z_index > 0, "Needle hand draws above the sacrifice panel during the gesture")
				keyframes[frames.size()-1] = "needle_point"
			if stage == "transfer":
				check(is_equal_approx((view.get("_source_icon") as CanvasItem).modulate.a, 1.0), "Sacrifice equipment remains visible through transfer")
			if stage == "unravel" and frames.size() % 4 == 0: keyframes[frames.size()-1] = "dissolution"
			if not stage.is_empty():
				check(bool(view.get("busy")), "Ritual holds input until destruction completes")
				check(view.find_child("GraftContinue", true, false) == null, "Result never arrives before destruction")

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
