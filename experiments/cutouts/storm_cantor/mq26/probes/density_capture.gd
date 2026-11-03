extends SceneTree
## Native treated production rest overview; the rebaker owns the 255px data.
const Rig = preload("res://assets/units/storm_cantor_cutout/rig.gd")
const SIZE := Vector2i(1920, 1080)
const POSE_SIZE := Vector2i(512, 512)
const ORIGIN := Vector2(128, 128)
const PROOF_SCALE := Vector2(2, 2)
const PROOF_Y: float = 540.0
var failures: Array[String]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	root.size = SIZE
	root.content_scale_size = SIZE
	var settings: Dictionary = preload("res://scripts/settings_store.gd").default_settings()
	settings["ui_scale"] = 1.0
	preload("res://scripts/settings_store.gd").apply_settings(settings, root, false)
	var canvas := SubViewport.new()
	canvas.size = SIZE
	canvas.disable_3d = true
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	var background := ColorRect.new()
	background.size = Vector2(SIZE)
	background.color = Color("1e1e24")
	canvas.add_child(background)
	for view: String in ["front", "rear"]:
		var viewport := SubViewport.new()
		viewport.size = POSE_SIZE
		viewport.transparent_bg = true
		viewport.disable_3d = true
		viewport.world_2d = World2D.new()
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var rig := Rig.new()
		rig.position = ORIGIN
		rig.facing = view
		viewport.add_child(rig)
		if not rig.load_rig(): failures.append(str(rig.load_errors))
		rig.apply_pose("rest", 0.0)
		var sprite := Sprite2D.new()
		sprite.texture = viewport.get_texture()
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.position = Vector2(SIZE.x * (0.25 if view == "front" else 0.75), PROOF_Y)
		sprite.scale = PROOF_SCALE
		canvas.add_child(sprite)
	if args.has("--validate-only"):
		print("RR56 DENSITY PROBE LOAD: " + ("PASS" if failures.is_empty() else "FAIL"))
		quit(0 if failures.is_empty() else 1)
		return
	if DisplayServer.get_name() == "headless" or not args.has("--output"):
		push_error("Use a windowed renderer and --output DIRECTORY")
		quit(1)
		return
	DisplayServer.window_set_size(SIZE)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var output: String = args[args.find("--output") + 1]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var path: String = output.path_join("density_pair.png")
	if canvas.get_texture().get_image().save_png(path) != OK: failures.append("save failed")
	for error: String in failures: push_error(error)
	print(ProjectSettings.globalize_path(path))
	print("RR56 DENSITY NATIVE OVERVIEW: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
