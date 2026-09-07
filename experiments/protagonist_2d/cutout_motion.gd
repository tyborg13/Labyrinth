extends RefCounted
## Restrained motion for a source-painted Bone2D cutout rig.
## Input joint positions are GLOBAL source-image pixels; returned positions are
## LOCAL to the joint's parent. Rotations are offsets from identity-basis rests.
## Each call returns a complete pose, so seeking and changing clips cannot leave
## transforms behind. Rear motion changes direction without mirroring textures.


static func clip_specs() -> Dictionary:
	return {
		"idle": {"frames": 48, "fps": 24, "loop": true, "duration": 2.0},
		"walk": {"frames": 32, "fps": 24, "loop": true, "duration": 32.0 / 24.0},
		"attack": {"frames": 32, "fps": 24, "loop": false, "duration": 32.0 / 24.0},
		"block": {"frames": 36, "fps": 24, "loop": false, "duration": 1.5},
		"hit": {"frames": 24, "fps": 24, "loop": false, "duration": 1.0},
	}


static func sample_pose(clip: String, phase: float, layout: Dictionary, facing: String) -> Dictionary:
	var pose := _rest_pose(layout)
	var specs := clip_specs()
	if not specs.has(clip):
		return pose
	var looped: bool = bool(specs[clip]["loop"])
	var t: float = fposmod(phase, 1.0) if looped else clampf(phase, 0.0, 1.0)
	# Preserve the exact source pose at every clip boundary, including idle phase 0.
	if is_zero_approx(t) or is_equal_approx(t, 1.0):
		return pose
	var direction: float = -1.0 if facing.to_lower().contains("rear") or facing.to_lower() == "back" else 1.0
	var right_target := _joint_position(layout, "foot_r")
	var left_target := _joint_position(layout, "foot_l")
	var right_foot_angle := 0.0
	var left_foot_angle := 0.0

	match clip:
		"idle":
			var breath: float = 0.5 - 0.5 * cos(TAU * t)
			var sway: float = sin(TAU * t)
			_offset(pose, "hips", Vector2(0.0, 0.34 * breath))
			_offset(pose, "torso", Vector2(0.0, -0.22 * breath))
			_rotate(pose, "torso", direction * 0.008 * sway)
			_rotate(pose, "neck", -direction * 0.004 * sway)
			_rotate(pose, "head", -direction * 0.004 * sway)
			_rotate(pose, "arm_r", direction * 0.009 * breath)
			_rotate(pose, "forearm_r", -direction * 0.010 * breath)
			_rotate(pose, "arm_l", -direction * 0.008 * breath)
			_rotate(pose, "cape_root", direction * 0.009 * sway)
			_rotate(pose, "cape_mid", direction * (0.015 * sway + 0.010 * breath))
			_rotate(pose, "cape_tip", direction * (0.020 * sway - 0.015 * breath))
		"walk":
			var stride: float = sin(TAU * t)
			var weight_shift: float = stride * (0.5 - 0.5 * cos(TAU * t))
			var settle: float = 0.4 * (1.0 - cos(TAU * t)) + 0.15 * (1.0 - cos(2.0 * TAU * t))
			_offset(pose, "root", Vector2(direction * 0.45 * weight_shift, 0.0))
			_offset(pose, "hips", Vector2(0.0, settle))
			_rotate(pose, "hips", direction * 0.007 * weight_shift)
			_rotate(pose, "torso", -direction * 0.018 * stride)
			_rotate(pose, "neck", direction * 0.006 * stride)
			_rotate(pose, "head", direction * 0.005 * stride)
			_rotate(pose, "arm_r", -direction * 0.11 * stride)
			_rotate(pose, "forearm_r", direction * 0.060 * stride)
			_rotate(pose, "hand_r", direction * 0.018 * stride)
			_rotate(pose, "arm_l", direction * 0.13 * stride)
			_rotate(pose, "forearm_l", -direction * 0.070 * stride)
			var right_step := _in_place_step(t, direction)
			var left_step := _in_place_step(fposmod(t + 0.5, 1.0), direction)
			right_target += Vector2(right_step.x, right_step.y)
			left_target += Vector2(left_step.x, left_step.y)
			right_foot_angle = right_step.z
			left_foot_angle = left_step.z
			var cloth_lag: float = sin(TAU * t - 0.45) + sin(0.45)
			var cloth_tail: float = sin(TAU * t - 0.85) + sin(0.85)
			_rotate(pose, "cape_root", direction * 0.018 * stride)
			_rotate(pose, "cape_mid", direction * 0.023 * cloth_lag)
			_rotate(pose, "cape_tip", direction * 0.028 * cloth_tail)
		"attack":
			var prepare: float = _pulse(t, 0.0, 0.19, 0.37)
			var strike: float = _pulse(t, 0.24, 0.44, 0.87)
			var cloth_follow: float = _pulse(t, 0.36, 0.60, 1.0)
			_offset(pose, "root", Vector2(direction * (0.45 * prepare - 1.3 * strike), 0.0))
			_offset(pose, "hips", Vector2(0.0, 0.5 * prepare + 0.75 * strike))
			_rotate(pose, "hips", direction * (-0.008 * prepare + 0.014 * strike))
			_rotate(pose, "torso", direction * (-0.032 * prepare + 0.075 * strike))
			_rotate(pose, "neck", direction * (0.012 * prepare - 0.025 * strike))
			_rotate(pose, "head", direction * (0.010 * prepare - 0.020 * strike))
			# A compact upward/outward cut gives the original down-left blade a
			# readable arc without lifting the shoulder far beyond its painted cap.
			_rotate(pose, "arm_r", direction * (-0.075 * prepare + 0.29 * strike))
			_rotate(pose, "forearm_r", direction * (-0.12 * prepare + 0.49 * strike))
			_rotate(pose, "hand_r", direction * (-0.05 * prepare + 0.07 * strike))
			_rotate(pose, "arm_l", direction * (0.035 * prepare - 0.075 * strike))
			_rotate(pose, "forearm_l", direction * (0.05 * prepare - 0.11 * strike))
			_rotate(pose, "cape_root", direction * (-0.012 * prepare - 0.026 * strike))
			_rotate(pose, "cape_mid", direction * (-0.035 * strike + 0.030 * cloth_follow))
			_rotate(pose, "cape_tip", direction * (-0.025 * strike + 0.048 * cloth_follow))
		"block":
			var guard: float = _hold(t, 0.0, 0.24, 0.65, 1.0)
			var catch: float = _pulse(t, 0.30, 0.39, 0.58)
			_offset(pose, "root", Vector2(direction * (-0.5 * guard + 0.6 * catch), 0.0))
			_offset(pose, "hips", Vector2(0.0, 0.55 * guard + 0.25 * catch))
			_rotate(pose, "torso", direction * (-0.018 * guard + 0.028 * catch))
			_rotate(pose, "head", direction * 0.012 * guard)
			_rotate(pose, "arm_r", direction * (-0.10 * guard + 0.035 * catch))
			_rotate(pose, "forearm_r", direction * (-0.20 * guard + 0.070 * catch))
			_rotate(pose, "hand_r", direction * (1.02 * guard - 0.055 * catch))
			_rotate(pose, "arm_l", -direction * 0.085 * guard)
			_rotate(pose, "forearm_l", -direction * 0.17 * guard)
			_rotate(pose, "cape_root", direction * 0.012 * catch)
			_rotate(pose, "cape_mid", direction * 0.025 * catch)
			_rotate(pose, "cape_tip", direction * 0.034 * _pulse(t, 0.35, 0.48, 0.76))
		"hit":
			var recoil: float = _pulse(t, 0.0, 0.14, 0.85)
			var recover: float = _pulse(t, 0.36, 0.63, 1.0)
			_offset(pose, "root", Vector2(direction * 2.0 * recoil, 0.0))
			_offset(pose, "hips", Vector2(0.0, 0.85 * recoil))
			_rotate(pose, "hips", direction * 0.010 * recoil)
			_rotate(pose, "torso", direction * (0.062 * recoil - 0.008 * recover))
			_rotate(pose, "neck", -direction * 0.040 * recoil)
			_rotate(pose, "head", -direction * 0.070 * recoil)
			_rotate(pose, "arm_r", direction * 0.090 * recoil)
			_rotate(pose, "forearm_r", -direction * 0.13 * recoil)
			_rotate(pose, "hand_r", direction * 0.060 * recoil)
			_rotate(pose, "arm_l", -direction * 0.075 * recoil)
			_rotate(pose, "forearm_l", -direction * 0.10 * recoil)
			_rotate(pose, "cape_root", -direction * 0.024 * recoil)
			_rotate(pose, "cape_mid", direction * (-0.025 * recoil + 0.026 * recover))
			_rotate(pose, "cape_tip", direction * (-0.016 * recoil + 0.046 * recover))

	# Contact feet remain at their exact rig-space anchors while the torso moves.
	# Swinging feet use the same analytic two-segment solve. The ankle counter-
	# rotation also keeps each planted boot's orientation fixed.
	_solve_leg(pose, layout, "thigh_r", "shin_r", "foot_r", right_target, right_foot_angle, -direction)
	_solve_leg(pose, layout, "thigh_l", "shin_l", "foot_l", left_target, left_foot_angle, direction)
	return pose


static func _rest_pose(layout: Dictionary) -> Dictionary:
	var pose: Dictionary = {}
	var joints: Dictionary = layout.get("joints", {})
	for joint_name in joints:
		var name := String(joint_name)
		pose[name] = {"rotation": 0.0, "position": _local_position(layout, name)}
	return pose


static func _joint_position(layout: Dictionary, name: String) -> Vector2:
	var joints: Dictionary = layout.get("joints", {})
	var definition: Dictionary = joints.get(name, {})
	var value: Variant = definition.get("position", Vector2.ZERO)
	if value is Vector2:
		return value
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO


static func _parent_name(layout: Dictionary, name: String) -> String:
	var joints: Dictionary = layout.get("joints", {})
	var definition: Dictionary = joints.get(name, {})
	var value: Variant = definition.get("parent", "")
	return "" if value == null else String(value)


static func _local_position(layout: Dictionary, name: String) -> Vector2:
	var parent := _parent_name(layout, name)
	return _joint_position(layout, name) - _joint_position(layout, parent)


static func _offset(pose: Dictionary, name: String, amount: Vector2) -> void:
	if pose.has(name):
		var entry: Dictionary = pose[name]
		var original: Vector2 = entry["position"]
		entry["position"] = original + amount


static func _rotate(pose: Dictionary, name: String, angle: float) -> void:
	if pose.has(name):
		pose[name]["rotation"] = angle


static func _world_transform(pose: Dictionary, layout: Dictionary, name: String) -> Transform2D:
	if not pose.has(name):
		return Transform2D.IDENTITY
	var entry: Dictionary = pose[name]
	var local := Transform2D(float(entry["rotation"]), Vector2(entry["position"]))
	return _world_transform(pose, layout, _parent_name(layout, name)) * local


static func _solve_leg(pose: Dictionary, layout: Dictionary, upper: String, lower: String,
		foot: String, target: Vector2, foot_angle: float, fallback_bend: float) -> void:
	if not pose.has(upper) or not pose.has(lower) or not pose.has(foot):
		return
	var rest_start := _joint_position(layout, upper)
	var rest_knee := _joint_position(layout, lower)
	var rest_end := _joint_position(layout, foot)
	var first := rest_knee - rest_start
	var second := rest_end - rest_knee
	var first_length := first.length()
	var second_length := second.length()
	if first_length < 0.001 or second_length < 0.001:
		return
	var start := _world_transform(pose, layout, upper).origin
	var parent_angle := _world_transform(pose, layout, _parent_name(layout, upper)).get_rotation()
	var toward := target - start
	if toward.length_squared() < 0.000001:
		return
	var reach := clampf(toward.length(), absf(first_length - second_length) + 0.00001,
		first_length + second_length - 0.00001)
	var bend_cross := (rest_end - rest_start).cross(rest_knee - rest_start)
	var bend: float = signf(bend_cross) if absf(bend_cross) > 0.00001 else fallback_bend
	var cosine := clampf((first_length * first_length + reach * reach - second_length * second_length)
		/ (2.0 * first_length * reach), -1.0, 1.0)
	var first_angle := toward.angle() + bend * acos(cosine)
	var knee := start + Vector2.from_angle(first_angle) * first_length
	var reached_target := start + toward.normalized() * reach
	var upper_global := first_angle - first.angle()
	var lower_global := (reached_target - knee).angle() - second.angle()
	_rotate(pose, upper, wrapf(upper_global - parent_angle, -PI, PI))
	_rotate(pose, lower, wrapf(lower_global - upper_global, -PI, PI))
	_rotate(pose, foot, wrapf(foot_angle - lower_global, -PI, PI))


static func _in_place_step(phase: float, direction: float) -> Vector3:
	# A 55% contact interval plus a short lifted return produces an in-place
	# step, with no translation of the planted foot along the painted floor.
	if phase <= 0.55:
		return Vector3.ZERO
	var u := _ease((phase - 0.55) / 0.45)
	var travel := 4.5 * sin(TAU * u)
	var lift := 6.5 * sin(PI * u)
	return Vector3(direction * travel, -0.35 * direction * travel - lift,
		direction * 0.045 * sin(TAU * u))


static func _ease(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


static func _pulse(t: float, start: float, peak: float, finish: float) -> float:
	if t <= start or t >= finish:
		return 0.0
	if t < peak:
		return _ease((t - start) / (peak - start))
	return 1.0 - _ease((t - peak) / (finish - peak))


static func _hold(t: float, start: float, full: float, release: float, finish: float) -> float:
	if t <= start or t >= finish:
		return 0.0
	return _ease((t - start) / (full - start)) * (1.0 - _ease((t - release) / (finish - release)))
