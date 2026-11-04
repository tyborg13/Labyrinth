extends "res://tests/rr38/samples.gd"

## Every presented frame, actual production adapters; headless transforms only.
func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var directory: String = args[args.find("--case") + 1]
	var output: String = args[args.find("--output") + 1]
	var binding: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("rr58_binding.json")))
	var data: Dictionary = Motion.data_for({"motion_data": directory.path_join("compiled_motion.json")})
	var geometry: Dictionary = await proof_geometry(data)
	for view: String in data["view_tracks"]:
		var script: Script = load("res://assets/units/%s_cutout/rig.gd" % str(binding["rig"])) as Script
		var rig: Node2D = script.new()
		rig.case_directory = directory
		rig.facing = view
		root.add_child(rig)
		if not rig.load_rig(): errors.append(str(rig.load_errors))
		rig.layout["screen_pixel_scale"] = geometry["scale"]
		rig.layout["step_distance_px"] = geometry["step"]
		for clip: String in data["clips"]:
			var count: int = roundi(float(data["clips"][clip]["seconds"]) * FPS)
			for frame: int in range(count):
				var at: float = float(frame) / float(count if data["clips"][clip].get("loop", false) else count - 1)
				rig.apply_pose(clip, at)
				var row: Dictionary = record(rig, view, clip, at, frame, "presented")
				row["textures"] = {}
				for part: Dictionary in rig.layout["parts"]:
					var sprite: Sprite2D = rig.bones[part["bone"]].get_node_or_null(NodePath(part["name"])) as Sprite2D
					if sprite != null:
						var source: String = str(sprite.texture.get_meta("asset_source_path", sprite.texture.resource_path))
						row["textures"][part["name"]] = {"file": source.trim_prefix(directory + "/"), "sha256": FileAccess.get_sha256(source)}
				rows.append(row)
		# Release/reset regression: subsequent clips must restore held caches.
		for clip: String in ["death", "idle", "rest", "death", "move", "idle"]:
			rig.apply_pose(clip, 1.0 if clip == "death" else 0.0)
			for part: Dictionary in rig.layout["parts"]:
				if not part.has("release_texture"): continue
				var sprite: Sprite2D = rig.bones[part["bone"]].get_node(NodePath(part["name"])) as Sprite2D
				var expected: String = str(part["release_texture"]["file"] if clip == "death" else part["file"])
				if sprite.texture != rig._texture(expected): errors.append("Release cache reset: " + clip + "/" + str(part["name"]))
				var shift: Array = part["release_texture"].get("sprite_offset", [0, 0])
				var expected_offset := Vector2(float(shift[0]), float(shift[1])) if clip == "death" else Vector2.ZERO
				if sprite.offset != expected_offset: errors.append("Release crop reset: " + clip + "/" + str(part["name"]))
		rig.free()
	write_report(output, {"ok": errors.is_empty(), "native_pixels": false, "samples": rows, "errors": errors,
		"step_distance_px": geometry["step"], "screen_pixel_scale": geometry["scale"],
		"compiled_sha256": FileAccess.get_sha256(directory.path_join("compiled_motion.json")),
		"inputs": preload("res://tests/rr10/bindings.gd").for_case(directory)})
	print("RR58 BONE SAMPLES: %s (%s; %d frames; release/reset checked)" % ["PASS" if errors.is_empty() else "FAIL", binding["rig"], rows.size()])
	quit(0 if errors.is_empty() else 1)
