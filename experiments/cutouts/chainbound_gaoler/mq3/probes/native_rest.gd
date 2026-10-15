extends SceneTree

const Rig = preload("res://tools/cutout_pipeline/rig.gd")
const SIZE := Vector2i(1920, 1080)
const SOURCE := Vector2i(255, 255)
const PROOF_SCALE: float = 3.0
const REST_ORIGIN := Vector2(80, 160)
const OWNERSHIP_ORIGIN := Vector2(1000, 160)
const OUTPUT: String = "user://probes/maquette_rest"
var failures: Array[String]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var settings: Dictionary = preload("res://scripts/settings_store.gd").default_settings()
	settings["ui_scale"] = 1.0
	preload("res://scripts/settings_store.gd").set_storage_path("user://maquette_settings.json")
	preload("res://scripts/settings_store.gd").save_settings(settings)
	call_deferred("_run")

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var index: int = args.find("--case")
	if index < 0 or index + 1 >= args.size():
		push_error("Use -- --case /absolute/path/cutout.json")
		quit(1)
		return
	root.size = SIZE
	root.content_scale_size = SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var canvas := SubViewport.new()
	canvas.size = SIZE
	canvas.disable_3d = true
	canvas.world_2d = World2D.new()
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	var native := SubViewport.new()
	native.size = SOURCE
	native.transparent_bg = true
	native.disable_3d = true
	native.world_2d = World2D.new()
	native.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(native)
	var rig := Rig.new()
	native.add_child(rig)
	if not rig.configure(args[index + 1]):
		push_error(str(rig.load_errors))
		quit(1)
		return
	var rest := Sprite2D.new()
	rest.centered = false
	rest.position = REST_ORIGIN
	rest.scale = Vector2.ONE * PROOF_SCALE
	rest.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rest.texture = native.get_texture()
	canvas.add_child(rest)
	var ownership := Sprite2D.new()
	ownership.centered = false
	ownership.position = OWNERSHIP_ORIGIN
	ownership.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	canvas.add_child(ownership)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	for facing: String in rig.config["layouts"]:
		rig.set_facing(facing)
		rig.apply_pose("rest", 0.0)
		ownership.texture = ImageTexture.create_from_image(Image.load_from_file(rig.case_directory.path_join("proof/" + facing + "_ownership_3x.png")))
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var actual: Image = native.get_texture().get_image()
		actual.convert(Image.FORMAT_RGBA8)
		var approved: Image = Image.load_from_file(rig.case_directory.path_join("source/" + facing + "/processed.png"))
		approved.convert(Image.FORMAT_RGBA8)
		if actual.get_data() != approved.get_data():
			failures.append(facing + " native RGBA rest differs from approved painting")
		actual.save_png(OUTPUT.path_join(facing + "_rest.png"))
		canvas.get_texture().get_image().save_png(OUTPUT.path_join(facing + "_rest_ownership.png"))
	var file := FileAccess.open(OUTPUT.path_join("rest_identity.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"ok": failures.is_empty(), "errors": failures, "size": [1920, 1080], "ui_scale": 1.0}, "\t"))
	file.close()
	for failure: String in failures:
		push_error(failure)
	print("Saved ", ProjectSettings.globalize_path(OUTPUT))
	print("MAQUETTE_NATIVE_REST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
