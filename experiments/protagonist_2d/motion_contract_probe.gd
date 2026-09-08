extends SceneTree
const Motion = preload("res://experiments/protagonist_2d/cutout_motion.gd")
const PHASE_SAMPLES: int = 257
var failures: Array[String]

func _init() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var maximum_target_error := 0.0
	var maximum_support_drift := 0.0
	var maximum_painted_sole_ground_error := 0.0
	var maximum_contact_rotation := 0.0
	var maximum_wrap_position_delta := 0.0
	var maximum_wrap_rotation_delta := 0.0
	var worst_case := ""
	var maximum_boot_basis_error := 0.0
	var maximum_limb_width_error := 0.0
	var minimum_projected_length_ratio := INF
	var maximum_projected_length_ratio := -INF
	var gait_metrics := {}
	var joint_rotation_peaks := {}
	var attack_metrics := {}
	for facing: String in ["front", "rear"]:
		var layout_path := "res://experiments/protagonist_2d/cutout_layout.json" if facing == "front" else "res://experiments/protagonist_2d/cutout_layout_rear.json"
		var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(layout_path))
		var bones := {}
		var skeleton := Skeleton2D.new()
		root.add_child(skeleton)
		var neutral: Dictionary = Motion.sample_pose("rest", 0.0, layout, facing)
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
		var traces := {}
		var sole_geometry := _painted_sole_geometry(layout)
		var maximum_lead_toe_error := 0.0
		var lead_boot_angle := 0.0
		var minimum_knee_toe_angle := PI
		var minimum_toe_knee_distance := INF
		var maximum_swing_boot_relaxation := 0.0
		var lead_foot_name: String = "foot_l" if facing == "front" else "foot_r"
		# Independent landmarks inspected on the newly painted near-boot PNGs.
		# Their perspective already faces into travel; test those actual features
		# instead of requiring a large rotation of the previous toe-cap painting.
		var painted_toe_direction := Vector2(-27.0, 12.0) if facing == "front" else Vector2(26.0, -8.0)
		var desired_toe_direction := Vector2(-1.0, 0.5) if facing == "front" else Vector2(1.0, -0.5)
		var blade_tip_source := Vector2(float(layout.weapon_grip.tip[0]), float(layout.weapon_grip.tip[1]))
		for clip: String in Motion.clip_specs():
			var initial: Dictionary = Motion.sample_pose(clip, 0.0, layout, facing)
			if initial != Motion.sample_pose(clip, 1.0, layout, facing):
				failures.append("Clip closure differs: " + clip + "/" + facing)
			if clip != "walk" and initial != neutral:
				failures.append("Neutral source pose differs: " + clip + "/" + facing)
			if clip == "walk" and initial == neutral:
				failures.append("Walk contact was replaced with neutral: " + facing)
			var support_anchors := {}
			var contact_angles := {}
			traces[clip] = []
			for index: int in range(PHASE_SAMPLES):
				var phase: float = float(index) / float(PHASE_SAMPLES - 1)
				var pose: Dictionary = Motion.sample_pose(clip, phase, layout, facing)
				if pose.size() != 21 or pose.size() != bones.size():
					failures.append("Pose does not contain all 21 bones: " + clip + "/" + facing)
				for name: String in bones:
					var bone: Bone2D = bones[name]
					bone.position = pose[name].position
					bone.rotation = float(pose[name].rotation)
					bone.scale = pose[name].get("scale", Vector2.ONE)
					bone.skew = float(pose[name].get("skew", 0.0))
					if not bone.transform.is_finite():
						failures.append("Nonfinite " + clip + "/" + name)
					var key: String = facing + "/" + name
					joint_rotation_peaks[key] = maxf(float(joint_rotation_peaks.get(key, 0.0)), absf(bone.rotation))
				# Independent checks on the actual Node2D transforms: longitudinal
				# projection may vary, but painted widths and boot geometry may not.
				for pair: Array in [["thigh_r", "shin_r"], ["shin_r", "foot_r"], ["thigh_l", "shin_l"], ["shin_l", "foot_l"]]:
					var segment: Bone2D = bones[pair[0]]
					var axis: Vector2 = (Motion._joint_position(layout, pair[1]) - Motion._joint_position(layout, pair[0])).normalized()
					var width: Vector2 = segment.global_transform.basis_xform(axis.orthogonal())
					var longitudinal: Vector2 = segment.global_transform.basis_xform(axis)
					maximum_limb_width_error = maxf(maximum_limb_width_error, absf(width.length() - 1.0))
					minimum_projected_length_ratio = minf(minimum_projected_length_ratio, longitudinal.length())
					maximum_projected_length_ratio = maxf(maximum_projected_length_ratio, longitudinal.length())
				for foot_name: String in ["foot_r", "foot_l"]:
					var basis: Transform2D = (bones[foot_name] as Bone2D).global_transform
					maximum_boot_basis_error = maxf(maximum_boot_basis_error, maxf(absf(basis.x.length() - 1.0), maxf(absf(basis.y.length() - 1.0), absf(basis.x.dot(basis.y)))))
				var hand: Bone2D = bones["weapon_r"]
				var cape: Bone2D = bones["cape_tip"]
				var cape_material_point := Vector2(207.0, 179.0) if facing == "front" else Vector2(41.0, 174.0)
				traces[clip].append({"tip": hand.global_transform * (blade_tip_source - Motion._joint_position(layout, "weapon_r")),
					"hips": bones["hips"].global_position, "torso": bones["torso"].global_position,
					"head": bones["head"].global_position, "hand_l": bones["hand_l"].global_position, "hand": hand.global_position,
					"cape": cape.global_transform * (cape_material_point - Motion._joint_position(layout, "cape_tip"))})
				if clip == "walk":
					var hips: Bone2D = bones["hips"]
					minimum_hips_y = minf(minimum_hips_y, hips.global_position.y)
					maximum_hips_y = maxf(maximum_hips_y, hips.global_position.y)
				for foot_name: String in ["foot_r", "foot_l"]:
					var source: Array = layout.joints[foot_name].position
					var target := Vector2(float(source[0]), float(source[1]))
					var contact := true
					var foot_phase := 0.0
					var sole_ground_y := 0.0
					if clip == "walk":
						var state: Dictionary = Motion.walk_foot_state(phase, foot_name, layout, facing)
						target = state.target
						sole_ground_y = Vector2(state.ground).y + float(sole_geometry[foot_name].rest_depth)
						contact = state.contact
						foot_phase = float(state.cycle_phase)
						maximum_lift = maxf(maximum_lift, float(state.lift_px))
					var foot: Bone2D = bones[foot_name]
					if clip == "walk" and foot_name == lead_foot_name:
						var knee: Bone2D = bones[foot_name.replace("foot_", "shin_")]
						var toe_source := Vector2(137.0, 220.0) if facing == "front" else Vector2(168.0, 216.0)
						var toe: Vector2 = foot.global_transform * (toe_source - Motion._joint_position(layout, foot_name))
						minimum_knee_toe_angle = minf(minimum_knee_toe_angle, absf((knee.global_position - foot.global_position).angle_to(toe - foot.global_position)))
						minimum_toe_knee_distance = minf(minimum_toe_knee_distance, toe.distance_to(knee.global_position))
						if not contact:
							var contact_pose: Dictionary = Motion.sample_pose("walk", 0.0 if facing == "rear" else 0.5, layout, facing)
							var planted_angle: float = Motion._world_transform(contact_pose, layout, foot_name).get_rotation()
							maximum_swing_boot_relaxation = maxf(maximum_swing_boot_relaxation, absf(wrapf(foot.global_rotation - planted_angle, -PI, PI)))
					var error: float = foot.global_position.distance_to(target)
					if error > maximum_target_error:
						maximum_target_error = error
						worst_case = "%s/%s/%s/%.4f" % [facing, clip, foot_name, phase]
					if not contact:
						support_anchors.erase(foot_name)
						contact_angles.erase(foot_name)
						continue
					if not contact_angles.has(foot_name):
						contact_angles[foot_name] = foot.global_rotation if clip == "walk" else 0.0
					maximum_contact_rotation = maxf(maximum_contact_rotation,
						absf(wrapf(foot.global_rotation - float(contact_angles[foot_name]), -PI, PI)))
					if clip == "walk" and foot_name == lead_foot_name:
						var toe_direction: Vector2 = painted_toe_direction.rotated(foot.global_rotation)
						maximum_lead_toe_error = maxf(maximum_lead_toe_error, absf(toe_direction.angle_to(desired_toe_direction)))
						lead_boot_angle = foot.global_rotation
					if clip == "walk":
						var sole_depth := -INF
						for pixel: Vector2 in sole_geometry[foot_name].pixels:
							sole_depth = maxf(sole_depth, pixel.rotated(foot.global_rotation).y)
						maximum_painted_sole_ground_error = maxf(maximum_painted_sole_ground_error,
							absf(foot.global_position.y + sole_depth - sole_ground_y))
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
		attack_metrics[facing] = _measure_attack(traces, facing)
		# Direction is a moderate turn of a painted view, not a forced exact
		# 3D yaw. Reject toe-to-knee folding through the entire cycle instead.
		if minimum_knee_toe_angle < deg_to_rad(72.0) or minimum_toe_knee_distance < 28.0:
			failures.append("Walking toe folds toward its knee: " + facing)
		if maximum_swing_boot_relaxation < 0.08:
			failures.append("Walking boot stays locked during swing: " + facing)
		if maximum_lead_toe_error > 0.40 or absf(lead_boot_angle) > 0.20:
			failures.append("Walking near boot still splays away from travel: " + facing)
		var before: Dictionary = Motion.sample_pose("walk", 1.0 - 0.00001, layout, facing)
		var after: Dictionary = Motion.sample_pose("walk", 0.00001, layout, facing)
		for name: String in bones:
			maximum_wrap_position_delta = maxf(maximum_wrap_position_delta, Vector2(before[name].position).distance_to(Vector2(after[name].position)))
			maximum_wrap_rotation_delta = maxf(maximum_wrap_rotation_delta, absf(wrapf(float(before[name].rotation) - float(after[name].rotation), -PI, PI)))
		var hips_range: float = maximum_hips_y - minimum_hips_y
		if maximum_lift < 6.0 or maximum_lift > 10.0 or float(walk_info.stride_px) < 24.0 or hips_range < 3.0:
			failures.append("Walk lacks authored stride, clearance or weight transfer: " + facing)
		if int(Motion.clip_specs()["walk"].fps) != 36 or absf(float(Motion.clip_specs()["walk"].duration) - 2.0 / 3.0) > 0.0001:
			failures.append("Walking cadence is not 50 percent faster: " + facing)
		if support_samples < 250:
			failures.append("Insufficient planted-foot samples: " + facing)
		gait_metrics[facing] = {"frames": Motion.clip_specs()["walk"]["frames"],
			"fps": Motion.clip_specs()["walk"]["fps"], "stance_fraction": walk_info.stance_fraction,
			"stride_px": walk_info.stride_px,
			"travel_per_cycle_px": [cycle_travel.x, cycle_travel.y],
			"maximum_lift_px": maximum_lift, "pelvis_vertical_range_px": hips_range,
			"support_samples": support_samples, "lead_boot_angle_rad": lead_boot_angle,
			"maximum_lead_toe_direction_error_rad": maximum_lead_toe_error,
			"minimum_knee_toe_angle_rad": minimum_knee_toe_angle, "minimum_toe_knee_distance_px": minimum_toe_knee_distance,
			"maximum_swing_boot_relaxation_rad": maximum_swing_boot_relaxation,
			"duration_seconds": Motion.clip_specs()["walk"].duration}
		skeleton.free()
	if maximum_target_error > 0.02:
		failures.append("IK target error exceeds 0.02 px: " + str(maximum_target_error) + " at " + worst_case)
	if maximum_painted_sole_ground_error > 0.35:
		failures.append("Turned walking boot loses its painted sole ground depth: " + str(maximum_painted_sole_ground_error))
	if maximum_support_drift > 0.02:
		failures.append("World-space support foot slides: " + str(maximum_support_drift))
	if maximum_contact_rotation > 0.0001:
		failures.append("Contact foot changes its planted angle: " + str(maximum_contact_rotation))
	if maximum_wrap_position_delta > 0.05 or maximum_wrap_rotation_delta > 0.001:
		failures.append("Walk has a discontinuity at wrap")
	if maximum_boot_basis_error > 0.0001 or maximum_limb_width_error > 0.0001:
		failures.append("Projected leg motion stretches limb width or boot geometry")
	if minimum_projected_length_ratio < 0.78 or maximum_projected_length_ratio > 1.22:
		failures.append("Projected segment lengths exceed the authored foreshortening range")
	var matrices_path: String = OS.get_environment("LABYRINTH_CUTOUT_POSE_MATRICES")
	if not matrices_path.is_empty():
		_write_pose_matrices(matrices_path)
	print("CUTOUT_MOTION_PROOF " + JSON.stringify({"phase_samples": PHASE_SAMPLES, "layouts": 2, "actual_layouts": true, "clips": Motion.clip_specs().size(),
		"maximum_boot_basis_error": maximum_boot_basis_error, "maximum_limb_width_error": maximum_limb_width_error,
		"projected_segment_length_ratio": [minimum_projected_length_ratio, maximum_projected_length_ratio], "max_target_error_px": maximum_target_error, "max_world_support_drift_px": maximum_support_drift,
		"max_contact_rotation_rad": maximum_contact_rotation, "max_painted_sole_ground_error_px": maximum_painted_sole_ground_error, "worst_case": worst_case,
		"max_wrap_position_delta_px": maximum_wrap_position_delta, "max_wrap_rotation_delta_rad": maximum_wrap_rotation_delta,
		"gait_metrics": gait_metrics, "attack_metrics": attack_metrics, "joint_rotation_peaks_rad": joint_rotation_peaks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)


func _painted_sole_geometry(layout: Dictionary) -> Dictionary:
	var geometry := {}
	for part: Dictionary in layout.parts:
		var name := String(part.name)
		if name != "foot_r" and name != "foot_l":
			continue
		var image := Image.load_from_file("res://experiments/protagonist_2d/" + String(part.file))
		var pixels: Array[Vector2]
		var rest_depth := -INF
		var offset := Vector2(float(part.offset[0]), float(part.offset[1])) - Motion._joint_position(layout, name)
		for y: int in range(image.get_height()):
			for x: int in range(image.get_width()):
				if image.get_pixel(x, y).a > 0.0:
					var point: Vector2 = Vector2(x, y) + offset
					pixels.append(point)
					rest_depth = maxf(rest_depth, point.y)
		geometry[name] = {"pixels": pixels, "rest_depth": rest_depth}
	return geometry


func _measure_attack(traces: Dictionary, facing: String) -> Dictionary:
	var attack: Array = traces["attack"]
	var windup: Vector2 = attack[roundi(0.29 * (PHASE_SAMPLES - 1))].tip
	var finish: Vector2 = attack[roundi(0.43 * (PHASE_SAMPLES - 1))].tip
	var cut: Vector2 = finish - windup
	var lift: float = Vector2(attack[0].tip).y - windup.y
	var preparation_speed := 0.0
	var cut_speed := 0.0
	var recovery_speed := 0.0
	var upward_cut_travel := 0.0
	for index: int in range(1, attack.size()):
		var phase: float = float(index) / float(PHASE_SAMPLES - 1)
		var travel: Vector2 = Vector2(attack[index].tip) - Vector2(attack[index - 1].tip)
		var speed: float = travel.length() * float(PHASE_SAMPLES - 1) / float(Motion.clip_specs()["attack"].duration)
		if phase < 0.29:
			preparation_speed = maxf(preparation_speed, speed)
		elif phase >= 0.31 and phase <= 0.44:
			cut_speed = maxf(cut_speed, speed)
			upward_cut_travel += maxf(0.0, -travel.y)
		elif phase >= 0.60:
			recovery_speed = maxf(recovery_speed, speed)
	var raised_sample: Dictionary = attack[roundi(0.29 * (PHASE_SAMPLES - 1))]
	var blade_up: Vector2 = windup - Vector2(raised_sample.hand)
	var overhead_angle_error: float = absf(blade_up.angle_to(Vector2.UP))
	var overhead_clearance: float = Vector2(raised_sample.head).y - windup.y
	var strike_sample: Dictionary = attack[roundi(0.43 * (PHASE_SAMPLES - 1))]
	var forward_reach: float = (finish.x - Vector2(strike_sample.hips).x) * (-1.0 if facing == "front" else 1.0)
	var cut_height_above_feet: float = (202.0 if facing == "front" else 204.0) - finish.y
	if overhead_angle_error > deg_to_rad(18.0) or overhead_clearance < 58.0:
		failures.append("Attack preparation is not nearly vertical and above the head: " + facing)
	if forward_reach < 100.0 or cut_height_above_feet < 50.0:
		failures.append("Attack hits beside the feet instead of in front at body height: " + facing)
	# Blade landmarks are from source pixels. These spatial and timing bounds
	# reject the previous upward flick even when its joint values are finite.
	if lift < 45.0 or cut.y < 70.0 or absf(cut.x) < 40.0 or upward_cut_travel > 2.0:
		failures.append("Attack lacks raised anticipation followed by a sideways/downward cut: " + facing)
	if cut_speed < preparation_speed * 1.40 or cut_speed < recovery_speed * 2.0:
		failures.append("Attack cut is not faster than preparation/recovery: " + facing)
	return {"painted_blade_tip_lift_px": lift, "cut_delta_px": [cut.x, cut.y],
		"upward_travel_during_cut_px": upward_cut_travel, "preparation_peak_speed_px_s": preparation_speed,
		"cut_peak_speed_px_s": cut_speed, "recovery_peak_speed_px_s": recovery_speed,
		"overhead_angle_error_rad": overhead_angle_error,
		"overhead_clearance_from_head_bone_px": overhead_clearance, "forward_reach_px": forward_reach,
		"cut_height_above_feet_px": cut_height_above_feet}


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
