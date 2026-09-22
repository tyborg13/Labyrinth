extends SceneTree

const CHARACTERS: PackedStringArray = ["crawler", "harrier", "stone_warden", "bile_bloomer", "lightning_wisp", "cinder_ooze", "cinder_droplet"]
var failures: PackedStringArray = []
var checks: int = 0

func _initialize() -> void:
	for character: String in CHARACTERS:
		var base: String = "res://output/contextual-animation-polish/creatures/cases/" + character + "/"
		_check(FileAccess.get_file_as_string(base + "motion.gd") == FileAccess.get_file_as_string("res://scripts/" + character + "_cutout/motion.gd"), character + " production matches reviewed case")
		var motion: Script = load(base + "motion.gd")
		var original: Script = load(base + "source/baseline_motion.gd")
		var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(base + "cutout.json"))
		for facing: String in config["layouts"]:
			var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(base + str(config["layouts"][facing])))
			for clip: String in config["clips"]:
				var context: String = character + "/" + facing + "/" + clip
				for index: int in range(101):
					var phase: float = float(index) / 100.0
					var pose: Dictionary = motion.sample_pose(clip, phase, layout, facing)
					if clip == "hit":
						var rest: Dictionary = motion.sample_pose("idle",0.0,layout,facing)
						for foot: String in config["contact_feet"]:
							_check(_world(pose,layout,foot).origin.distance_to(_world(rest,layout,foot).origin) < 0.001,context + " planted impact support " + foot)
					if clip not in ["hit", "death"]:
						_check(pose == original.sample_pose(clip, phase, layout, facing), context + " preserved baseline")
					for bone: String in layout["joints"]:
						var transform: Transform2D = _world(pose, layout, bone)
						_check(transform.is_finite() and absf(transform.determinant()) > 0.00001, context + " finite nonsingular " + bone)
						if bone in config["rigid_bones"]:
							_check(absf(transform.x.length() - 1.0) < 0.001 and absf(transform.y.length() - 1.0) < 0.001 and absf(transform.x.dot(transform.y)) < 0.001, context + " rigid " + bone)
				if clip == "hit":
					var rest: Dictionary = motion.sample_pose("idle", 0.0, layout, facing)
					_check(_same_transforms(rest,motion.sample_pose(clip,0.0,layout,facing),layout),context + " begins at rest")
					_check(_same_transforms(rest,motion.sample_pose(clip,1.0,layout,facing),layout),context + " fully recovers")
					_check(not _same_transforms(rest,motion.sample_pose(clip,0.15,layout,facing),layout),context + " readable impact")
				if clip == "death":
					_check(_same_transforms(motion.sample_pose("idle",0.0,layout,facing),motion.sample_pose(clip,0.0,layout,facing),layout),context + " begins at rest")
					_check(_same_transforms(motion.sample_pose(clip,0.84,layout,facing),motion.sample_pose(clip,1.0,layout,facing),layout),context + " terminal pose held")
					_check(not _same_transforms(motion.sample_pose("idle",0.0,layout,facing),motion.sample_pose(clip,1.0,layout,facing),layout),context + " distinct collapse")
	print("Contextual creature motion: ", checks, " checks; ", failures.size(), " failures")
	for failure: String in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value and label not in failures:
		failures.append(label)

func _same_transforms(a: Dictionary,b: Dictionary,layout: Dictionary) -> bool:
	for bone: String in layout["joints"]:
		if not _world(a,layout,bone).is_equal_approx(_world(b,layout,bone)):
			return false
	return true

func _world(pose: Dictionary,layout: Dictionary,bone: String) -> Transform2D:
	var item: Dictionary = pose[bone]
	var local := Transform2D(float(item.get("rotation",0.0)),Vector2(item.get("scale",Vector2.ONE)),float(item.get("skew",0.0)),Vector2(item["position"]))
	var parent: Variant = layout["joints"][bone]["parent"]
	return local if parent == null else _world(pose,layout,str(parent)) * local
