extends SceneTree
const Motion = preload("res://scripts/guardian_cutout/motion.gd")
var failures: int = 0
func _initialize() -> void:
	for id: String in ["ashen_reaver", "rimejaw", "storm_cantor", "gallows_roc", "craghide", "last_lamplighter", "ash_hound", "rime_whelp", "rime_spitter", "bell_tender", "roc_fledgling", "stoneback_mite", "wick_shade"]:
		for facing: String in ["front", "rear"]:
			var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://experiments/cutouts/%s/v01/cutout.json" % id))
			var path: String = "res://experiments/cutouts/%s/v01/" % id + str(config["layouts"][facing])
			var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
			for clip: String in ["rest", "idle", "walk", "strike", "cast", "brace"]:
				for frame: int in range(41):
					var t: float = float(frame) / 40.0
					var pose: Dictionary = Motion.sample_pose(clip, t, layout, facing)
					for chain: Dictionary in layout["chains"]:
						if chain["kind"] != "leg": continue
						var foot: String = str(chain["bones"][2])
						var world: Transform2D = Motion._world(pose, layout, foot)
						var target: Vector2 = Motion.walk_foot_state(t, foot, layout, facing)["target"] if clip == "walk" else Motion._point(layout, foot)
						if world.origin.distance_to(target) > 0.2 or absf(world.x.length()-1) > 0.001 or absf(world.y.length()-1) > 0.001:
							failures += 1
		print("Guardian motion sampled: ", id)
	print("GUARDIAN MOTION: ", "PASS" if failures == 0 else "FAIL", " ", failures)
	quit(0 if failures == 0 else 1)
