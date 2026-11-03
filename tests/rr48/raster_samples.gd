extends SceneTree

const Rig = preload("res://assets/units/ashen_reaver_cutout/rig.gd")
const Motion = preload("res://scripts/maquette_cutout_runtime/motion.gd")
const ORIGIN := Vector2(192, 192) # Native isolated viewport's actual origin.

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func values(t: Transform2D) -> Array:
	return [t.x.x, t.x.y, t.y.x, t.y.y, t.origin.x, t.origin.y]

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var directory: String = args[args.find("--case") + 1]
	var output: String = args[args.find("--output") + 1]
	var geometry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[args.find("--geometry") + 1]))
	var data: Dictionary = Motion.data_for({"motion_data": directory.path_join("compiled_motion.json")})
	var rows: Array[Dictionary]
	for view: String in data["view_tracks"]:
		var rig: Node2D = Rig.new()
		rig.case_directory = directory
		rig.facing = view
		rig.position = ORIGIN
		root.add_child(rig)
		assert(rig.load_rig(), str(rig.load_errors))
		rig.layout["screen_pixel_scale"] = geometry["screen_pixel_scale"]
		rig.layout["step_distance_px"] = geometry["step_distance_px"]
		for clip: String in data["clips"]:
			var count: int = roundi(float(data["clips"][clip]["seconds"]) * 60.0)
			for frame: int in range(count):
				var phase: float = float(frame) / float(count if data["clips"][clip].get("loop", false) else count - 1)
				rig.apply_pose(clip, phase)
				var bones: Dictionary = {}
				var parts: Dictionary = {}
				var inverse: Transform2D = rig.global_transform.affine_inverse()
				for name: String in rig.bones:
					var bone: Bone2D = rig.bones[name]
					bones[name] = {"global": values(inverse * bone.global_transform), "local": values(bone.transform)}
				for part: Dictionary in rig.layout["parts"]:
					var node: Node2D = rig.get_node_or_null(NodePath(part["name"])) as Node2D
					if node == null: node = rig.bones[part["bone"]].get_node(NodePath(part["name"])) as Node2D
					parts[part["name"]] = {"transform": values(inverse * node.global_transform), "z_index": node.z_index}
				rows.append({"view": view, "clip": clip, "frame": frame, "phase": phase, "kind": "presented", "bones": bones, "parts": parts})
		rig.free()
	FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify({"samples": rows, "native_pixels": false, "origin": [192, 192],
		"compiled_sha256": FileAccess.get_sha256(directory.path_join("compiled_motion.json")),
		"inputs": preload("res://tests/rr10/bindings.gd").for_case(directory)}))
	print("RR48 RASTER POSES: PASS (%d frames; native viewport origin, headless transforms only)" % rows.size())
	quit()
