extends SceneTree
const Motion = preload("res://experiments/protagonist_2d/cutout_motion.gd")
var failures: Array[String] = []

func _init() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var maximum_contact_error := 0.0
	var maximum_contact_rotation := 0.0
	var worst_case := ""
	for facing in ["front", "rear"]:
		var layout_path := "res://experiments/protagonist_2d/cutout_layout.json" if facing == "front" else "res://experiments/protagonist_2d/cutout_layout_rear.json"
		var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(layout_path))
		var bones := {}
		var skeleton := Skeleton2D.new()
		root.add_child(skeleton)
		var neutral: Dictionary = Motion.sample_pose("idle", 0.0, layout, facing)
		for name in layout.joints:
			var bone := Bone2D.new()
			bone.name = name
			bone.set_autocalculate_length_and_angle(false)
			bone.set_length(8.0)
			bone.position = neutral[name].position
			bone.rest = bone.transform
			var parent_value: Variant = layout.joints[name].get("parent")
			var parent_name := "" if parent_value == null else String(parent_value)
			var parent: Node = skeleton if parent_name.is_empty() else bones[parent_name]
			parent.add_child(bone)
			bones[name] = bone
		for clip in Motion.clip_specs():
			if Motion.sample_pose(clip, 0.0, layout, facing) != Motion.sample_pose(clip, 1.0, layout, facing):
				failures.append("Clip closure differs: " + clip + "/" + facing)
			for index in range(129):
				var phase := float(index) / 128.0
				var pose: Dictionary = Motion.sample_pose(clip, phase, layout, facing)
				for name in bones:
					var bone: Bone2D = bones[name]
					bone.position = pose[name].position
					bone.rotation = float(pose[name].rotation)
					if not bone.transform.is_finite():
						failures.append("Nonfinite " + clip + "/" + name)
				for foot_name in ["foot_r", "foot_l"]:
					var foot_phase := fposmod(phase + (0.5 if foot_name == "foot_l" else 0.0), 1.0)
					if clip == "walk" and foot_phase > 0.55:
						continue
					var source: Array = layout.joints[foot_name].position
					var target := Vector2(float(source[0]), float(source[1]))
					var foot: Bone2D = bones[foot_name]
					var error := foot.global_position.distance_to(target)
					if error > maximum_contact_error:
						maximum_contact_error = error
						worst_case = "%s/%s/%s/%.4f" % [facing, clip, foot_name, phase]
					maximum_contact_rotation = maxf(maximum_contact_rotation, absf(foot.global_rotation))
		skeleton.free()
	if maximum_contact_error > 0.02:
		failures.append("Contact drift exceeds 0.02 px: " + str(maximum_contact_error) + " at " + worst_case)
	if maximum_contact_rotation > 0.0001:
		failures.append("Contact foot rotates: " + str(maximum_contact_rotation))
	print("CUTOUT_MOTION_PROOF " + JSON.stringify({"phase_samples": 129, "layouts": 2, "actual_layouts": true, "clips": 5,
		"max_contact_error_px": maximum_contact_error, "max_contact_rotation_rad": maximum_contact_rotation,
		"worst_case": worst_case, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
