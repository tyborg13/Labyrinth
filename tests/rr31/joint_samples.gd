extends "res://tests/rr10/samples.gd"

## Sample one compiled channel at a time with the production Bone2D sampler.
## All mutations are process-local proof data; no authored file is written.
func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var directory: String = "res://experiments/cutouts/slag_mortar/rr30"
	var requests_path: String = args[args.find("--requests") + 1]
	var output: String = args[args.find("--output") + 1]
	var requests: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(requests_path))
	var original: Dictionary = Motion.data_for({"motion_data": directory.path_join("compiled_motion.json")})
	for view: String in original["view_tracks"]:
		var rig := Rig.new()
		rig.position = SOURCE_ORIGIN
		rig.case_directory = directory
		rig.facing = view
		root.add_child(rig)
		if not rig.load_rig(): errors.append(str(rig.load_errors))
		rig.layout["screen_pixel_scale"] = requests["screen_pixel_scale"]
		rig.layout["step_distance_px"] = requests["step_distance_px"]
		var data: Dictionary = original.duplicate(true)
		# Rig.apply_pose restores this canonical path before calling the sampler.
		var cache_key: String = directory.path_join("compiled_motion.json")
		Motion._cache[cache_key] = data
		rig.layout["motion_data"] = cache_key
		data["clips"]["joint_budget"] = {"seconds": 1.0}
		for request: Dictionary in requests["requests"]:
			if request["view"] != view: continue
			var track: Dictionary = request["track"].duplicate(true)
			data["clips"]["joint_budget"] = {"seconds": 1.0}
			var isolated: Array[Dictionary]
			isolated.assign([])
			if str(track["source"]).begins_with("foot_") or track["source"] == "root.forward_px":
				# Generated foot lanes are defined only inside the gait solver.
				# Required companion targets are zero; only this channel varies.
				data["clips"]["joint_budget"]["gait"] = original["clips"]["move"]["gait"].duplicate(true)
				for side: String in ["near", "far"]:
					for channel: String in ["forward_px", "lift_px", "lane_px"]:
						var source: String = "foot_" + side + "." + channel
						if source == track["source"]: continue
						isolated.append({"source": source, "bone": "foot_" + side, "channel": channel,
							"forward_mode": "world_step", "keys": [{"at": 0.0, "value": 0.0, "interpolation": "linear"}]})
			isolated.append(track)
			for value: float in request["values"]:
				track["keys"] = [{"at": 0.0, "value": value, "interpolation": "linear"}]
				data["view_tracks"][view]["joint_budget"] = isolated
				rig.apply_pose("joint_budget", 0.0)
				var row: Dictionary = record(rig, view, "joint_budget", 0.0, rows.size(), "presented")
				row.erase("bones")
				row["channel"] = track["source"]
				row["value"] = value
				rows.append(row)
		rig.free()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	write_report(output, {"ok": errors.is_empty(), "samples": rows, "errors": errors,
		"requests_sha256": FileAccess.get_sha256(requests_path),
		"inputs": preload("res://tests/rr10/bindings.gd").for_case(directory)})
	print("RR31 JOINT SAMPLES: %s (%d poses; isolated channels)" % ["PASS" if errors.is_empty() else "FAIL", rows.size()])
	quit(0 if errors.is_empty() else 1)
