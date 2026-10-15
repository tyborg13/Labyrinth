extends SceneTree

## Numerical proof only. Never presents these samples as real-renderer images.
const Rig = preload("res://tools/cutout_pipeline/rig.gd")
const SUPPORT_TOLERANCE: float = 0.02
const TARGET_TOLERANCE: float = 0.2
const RIGID_TOLERANCE: float = 0.001
var failures: Array[String]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var ci: int = args.find("--case")
	var oi: int = args.find("--output")
	if ci < 0 or oi < 0 or ci + 1 >= args.size() or oi + 1 >= args.size():
		push_error("Use -- --case /absolute/cutout.json --output /absolute/motion_samples.json")
		quit(1)
		return
	var rig := Rig.new()
	root.add_child(rig)
	if not rig.configure(args[ci + 1]):
		push_error(str(rig.load_errors))
		quit(1)
		return
	var records: Array[Dictionary]
	var inputs: Dictionary = {"cutout.json": FileAccess.get_sha256(args[ci + 1]),
		str(rig.config["motion"]): FileAccess.get_sha256(rig.case_directory.path_join(str(rig.config["motion"]))),
		"gaoler_motion.gd": FileAccess.get_sha256(rig.case_directory.path_join("gaoler_motion.gd"))}
	for facing: String in rig.config["layouts"]:
		_check(rig.set_facing(facing), "Load facing " + facing)
		var layout_path: String = str(rig.config["layouts"][facing])
		inputs[layout_path] = FileAccess.get_sha256(rig.case_directory.path_join(layout_path))
		for part: Dictionary in rig.layout["parts"]:
			var path: String = str(part["file"])
			inputs[path] = FileAccess.get_sha256(path if path.is_absolute_path() else rig.case_directory.path_join(path))
		for clip: String in rig.config["clips"]:
			var definition: Dictionary = rig.config["clips"][clip]
			var count: int = int(definition["frames"])
			var anchors: Dictionary = {}
			for index: int in range(count):
				rig.show_frame(clip, index)
				var phase: float = rig.playback_phase(clip, float(index) / float(count if definition["loop"] else count - 1))
				var matrices: Dictionary = {}
				for bone_name: String in rig.bones:
					var bone: Bone2D = rig.bones[bone_name]
					var world: Transform2D = rig.global_transform.affine_inverse() * bone.global_transform
					_check(world.is_finite(), "Finite transform " + facing + "/" + clip + "/" + bone_name)
					matrices[bone_name] = [world.x.x, world.x.y, world.y.x, world.y.y, world.origin.x, world.origin.y]
					if bone_name in rig.config["rigid_bones"]:
						_check(absf(world.x.length() - 1) < RIGID_TOLERANCE and absf(world.y.length() - 1) < RIGID_TOLERANCE and absf(world.x.dot(world.y)) < RIGID_TOLERANCE, "Rigid basis " + bone_name)
				if clip == "walk":
					for foot: String in rig.config["contact_feet"]:
						var state: Dictionary = rig.sampler.call("walk_foot_state", phase, foot, rig.layout, facing)
						var position: Vector2 = rig.to_local((rig.bones[foot] as Bone2D).global_position)
						_check(position.distance_to(state["target"]) < TARGET_TOLERANCE, "Foot target " + foot)
						if state["contact"]:
							var grounded: Vector2 = position + rig.travel_for_frame(clip, index)
							if not anchors.has(foot) or float(state["cycle_phase"]) < float(anchors[foot]["phase"]):
								anchors[foot] = {"point": grounded, "phase": state["cycle_phase"]}
							_check(grounded.distance_to(anchors[foot]["point"]) < SUPPORT_TOLERANCE, "Planted support " + foot)
							anchors[foot]["phase"] = state["cycle_phase"]
						else:
							anchors.erase(foot)
				_check(rig.load_errors.is_empty(), "Rig errors: " + str(rig.load_errors))
				records.append({"view": facing, "clip": clip, "frame": index, "phase": phase, "bones": matrices})
	var report: Dictionary = {"ok": failures.is_empty(), "basis": "Headless production sampler and actual Skeleton2D transforms; no rendered proof", "inputs": inputs, "samples": records, "errors": failures}
	var file := FileAccess.open(args[oi + 1], FileAccess.WRITE)
	if file == null:
		push_error("Cannot write motion sample report")
		quit(1)
		return
	file.store_string(JSON.stringify(report))
	file.close()
	rig.free()
	print("MAQUETTE_MOTION_SAMPLES: %s (%d poses)" % ["PASS" if failures.is_empty() else "FAIL", records.size()])
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	if not condition and message not in failures:
		failures.append(message)
		push_error(message)
