extends "res://tests/rr48/samples.gd"

## Batch candidate sampling uses the same production Bone2D implementation.
func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var request: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[args.find("--request")+1]))
	for candidate: Dictionary in request["candidates"]:
		rows.clear()
		var data: Dictionary = Motion.data_for({"motion_data": str(candidate["case"]).path_join("compiled_motion.json")})
		for view: String in data["view_tracks"]:
			var rig: Node2D = Rig.new()
			rig.case_directory = candidate["case"]
			rig.facing = view
			root.add_child(rig)
			assert(rig.load_rig(), str(rig.load_errors))
			rig.layout["screen_pixel_scale"] = request["screen_pixel_scale"]
			rig.layout["step_distance_px"] = request["step_distance_px"]
			var clip: String = candidate["clip"]
			var count: int = roundi(float(data["clips"][clip]["seconds"])*FPS)
			for frame: int in range(count):
				if candidate.has("frames") and frame not in candidate["frames"]: continue
				var phase: float = float(frame)/float(count if data["clips"][clip].get("loop",false) else count-1)
				rig.apply_pose(clip,phase)
				rows.append(record(rig,view,clip,phase,frame,"presented"))
			rig.free()
		write_report(candidate["output"], {"samples":rows,"compiled_sha256":FileAccess.get_sha256(str(candidate["case"]).path_join("compiled_motion.json")),"step_distance_px":request["step_distance_px"],"screen_pixel_scale":request["screen_pixel_scale"],"native_pixels":false})
	print("RR48 BUDGET CANDIDATES: PASS (%d engine-sampled cases)"%request["candidates"].size())
	quit()
