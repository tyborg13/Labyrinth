extends SceneTree

## Director-only real renderer. No CPU raster is used in these captures.
const SIZE := Vector2i(1920, 1080)
const POSE_SIZE := Vector2i(1024, 1024)
const SOURCE_ORIGIN := Vector2(384, 384)
const REVIEW_ORIGIN := Vector2(448, 28)
const FPS: float = 60.0
const PROOF_STEP_PX: float = 96.0
const PROOF_SCALE: float = 2.0
var errors: Array[String]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var directory: String = args[args.find("--case") + 1]
	var output: String = args[args.find("--output") + 1]
	var binding: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("rr58_binding.json")))
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("compiled_motion.json")))
	if not args.has("--validate-only") and DisplayServer.get_name() == "headless":
		push_error("rr-58 native proof requires the director's windowed renderer")
		quit(1)
		return
	root.size = SIZE
	root.content_scale_size = SIZE
	var pose := SubViewport.new()
	pose.size = POSE_SIZE
	pose.transparent_bg = true
	pose.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	pose.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(pose)
	var script: Script = load("res://assets/units/%s_cutout/rig.gd" % str(binding["rig"])) as Script
	var rig: Node2D = script.new()
	rig.case_directory = directory
	rig.position = SOURCE_ORIGIN
	pose.add_child(rig)
	var canvas := SubViewport.new()
	canvas.size = SIZE
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	var background := ColorRect.new()
	background.size = Vector2(SIZE)
	background.color = Color("2a2a2f")
	canvas.add_child(background)
	var display := TextureRect.new()
	display.texture = pose.get_texture()
	display.position = REVIEW_ORIGIN
	display.size = Vector2(POSE_SIZE)
	display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	canvas.add_child(display)
	var label := Label.new()
	canvas.add_child(label)
	var records: Array[Dictionary]
	var geometry: Dictionary = {"step": PROOF_STEP_PX, "scale": PROOF_SCALE}
	# Match current board step and scale for traveling rigs.
	if data["clips"].get("move", {}).has("gait"):
		geometry = await preload("res://tests/gait01/board_geometry.gd").measure(self, str(data["creature"]))
	DirAccess.make_dir_recursive_absolute(output)
	for view: String in data["view_tracks"]:
		rig.facing = view
		if not rig.load_rig(): errors.append(str(rig.load_errors))
		rig.layout["step_distance_px"] = geometry["step"]
		rig.layout["screen_pixel_scale"] = geometry["scale"]
		for clip: String in data["clips"]:
			var count: int = roundi(float(data["clips"][clip]["seconds"]) * FPS)
			for frame: int in range(count):
				var phase: float = float(frame) / float(count if data["clips"][clip].get("loop", false) else count - 1)
				rig.apply_pose(clip, phase)
				if args.has("--validate-only"): continue
				label.text = "%s %s %s %d | 1920x1080 / 100%% UI" % [binding["rig"], view, clip, frame]
				await process_frame
				await RenderingServer.frame_post_draw
				var relative: String = "%s/%s/frame_%04d.png" % [view, clip, frame]
				var path: String = output.path_join(relative)
				DirAccess.make_dir_recursive_absolute(path.get_base_dir())
				var image: Image = pose.get_texture().get_image()
				image.convert(Image.FORMAT_RGBA8)
				if image.save_png(path) != OK: errors.append("Capture write failed: " + path)
				records.append({"view": view, "clip": clip, "frame": frame, "phase": phase,
					"file": relative, "sha256": FileAccess.get_sha256(path)})
				if clip == "death" and frame == count - 1:
					var overview: String = output.path_join(view + "_overview.png")
					if canvas.get_texture().get_image().save_png(overview) != OK: errors.append("Overview write failed")
					print(overview)
	var file := FileAccess.open(output.path_join("frames.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"native_pixels": not args.has("--validate-only"), "size": [1920, 1080],
		"ui_scale": 1.0, "fps": FPS, "frames": records, "errors": errors, "ok": errors.is_empty(),
		"rig": binding["rig"], "before": binding["before"],
		"case_directory": directory, "probe_sha256": FileAccess.get_sha256("res://experiments/cutouts/held_items_rr58/native.gd"),
		"inputs": preload("res://tests/rr10/bindings.gd").for_case(directory)}))
	file.close()
	print("RR58 NATIVE %s: %s" % ["PROBE LOAD" if args.has("--validate-only") else "CAPTURE", "PASS" if errors.is_empty() else "FAIL"])
	quit(0 if errors.is_empty() else 1)
