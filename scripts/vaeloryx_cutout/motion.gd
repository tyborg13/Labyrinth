extends RefCounted

## Vaeloryx's serpentine hover and wing-driven wind gestures. Positions retain
## the 255px source registration; world travel belongs to the resolved path.
const IDLE_SECONDS: float = 2.0
const WALK_SECONDS: float = 0.8
const IDLE_BOB: float = 2.4
const CONTACT: float = 0.42

static func sample_pose(clip: String, phase: float, layout: Dictionary, facing: String) -> Dictionary:
	var pose: Dictionary = {}
	for name: String in layout["joints"]:
		var parent: Variant = layout["joints"][name].get("parent")
		var local_point: Vector2 = _point(layout, name)
		if parent != null:
			local_point -= _point(layout, str(parent))
		pose[name] = {"position": local_point, "rotation": 0.0, "scale": Vector2.ONE, "skew": 0.0}
	var t: float = clampf(phase, 0.0, 1.0)
	var rear: bool = facing == "rear"
	var forward: Vector2 = Vector2(1.0, -0.5) if rear else Vector2(-1.0, 0.5)
	var side: float = -1.0 if rear else 1.0
	if clip == "idle":
		# One translation moves every surface together. No idle rotations,
		# scales, skew or independent membrane oscillations.
		pose["root"]["position"] += Vector2(0.0, -IDLE_BOB * (0.5 - 0.5 * cos(TAU * t)))
		return pose
	if clip == "walk":
		# One deliberate wing beat accompanies 96:48 source pixels of travel.
		# Claws tuck together; this hovering creature has no planted-foot gait.
		var beat: float = sin(TAU * t)
		var lift: float = 0.5 - 0.5 * cos(TAU * t)
		pose["root"]["position"] += Vector2(0.0, -4.0 * lift)
		pose["wing_far"]["rotation"] = 0.12 * beat
		pose["wing_near"]["rotation"] = -0.14 * beat
		pose["arm_far"]["rotation"] = -side * 0.07 * lift
		pose["arm_near"]["rotation"] = -side * 0.10 * lift
		pose["hind_limb"]["rotation"] = side * 0.06 * lift
		pose["tail_base"]["rotation"] = side * 0.025 * beat
		pose["tail_mid"]["rotation"] = -side * 0.035 * beat
		return pose
	# The runtime maps authored 42% contact/release onto the effect's existing
	# result boundary. Presentation never applies combat results.
	var prepare: float = _curve(t, PackedVector2Array([Vector2(0, 0), Vector2(0.28, 1), Vector2(0.34, 1), Vector2(CONTACT, 0), Vector2(1, 0)]))
	var release: float = _curve(t, PackedVector2Array([Vector2(0, 0), Vector2(0.34, 0), Vector2(CONTACT, 1), Vector2(0.55, 1), Vector2(1, 0)]))
	match clip:
		"dive":
			pose["root"]["position"] += -forward * 5.0 * prepare + forward * 13.0 * release + Vector2(0, -9.0 * prepare + 3.0 * release)
			pose["body"]["rotation"] = side * (-0.035 * prepare + 0.055 * release)
			pose["wing_far"]["rotation"] = -0.10 * prepare + 0.21 * release
			pose["wing_near"]["rotation"] = 0.12 * prepare - 0.22 * release
			pose["arm_near"]["rotation"] = side * (-0.22 * prepare + 0.46 * release)
			pose["arm_far"]["rotation"] = side * (-0.14 * prepare + 0.26 * release)
			pose["claw_near"]["rotation"] = -side * 0.10 * release
			pose["claw_far"]["rotation"] = -side * 0.06 * release
			pose["neck"]["rotation"] = side * 0.035 * release
			pose["head"]["rotation"] = side * 0.04 * release
			pose["tail_base"]["rotation"] = -side * 0.045 * release
			pose["tail_mid"]["rotation"] = side * 0.06 * release
		"gale":
			# Gather inward, then throw both wings outward with a head thrust.
			pose["root"]["position"] += -forward * 3.0 * prepare + forward * 5.0 * release + Vector2(0, -4.0 * prepare)
			pose["wing_far"]["rotation"] = -0.13 * prepare + 0.18 * release
			pose["wing_near"]["rotation"] = 0.16 * prepare - 0.20 * release
			pose["neck"]["rotation"] = -side * 0.045 * prepare + side * 0.06 * release
			pose["head"]["rotation"] = side * 0.045 * release
			pose["arm_near"]["rotation"] = side * 0.13 * release
			pose["arm_far"]["rotation"] = side * 0.09 * release
			pose["tail_base"]["rotation"] = -side * 0.035 * release
		"pull":
			# Open the wings to gather a broad current, then scoop it inward.
			pose["root"]["position"] += forward * 3.0 * prepare - forward * 5.0 * release + Vector2(0, -3.0 * release)
			pose["wing_far"]["rotation"] = 0.17 * prepare - 0.14 * release
			pose["wing_near"]["rotation"] = -0.20 * prepare + 0.17 * release
			pose["neck"]["rotation"] = side * 0.035 * prepare - side * 0.055 * release
			pose["head"]["rotation"] = -side * 0.04 * release
			pose["arm_near"]["rotation"] = side * (0.12 * prepare - 0.19 * release)
			pose["arm_far"]["rotation"] = side * (0.08 * prepare - 0.12 * release)
			pose["tail_mid"]["rotation"] = side * 0.035 * release
		"guard":
			var settle: float = _curve(t, PackedVector2Array([Vector2(0, 0), Vector2(0.30, 1), Vector2(0.65, 1), Vector2(1, 0)]))
			pose["root"]["position"] += Vector2(0, -3.0 * settle)
			pose["wing_far"]["rotation"] = -0.09 * settle
			pose["wing_near"]["rotation"] = 0.11 * settle
			pose["arm_far"]["rotation"] = -side * 0.08 * settle
			pose["arm_near"]["rotation"] = -side * 0.12 * settle
	return pose

static func walk_cycle_info(_layout: Dictionary, facing: String) -> Dictionary:
	var travel: Vector2 = Vector2(96, -48) if facing == "rear" else Vector2(-96, 48)
	return {"direction": travel.normalized(), "travel_per_cycle": travel, "contact_model": "hover", "hover_lift_px": 4.0}

static func _point(layout: Dictionary, name: String) -> Vector2:
	var p: Array = layout["joints"][name]["position"]
	return Vector2(float(p[0]), float(p[1]))

static func _curve(t: float, keys: PackedVector2Array) -> float:
	for index: int in range(1, keys.size()):
		if t <= keys[index].x:
			var u: float = inverse_lerp(keys[index - 1].x, keys[index].x, t)
			return lerpf(keys[index - 1].y, keys[index].y, u * u * (3.0 - 2.0 * u))
	return keys[-1].y
