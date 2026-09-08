extends SceneTree

const ROOT := "/private/tmp/cutout-forward-HD8292"
const CASE := ROOT + "/protagonist_salute/v01"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var baseline: Script = load(ROOT + "/original_motion.gd")
	var candidate: Script = load(CASE + "/motion.gd")
	var failures: Array[String] = []
	var samples: int = 0
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CASE + "/cutout.json"))
	for facing: String in ["front", "rear"]:
		var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CASE + "/layouts/" + facing + ".json"))
		for part: Dictionary in layout["parts"]:
			part["file"] = CASE.path_join(part["file"])
		for clip: String in ["idle", "walk", "attack"]:
			for index: int in range(101):
				var phase: float = float(index) / 100.0
				var before: Dictionary = baseline.call("sample_pose", clip, phase, layout, facing)
				var after: Dictionary = candidate.call("sample_pose", clip, phase, layout, facing)
				samples += 1
				if before != after:
					failures.append("Changed pose: %s/%s/%d" % [facing, clip, index])
		var rest: Dictionary = baseline.call("sample_pose", "rest", 0.0, layout, facing)
		for endpoint: float in [0.0, 1.0]:
			if candidate.call("sample_pose", "salute", endpoint, layout, facing) != rest:
				failures.append("Salute endpoint differs: " + facing)
		for index: int in range(31):
			var pose: Dictionary = candidate.call("sample_pose", "salute", float(index) / 30.0, layout, facing)
			for name: String in ["root", "hips", "thigh_r", "shin_r", "foot_r", "thigh_l", "shin_l", "foot_l"]:
				if pose[name] != rest[name]:
					failures.append("Salute moved support: " + facing + "/" + name)
	var report := {"ok": failures.is_empty(), "preserved_pose_samples": samples, "salute_endpoints_and_support": "PASS" if failures.is_empty() else "FAIL", "errors": failures}
	var output := FileAccess.open(ROOT + "/pose_regression.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t"))
	output.close()
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
