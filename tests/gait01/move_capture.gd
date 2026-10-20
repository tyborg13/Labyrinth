extends SceneTree

const CaptureStorage = preload("res://tests/maquette_cutout/capture_storage.gd")

## Director-only native board-scale frames. Headless --validate-only checks all
## resources and every sampling phase without making any renderer claim.
const Rig = preload("res://scripts/maquette_cutout_runtime/rig.gd")
const Motion = preload("res://scripts/maquette_cutout_runtime/motion.gd")
const Humanoid = preload("res://scripts/maquette_cutout_runtime/humanoid_motion.gd")
const Samples = preload("res://tests/rr10/samples.gd")
const Bindings = preload("res://tests/rr10/bindings.gd")
const FRAME_COUNT: int = 12
const SIZE := Vector2i(1920, 1080)
const PROOF_ORIGIN := Vector2(960, 760)
const VALIDATION_SCALE: float = 1.0
const VALIDATION_STEP_PX: float = 96.0
var rows: Array[Dictionary]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var directory: String = args[args.find("--case") + 1] if args.has("--case") else ""
	var output: String = args[args.find("--output") + 1] if args.has("--output") else ""
	if directory.is_empty() or output.is_empty():
		push_error("Use -- --case CASE --output DIRECTORY [--validate-only]")
		quit(1)
		return
	CaptureStorage.setup(output)
	var data: Dictionary = Motion.data_for({"motion_data": directory.path_join("compiled_motion.json")})
	var validate: bool = args.has("--validate-only")
	if not validate and DisplayServer.get_name() == "headless":
		push_error("Gait native proof requires the director's windowed renderer")
		quit(1)
		return
	root.size = SIZE
	root.content_scale_size = SIZE
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	var geometry: Dictionary = {"scale": VALIDATION_SCALE, "step": VALIDATION_STEP_PX} if validate else await preload("res://tests/gait01/board_geometry.gd").measure(self, str(data["creature"]))
	var scale: float = float(geometry["scale"])
	var step: float = float(geometry["step"])
	var viewport := SubViewport.new()
	viewport.size = SIZE
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var bounds := Rect2()
	for view: String in data["view_tracks"]:
		var forward: Vector2 = Motion.point(data["projection"][view]["forward"])
		for phase: float in [0.0, 1.0]:
			var canvas := Rect2(PROOF_ORIGIN - forward * step * phase - Vector2(128, 128) * scale, Vector2(512, 512) * scale)
			bounds = bounds.merge(canvas) if bounds.has_area() else canvas
	CaptureStorage.set_crop(bounds, SIZE)
	var sampler := Samples.new()
	for view: String in data["view_tracks"]:
		var rig := Rig.new()
		rig.case_directory = directory
		rig.facing = view
		viewport.add_child(rig)
		if not rig.load_rig():
			push_error(str(rig.load_errors))
			quit(1)
			return
		rig.scale = Vector2.ONE * scale
		rig.layout["screen_pixel_scale"] = scale
		rig.layout["step_distance_px"] = step
		for index: int in range(FRAME_COUNT):
			var phase: float = float(index) / float(FRAME_COUNT - 1)
			# Debug camera follows root travel; source-space world targets remain
			# in the evidence. Only the proof camera changes between cells.
			var forward: Vector2 = Motion.point(data["projection"][view]["forward"])
			rig.position = PROOF_ORIGIN - forward * step * phase
			rig.apply_pose("move", phase)
			var row: Dictionary = sampler.record(rig, view, "move", phase, index, "presented")
			row["scale"] = scale
			row["origin"] = [rig.position.x, rig.position.y]
			row["file"] = "%s_move_%02d.png" % [view, index]
			if not validate:
				await process_frame
				await RenderingServer.frame_post_draw
				var path: String = output.path_join(row["file"])
				CaptureStorage.save(viewport.get_texture().get_image(), path, "move")
				row["sha256"] = CaptureStorage.file_hash(path)
				print(ProjectSettings.globalize_path(CaptureStorage.proof_png(path)))
			rows.append(row)
		rig.free()
	sampler.free()
	var manifest: Dictionary = {"ok": true, "native_pixels": not validate, "size": [1920,1080], "ui_scale": 1.0,
		"board_scale": scale, "step_distance_px": step, "screen_pixel_scale": scale,
		"inputs": Bindings.for_case(directory), "frames": rows}
	manifest.merge(CaptureStorage.metadata())
	CaptureStorage.finish()
	FileAccess.open(output.path_join("frames.json"), FileAccess.WRITE).store_string(JSON.stringify(manifest))
	print("GAIT MOVE PROBE %s: PASS (24 frames; 12 per view)" % ("LOAD" if validate else "NATIVE"))
	quit()

