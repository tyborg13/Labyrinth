extends RefCounted
## Projected walking and staged actions for an articulated painted Bone2D rig.
## Input joint positions are GLOBAL source-image pixels; returned positions are
## LOCAL to the joint's parent. Rotations are offsets from identity-basis rests.
## Each call returns a complete pose, so seeking and changing clips cannot leave
## transforms behind. Rear motion changes direction without mirroring textures.
## Walk contact/down/passing/up timing, linear support-foot travel and delayed
## arm/cloth overlap follow Jason Martinsen's Animation Mentor demonstration:
## https://www.animationmentor.com/blog/tutorial-animating-human-walk-cycle/
## Ground-plane direction is inferred from the two painted three-quarter views.

const WALK_STANCE_FRACTION: float = 0.60
static var _boot_geometry: Dictionary = {}


static func clip_specs() -> Dictionary:
	return {
		"idle": {"frames": 20, "fps": 24, "loop": true, "duration": 20.0 / 24.0},
		"walk": {"frames": 24, "fps": 36, "loop": true, "duration": 2.0 / 3.0},
		"attack": {"frames": 32, "fps": 24, "loop": false, "duration": 32.0 / 24.0},
		"block": {"frames": 36, "fps": 24, "loop": false, "duration": 1.5},
		"hit": {"frames": 24, "fps": 24, "loop": false, "duration": 1.0},
	}


static func sample_pose(clip: String, phase: float, layout: Dictionary, facing: String) -> Dictionary:
	var pose := _rest_pose(layout)
	var specs := clip_specs()
	if not specs.has(clip):
		return _separate_grip(pose)
	var looped: bool = bool(specs[clip]["loop"])
	var t: float = fposmod(phase, 1.0) if looped else clampf(phase, 0.0, 1.0)
	# A walking loop starts at contact, not neutral. Neutral remains an explicit
	# exact-source pose; one-shot actions and idle also return to that pose.
	if clip != "walk" and (is_zero_approx(t) or is_equal_approx(t, 1.0)):
		return _separate_grip(pose)
	var direction: float = -1.0 if facing.to_lower().contains("rear") or facing.to_lower() == "back" else 1.0
	var right_target := _joint_position(layout, "foot_r")
	var left_target := _joint_position(layout, "foot_l")
	var right_foot_angle := 0.0
	var left_foot_angle := 0.0

	match clip:
		"idle":
			# The original eight-frame sheet lifts chest, face and free hand
			# together by ~1 source pixel at 10 fps. Twenty frames at 24 fps
			# retain its ~0.8 s cadence. The hips and upper body translate together;
			# counter-translation at the thighs leaves the painted legs unchanged.
			# Solving this small bob as fixed-length leg IK buckled the knees inward.
			var bob: float = _curve(t, PackedVector2Array([
				Vector2(0.0, 0.0), Vector2(0.14, 1.5), Vector2(0.62, 1.5),
				Vector2(0.91, 0.0), Vector2(1.0, 0.0)]))
			var sword_bob: float = _curve(t, PackedVector2Array([
				Vector2(0.0, 0.0), Vector2(0.12, 0.0), Vector2(0.26, 1.5),
				Vector2(0.61, 1.5), Vector2(0.83, 0.0), Vector2(1.0, 0.0)]))
			_offset(pose, "hips", Vector2(0.0, bob))
			_offset(pose, "thigh_r", Vector2(0.0, -bob))
			_offset(pose, "thigh_l", Vector2(0.0, -bob))
			_offset(pose, "arm_r", Vector2(0.0, sword_bob - bob))
			# Cloth travels with the chest. Subpixel overlap is secondary to the
			# body bob, rather than a chain of opposing surface ripples.
			var overlap: float = sin(TAU * t) * bob / 1.5
			_rotate(pose, "cape_mid", direction * 0.002 * overlap)
			_rotate(pose, "cape_tip", direction * 0.003 * overlap)
		"walk":
			var info := walk_cycle_info(layout, facing)
			var scale_factor: float = float(info["stride_px"]) / 30.0
			var transfer: float = sin(TAU * t)
			var step_phase: float = fposmod(t * 2.0, 1.0)
			# Contact, down, passing, up, contact. The down arrives quickly after
			# impact; the rise lasts longer while the support leg straightens.
			var settle: float = _curve(step_phase, PackedVector2Array([
				Vector2(0.0, 3.0), Vector2(0.16, 5.5), Vector2(0.50, 1.0),
				Vector2(0.80, 0.5), Vector2(1.0, 3.0)]))
			var foot_separation: Vector2 = _joint_position(layout, "foot_r") - _joint_position(layout, "foot_l")
			var support_side: float = signf(foot_separation.x)
			_offset(pose, "hips", Vector2(support_side * 2.2 * transfer, settle) * scale_factor)
			_rotate(pose, "hips", -support_side * 0.020 * transfer)
			_rotate(pose, "torso", support_side * 0.034 * transfer)
			_rotate(pose, "neck", -support_side * 0.010 * sin(TAU * t - 0.16))
			_rotate(pose, "head", -support_side * 0.010 * sin(TAU * t - 0.30))
			# Opposite arm leads the forward leg. Forearm and wrist trail the
			# shoulder, instead of all three joints reaching extremes together.
			var arm_swing: float = cos(TAU * t - 0.16)
			var elbow_swing: float = cos(TAU * t - 0.40)
			_rotate(pose, "arm_r", -direction * 0.25 * arm_swing)
			_rotate(pose, "forearm_r", direction * (0.09 * elbow_swing - 0.05))
			_rotate(pose, "hand_r", direction * 0.035 * cos(TAU * t - 0.64))
			_rotate(pose, "arm_l", direction * 0.30 * arm_swing)
			_rotate(pose, "forearm_l", -direction * (0.12 * elbow_swing + 0.06))
			var right_step := walk_foot_state(t, "foot_r", layout, facing)
			var left_step := walk_foot_state(t, "foot_l", layout, facing)
			right_target = right_step["target"]
			left_target = left_step["target"]
			right_foot_angle = float(right_step["angle"])
			left_foot_angle = float(left_step["angle"])
			_rotate(pose, "cape_root", -direction * 0.028 * sin(TAU * t - 0.18))
			_rotate(pose, "cape_mid", -direction * 0.043 * sin(TAU * t - 0.55))
			_rotate(pose, "cape_tip", -direction * 0.060 * sin(TAU * t - 0.92))
			_fit_walk_pelvis(pose, layout, right_target, left_target)
		"attack":
			# Read the two painted sword orientations independently: front starts
			# down-left; rear starts down-right. Their lifts and cuts need opposite
			# signs and different amplitudes, not a mirrored upward wrist flick.
			# Nine-frame anticipation, a fast three-to-four-frame cut and follow-through,
			# then a substantially slower recovery into the exact source stance.
			var prepare: float = _hold(t, 0.0, 0.22, 0.27, 0.40)
			var drive: float = _hold(t, 0.26, 0.38, 0.49, 0.94)
			var strike: float = _hold(t, 0.28, 0.41, 0.54, 0.96)
			var cloth_follow: float = _pulse(t, 0.36, 0.59, 1.0)
			_offset(pose, "root", Vector2(direction * (1.0 * prepare - 3.2 * drive), 0.0))
			_offset(pose, "hips", Vector2(0.0, 0.9 * prepare + 2.4 * drive))
			_rotate(pose, "hips", direction * (0.012 * prepare - 0.018 * drive))
			_rotate(pose, "torso", direction * (0.035 * prepare - 0.070 * drive))
			_rotate(pose, "neck", direction * (-0.014 * prepare + 0.024 * strike))
			_rotate(pose, "head", direction * (-0.012 * prepare + 0.018 * strike))
			# Near-vertical overhead blade, then a cut through the space ahead at
			# body height. Separate follow-through lowers the blade while it stays
			# extended in front, rather than flicking the tip down beside the boots.
			var arm_curve := _curve(t, PackedVector2Array([
				Vector2(0.0, 0.0), Vector2(0.27, 1.0), Vector2(0.31, 1.0),
				Vector2(0.41, 0.0), Vector2(1.0, 0.0)]))
			var cut_hold := _hold(t, 0.31, 0.41, 0.54, 0.96)
			var follow_hold := _hold(t, 0.44, 0.58, 0.66, 0.98)
			if direction > 0.0:
				_rotate(pose, "arm_r", 1.30 * arm_curve + 0.60 * cut_hold - 0.15 * follow_hold)
				_rotate(pose, "forearm_r", 0.65 * arm_curve + 0.20 * cut_hold - 0.20 * follow_hold)
				_rotate(pose, "hand_r", 0.25 * arm_curve - 0.10 * cut_hold + 0.05 * follow_hold)
			else:
				_rotate(pose, "arm_r", -1.35 * arm_curve - 0.60 * cut_hold + 0.15 * follow_hold)
				_rotate(pose, "forearm_r", -0.75 * arm_curve + 0.35 * cut_hold - 0.10 * follow_hold)
				_rotate(pose, "hand_r", -0.18 * arm_curve - 0.53 * cut_hold + 0.16 * follow_hold)
			_rotate(pose, "arm_l", direction * (0.10 * prepare - 0.17 * strike))
			_rotate(pose, "forearm_l", direction * (0.12 * prepare - 0.20 * strike))
			_rotate(pose, "cape_root", direction * (0.015 * prepare + 0.025 * drive))
			_rotate(pose, "cape_mid", direction * (0.025 * strike - 0.038 * cloth_follow))
			_rotate(pose, "cape_tip", direction * (0.020 * strike - 0.060 * cloth_follow))
		"block":
			var guard: float = _hold(t, 0.0, 0.21, 0.64, 1.0)
			var blade_guard: float = _hold(t, 0.025, 0.25, 0.69, 1.0)
			var catch: float = _pulse(t, 0.33, 0.39, 0.59)
			var head_catch: float = _pulse(t, 0.37, 0.45, 0.67)
			_offset(pose, "root", Vector2(direction * (-1.5 * guard + 2.8 * catch), 0.0))
			_offset(pose, "hips", Vector2(0.0, 2.2 * guard + 1.6 * catch))
			_rotate(pose, "torso", direction * (-0.035 * guard + 0.065 * catch))
			_rotate(pose, "neck", -direction * 0.024 * head_catch)
			_rotate(pose, "head", direction * (0.017 * guard - 0.028 * head_catch))
			# The raised diagonal crosses the upper body instead of standing out
			# beside it. The rear uses its own elbow route for the painted view.
			if direction > 0.0:
				_rotate(pose, "arm_r", -0.70 * guard + 0.07 * catch)
				_rotate(pose, "forearm_r", -1.40 * guard + 0.10 * catch)
				_rotate(pose, "hand_r", -1.13 * guard + 0.035 * catch)
			else:
				_rotate(pose, "arm_r", -0.65 * guard + 0.06 * catch)
				_rotate(pose, "forearm_r", -1.50 * guard + 0.10 * catch)
				_rotate(pose, "hand_r", -0.90 * blade_guard + 0.035 * catch)
			_rotate(pose, "arm_l", direction * 0.17 * guard)
			_rotate(pose, "forearm_l", direction * 0.29 * guard)
			_rotate(pose, "cape_root", direction * 0.024 * catch)
			_rotate(pose, "cape_mid", direction * 0.045 * head_catch)
			_rotate(pose, "cape_tip", direction * 0.070 * _pulse(t, 0.40, 0.53, 0.82))
		"hit":
			var recoil: float = _pulse(t, 0.0, 0.10, 0.66)
			var head_recoil: float = _pulse(t, 0.025, 0.18, 0.73)
			var arm_drag: float = _pulse(t, 0.055, 0.23, 0.79)
			var recover: float = _pulse(t, 0.39, 0.68, 1.0)
			_offset(pose, "root", Vector2(direction * (4.7 * recoil - 0.7 * recover), 0.0))
			_offset(pose, "hips", Vector2(0.0, 2.9 * recoil + 0.6 * recover))
			_rotate(pose, "hips", direction * (0.026 * recoil - 0.012 * recover))
			_rotate(pose, "torso", direction * (0.11 * recoil - 0.035 * recover))
			_rotate(pose, "neck", -direction * 0.055 * head_recoil)
			_rotate(pose, "head", -direction * (0.11 * head_recoil - 0.025 * recover))
			_rotate(pose, "arm_r", direction * 0.19 * arm_drag)
			_rotate(pose, "forearm_r", -direction * 0.26 * arm_drag)
			_rotate(pose, "hand_r", direction * 0.085 * head_recoil)
			_rotate(pose, "arm_l", -direction * 0.17 * arm_drag)
			_rotate(pose, "forearm_l", -direction * 0.21 * arm_drag)
			_rotate(pose, "cape_root", -direction * 0.040 * head_recoil)
			_rotate(pose, "cape_mid", direction * (-0.050 * arm_drag + 0.045 * recover))
			_rotate(pose, "cape_tip", direction * (-0.028 * arm_drag + 0.077 * recover))

	# Idle legs remain source-identical; only the upper body bobs.
	if clip == "idle":
		return _separate_grip(pose)

	# Non-walking feet stay at painted anchors. Walking support feet move
	# opposite the host's root travel and therefore stay fixed in world space.
	# Every non-idle target uses the same two-segment solve and boot counter-rotation.
	# Perspective can put a painted knee less than a pixel either side of a
	# straight leg. That tiny sign must not make a walking knee bend backward.
	var walking_pole: float = direction if clip == "walk" else 0.0
	_solve_leg(pose, layout, "thigh_r", "shin_r", "foot_r", right_target, right_foot_angle, -direction, walking_pole)
	_solve_leg(pose, layout, "thigh_l", "shin_l", "foot_l", left_target, left_foot_angle, direction, walking_pole)
	return _separate_grip(pose)


static func _separate_grip(pose: Dictionary) -> Dictionary:
	# The generated closed fist follows its forearm with modest wrist flex.
	# A separate weapon bone retains the authored blade attitude at the grip.
	if pose.has("weapon_r"):
		var combined: float = float(pose["hand_r"]["rotation"])
		pose["hand_r"]["rotation"] = combined * 0.15
		pose["weapon_r"]["rotation"] = combined * 0.85
	return pose


static func _rest_pose(layout: Dictionary) -> Dictionary:
	var pose: Dictionary = {}
	var joints: Dictionary = layout.get("joints", {})
	for joint_name in joints:
		var name := String(joint_name)
		pose[name] = {"rotation": 0.0, "position": _local_position(layout, name)}
	return _separate_grip(pose)


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
		foot: String, target: Vector2, foot_angle: float, fallback_bend: float, bend_override: float = 0.0) -> void:
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
	if not is_zero_approx(bend_override):
		bend = bend_override
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


static func walk_cycle_info(layout: Dictionary, facing: String) -> Dictionary:
	var shortest_leg: float = minf(_leg_length(layout, "r"), _leg_length(layout, "l"))
	var stride: float = clampf(shortest_leg * 0.73, 24.0, 34.0)
	var rear: bool = facing.to_lower().contains("rear") or facing.to_lower() == "back"
	var projected_direction := Vector2(1.0, -0.28) if rear else Vector2(-1.0, 0.28)
	projected_direction = projected_direction.normalized()
	return {"direction": projected_direction, "stride_px": stride,
		"travel_per_cycle": projected_direction * stride / WALK_STANCE_FRACTION,
		"stance_fraction": WALK_STANCE_FRACTION, "foot_lift_px": shortest_leg * 0.18}


static func walk_foot_state(phase: float, foot_name: String, layout: Dictionary, facing: String) -> Dictionary:
	var info := walk_cycle_info(layout, facing)
	var t: float = fposmod(phase + (0.5 if foot_name == "foot_l" else 0.0), 1.0)
	var stride: float = info["stride_px"]
	var travel: float
	var lift := 0.0
	# Fifth-pass boot artwork already faces into the projected walking lane.
	# Keep its painted sole level in support; only a small swing relaxation is
	# needed. This avoids rotating a front-facing toe cap toward the knee.
	var rear: bool = facing.to_lower().contains("rear") or facing.to_lower() == "back"
	var angle: float = 0.0
	var contact: bool = t <= WALK_STANCE_FRACTION
	if contact:
		# A constant velocity here cancels the host's root translation exactly.
		travel = stride * (0.5 - t / WALK_STANCE_FRACTION)
	else:
		var u: float = (t - WALK_STANCE_FRACTION) / (1.0 - WALK_STANCE_FRACTION)
		# Hermite endpoint tangents match linear stance speed, including wrap.
		# The toe briefly trails after push-off before accelerating past support.
		var tangent: float = -stride * (1.0 - WALK_STANCE_FRACTION) / WALK_STANCE_FRACTION
		travel = lerpf(-stride * 0.5, stride * 0.5, _ease(u)) + tangent * (2.0 * u * u * u - 3.0 * u * u + u)
		lift = float(info["foot_lift_px"]) * pow(sin(PI * u), 1.35)
		angle += (0.14 if rear else -0.14) * sin(PI * u)
	# The source neutral is a wide combat stance. Walking uses narrower lanes
	# under the hips rather than forcing that splayed pose through every step.
	var anchor: Vector2 = _joint_position(layout, foot_name)
	var thigh: Vector2 = _joint_position(layout, foot_name.replace("foot_", "thigh_"))
	anchor.x = lerpf(anchor.x, thigh.x, 0.70)
	var ground: Vector2 = anchor + Vector2(info["direction"]) * travel
	# The actual alpha contour sets both planted depth and airborne clearance.
	# This remains correct while the swing boot relaxes to a different angle.
	var geometry: Dictionary = _painted_boot_geometry(layout, foot_name)
	var depth := -INF
	for point: Vector2 in geometry.outline:
		depth = maxf(depth, point.rotated(angle).y)
	var sole_drop: float = float(geometry.rest_depth) - depth
	return {"target": ground + Vector2(0.0, sole_drop - lift), "ground": ground,
		"angle": angle, "contact": contact, "cycle_phase": t, "lift_px": lift}


static func _painted_boot_geometry(layout: Dictionary, name: String) -> Dictionary:
	for part: Dictionary in layout.parts:
		if String(part.name) != name:
			continue
		var file: String = "res://experiments/protagonist_2d/" + String(part.file)
		if _boot_geometry.has(file):
			return _boot_geometry[file]
		var image := Image.load_from_file(file)
		var points := PackedVector2Array()
		var offset := Vector2(float(part.offset[0]), float(part.offset[1])) - _joint_position(layout, name)
		var rest_depth := -INF
		for y: int in range(image.get_height()):
			for x: int in range(image.get_width()):
				if image.get_pixel(x, y).a > 0.0:
					var point := Vector2(x, y) + offset
					points.append(point)
					rest_depth = maxf(rest_depth, point.y)
		var geometry := {"outline": Geometry2D.convex_hull(points), "rest_depth": rest_depth}
		_boot_geometry[file] = geometry
		return geometry
	return {"outline": PackedVector2Array([Vector2.ZERO]), "rest_depth": 0.0}


static func _leg_length(layout: Dictionary, suffix: String) -> float:
	return _joint_position(layout, "thigh_" + suffix).distance_to(_joint_position(layout, "shin_" + suffix)) \
		+ _joint_position(layout, "shin_" + suffix).distance_to(_joint_position(layout, "foot_" + suffix))


static func _fit_walk_pelvis(pose: Dictionary, layout: Dictionary, right: Vector2, left: Vector2) -> void:
	# Painted perspective gives the far leg a shorter chain. Lower the pelvis
	# only as much as needed to reach the authored footprint without stretching
	# skin or allowing IK clamping to create foot sliding during support.
	var drop := 0.0
	for suffix: String in ["r", "l"]:
		var target: Vector2 = right if suffix == "r" else left
		var start := _world_transform(pose, layout, "thigh_" + suffix).origin
		var reach: float = _leg_length(layout, suffix) - 0.10
		var horizontal: float = target.x - start.x
		var vertical: float = sqrt(maxf(0.01, reach * reach - horizontal * horizontal))
		drop = maxf(drop, target.y - start.y - vertical)
	_offset(pose, "hips", Vector2(0.0, drop))


static func _curve(t: float, keys: PackedVector2Array) -> float:
	for index: int in range(1, keys.size()):
		if t <= keys[index].x:
			var previous: Vector2 = keys[index - 1]
			var next: Vector2 = keys[index]
			return lerpf(previous.y, next.y, _ease((t - previous.x) / (next.x - previous.x)))
	return keys[keys.size() - 1].y


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
