extends "res://tests/rr48/samples.gd"

## Exact target/contact phases plus every fall recovery frame, through the
## unchanged production loader and both authored/presented paths. No GPU proof.
const TARGET_PHASES := {"rake": 0.25, "sweep": 0.28, "fall": 0.30}

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var directory: String = "res://experiments/cutouts/ashen_reaver/rr48"
	var output: String = args[args.find("--output") + 1]
	var variants: Dictionary = {
		"baseline": directory.path_join("rr57/baseline_compiled.json"),
		"feedback1": directory.path_join("rr57/feedback1_baseline_compiled.json"),
		"current": directory.path_join("compiled_motion.json"),
		"production": "res://assets/units/ashen_reaver_cutout/humanoid_v2/compiled_motion.json"}
	for view: String in ["front", "rear"]:
		for variant: String in variants:
			var rig: Node2D = ReaverRig.new()
			rig.position = Vector2(192, 192) # Same native viewport origin as raster_samples.gd.
			if variant != "production": rig.case_directory = directory
			rig.facing = view
			root.add_child(rig)
			assert(rig.load_rig(), str(rig.load_errors))
			rig.apply_pose("rest", 0.0)
			rig.layout["motion_data"] = variants[variant]
			var data: Dictionary = Motion.data_for(rig.layout)
			for clip: String in TARGET_PHASES:
				var phases: Array[float]
				phases.assign([TARGET_PHASES[clip], data["clips"][clip]["contact"]])
				if clip == "sweep": phases.append_array(typed_phases([0.6, 0.75]))
				# Every rear frame and every contact-on pose are protected.
				var count: int = roundi(float(data["clips"][clip]["seconds"]) * FPS)
				for frame: int in range(count):
					var at: float = float(frame) / float(count - 1)
					if (view == "rear" or at >= float(data["clips"][clip]["contact"])) and not phases.has(at): phases.append(at)
				for phase: float in phases:
					for kind: String in ["authored", "presented"]:
						if kind == "authored": rig.apply_authored_pose(clip, phase)
						else: rig.apply_pose(clip, phase)
						var row: Dictionary = record(rig, view, clip, phase, -1, kind)
						row["variant"] = variant
						rows.append(row)
			rig.free()
	write_report(output, {"native_pixels": false, "samples": rows,
		"compiled_sha256": FileAccess.get_sha256(variants["current"]),
		"baseline_sha256": FileAccess.get_sha256(variants["baseline"])})
	print("RR57 EXACT ATTACK POSES: PASS (%d poses; headless transforms only)" % rows.size())
	quit()

func typed_phases(values: Array) -> Array[float]:
	var result: Array[float]
	result.assign(values)
	return result
