extends RefCounted
## Full-pass weapon poses. The base sampler is supplied by motion.gd so these
## additions reuse its painted-length IK without a circular preload or rules data.

static func sample_pose(clip: String, phase: float, layout: Dictionary, facing: String,
		base: Script) -> Dictionary:
	match clip:
		"attack_thrust": return _thrust(phase, layout, facing, base)
		"attack_lash": return _lash(phase, layout, facing, base)
		_: return _shoot(clip, phase, layout, facing, base)

static func _thrust(phase: float, layout: Dictionary, facing: String, base: Script) -> Dictionary:
	var pose: Dictionary = base._rest_pose(layout)
	pose["crossbow_r"]["visible"] = false
	var t: float = clampf(phase, 0.0, 1.0)
	if is_zero_approx(t) or is_equal_approx(t, 1.0):
		return base._carry_pose(pose, "attack_thrust", t, layout)
	var rear: bool = facing == "rear"
	var direction: float = -1.0 if rear else 1.0
	var line: Vector2 = (Vector2(0.894, -0.447) if rear else Vector2(-0.894, 0.447)).normalized()
	var rest: Vector2 = base._joint_position(layout, "hand_r")
	var rest_angle: float = base._gear_axis(layout).angle()
	var upright_angle: float = rest_angle + (0.0 if rear else TAU)
	# Lower at the hip, withdraw 8px, then drive 26px from that cock.
	var lowered := Vector2(158, 128) if rear else Vector2(100, 130)
	var cock: Vector2 = lowered - line * 8.0
	var contact: Vector2 = cock + line * 26.0
	var keys: Array = [
		base._gear_key(0.00, rest, upright_angle, 0.0, 0.0, 0.0),
		base._gear_key(0.20, lowered, line.angle(), 0.0, 0.0, 0.0),
		base._gear_key(0.30, cock, line.angle(), direction * 0.06, 1.0, direction * 2.0),
		base._gear_key(0.42, contact, line.angle(), -direction * 0.10, 0.0, 0.0),
		base._gear_key(0.56, contact, line.angle(), -direction * 0.10, 0.0, 0.0),
		base._gear_key(0.62, contact, line.angle(), -direction * 0.08, 0.0, 0.0),
		base._gear_key(0.78, lowered, line.angle(), 0.0, 0.0, 0.0),
		base._gear_key(1.00, rest, upright_angle, 0.0, 0.0, 0.0)]
	var key: Dictionary = base._gear_keys(t, keys)
	base._offset(pose, "root", Vector2(float(key["root_x"]), 0.0)
		+ line * 10.0 * base._hold(t, 0.30, 0.42, 0.56, 0.90))
	base._offset(pose, "hips", Vector2(0, float(key["hips_y"])))
	base._rotate(pose, "torso", float(key["torso"]))
	base._stab_step_feet(pose, layout, line, direction, t)
	base._solve_leg(pose, layout, "arm_r", "forearm_r", "hand_r", key["wrist"], 0.0, direction)
	base._rotate(pose, "forearm_l", -direction * 0.10 * base._hold(t, 0.30, 0.42, 0.56, 0.80))
	base._gear_place_weapon(pose, layout, float(key["angle"]) - rest_angle)
	return base._carry_pose(pose, "attack_thrust", t, layout)

static func _lash(phase: float, layout: Dictionary, facing: String, base: Script) -> Dictionary:
	var pose: Dictionary = base._rest_pose(layout)
	pose["crossbow_r"]["visible"] = false
	var t: float = clampf(phase, 0.0, 1.0)
	if is_zero_approx(t) or t >= 0.90:
		return pose
	var rear: bool = facing == "rear"
	var direction: float = -1.0 if rear else 1.0
	var rest: Vector2 = base._joint_position(layout, "hand_r")
	var shoulder: Vector2 = base._joint_position(layout, "arm_r")
	var rest_angle: float = base._gear_axis(layout).angle()
	var overhead: Vector2 = Vector2(0.30, -0.95) if rear else Vector2(-0.30, -0.95)
	var line: Vector2 = Vector2(0.894, -0.447) if rear else Vector2(-0.894, 0.447)
	var apex_angle: float = overhead.angle() + (0.0 if rear else TAU)
	var keys: Array = [
		base._gear_key(0.00, rest, rest_angle, 0.0, 0.0, 0.0),
		base._gear_key(0.30, shoulder + Vector2(direction * 6.0, -20), apex_angle, direction * 0.06, 0.0, direction),
		base._gear_key(0.42, shoulder + Vector2(-direction * 26.0, 0), line.angle(), -direction * 0.08, 2.0, -direction * 2.0),
		base._gear_key(0.58, shoulder + Vector2(-direction * 22.0, 31), Vector2(-direction * 0.60, 0.80).angle(), -direction * 0.04, 1.0, -direction),
		base._gear_key(0.90, rest, rest_angle, 0.0, 0.0, 0.0)]
	var key: Dictionary = base._gear_keys(t, keys)
	base._offset(pose, "root", Vector2(float(key["root_x"]), 0))
	base._offset(pose, "hips", Vector2(0, float(key["hips_y"])))
	base._rotate(pose, "torso", float(key["torso"]))
	base._gear_planted_feet(pose, layout, direction)
	base._solve_leg(pose, layout, "arm_r", "forearm_r", "hand_r", key["wrist"], 0.0, direction)
	base._gear_place_weapon(pose, layout, float(key["angle"]) - rest_angle)
	return pose

static func aim_for_facing(facing: String) -> Vector2:
	return (Vector2(1, -0.3) if facing == "rear" else Vector2(-1, -0.2)).normalized()

static func _shoot(clip: String, phase: float, layout: Dictionary, facing: String,
		base: Script) -> Dictionary:
	var pose: Dictionary = base.sample_pose("shoot", phase, layout, facing)
	pose["crossbow_r"]["visible"] = false
	pose["weapon_r"]["visible"] = true
	var t: float = clampf(phase, 0.0, 1.0)
	if is_zero_approx(t) or is_equal_approx(t, 1.0):
		return pose
	var rear: bool = facing == "rear"
	var aim: Vector2 = aim_for_facing(facing)
	var raised: float = base._hold(t, 0.0, 0.24, 0.62, 1.0)
	var rest_angle: float = base._gear_axis(layout).angle()
	var weapon_angle: float = aim.angle()
	if clip == "shoot_bow":
		# Owner review: one-arm aim uses the crossbow solve unchanged. The
		# short painted arms cannot support a two-hand draw at arm's length.
		# Only the bow's attitude changes; the offhand stays at rest.
		var upright := Vector2(aim.y, -aim.x) if rear else Vector2(-aim.y, aim.x)
		weapon_angle = upright.angle()
	# Keep the upright rest axis from each weapon's own landmarks. Repeater
	# aims its muzzle forward; the bow's upper limb is perpendicular to aim.
	var angle: float = lerp_angle(rest_angle, weapon_angle, raised) - rest_angle
	base._gear_place_weapon(pose, layout, angle)
	return pose
