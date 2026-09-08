extends SceneTree
const Motion = preload("res://experiments/protagonist_2d/cutout_motion.gd")
const PHASE_SAMPLES: int = 257
var failures: Array[String]

func _init() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var maximum_target_error := 0.0
	var maximum_support_drift := 0.0
	var maximum_contact_rotation := 0.0
	var maximum_wrap_position_delta := 0.0
	var maximum_wrap_rotation_delta := 0.0
	var worst_case := ""
	var gait_metrics := {}
	var joint_rotation_peaks := {}
	for facing: String in ["front", "rear"]:
		var layout_path := "res://experiments/protagonist_2d/cutout_layout.json" if facing == "front" else "res://experiments/protagonist_2d/cutout_layout_rear.json"
		var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(layout_path))
		var bones := {}
		var skeleton := Skeleton2D.new()
		root.add_child(skeleton)
		var neutral: Dictionary = Motion.sample_pose("idle", 0.0, layout, facing)
		for name: String in layout.joints:
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
		var walk_info: Dictionary = Motion.walk_cycle_info(layout, facing)
		var cycle_travel: Vector2 = walk_info.travel_per_cycle
		var maximum_lift := 0.0
		var minimum_hips_y := INF
		var maximum_hips_y := -INF
		var support_samples := 0
		for clip: String in Motion.clip_specs():
			var initial: Dictionary = Motion.sample_pose(clip, 0.0, layout, facing)
			if initial != Motion.sample_pose(clip, 1.0, layout, facing):
				failures.append("Clip closure differs: " + clip + "/" + facing)
			if clip != "walk" and initial != neutral:
				failures.append("Neutral source pose differs: " + clip + "/" + facing)
			if clip == "walk" and initial == neutral:
				failures.append("Walk contact was replaced with neutral: " + facing)
			var support_anchors := {}
			for index: int in range(PHASE_SAMPLES):
				var phase: float = float(index) / float(PHASE_SAMPLES - 1)
				var pose: Dictionary = Motion.sample_pose(clip, phase, layout, facing)
				for name: String in bones:
					var bone: Bone2D = bones[name]
					bone.position = pose[name].position
					bone.rotation = float(pose[name].rotation)
					if not bone.transform.is_finite():
						failures.append("Nonfinite " + clip + "/" + name)
					var key: String = facing + "/" + name
					joint_rotation_peaks[key] = maxf(float(joint_rotation_peaks.get(key, 0.0)), absf(bone.rotation))
				if clip == "walk":
					var hips: Bone2D = bones["hips"]
					minimum_hips_y = minf(minimum_hips_y, hips.global_position.y)
					maximum_hips_y = maxf(maximum_hips_y, hips.global_position.y)
				for foot_name: String in ["foot_r", "foot_l"]:
					var source: Array = layout.joints[foot_name].position
					var target := Vector2(float(source[0]), float(source[1]))
					var contact := true
					var foot_phase := 0.0
					if clip == "walk":
						var state: Dictionary = Motion.walk_foot_state(phase, foot_name, layout, facing)
						target = state.target
						contact = state.contact
						foot_phase = float(state.cycle_phase)
						maximum_lift = maxf(maximum_lift, float(state.lift_px))
					var foot: Bone2D = bones[foot_name]
					var error: float = foot.global_position.distance_to(target)
					if error > maximum_target_error:
						maximum_target_error = error
						worst_case = "%s/%s/%s/%.4f" % [facing, clip, foot_name, phase]
					if not contact:
						support_anchors.erase(foot_name)
						continue
					maximum_contact_rotation = maxf(maximum_contact_rotation, absf(foot.global_rotation))
					if clip == "walk":
						# Independent world-space contact test: add the same constant
						# root travel as the inspection host, then compare all samples
						# in each uninterrupted support interval to its first footprint.
						var world_foot: Vector2 = foot.global_position + cycle_travel * phase
						if not support_anchors.has(foot_name) or foot_phase < float(support_anchors[foot_name].phase):
							support_anchors[foot_name] = {"point": world_foot, "phase": foot_phase}
						var anchor: Vector2 = support_anchors[foot_name].point
						maximum_support_drift = maxf(maximum_support_drift, world_foot.distance_to(anchor))
						support_anchors[foot_name].phase = foot_phase
						support_samples += 1
		var before: Dictionary = Motion.sample_pose("walk", 1.0 - 0.00001, layout, facing)
		var after: Dictionary = Motion.sample_pose("walk", 0.00001, layout, facing)
		for name: String in bones:
			maximum_wrap_position_delta = maxf(maximum_wrap_position_delta, Vector2(before[name].position).distance_to(Vector2(after[name].position)))
			maximum_wrap_rotation_delta = maxf(maximum_wrap_rotation_delta, absf(wrapf(float(before[name].rotation) - float(after[name].rotation), -PI, PI)))
		var hips_range: float = maximum_hips_y - minimum_hips_y
		if maximum_lift < 10.0 or float(walk_info.stride_px) < 24.0 or hips_range < 3.0:
			failures.append("Walk lacks authored stride, clearance or weight transfer: " + facing)
		if support_samples < 250:
			failures.append("Insufficient planted-foot samples: " + facing)
		gait_metrics[facing] = {"frames": Motion.clip_specs()["walk"]["frames"],
			"fps": Motion.clip_specs()["walk"]["fps"], "stance_fraction": walk_info.stance_fraction,
			"stride_px": walk_info.stride_px,
			"travel_per_cycle_px": [cycle_travel.x, cycle_travel.y],
			"maximum_lift_px": maximum_lift, "pelvis_vertical_range_px": hips_range,
			"support_samples": support_samples}
		skeleton.free()
	if maximum_target_error > 0.02:
		failures.append("IK target error exceeds 0.02 px: " + str(maximum_target_error) + " at " + worst_case)
	if maximum_support_drift > 0.02:
		failures.append("World-space support foot slides: " + str(maximum_support_drift))
	if maximum_contact_rotation > 0.0001:
		failures.append("Contact foot rotates: " + str(maximum_contact_rotation))
	if maximum_wrap_position_delta > 0.05 or maximum_wrap_rotation_delta > 0.001:
		failures.append("Walk has a discontinuity at wrap")
	var matrices_path: String = OS.get_environment("LABYRINTH_CUTOUT_POSE_MATRICES")
	if not matrices_path.is_empty():
		_write_pose_matrices(matrices_path)
	print("CUTOUT_MOTION_PROOF " + JSON.stringify({"phase_samples": PHASE_SAMPLES, "layouts": 2, "actual_layouts": true, "clips": 5,
		"max_target_error_px": maximum_target_error, "max_world_support_drift_px": maximum_support_drift,
		"max_contact_rotation_rad": maximum_contact_rotation, "worst_case": worst_case,
		"max_wrap_position_delta_px": maximum_wrap_position_delta, "max_wrap_rotation_delta_rad": maximum_wrap_rotation_delta,
		"gait_metrics": gait_metrics, "joint_rotation_peaks_rad": joint_rotation_peaks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)


func _write_pose_matrices(path: String) -> void:
	# Optional source-pixel skinning matrices let the mesh audit check triangle
	# orientation against every authored frame, using the same sampled motion.
	var samples: Array[Dictionary]
	for facing: String in ["front", "rear"]:
		var layout_path := "res://experiments/protagonist_2d/cutout_layout.json" if facing == "front" else "res://experiments/protagonist_2d/cutout_layout_rear.json"
		var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(layout_path))
		var specs: Dictionary = Motion.clip_specs()
		for clip: String in specs:
			var frames: int = int(specs[clip].frames)
			var looping: bool = bool(specs[clip].loop)
			for frame: int in range(frames):
				var phase: float = float(frame) / float(frames if looping else frames - 1)
				var pose: Dictionary = Motion.sample_pose(clip, phase, layout, facing)
				var matrices := {}
				for name: String in layout.joints:
					var rest: Vector2 = Motion._joint_position(layout, name)
					var skin: Transform2D = Motion._world_transform(pose, layout, name) * Transform2D(0.0, -rest)
					matrices[name] = [skin.x.x, skin.x.y, skin.y.x, skin.y.y, skin.origin.x, skin.origin.y]
				samples.append({"facing": facing, "clip": clip, "frame": frame, "phase": phase, "bones": matrices})
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		failures.append("Cannot write optional posed mesh audit matrices: " + path)
		return
	var inputs := {}
	for resource_path: String in ["res://experiments/protagonist_2d/cutout_motion.gd",
			"res://experiments/protagonist_2d/cutout_layout.json",
			"res://experiments/protagonist_2d/cutout_layout_rear.json"]:
		inputs[resource_path] = FileAccess.get_sha256(resource_path)
	file.store_string(JSON.stringify({"input_sha256": inputs,
		"matrix_order": ["xx", "xy", "yx", "yy", "ox", "oy"], "samples": samples}))
	file.close()
	print("CUTOUT_POSE_MATRICES " + path)
