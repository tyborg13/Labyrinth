extends SceneTree

## Real bone and Sprite2D transforms at every 60 Hz sample. No renderer claims.
const Rig = preload("res://scripts/maquette_cutout_runtime/rig.gd")
const Pixels = preload("res://scripts/maquette_cutout_runtime/pixel_presentation.gd")
const Motion = preload("res://scripts/maquette_cutout_runtime/motion.gd")
const FPS: float = 60.0
const PROOF_STEP_PX: float = 96.0
var rows: Array[Dictionary]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.find("--case") < 0 or args.find("--output") < 0:
		push_error("Use -- --case CASE --output FILE")
		quit(1)
		return
	var directory: String = args[args.find("--case") + 1]
	var data: Dictionary = Motion.data_for({"motion_data": directory.path_join("compiled_motion.json")})
	for view: String in ["front", "rear"]:
		var rig := Rig.new()
		rig.facing = view
		rig.case_directory = directory
		root.add_child(rig)
		if not rig.load_rig():
			push_error(str(rig.load_errors))
			quit(1)
			return
		rig.layout["step_distance_px"] = PROOF_STEP_PX
		for clip: String in data["clips"]:
			var definition: Dictionary = data["clips"][clip]
			var count: int = roundi(float(definition["seconds"]) * FPS)
			for frame: int in range(count):
				var at: float = float(frame) / float(count if bool(definition.get("loop", false)) else count - 1)
				rig.apply_authored_pose(clip, at)
				var before: Dictionary = raw_parts(rig)
				rig.apply_pose(clip, at)
				var parts: Dictionary = parts_for(rig)
				for name: String in parts: parts[name]["before"] = before[name]
				rows.append({"view": view, "clip": clip, "frame": frame, "phase": at,
					"presented_phase": Pixels.phase_for(data, clip, at), "parts": parts})
		rig.free()
	var output: String = args[args.find("--output") + 1]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify({"ok": true, "fps": FPS, "native_pixels": false,
		"step_distance_px": PROOF_STEP_PX, "inputs": preload("proof_inputs.gd").bindings(directory), "samples": rows}))
	print("MAQUETTE PIXEL SAMPLES: PASS (%d poses; headless transforms only)" % rows.size())
	quit()

static func values(t: Transform2D) -> Array:
	return [t.x.x, t.x.y, t.y.x, t.y.y, t.origin.x, t.origin.y]

static func raw_parts(rig: Node2D) -> Dictionary:
	var result: Dictionary = {}
	var to_source: Transform2D = rig.global_transform.affine_inverse()
	for part: Dictionary in rig.layout["parts"]:
		var bone: Bone2D = rig.bones[part["bone"]]
		var pivot: Vector2 = rig._vector(rig.layout["joints"][part["bone"]]["position"])
		result[part["name"]] = values(to_source * bone.global_transform * Transform2D(0.0, rig._vector(part["offset"]) - pivot))
	return result

static func parts_for(rig: Node2D) -> Dictionary:
	var result: Dictionary = {}
	var to_source: Transform2D = rig.global_transform.affine_inverse()
	for part: Dictionary in rig.layout["parts"]:
		var bone: Bone2D = rig.bones[part["bone"]]
		var sprite: Sprite2D = bone.get_node(NodePath(part["name"]))
		var alpha: float = sprite.modulate.a
		var parent: Node = sprite.get_parent()
		while parent is Bone2D:
			alpha *= (parent as Bone2D).modulate.a
			parent = parent.get_parent()
		result[part["name"]] = {"bone": part["bone"], "transform": values(to_source * sprite.global_transform), "alpha": alpha}
	return result
