extends RefCounted
## Landmark-driven pole/bow grip, independent of equipment rules and art paths.

static func apply(pose: Dictionary, clip: String, phase: float, layout: Dictionary,
		base: Script) -> Dictionary:
	var carry: Dictionary = layout.get("weapon_carry", {})
	if carry.is_empty():
		return pose
	var weight: float = 1.0
	if clip == "attack_thrust" and carry["motion"] == "thrust":
		weight -= base._hold(clampf(phase, 0.0, 1.0), 0.0, 0.20, 0.78, 1.0)
	elif clip == "shoot_bow" and carry["motion"] == "bow":
		weight -= base._hold(clampf(phase, 0.0, 1.0), 0.0, 0.24, 0.62, 1.0)
	elif clip not in ["rest", "idle", "walk", "block", "block_shield", "hit", "death"]:
		return pose
	if is_zero_approx(weight):
		return pose
	var delta: float = wrapf(base._gear_axis(layout).angle() - (carry["sword_axis"] as Vector2).angle(), -PI, PI) * weight
	var weapon_angle: float = base._world_transform(pose, layout, "weapon_r").get_rotation()
	var hand_angle: float = float(pose["hand_r"]["rotation"])
	pose["hand_r"]["rotation"] = delta
	base._separate_grip(pose)
	pose["hand_r"]["rotation"] += hand_angle
	# The replacement paint already has the landmark-defined rest axis. Split
	# the carry turn 15/85 like the sword, then compensate that painted basis
	# rather than turning the pole twice. Re-register at the rotated fist so
	# arbitrary authored grip offsets stay attached through gait and reactions.
	base._gear_place_weapon(pose, layout, weapon_angle)
	return pose
