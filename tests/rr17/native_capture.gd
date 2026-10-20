extends SceneTree

const CaptureStorage = preload("res://tests/maquette_cutout/capture_storage.gd")

## Director-only 1920x1080 native renderer. One centred actor, never mirrored.
const Rig = preload("res://scripts/maquette_cutout_runtime/rig.gd")
const Motion = preload("res://scripts/maquette_cutout_runtime/motion.gd")
const Samples = preload("samples.gd")
const CASE: String = "res://experiments/cutouts/storm_capacitor/mq5"
const SIZE := Vector2i(1920, 1080)
const POSE_SIZE := Vector2i(512, 512)
const SOURCE_ORIGIN := Vector2(128, 128)
const FPS: float = 60.0
const LABEL_Y: float = 60.0
const LABEL_HEIGHT: float = 60.0
var _canvas: SubViewport
var _native: SubViewport
var _rig: Node2D
var _label: Label
var _frames: Array[Dictionary]
var _contacts: Array[Dictionary]
var _errors: Array[String]
var _output: String

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_output = args[args.find("--output") + 1] if args.has("--output") else CASE.path_join("proof/native")
	CaptureStorage.setup(_output)
	_rig = Rig.new()
	_rig.case_directory = CASE
	if args.has("--validate-only"):
		root.add_child(_rig)
		var ok: bool = _rig.load_rig()
		print("RR17 NATIVE CAPTURE PARSE: " + ("PASS" if ok else "FAIL"))
		quit(0 if ok else 1)
		return
	if DisplayServer.get_name() == "headless":
		push_error("rr-17 native capture requires the director's windowed renderer")
		quit(1)
		return
	root.size = SIZE
	root.content_scale_size = SIZE
	DisplayServer.window_set_size(SIZE)
	_canvas = viewport(SIZE, false)
	var background := ColorRect.new()
	background.color = Color("1e1e24")
	background.size = Vector2(SIZE)
	_canvas.add_child(background)
	_label = Label.new()
	_label.position = Vector2(0, LABEL_Y)
	_label.size = Vector2(SIZE.x, LABEL_HEIGHT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_canvas.add_child(_label)
	_native = viewport(POSE_SIZE, true)
	_rig.position = SOURCE_ORIGIN
	_native.add_child(_rig)
	if not _rig.load_rig(): _errors.append(str(_rig.load_errors))
	var display := Sprite2D.new()
	display.texture = _native.get_texture()
	display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	display.position = Vector2(SIZE) / 2.0
	display.scale = Vector2(2, 2)
	_canvas.add_child(display)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output))
	_rig.apply_pose("rest", 0.0)
	await draw_frame()
	for view: String in ["front", "rear"]:
		var rest: Image = _native.get_texture().get_image().get_region(Rect2i(128, 128, 255, 255))
		rest.convert(Image.FORMAT_RGBA8)
		var approved: Image = Image.load_from_file(CASE.path_join("source/" + view + "/processed.png"))
		approved.convert(Image.FORMAT_RGBA8)
		if rest.get_data() != approved.get_data(): _errors.append(view + ": native rest identity differs")
		CaptureStorage.save(rest, _output.path_join(view + "_rest.png"))
	CaptureStorage.plan_review(_canvas)
	CaptureStorage.save(_canvas.get_texture().get_image(), _output.path_join("rest.png"))
	if not args.has("--rest-only"):
		var data: Dictionary = Motion.data_for({"motion_data": CASE.path_join("compiled_motion.json")})
		for view: String in ["front", "rear"]:
			_rig.facing = view
			if not _rig.load_rig(): _errors.append(str(_rig.load_errors))
			for clip: String in data["clips"]:
				_label.text = clip
				var item: Dictionary = data["clips"][clip]
				var count: int = roundi(float(item["seconds"]) * FPS)
				for frame: int in range(count):
					var phase: float = float(frame) / float(count if bool(item.get("loop", false)) else count - 1)
					_rig.apply_pose(clip, phase)
					await capture(view, clip, frame, phase)
				if item.has("contact"):
					_rig.apply_pose(clip, float(item["contact"]))
					await capture(view, clip, count, float(item["contact"]), true)
	CaptureStorage.finish()
	var file := FileAccess.open(_output.path_join("frames.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(CaptureStorage.annotate({"ok": _errors.is_empty(), "native_pixels": true, "size": [1920, 1080], "ui_scale": 1.0,
		"fps": FPS, "frames": _frames, "contacts": _contacts, "inputs": preload("res://tests/maquette_cutout/proof_inputs.gd").bindings(CASE), "errors": _errors})))
	print("RR17 NATIVE CAPTURE: " + ("PASS" if _errors.is_empty() else "FAIL"))
	for path: String in ["rest.png", "front_rest.png", "rear_rest.png"]: print(ProjectSettings.globalize_path(CaptureStorage.proof_png(_output.path_join(path))))
	for clip: String in ["idle", "charge", "discharge", "hit", "death"]:
		var rows: Array = _frames.filter(func(row: Dictionary) -> bool: return row["view"] == "front" and row["clip"] == clip)
		for index: int in range(mini(6, rows.size())):
			var selected: int = roundi(float(index) * (rows.size() - 1) / 5.0)
			print(ProjectSettings.globalize_path(CaptureStorage.proof_png(_output.path_join(rows[selected]["overview"]))))
	quit(0 if _errors.is_empty() else 1)

func capture(view: String, clip: String, frame: int, phase: float, contact: bool = false) -> void:
	var prefix: String = "%s_%s_%04d" % [view, clip, frame]
	await draw_frame()
	var full: String = prefix + ".png"
	CaptureStorage.save(_native.get_texture().get_image(), _output.path_join(full))
	var overview: String = prefix + "_overview.png"
	CaptureStorage.save(_canvas.get_texture().get_image(), _output.path_join(overview), clip)
	var layers: Dictionary = {}
	for name: String in ["column", "cap"]:
		for part: String in ["column", "cap"]: _rig.bones[part].get_node(NodePath(part)).visible = name == part
		await draw_frame()
		var path: String = prefix + "_" + name + ".png"
		CaptureStorage.save(_native.get_texture().get_image(), _output.path_join(path))
		layers[name] = {"file": path, "sha256": CaptureStorage.file_hash(_output.path_join(path))}
	for name: String in ["column", "cap"]: _rig.bones[name].get_node(NodePath(name)).visible = true
	var row: Dictionary = {"view": view, "clip": clip, "frame": frame, "phase": phase, "file": full,
		"sha256": CaptureStorage.file_hash(_output.path_join(full)), "overview": overview,
		"overview_sha256": CaptureStorage.file_hash(_output.path_join(overview)), "layers": layers}
	if contact: _contacts.append(row)
	else: _frames.append(row)

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
