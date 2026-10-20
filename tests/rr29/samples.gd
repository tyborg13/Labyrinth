extends SceneTree

## Real Bone2D evidence, both authored keys/midpoints and every presented frame.
## Mesh vertices are not rasterized on the CPU.
const Rig = preload("res://assets/units/hollow_mimic_cutout/rig.gd")
const Motion = preload("res://scripts/maquette_cutout_runtime/motion.gd")
const FPS: float = 60.0
const PROOF_STEP_PX: float = 96.0
const PROOF_SCALE: float = 2.0
const SOURCE_ORIGIN := Vector2(128,128)
var rows: Array[Dictionary]
var errors: Array[String]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var directory: String = "res://experiments/cutouts/hollow_mimic/rr29"
	var output: String = directory.path_join("proof/samples.json")
	if args.has("--case"): directory = args[args.find("--case") + 1]
	if args.has("--output"): output = args[args.find("--output") + 1]
	var data: Dictionary = Motion.data_for({"motion_data": directory.path_join("compiled_motion.json")})
	var geometry: Dictionary = await proof_geometry(data)
	for view: String in data["view_tracks"]:
		var rig := Rig.new()
		rig.position=SOURCE_ORIGIN
		rig.case_directory = directory
		rig.facing = view
		root.add_child(rig)
		if not rig.load_rig(): errors.append(str(rig.load_errors))
		rig.layout["screen_pixel_scale"] = geometry["scale"]
		rig.layout["step_distance_px"] = geometry["step"]
		for clip: String in data["clips"]:
			var phases: Array[float]
			phases.assign([0.0, 1.0])
			for track: Dictionary in data["view_tracks"][view][clip]:
				for i: int in range(track["keys"].size()):
					var at: float = float(track["keys"][i]["at"])
					if not phases.has(at): phases.append(at)
					if i > 0:
						var middle: float = (at + float(track["keys"][i - 1]["at"])) / 2.0
						if not phases.has(middle): phases.append(middle)
			phases.sort()
			for at: float in phases:
				rig.apply_authored_pose(clip, at)
				rows.append(record(rig, view, clip, at, -1, "authored"))
			var count: int = roundi(float(data["clips"][clip]["seconds"]) * FPS)
			for frame: int in range(count):
				var at: float = float(frame) / float(count if data["clips"][clip].get("loop", false) else count - 1)
				rig.apply_pose(clip, at)
				rows.append(record(rig, view, clip, at, frame, "presented"))
		rig.free()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	write_report(output, {"ok": errors.is_empty(), "native_pixels": false, "fps": FPS,
		"inputs": preload("res://tests/rr10/bindings.gd").for_case(directory),
		"compiled_sha256": FileAccess.get_sha256(directory.path_join("compiled_motion.json")),
		"step_distance_px": geometry["step"], "screen_pixel_scale": geometry["scale"],
		"samples": rows, "errors": errors})
	print("RR29 BONE SAMPLES: %s (%d poses; headless transforms only)" % ["PASS" if errors.is_empty() else "FAIL", rows.size()])
	quit(0 if errors.is_empty() else 1)

func write_report(output: String, report: Dictionary) -> void:
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(report))
	file.close()

func proof_geometry(_data: Dictionary) -> Dictionary:
	return await preload("res://tests/gait01/board_geometry.gd").measure(self, str(_data["creature"]))

func record(rig: Node2D, view: String, clip: String, phase: float, frame: int, kind: String) -> Dictionary:
	var bones: Dictionary = {}
	var to_source: Transform2D=rig.global_transform.affine_inverse()
	for name: String in rig.bones:
		var bone: Bone2D = rig.bones[name]
		if not bone.global_transform.is_finite(): errors.append("Nonfinite bone: " + name)
		bones[name] = {"local": matrix(bone.transform), "global": matrix(to_source*bone.global_transform)}
	var parts: Dictionary = {}
	for part: Dictionary in rig.layout["parts"]:
		var bone: Bone2D = rig.bones[part["bone"]]
		var sprite: Sprite2D = bone.get_node_or_null(NodePath(part["name"])) as Sprite2D
		if sprite != null: parts[part["name"]] = {"transform": matrix(to_source*sprite.global_transform), "alpha": 1.0, "z_index": sprite.z_index}
	for mesh: Dictionary in rig.layout.get("joint_meshes", []):
		parts[mesh["name"]] = {"z_index": rig.get_node(NodePath(mesh["name"])).z_index}
	var row: Dictionary = {"view": view, "clip": clip, "phase": phase, "frame": frame, "kind": kind, "bones": bones, "parts": parts}
	var at: float = phase
	if kind == "presented":
		at = preload("res://scripts/maquette_cutout_runtime/pixel_presentation.gd").phase_for(Motion.data_for(rig.layout), clip, phase)
		rig.apply_authored_pose(clip, at)
	var continuous: Dictionary = {}
	for name: String in rig.bones:
		continuous[name] = {"global": matrix(to_source * (rig.bones[name] as Bone2D).global_transform)}
	row["direction_bones"] = continuous
	row["direction_phase"] = at
	if kind == "presented": rig.apply_pose(clip, phase)
	return row

static func matrix(t: Transform2D) -> Array:
	return [t.x.x, t.x.y, t.y.x, t.y.y, t.origin.x, t.origin.y]
