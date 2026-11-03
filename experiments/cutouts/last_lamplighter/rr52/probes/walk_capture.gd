extends SceneTree

## Native 512-canvas contact sheet inputs inside the required 1920x1080 host.
## --validate-only loads/samples everything headlessly, without saving images.
const TYPES = ["last_lamplighter"]
const SIZE := Vector2i(1920, 1080)
const CANVAS := Vector2i(512, 512)
const PROOF_CANVAS_ORIGIN := Vector2(128, 128)
const FRAME_COUNT: int = 8
const PROOF_HOST_ORIGIN := Vector2(704, 284)

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.has("--type") or not args.has("--output"):
		push_error("Use -- --type CREATURE --output DIRECTORY [--validate-only]")
		quit(1)
		return
	var type: String = args[args.find("--type") + 1]
	var output: String = args[args.find("--output") + 1]
	var validate: bool = args.has("--validate-only")
	if type not in TYPES or (not validate and DisplayServer.get_name() == "headless"):
		push_error("Native capture needs the director's windowed renderer and a walk-02 rig")
		quit(1)
		return
	root.size = SIZE
	root.content_scale_size = SIZE
	var geometry: Dictionary = await preload("res://tests/gait01/board_geometry.gd").measure(self, type)
	var viewport := SubViewport.new()
	viewport.size = CANVAS
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var display := TextureRect.new()
	display.position = PROOF_HOST_ORIGIN
	display.size = CANVAS
	display.texture = viewport.get_texture()
	root.add_child(display)
	DirAccess.make_dir_recursive_absolute(output)
	var frames: Array[Dictionary]
	for view: String in ["front", "rear"]:
		var rig: Node2D = load("res://assets/units/%s_cutout/rig.gd" % type).new()
		rig.facing = view
		rig.position = PROOF_CANVAS_ORIGIN
		viewport.add_child(rig)
		if not rig.load_rig():
			push_error(str(rig.load_errors))
			quit(1)
			return
		# Same tile distance in source pixels as the production board.
		rig.layout["screen_pixel_scale"] = 1.0
		rig.layout["step_distance_px"] = float(geometry["step"]) / float(geometry["scale"])
		for frame: int in range(FRAME_COUNT):
			var phase: float = float(frame) / (FRAME_COUNT - 1)
			rig.apply_pose("move", phase)
			var name: String = "%s_%02d.png" % [view, frame]
			if not validate:
				await process_frame
				await RenderingServer.frame_post_draw
				viewport.get_texture().get_image().save_png(output.path_join(name))
				var full: String = output.path_join("full_" + name)
				root.get_texture().get_image().save_png(full)
				print(ProjectSettings.globalize_path(full))
			frames.append({"view": view, "phase": phase, "frame": frame, "file": name})
		rig.free()
	FileAccess.open(output.path_join("frames.json"), FileAccess.WRITE).store_string(JSON.stringify({"ok": true,
		"native_pixels": not validate, "size": [1920, 1080], "ui_scale": 1.0, "canvas_size": [512, 512], "frames": frames,
		"compiled_sha256": FileAccess.get_sha256("res://assets/units/%s_cutout/humanoid_v2/compiled_motion.json" % type)}))
	print("WALK-02 CONTACT CAPTURE: PASS (%s; 16 frames; native pixels=%s)" % [type, str(not validate)])
	quit()
