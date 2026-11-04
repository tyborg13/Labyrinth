extends "res://tests/rr48/samples.gd"

## Numerical solve on the real production rig; no renderer/paint claims.
func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var request: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[args.find("--request") + 1]))
	var output: String = args[args.find("--output") + 1]
	var rig: Node2D = ReaverRig.new()
	rig.case_directory = "res://experiments/cutouts/ashen_reaver/rr48"
	rig.position = Vector2(192, 192)
	rig.facing = "front"
	root.add_child(rig)
	assert(rig.load_rig(), str(rig.load_errors))
	var data: Dictionary = Motion.data_for(rig.layout)
	var chosen: Array[Dictionary]
	var forward: Vector2 = Motion.point(data["projection"]["front"]["forward"])
	for pose: Dictionary in request["poses"]:
		var found: bool = false
		for candidate: Dictionary in pose["candidates"]:
			for track: Dictionary in data["view_tracks"]["front"][pose["clip"]]:
				if track["source"] not in ["hand_far.forward_px", "hand_far.lift_px"]: continue
				var value: float = candidate[track["channel"]]
				track["keys"] = [{"at": 0.0, "value": value, "interpolation": "smoothstep"}, {"at": 1.0, "value": value, "interpolation": "smoothstep"}]
			var ok: bool = true
			var maximum: float = 0.0
			for kind: String in ["authored", "presented"]:
				if kind == "authored": rig.apply_authored_pose(pose["clip"], pose["phase"])
				else: rig.apply_pose(pose["clip"], pose["phase"])
				var inverse: Transform2D = rig.global_transform.affine_inverse()
				var a: Vector2 = (inverse * rig.bones["upper_far"].global_transform).origin
				var b: Vector2 = (inverse * rig.bones["fore_far"].global_transform).origin
				var c: Vector2 = (inverse * rig.bones["hand_far"].global_transform).origin
				var hyper: float = maxf(0.0, -rad_to_deg((b-a).angle_to(c-b)) * signf((b-a).cross(forward)))
				maximum = maxf(maximum, hyper)
				ok = ok and hyper <= float(data["elbow_policy"]["max_hyperextension_deg"]) and c.x <= a.x - 4.0 + 0.0001
			if ok:
				chosen.append({"clip": pose["clip"], "phase": pose["phase"], "candidate": candidate, "max_hyperextension_deg": maximum})
				found = true
				break
		if not found: errors.append("No legal guard at " + str(pose["phase"]))
	rig.free()
	write_report(output, {"poses": chosen, "errors": errors, "native_pixels": false})
	print("RR57 SIDEWARD GUARD CANDIDATES: %d solved; %d errors" % [chosen.size(), errors.size()])
	quit(0 if errors.is_empty() else 1)
