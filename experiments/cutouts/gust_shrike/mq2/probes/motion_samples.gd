extends SceneTree

## Numerical transforms only. Incomplete director data is reported separately.
const Rig = preload("res://tools/cutout_pipeline/rig.gd")
const RIGID_TOLERANCE: float = 0.001
const SUPPORT_TOLERANCE: float = 0.02
var failures: Array[String]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var ci: int = args.find("--case")
	var oi: int = args.find("--output")
	if ci < 0 or oi < 0 or ci + 1 >= args.size() or oi + 1 >= args.size():
		push_error("Use -- --case /absolute/cutout.json --output /absolute/samples.json")
		quit(1)
		return
	var rig := Rig.new()
	root.add_child(rig)
	if not rig.configure(args[ci + 1]):
		push_error(str(rig.load_errors))
		quit(1)
		return
	var inputs: Dictionary = {}
	var paths: Array = rig.config.get("sources", []).duplicate()
	paths.append_array(["cutout.json", "motion.gd", "motion_data.gd", "probes/motion_samples.gd"])
	for path: String in paths: inputs[path] = FileAccess.get_sha256(rig.case_directory.path_join(path))
	var records: Array[Dictionary]
	var channel_records: Array[Dictionary]
	var bone_records: Array[Dictionary]
	var track_records: Dictionary = {}
	for view: String in rig.config["layouts"]:
		track_records[view] = {}
		_check(rig.set_facing(view), "Load " + view)
		var layout_path: String = rig.config["layouts"][view]
		inputs[layout_path] = FileAccess.get_sha256(rig.case_directory.path_join(layout_path))
		for part: Dictionary in rig.layout["parts"]:
			var path: String = str(part["file"]).trim_prefix(rig.case_directory + "/")
			inputs[path] = FileAccess.get_sha256(rig.case_directory.path_join(path))
		for clip: String in rig.config["clips"]:
			var tracks: Array = rig.sampler.call("tracks_for", clip, view)
			track_records[view][clip] = tracks
			var phases: Array[float]
			for track: Dictionary in tracks:
				var keys: Array = track["keys"]
				for index: int in range(keys.size()):
					var at: float = float(keys[index]["at"])
					if not phases.has(at): phases.append(at)
					if index > 0:
						var middle: float = (at + float(keys[index - 1]["at"])) / 2.0
						if not phases.has(middle): phases.append(middle)
			phases.sort()
			for at: float in phases:
				# Apply through the real rig before observing Bone2D transforms.
				# Channel values alone cannot detect a downstream sign/offset bug.
				rig.apply_pose(clip, at)
				bone_records.append({"view": view, "clip": clip, "phase": at,
					"bones": _bone_matrices(rig), "screen_pixel_scale": rig.sampler.call("pixel_scale", rig.layout)})
				channel_records.append({"view": view, "clip": clip, "phase": at,
					"values": rig.sampler.call("channel_values", tracks, at)})
			var definition: Dictionary = rig.config["clips"][clip]
			var count: int = int(definition["frames"])
			for frame: int in range(count):
				rig.show_frame(clip, frame)
				var matrices: Dictionary = {}
				for name: String in rig.bones:
					var bone: Bone2D = rig.bones[name]
					var world: Transform2D = rig.global_transform.affine_inverse() * bone.global_transform
					_check(world.is_finite(), "Finite " + view + "/" + clip + "/" + name)
					matrices[name] = [world.x.x, world.x.y, world.y.x, world.y.y, world.origin.x, world.origin.y]
					if name in rig.config["rigid_bones"]:
						_check(absf(world.x.length() - 1) < RIGID_TOLERANCE and absf(world.y.length() - 1) < RIGID_TOLERANCE and absf(world.x.dot(world.y)) < RIGID_TOLERANCE, "Rigid " + name)
					if clip == "idle" and name in ["root", "body", "legs"]:
						var bind: Array = rig.layout["joints"][name]["position"]
						_check(world.origin.distance_to(Vector2(bind[0], bind[1])) < SUPPORT_TOLERANCE, "Idle no-bob/planted " + name)
				var depths: Dictionary = {}
				for part: Dictionary in rig.layout["parts"]:
					var matches: Array[Node] = rig.find_children(str(part["name"]), "Sprite2D", true, false)
					_check(matches.size() == 1, "Unique paint node " + str(part["name"]))
					if matches.size() == 1: depths[part["name"]] = (matches[0] as Sprite2D).z_index
				var phase: float = rig.playback_phase(clip, float(frame) / float(count if definition["loop"] else count - 1))
				records.append({"view": view, "clip": clip, "frame": frame, "phase": phase, "bones": matrices, "draw_order": depths,
					"screen_pixel_scale": rig.sampler.call("pixel_scale", rig.layout)})
	var design_errors: Array = rig.sampler.call("design_errors")
	var report: Dictionary = {"ok": failures.is_empty(), "design_complete": design_errors.is_empty(), "design_errors": design_errors,
		"tracks": track_records, "channel_samples": channel_records, "bone_samples": bone_records,
		"basis": "Headless Skeleton2D transforms, no native pixels; incomplete design never passes motion gates", "inputs": inputs, "samples": records, "errors": failures}
	var file := FileAccess.open(args[oi + 1], FileAccess.WRITE)
	if file == null:
		push_error("Cannot write motion samples")
		quit(1)
		return
	file.store_string(JSON.stringify(report))
	file.close()
	print("SHRIKE MOTION SAMPLES: %s (%d poses; %d authored bone poses; design complete=%s)" % ["PASS" if failures.is_empty() else "FAIL", records.size(), bone_records.size(), str(design_errors.is_empty())])
	quit(0 if failures.is_empty() else 1)

func _bone_matrices(rig: Node2D) -> Dictionary:
	var matrices: Dictionary = {}
	for name: String in rig.bones:
		var bone: Bone2D = rig.bones[name]
		var applied: Transform2D = rig.global_transform.affine_inverse() * bone.global_transform
		_check(applied.is_finite(), "Finite authored sample/" + name)
		matrices[name] = [applied.x.x, applied.x.y, applied.y.x, applied.y.y, applied.origin.x, applied.origin.y]
	return matrices

func _check(condition: bool, message: String) -> void:
	if not condition and message not in failures:
		failures.append(message)
		push_error(message)
