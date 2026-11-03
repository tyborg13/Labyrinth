extends "res://tests/rr11/action_direction.gd"

## Task proof, not a permanent suite guard. Uses each production rig adapter.
const TYPES := ["arc_thrall", "ashen_reaver", "briar_weaver", "chainbound_gaoler", "frostglass_lancer", "gale_herald", "glacial_mirror", "gloam_stalker", "slag_mortar", "hoarfrost_seer"]
const REQUIRED_PHASES := [0.0, 0.1, 0.2, 0.3, 0.5, 0.7, 0.8, 1.0]
const PROOF_ORIGIN := Vector2.ZERO
const PROOF_TILE_COUNT: int = 3
const DIRECTIONS := [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.has("--output"):
		push_error("Use -- --output DIRECTORY")
		quit(1)
		return
	var output: String = args[args.find("--output") + 1]
	DirAccess.make_dir_recursive_absolute(output)
	for type: String in TYPES:
		rows.clear()
		var movement_rows: Array[Dictionary]
		var directory: String = "res://assets/units/%s_cutout/humanoid_v2" % type
		var motion_path: String = directory.path_join("compiled_motion.json")
		var proof_motion_path: String = args[args.find("--motion-dir") + 1].path_join(type + ".json") if args.has("--motion-dir") else motion_path
		if args.has("--motion-dir"):
			# Process-local candidate substitution; no production assets or
			# anatomy change while measuring the director's 4/5-step options.
			Motion._cache[motion_path] = JSON.parse_string(FileAccess.get_file_as_string(proof_motion_path))
		var data: Dictionary = Motion.data_for({"motion_data": motion_path})
		var geometry: Dictionary = await preload("res://tests/gait01/board_geometry.gd").measure(self, type)
		for view: String in data["view_tracks"]:
			var rig: Node2D = load("res://assets/units/%s_cutout/rig.gd" % type).new()
			rig.position = PROOF_ORIGIN
			rig.facing = view
			root.add_child(rig)
			if not rig.load_rig(): errors.append(str(rig.load_errors))
			rig.layout["screen_pixel_scale"] = geometry["scale"]
			rig.layout["step_distance_px"] = geometry["step"]
			# Full clip inventories let the existing gates validate their own
			# provenance. Extra requested phases are kept in a separate inventory.
			for clip: String in data["clips"]:
				if args.has("--move-only") and clip != "move": continue
				var phases: Array[float]
				phases.assign([0.0, 1.0])
				for drop: Dictionary in data.get("view_held_drops", {}).get(view, {}).get(clip, {}).values():
					for at: float in [float(drop["start"]), (float(drop["start"]) + float(drop["land"])) / 2.0, float(drop["land"])]:
						if not phases.has(at): phases.append(at)
				for track: Dictionary in data["view_tracks"][view][clip]:
					for index: int in range(track["keys"].size()):
						var at: float = float(track["keys"][index]["at"])
						if not phases.has(at): phases.append(at)
						if index > 0:
							var middle: float = (at + float(track["keys"][index - 1]["at"])) / 2.0
							if not phases.has(middle): phases.append(middle)
				phases.sort()
				for at: float in phases:
					rig.apply_authored_pose(clip, at)
					rows.append(record(rig, view, clip, at, -1, "authored"))
				var count: int = roundi(float(data["clips"][clip]["seconds"]) * FPS)
				for frame: int in range(count):
					var at: float = float(frame) / float(count if data["clips"][clip].get("loop", false) else count - 1)
					rig.apply_pose(clip, at)
					rows.append(record(rig, view, clip, at, frame, "presented"))
			var requested: Array[Dictionary]
			for at: float in REQUIRED_PHASES:
				rig.apply_pose("move", at)
				requested.append(record(rig, view, "move", at, -1, "presented"))
			write_report(output.path_join(type + "_" + view + "_phases.json"), {"samples": requested})
			# RunScene submits frame 1..count at frame/count, with rest before
			# frame 1. Keep this clock distinct from the standalone clip's
			# historical frame/(count-1) evidence inventory.
			var movement_count: int = roundi(float(data["clips"]["move"]["seconds"]) * FPS)
			for frame: int in range(movement_count + 1):
				var at: float = float(frame) / movement_count
				rig.apply_pose("move", at)
				movement_rows.append(record(rig, view, "move", at, frame, "presented"))
			rig.free()
		var routes: Array[Dictionary]
		for direction: Vector2i in DIRECTIONS:
			var axis: Vector2 = Vector2(direction.x - direction.y, (direction.x + direction.y) * 0.5).normalized()
			var frames: Array[Dictionary]
			var count: int = roundi(float(data["clips"]["move"]["seconds"]) * FPS)
			for frame: int in range(PROOF_TILE_COUNT * count + 1):
				var tile: int = mini(frame / count, PROOF_TILE_COUNT - 1)
				var phase: float = float(frame - tile * count) / count
				var offset: Vector2 = Motion.root_offset(data, "move", phase, direction, geometry["step"])
				var position: Vector2 = axis * float(geometry["step"]) * tile + offset
				frames.append({"frame": frame, "phase": phase, "position": [position.x, position.y]})
			var phases: Array[Dictionary]
			for phase: float in REQUIRED_PHASES:
				var offset: Vector2 = Motion.root_offset(data, "move", phase, direction, geometry["step"])
				phases.append({"phase": phase, "offset": [offset.x, offset.y]})
			routes.append({"direction": [direction.x, direction.y], "axis": [axis.x, axis.y], "frames": frames, "phases": phases})
		write_report(output.path_join(type + ".json"), {"ok": errors.is_empty(), "errors": errors,
			"native_pixels": false, "fps": FPS, "step_distance_px": geometry["step"], "screen_pixel_scale": geometry["scale"],
			"inputs": {"compiled_motion.json": FileAccess.get_sha256(proof_motion_path)},
			"compiled_sha256": FileAccess.get_sha256(proof_motion_path), "samples": rows, "movement_samples": movement_rows, "routes": routes})
		print("WALK-01 SAMPLES: %s (%s; %d poses; headless transforms only)" % ["PASS" if errors.is_empty() else "FAIL", type, rows.size()])
	quit(0 if errors.is_empty() else 1)

func record(rig: Node2D, view: String, clip: String, phase: float, frame: int, kind: String) -> Dictionary:
	var row: Dictionary = super.record(rig, view, clip, phase, frame, kind)
	for part: Dictionary in rig.layout["parts"]:
		var node: Node2D = rig.get_node_or_null(NodePath(part["name"])) as Node2D
		if node == null: node = rig.bones[part["bone"]].get_node_or_null(NodePath(part["name"])) as Node2D
		if node != null: row["parts"][part["name"]] = {"transform": matrix(rig.global_transform.affine_inverse() * node.global_transform), "alpha": 1.0}
	return row
