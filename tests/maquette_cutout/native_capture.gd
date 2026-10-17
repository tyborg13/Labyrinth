extends SceneTree

## Windowed, fixed 1920x1080 proof; sequential native 60fps samples, never CPU art.
const Rig = preload("res://scripts/maquette_cutout_runtime/rig.gd")
const Motion = preload("res://scripts/maquette_cutout_runtime/motion.gd")
const SIZE := Vector2i(1920, 1080)
const POSE_SIZE := Vector2i(512, 512)
const FPS: float = 60.0
const PROOF_STEP_PX: float = 96.0
const ORIGIN := Vector2(128, 128)
const PROOF_LABEL_Y: float = 60.0
const PROOF_LABEL_HEIGHT: float = 60.0
const PROOF_VERTICAL_OFFSET: float = 40.0
const PROOF_REPRESENTATIVES: int = 6
var directory: String
var output: String
var records: Array[Dictionary]
var pairs: Array[Dictionary]
var failures: Array[String]
var _canvas: SubViewport
var _views: Dictionary = {}
var _rigs: Dictionary = {}
var _label: Label
var _pixels := preload("pixel_capture.gd").new()
var _seams := preload("seam_capture.gd").new()

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.find("--case") < 0 or args.find("--output") < 0:
		push_error("Use -- --case CASE --output DIRECTORY [--rest-only]")
		quit(1)
		return
	directory = args[args.find("--case") + 1].trim_suffix("/cutout.json")
	output = args[args.find("--output") + 1]
	var data: Dictionary = Motion.data_for({"motion_data": directory.path_join("compiled_motion.json")})
	if args.has("--validate-only"):
		for facing: String in ["front", "rear"]:
			var rig := Rig.new()
			rig.case_directory = directory
			rig.facing = facing
			root.add_child(rig)
			if not rig.load_rig(): failures.append(str(rig.load_errors))
		print("MAQUETTE NATIVE CAPTURE PARSE: " + ("PASS" if failures.is_empty() else "FAIL"))
		quit(0 if failures.is_empty() else 1)
		return
	if DisplayServer.get_name() == "headless":
		push_error("Native capture requires a windowed renderer")
		quit(1)
		return
	root.size = SIZE
	root.content_scale_size = SIZE
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	DisplayServer.window_set_size(SIZE)
	_canvas = viewport(SIZE, false)
	var background := ColorRect.new()
	background.color = Color("1e1e24")
	background.size = Vector2(SIZE)
	_canvas.add_child(background)
	_label = Label.new()
	_label.position = Vector2(0, PROOF_LABEL_Y)
	_label.size = Vector2(SIZE.x, PROOF_LABEL_HEIGHT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_canvas.add_child(_label)
	for view: String in ["front", "rear"]:
		var native: SubViewport = viewport(POSE_SIZE, true)
		_views[view] = native
		var rig := Rig.new()
		rig.facing = view
		rig.case_directory = directory
		rig.position = ORIGIN
		native.add_child(rig)
		if not rig.load_rig(): failures.append(str(rig.load_errors))
		rig.layout["step_distance_px"] = PROOF_STEP_PX
		_rigs[view] = rig
		var display := Sprite2D.new()
		display.texture = native.get_texture()
		display.position = Vector2(SIZE.x * (0.25 if view == "front" else 0.75), SIZE.y / 2.0 + PROOF_VERTICAL_OFFSET)
		display.scale = Vector2(2, 2)
		display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_canvas.add_child(display)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	if not args.has("--rest-only"):
		_pixels.setup(self, _rigs, output)
		_seams.setup(self, _rigs, output)
	for view: String in _rigs: _rigs[view].apply_pose("rest", 0.0)
	await draw_frame()
	for view: String in _rigs:
		var image: Image = (_views[view] as SubViewport).get_texture().get_image().get_region(Rect2i(128, 128, 255, 255))
		image.convert(Image.FORMAT_RGBA8)
		var approved: Image = Image.load_from_file(directory.path_join("source/" + view + "/processed.png"))
		approved.convert(Image.FORMAT_RGBA8)
		if image.get_data() != approved.get_data(): failures.append(view + ": native rest differs from approved art")
		image.save_png(output.path_join(view + "_rest.png"))
	_canvas.get_texture().get_image().save_png(output.path_join("rest_pair.png"))
	if not args.has("--rest-only"):
		for clip: String in data["clips"]:
			_label.text = clip
			var count: int = roundi(float(data["clips"][clip]["seconds"]) * FPS)
			for view: String in _rigs: DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.path_join(view + "_" + clip)))
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.path_join("pair_" + clip)))
			for frame: int in range(count):
				var phase: float = float(frame) / float(count if bool(data["clips"][clip].get("loop", false)) else count - 1)
				for view: String in _rigs:
					var rig: Node2D = _rigs[view]
					var before: Dictionary = {}
					if clip == "idle":
						rig.apply_authored_pose(clip, phase)
						before = preload("pixel_samples.gd").raw_parts(rig)
					rig.apply_pose(clip, phase)
					_seams.stage(view, rig)
					if clip == "idle": _pixels.stage(view, rig, before, frame, phase, rig.Pixels.phase_for(data, clip, phase))
				await draw_frame()
				for view: String in _rigs:
					var path: String = view + "_" + clip + "/pose_%04d.png" % frame
					if clip == "idle": _pixels.capture(view, frame)
					_seams.capture(view, clip, frame)
					(_views[view] as SubViewport).get_texture().get_image().save_png(output.path_join(path))
					records.append({"view": view, "clip": clip, "frame": frame, "phase": phase, "file": path, "sha256": FileAccess.get_sha256(output.path_join(path))})
				var pair_file: String = "pair_" + clip + "/frame_%04d.png" % frame
				_canvas.get_texture().get_image().save_png(output.path_join(pair_file))
				pairs.append({"clip": clip, "frame": frame, "file": pair_file, "sha256": FileAccess.get_sha256(output.path_join(pair_file))})
	var file := FileAccess.open(output.path_join("frames.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"ok": failures.is_empty(), "size": [1920, 1080], "ui_scale": 1.0, "fps": FPS, "native_pixels": true, "compiled_sha256": FileAccess.get_sha256(directory.path_join("compiled_motion.json")), "frames": records, "pairs": pairs, "inputs": preload("proof_inputs.gd").bindings(directory), "errors": failures}))
	if not args.has("--rest-only"):
		_pixels.finish(preload("proof_inputs.gd").bindings(directory))
		_seams.finish(preload("proof_inputs.gd").bindings(directory))
	print("MAQUETTE NATIVE CAPTURE: " + ("PASS" if failures.is_empty() else "FAIL"))
	print("Saved " + ProjectSettings.globalize_path(output))
	# The generic screenshot runner validates opaque pair views. Transparent
	# raw terminal frames (authored alpha=0) are checked by the native gate.
	for path: String in ["rest_pair.png", "front_rest.png", "rear_rest.png"]: print(ProjectSettings.globalize_path(output.path_join(path)))
	if not args.has("--rest-only"):
		for clip: String in data["clips"]:
			var count: int = roundi(float(data["clips"][clip]["seconds"]) * FPS)
			for sample: int in range(PROOF_REPRESENTATIVES):
				var frame: int = roundi(float(sample) * (count - 1) / (PROOF_REPRESENTATIVES - 1))
				print(ProjectSettings.globalize_path(output.path_join("pair_" + clip + "/frame_%04d.png" % frame)))
	quit(0 if failures.is_empty() else 1)

func viewport(dimensions: Vector2i, transparent: bool) -> SubViewport:
	var result := SubViewport.new()
	result.size = dimensions
	result.transparent_bg = transparent
	result.disable_3d = true
	result.world_2d = World2D.new()
	result.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(result)
	return result

func draw_frame() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
