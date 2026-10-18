extends SceneTree

const Rig = preload("res://scripts/maquette_cutout_runtime/rig.gd")
const Motion = preload("res://scripts/maquette_cutout_runtime/motion.gd")
const PROOF_STEP_PX: float = 96.0
var records: Array[Dictionary]
var failures: Array[String]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var ci: int = args.find("--case")
	var oi: int = args.find("--output")
	if ci < 0 or oi < 0:
		push_error("Use -- --case CASE --output FILE")
		quit(1)
		return
	var directory: String = args[ci + 1].trim_suffix("/cutout.json")
	var rig := Rig.new()
	rig.case_directory = directory
	root.add_child(rig)
	var data: Dictionary = Motion.data_for({"motion_data": directory.path_join("compiled_motion.json")})
	for view: String in ["front", "rear"]:
		rig.facing = view
		if not rig.load_rig(): failures.append(str(rig.load_errors))
		rig.layout["step_distance_px"] = PROOF_STEP_PX
		for clip: String in data["clips"]:
			var phases: Array[float]
			phases.assign([0.0, 1.0])
			for track: Dictionary in data["view_tracks"][view][clip]:
				var keys: Array = track["keys"]
				for index: int in range(keys.size()):
					var at: float = float(keys[index]["at"])
					if not phases.any(func(value: float) -> bool: return absf(value - at) < 0.00000001): phases.append(at)
					if index > 0:
						var middle: float = (at + float(keys[index - 1]["at"])) / 2.0
						if not phases.any(func(value: float) -> bool: return absf(value - middle) < 0.00000001): phases.append(middle)
			phases.sort()
			for at: float in phases:
				rig.apply_authored_pose(clip, at)
				var bones: Dictionary = {}
				for name: String in rig.bones:
					var bone: Bone2D = rig.bones[name]
					var matrix: Transform2D = rig.global_transform.affine_inverse() * bone.global_transform
					if not matrix.is_finite(): failures.append("Nonfinite bone: " + name)
					bones[name] = {"local": matrix_values(bone.transform), "global": matrix_values(matrix), "alpha": bone.modulate.a, "inherited_alpha": inherited_alpha(bone)}
				records.append({"view": view, "clip": clip, "phase": at, "bones": bones})
	var file := FileAccess.open(args[oi + 1], FileAccess.WRITE)
	file.store_string(JSON.stringify({"ok": failures.is_empty(), "basis": "real Bone2D; headless transforms only", "compiled_sha256": FileAccess.get_sha256(directory.path_join("compiled_motion.json")), "samples": records, "step_distance_px": PROOF_STEP_PX, "errors": failures}))
	print("MAQUETTE MOTION SAMPLES: %s (%d bone poses)" % ["PASS" if failures.is_empty() else "FAIL", records.size()])
	quit(0 if failures.is_empty() else 1)

func matrix_values(t: Transform2D) -> Array:
	return [t.x.x, t.x.y, t.y.x, t.y.y, t.origin.x, t.origin.y]

func inherited_alpha(bone: Bone2D) -> float:
	var value: float = bone.modulate.a
	var parent: Node = bone.get_parent()
	while parent is Bone2D:
		value *= (parent as Bone2D).modulate.a
		parent = parent.get_parent()
	return value
