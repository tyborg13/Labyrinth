extends SceneTree

## The director's production sampling path, including its zero-travel capture
## and real board geometry. No window or renderer readback is requested.
const Rig = preload("res://assets/units/glacial_mirror_cutout/rig.gd")
const Capture = preload("res://tests/gait01/production_walk.gd")
const EPSILON: float = 0.0001
const PROOF_SOURCE_ORIGIN := Vector2(128, 128)
var failures: Array[String]
var checks: int = 0

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var output: String = args[args.find("--output") + 1]
	var rig_script: Script = load(args[args.find("--rig-script") + 1]) if args.has("--rig-script") else Rig
	var geometry: Dictionary = await preload("res://tests/gait01/board_geometry.gd").measure(self, "glacial_mirror")
	var records: Array[Dictionary]
	for view: String in ["front", "rear"]:
		for mirrored: bool in [false, true]:
			var rig: Node2D = rig_script.new()
			rig.facing = view
			rig.position = PROOF_SOURCE_ORIGIN
			rig.scale.x = -1.0 if mirrored else 1.0
			root.add_child(rig)
			if not rig.load_rig(): failures.append(str(rig.load_errors))
			for travel: bool in [false, true]:
				rig.layout["step_distance_px"] = float(geometry["step"]) if travel else 0.0
				rig.layout["screen_pixel_scale"] = float(geometry["scale"]) if travel else 1.0
				var evidence: Dictionary = Capture.capture(rig, "idle", 0.0)
				records.append({"view": view, "mirrored": mirrored, "travel": travel, "evidence": evidence})
				var previous: Dictionary = {}
				for row: Dictionary in evidence["samples"]:
					if row["kind"] != "presented": continue
					for side: String in ["near", "far"]:
						var lift: float = float(preload("res://scripts/maquette_cutout_runtime/humanoid_motion.gd").channels(
							preload("res://scripts/maquette_cutout_runtime/motion.gd").data_for(rig.layout), "move", row["phase"], rig.layout, view)["foot_" + side]["lift_px"])
						if lift > 0.0:
							previous.erase(side)
							continue
						var foot: Array = row["bones"]["foot_" + side]["global"]
						var position := Vector2(float(foot[4]), float(foot[5]))
						var sprite: Array = row["parts"]["foot_" + side]["transform"]
						var painted := Vector2(float(sprite[4]), float(sprite[5]))
						if previous.has(side):
							checks += 1
							if position.distance_to(previous[side]["foot"]) > EPSILON or painted.distance_to(previous[side]["paint"]) > EPSILON:
								failures.append("%s/%s/travel %s/frame %s: planted bone or painted foot moved" % [view, side, travel, row["frame"]])
						previous[side] = {"foot": position, "paint": painted}
			rig.free()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify({"native_pixels": false, "records": records, "errors": failures}))
	for failure: String in failures: push_error(failure)
	print("GAIT PRESENTED STANCE: %s (%d consecutive planted checks; production frames 6,7,27,34,35 included)" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)
