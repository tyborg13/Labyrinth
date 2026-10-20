extends SceneTree

const CaptureStorage = preload("res://tests/maquette_cutout/capture_storage.gd")

## Windowed renderer only. All pieces/check masks use the real joint_meshes
## path. Clones isolate layers in parallel; none are CPU-skinned or rasterized.
const Rig = preload("res://scripts/maquette_cutout_runtime/rig.gd")
const Hero = preload("res://scripts/protagonist_cutout/rig.gd")
const Motion = preload("res://scripts/maquette_cutout_runtime/motion.gd")
const Samples = preload("samples.gd")
const SIZE := Vector2i(1920, 1080)
const POSE_SIZE := Vector2i(512, 512)
const ORIGIN := Vector2(128, 128)
const FPS: float = 60.0
const PROOF_LABEL_Y: float = 60.0
const PROOF_LABEL_HEIGHT: float = 60.0
const PROOF_VERTICAL_OFFSET: float = 40.0
const PROOF_REPRESENTATIVES: int = 6
const IDLE_COMPARISON_LOOPS: int = 5
var directory: String = "res://experiments/cutouts/hoarfrost_seer/rr10"
var output: String
var data: Dictionary
var anatomy: Dictionary
var rigs: Array[Node2D]
var primary: Dictionary = {}
var groups: Dictionary = {}
var isolated: Dictionary = {}
var records: Array[Dictionary]
var pairs: Array[Dictionary]
var pieces: Array[Dictionary]
var idle_groups: Array[Dictionary]
var hole_rigs: Dictionary = {}
var rest_holes: Array[Dictionary]
var seam_rigs: Dictionary = {}
var joint_seams: Array[Dictionary]
var failures: Array[String]
var canvas: SubViewport
var label: Label
var hero: Node2D
var _binding_script = preload("bindings.gd")

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.has("--case"): directory = args[args.find("--case") + 1]
	if not args.has("--output"):
		push_error("Use -- --output DIRECTORY [--rest-only|--idle-comparison|--validate-only]")
		quit(1)
		return
	output = args[args.find("--output") + 1]
	CaptureStorage.setup(output)
	data = Motion.data_for({"motion_data": directory.path_join("compiled_motion.json")})
	anatomy = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("anatomy.json")))
	if args.has("--validate-only"):
		for view: String in data["view_tracks"]:
			var rig: Node2D = make_rig(view)
			for part: Dictionary in rig.layout["parts"]:
				var node: Node2D = painted_node(rig,str(part["name"]))
				var mask: Texture2D = rig._texture(rig.layout["proof_layers"][part["name"]]["mask"])
				if mask.get_size() != (node.get("texture") as Texture2D).get_size(): failures.append("Check texture dimensions differ: "+str(part["name"]))
			for hole: Dictionary in rig.layout.get("proof_rest_holes", []):
				var reference: Node2D = make_hole_rig(view,hole)
				reference.apply_pose("death",1.0)
			for seam: Dictionary in rig.layout.get("proof_joint_seams", []):
				var reference: Node2D = make_hole_rig(view,seam)
				reference.apply_pose("death",1.0)
		print("RR10 NATIVE PROBE LOAD: " + ("PASS" if failures.is_empty() else "FAIL"))
		quit(0 if failures.is_empty() else 1)
		return
	if DisplayServer.get_name() == "headless":
		push_error("RR10 native proof requires the director's windowed renderer")
		quit(1)
		return
	root.size = SIZE
	root.content_scale_size = SIZE
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	DisplayServer.window_set_size(SIZE)
	var board_scales: Dictionary = {}
	if args.has("--idle-comparison"): board_scales = await preload("board_scales.gd").measure(self)
	canvas = viewport(SIZE, false)
	var background := ColorRect.new()
	background.size = Vector2(SIZE)
	background.color = Color("1e1e24")
	canvas.add_child(background)
	label = Label.new()
	label.position = Vector2(0, PROOF_LABEL_Y)
	label.size = Vector2(SIZE.x, PROOF_LABEL_HEIGHT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	canvas.add_child(label)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	for view: String in data["view_tracks"]:
		if args.has("--idle-comparison") and view != "front": continue
		var rig: Node2D = make_rig(view)
		primary[view] = rig
		display(rig.get_parent(), SIZE.x * (0.25 if view == "front" else 0.75), float(board_scales.get("hoarfrost_seer",1.0)))
		if not args.has("--rest-only") and not args.has("--idle-comparison"):
			for hole: Dictionary in rig.layout.get("proof_rest_holes", []):
				hole_rigs[view+"/"+str(hole["name"])] = make_hole_rig(view,hole)
			for seam: Dictionary in rig.layout.get("proof_joint_seams", []):
				seam_rigs[view+"/"+str(seam["name"])] = make_hole_rig(view,seam)
			for part: Dictionary in rig.layout["parts"]:
				var actual: Node2D = make_rig(view)
				isolate(actual, [str(part["name"])])
				var checks: Node2D = make_rig(view)
				isolate(checks, [str(part["name"])])
				var node: Node2D = painted_node(checks, str(part["name"]))
				node.set("texture", checks._texture(checks.layout["proof_layers"][part["name"]]["mask"]))
				isolated[view + "/" + str(part["name"])] = {"paint": actual, "checks": checks, "part": part}
		for group: String in rig.layout["idle_groups"]:
			var group_rig: Node2D = make_rig(view)
			var selected: Array = []
			for part: Dictionary in rig.layout["parts"]:
				if part["logical_part"] in rig.layout["idle_groups"][group]: selected.append(str(part["name"]))
			isolate(group_rig, selected)
			groups[view + "/" + group] = group_rig
	for rig: Node2D in rigs: rig.apply_pose("rest", 0.0)
	await draw_frame()
	for view: String in primary:
		var image: Image = picture(primary[view]).get_region(Rect2i(128,128,255,255))
		CaptureStorage.save(image, output.path_join(view + "_rest.png"))
		var source: Image = Image.load_from_file(directory.path_join("source/" + view + "/processed.png"))
		source.convert(Image.FORMAT_RGBA8)
		if image.get_data() != source.get_data(): failures.append(view + ": native rest mismatch")
	for key: String in groups: CaptureStorage.save(picture(groups[key]), path("groups/" + key + "_rest.png"))
	CaptureStorage.plan_review(canvas)
	CaptureStorage.save(canvas.get_texture().get_image(), output.path_join("rest_pair.png"))
	if args.has("--idle-comparison"):
		var hero_view: SubViewport = viewport(POSE_SIZE, true)
		hero = Hero.new()
		hero.position = ORIGIN
		hero_view.add_child(hero)
		if not hero.load_rig(): failures.append(str(hero.load_errors))
		display(hero_view, SIZE.x * 0.75, float(board_scales["protagonist"]))
		label.text = "idle"
		# Five exact cycles, sampled sequentially using each production clock.
		for frame: int in range(roundi(0.84 * FPS * IDLE_COMPARISON_LOOPS)):
			var phase: float = fposmod(float(frame) / FPS / 0.84, 1.0)
			for rig: Node2D in rigs: rig.apply_pose("idle", phase)
			hero.apply_pose("idle", phase)
			await draw_frame()
			CaptureStorage.save(canvas.get_texture().get_image(), path("idle_comparison/frame_%04d.png" % frame))
	elif not args.has("--rest-only"):
		for clip: String in data["clips"]:
			label.text = clip
			var count: int = roundi(float(data["clips"][clip]["seconds"]) * FPS)
			for frame: int in range(count):
				var phase: float = float(frame) / float(count if data["clips"][clip].get("loop", false) else count - 1)
				for rig: Node2D in rigs: rig.apply_pose(clip, phase)
				await draw_frame()
				for view: String in primary:
					var file: String = view + "_" + clip + "/pose_%04d.png" % frame
					CaptureStorage.save(picture(primary[view]), path(file))
					records.append({"view": view, "clip": clip, "frame": frame, "phase": phase, "file": file,
						"sha256": CaptureStorage.file_hash(path(file))})
				var pair: String = "pair_" + clip + "/frame_%04d.png" % frame
				CaptureStorage.save(canvas.get_texture().get_image(), path(pair))
				pairs.append({"clip": clip, "frame": frame, "file": pair, "sha256": CaptureStorage.file_hash(path(pair))})
				for key: String in isolated:
					var entry: Dictionary = isolated[key]
					var file: String = "pieces/" + clip + "/%04d/" % frame + key + ".png"
					var checks: String = file.trim_suffix(".png") + "_checks.png"
					CaptureStorage.save(picture(entry["paint"]), path(file))
					CaptureStorage.save(picture(entry["checks"]), path(checks))
					var node: Node2D = painted_node(entry["paint"], str(entry["part"]["name"]))
					var transform: Transform2D = node.global_transform
					transform.origin -= ORIGIN
					pieces.append({"view": key.get_slice("/",0), "clip": clip, "frame": frame,
						"name": entry["part"]["name"], "file": file, "checks": checks,
						"source": entry["part"]["file"], "z_index": entry["part"]["z_index"],
						"rigid": not node is Polygon2D, "transform": Samples.matrix(transform)})
				for key: String in hole_rigs:
					var hole_file: String = "holes/"+clip+"/%04d/" % frame+key+".png"
					CaptureStorage.save(picture(hole_rigs[key]), path(hole_file))
					rest_holes.append({"view":key.get_slice("/",0),"clip":clip,"frame":frame,"file":hole_file,
						"sha256":CaptureStorage.file_hash(path(hole_file))})
				for key: String in seam_rigs:
					var seam_file: String = "seams/"+clip+"/%04d/" % frame+key+".png"
					CaptureStorage.save(picture(seam_rigs[key]), path(seam_file))
					joint_seams.append({"view":key.get_slice("/",0),"clip":clip,"frame":frame,"file":seam_file,
						"sha256":CaptureStorage.file_hash(path(seam_file))})
				if clip == "idle":
					for key: String in groups:
						var group_rig: Node2D = groups[key]
						var file: String = "groups/" + key + "/frame_%04d.png" % frame
						CaptureStorage.save(picture(group_rig), path(file))
						var anchor: String = str(anatomy["idle_groups"][key.get_slice("/",1)]["bones"][0])
						var bone: Bone2D = group_rig.bones[anchor]
						var offset: Vector2 = bone.global_position - ORIGIN - Motion.point(group_rig.layout["joints"][anchor]["position"])
						idle_groups.append({"view":key.get_slice("/",0),"group":key.get_slice("/",1),"frame":frame,
							"file": file, "rest": "groups/" + key + "_rest.png", "offset": [roundi(offset.x),roundi(offset.y)]})
	CaptureStorage.finish()
	var file := FileAccess.open(output.path_join("frames.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(CaptureStorage.annotate({"native_pixels": true, "size": [1920,1080], "ui_scale": 1.0, "fps": FPS,
		"inputs": _binding_script.for_case(directory), "frames": records, "pairs": pairs, "pieces": pieces,
		"idle_groups": idle_groups, "rest_holes":rest_holes, "joint_seams":joint_seams,
		"errors": failures, "ok": failures.is_empty()})))
	print("RR10 NATIVE CAPTURE: " + ("PASS" if failures.is_empty() else "FAIL"))
	print(ProjectSettings.globalize_path(CaptureStorage.proof_png(output.path_join("rest_pair.png"))))
	if args.has("--idle-comparison"):
		var count: int = roundi(0.84 * FPS * IDLE_COMPARISON_LOOPS)
		for sample: int in range(PROOF_REPRESENTATIVES):
			print(ProjectSettings.globalize_path(CaptureStorage.proof_png(output.path_join("idle_comparison/frame_%04d.png" % roundi(float(sample) * (count - 1) / float(PROOF_REPRESENTATIVES - 1))))))
	elif not args.has("--rest-only"):
		for clip: String in data["clips"]:
			var count: int = roundi(float(data["clips"][clip]["seconds"]) * FPS)
			for sample: int in range(PROOF_REPRESENTATIVES):
				print(ProjectSettings.globalize_path(CaptureStorage.proof_png(output.path_join("pair_" + clip + "/frame_%04d.png" % roundi(float(sample) * (count - 1) / float(PROOF_REPRESENTATIVES - 1))))))
	quit(0 if failures.is_empty() else 1)

func path(relative: String) -> String:
	var result: String = output.path_join(relative)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(result.get_base_dir()))
	return result

func viewport(size: Vector2i, transparent: bool) -> SubViewport:
	var result := SubViewport.new()
	result.size = size
	result.transparent_bg = transparent
	result.disable_3d = true
	result.world_2d = World2D.new()
	result.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(result)
	return result

func make_rig(view: String) -> Node2D:
	var rig := Rig.new()
	rig.case_directory = directory
	rig.facing = view
	rig.position = ORIGIN
	viewport(POSE_SIZE,true).add_child(rig)
	if not rig.load_rig(): failures.append(str(rig.load_errors))
	rig.layout["step_distance_px"] = Samples.PROOF_STEP_PX
	rig.layout["screen_pixel_scale"] = Samples.PROOF_SCALE
	rigs.append(rig)
	return rig

func make_hole_rig(view: String, hole: Dictionary) -> Node2D:
	var rig: Node2D = make_rig(view)
	isolate(rig, [])
	rig.layout = rig.layout.duplicate(true)
	if hole.has("mesh_template"):
		var mesh: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join(str(hole["mesh_template"]))))
		mesh["file"] = hole["file"]
		rig._build_mesh(mesh, str(hole["name"]), str(hole["name"]))
	else:
		var sprite := Sprite2D.new()
		sprite.name = str(hole["name"])
		sprite.texture = rig._texture(str(hole["file"]))
		sprite.centered = false
		(rig.bones[hole["bone"]] as Bone2D).add_child(sprite)
		rig.layout["parts"].append({"name":hole["name"],"bone":hole["bone"],"offset":[0,0]})
	return rig

func display(view: SubViewport, x: float, board_scale: float = 1.0) -> void:
	if board_scale != 1.0:
		var native: SubViewport = viewport(POSE_SIZE,true)
		var at_board_scale := Sprite2D.new()
		at_board_scale.texture = view.get_texture()
		at_board_scale.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		at_board_scale.position = Vector2(POSE_SIZE) / 2.0
		at_board_scale.scale = Vector2.ONE * board_scale
		native.add_child(at_board_scale)
		view = native
	var sprite := Sprite2D.new()
	sprite.texture = view.get_texture()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(2,2)
	sprite.position = Vector2(x, SIZE.y / 2.0 + PROOF_VERTICAL_OFFSET)
	canvas.add_child(sprite)

func painted_node(rig: Node2D, name: String) -> Node2D:
	for mesh: Dictionary in rig.layout.get("joint_meshes", []):
		if mesh["name"] == name: return rig.get_node(NodePath(name)) as Node2D
	var part: Dictionary = rig.layout["parts"].filter(func(p: Dictionary) -> bool: return p["name"] == name)[0]
	return rig.bones[part["bone"]].get_node(NodePath(name)) as Node2D

func isolate(rig: Node2D, selected: Array) -> void:
	for part: Dictionary in rig.layout["parts"]: painted_node(rig,str(part["name"])).visible = str(part["name"]) in selected

func picture(rig: Node2D) -> Image:
	var result: Image = (rig.get_parent() as SubViewport).get_texture().get_image()
	result.convert(Image.FORMAT_RGBA8)
	return result

func draw_frame() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
