extends "res://tests/rr48/samples.gd"

## Inventory the production death releases, including release_at-only rigs.
## Headless transforms only; native renderer sheets remain director proof.
func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var output: String = args[args.find("--output") + 1]
	var inventory: Array[Dictionary]
	for directory: String in DirAccess.get_directories_at("res://assets/units"):
		var base: String = "res://assets/units/" + directory
		var motion_path: String = base.path_join("humanoid_v2/compiled_motion.json")
		if not FileAccess.file_exists(motion_path): continue
		var data: Dictionary = Motion.data_for({"motion_data": motion_path})
		var death: Dictionary = data.get("clips", {}).get("death", {})
		for view: String in data.get("view_tracks", {}):
			var releases: Dictionary = data.get("view_release_at", {}).get(view, {}).get("death", death.get("release_at", {}))
			if releases.is_empty(): continue
			var rig: Node2D = load(base.path_join("rig.gd")).new()
			rig.facing = view
			root.add_child(rig)
			if not rig.load_rig(): errors.append(str(rig.load_errors))
			for item: String in releases:
				var count: int = roundi(float(death["seconds"]) * FPS)
				var first: int = ceili(float(releases[item]) * float(count - 1))
				var frames: Array[int]
				frames.assign([maxi(0,first - 1),first,mini(count - 1,first + 12),count - 1])
				var witnesses: Array[Dictionary]
				for frame: int in frames:
					var phase: float = float(frame) / float(count - 1)
					rig.apply_pose("death", phase)
					witnesses.append(record(rig,view,"death",phase,frame,"presented"))
				inventory.append({"rig":directory,"view":view,"item":item,"release":releases[item],"seconds":death["seconds"],"layout":rig.layout,"samples":witnesses})
			rig.free()
	write_report(output,{"ok":errors.is_empty(),"native_pixels":false,"inventory":inventory,"errors":errors})
	print("RR57 HELD-ITEM AUDIT SAMPLES: %s (%d view/items)" % ["PASS" if errors.is_empty() else "FAIL",inventory.size()])
	quit(0 if errors.is_empty() else 1)
