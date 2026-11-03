extends "res://tests/rr11/action_direction.gd"

const ReaverRig = preload("res://assets/units/ashen_reaver_cutout/rig.gd")

const PROOF_SAMPLE_ORIGIN := Vector2.ZERO

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var directory: String = "res://experiments/cutouts/ashen_reaver/rr48"
	var output: String = directory.path_join("proof/samples.json")
	if args.has("--case"): directory = args[args.find("--case") + 1]
	if args.has("--output"): output = args[args.find("--output") + 1]
	var data: Dictionary = Motion.data_for({"motion_data": directory.path_join("compiled_motion.json")})
	var geometry: Dictionary = await proof_geometry(data)
	for view: String in data["view_tracks"]:
		var rig: Node2D = ReaverRig.new()
		rig.position=PROOF_SAMPLE_ORIGIN
		if not args.has("--production"): rig.case_directory = directory
		rig.facing = view
		root.add_child(rig)
		if not rig.load_rig(): errors.append(str(rig.load_errors))
		rig.layout["screen_pixel_scale"] = geometry["scale"]
		rig.layout["step_distance_px"] = geometry["step"]
		if args.has("--rest-only"):
			rig.apply_pose("rest", 0.0)
			rows.append(record(rig, view, "rest", 0.0, 0, "presented"))
			rig.free()
			continue
		for clip: String in data["clips"]:
			if args.has("--clips") and not clip in args[args.find("--clips") + 1].split(","): continue
			var phases: Array[float]
			phases.assign([0.0, 1.0])
			for drop: Dictionary in data.get("view_held_drops", {}).get(view, {}).get(clip, {}).values():
				for at: float in [float(drop["start"]), (float(drop["start"])+float(drop["land"]))/2.0, float(drop["land"])]:
					if not phases.has(at): phases.append(at)
			for track: Dictionary in data["view_tracks"][view][clip]:
				for i: int in range(track["keys"].size()):
					var at: float = float(track["keys"][i]["at"])
					if not phases.has(at): phases.append(at)
					if i > 0:
						var middle: float = (at + float(track["keys"][i - 1]["at"])) / 2.0
						if not phases.has(middle): phases.append(middle)
			phases.sort()
			for at: float in phases:
				if args.has("--presented-only"): continue
				rig.apply_authored_pose(clip, at)
				rows.append(record(rig, view, clip, at, -1, "authored"))
			var count: int = roundi(float(data["clips"][clip]["seconds"]) * FPS)
			for frame: int in range(count):
				if args.has("--frames") and not str(frame) in args[args.find("--frames") + 1].split(","): continue
				var at: float = float(frame) / float(count if data["clips"][clip].get("loop", false) else count - 1)
				rig.apply_pose(clip, at)
				rows.append(record(rig, view, clip, at, frame, "presented"))
		rig.free()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	write_report(output, {"ok": errors.is_empty(), "native_pixels": false, "fps": FPS,
		"inputs": preload("res://tests/rr10/bindings.gd").for_case(directory),
		"compiled_sha256": FileAccess.get_sha256(directory.path_join("compiled_motion.json")),
		"step_distance_px": geometry["step"], "screen_pixel_scale": geometry["scale"],
		"paint_scope": "production" if args.has("--production") else "source",
		"samples": rows, "errors": errors})
	print("RR48 BONE SAMPLES: %s (%d poses; headless transforms only)" % ["PASS" if errors.is_empty() else "FAIL", rows.size()])
	quit(0 if errors.is_empty() else 1)


## Capture actual painted-node depth, including mesh nodes and hidden layers.
func record(rig: Node2D, view: String, clip: String, phase: float, frame: int, kind: String) -> Dictionary:
	var row: Dictionary = super.record(rig, view, clip, phase, frame, kind)
	var data: Dictionary = Motion.data_for(rig.layout)
	var follower: Dictionary = data["clips"].get(clip, {}).get("held_follow", {})
	if not follower.is_empty():
		var delayed: float = phase - float(follower["lag_s"]) / float(data["clips"][clip]["seconds"])
		var target: float = 0.0
		if delayed >= 0.0:
			var world: Dictionary = preload("res://scripts/maquette_cutout_runtime/humanoid_motion.gd").world_transforms(data, clip, delayed, rig.layout, view, false, false)
			var grip: String = str(follower["grip"])
			var displacement: Vector2 = (world[grip] as Transform2D).origin - Motion.point(rig.layout["joints"][grip]["position"])
			if follower.get("reference_frame", "source") in ["root", "body"]:
				var attachment: Dictionary = rig.layout["held_items"]["falchion"]
				var reference: String = str(attachment.get("follow_reference_bone", follower.get("reference_bone", "root")))
				displacement = (world[reference] as Transform2D).affine_inverse() * (world[grip] as Transform2D).origin - (Motion.point(rig.layout["joints"][grip]["position"]) - Motion.point(rig.layout["joints"][reference]["position"]))
				if phase >= 1.0: displacement = Vector2.ZERO
			target = float(follower["deg_per_px"]) * displacement.dot(Motion.point(data["projection"][view]["forward"]))
		row["held_follow_budget"] = {"target_deg": target, "clamped_deg": clampf(target, -35.0, 35.0), "limit_deg": 35.0,
			"budget_note": "Binding 35-degree limit; director feedback 1, displacement relative to moving body reference."}
	for part: Dictionary in rig.layout["parts"]:
		var name: String = str(part["name"])
		var node: Node2D = rig.get_node_or_null(NodePath(name)) as Node2D
		if node == null: node = rig.bones[part["bone"]].get_node(NodePath(name)) as Node2D
		if not row["parts"].has(name): row["parts"][name] = {"transform": matrix(rig.global_transform.affine_inverse() * node.global_transform), "alpha": 1.0}
		row["parts"][name]["z_index"] = node.z_index
	return row
