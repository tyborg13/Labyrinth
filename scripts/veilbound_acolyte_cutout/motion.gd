extends RefCounted

## Grounded, robe-concealed caster. Hands and orb remain rigid; no mace poses.
const STANCE: float = 0.60
const STRIDE: float = 48.0
const CAST_RELEASE: float = 0.18
const MELEE_CONTACT: float = 0.42

static func sample_pose(clip: String, phase: float, layout: Dictionary, facing: String) -> Dictionary:
	var pose: Dictionary = {}
	for name: String in layout["joints"]:
		pose[name] = {"position": _point(layout, name) - _point(layout, _parent(layout, name)),
			"rotation": 0.0, "scale": Vector2.ONE, "skew": 0.0}
	var t: float = clampf(phase, 0.0, 1.0)
	var direction: Vector2 = Vector2(1, -0.5) if facing == "rear" else Vector2(-1, 0.5)
	if clip == "idle":
		# One coordinated translation. The concealed supports stay fixed and
		# the lower robe settles smoothly into them, without local ripple.
		pose["torso"]["position"] += Vector2(0, -1.2 * (0.5 - 0.5 * cos(TAU * t)))
	elif clip == "walk":
		pose["torso"]["position"] += Vector2(0.8 * sin(TAU * t), -1.8 * pow(sin(TAU * t), 2))
		for side: String in ["l", "r"]:
			var name: String = "support_" + side
			var state: Dictionary = walk_foot_state(t, name, layout, facing)
			pose[name]["position"] = Vector2(state["target"]) - _point(layout, "root")
		pose["cast_arm"]["position"] += direction * (1.2 * sin(TAU * t))
		pose["strike_arm"]["position"] -= direction * (1.2 * sin(TAU * t))
	elif clip == "cast":
		var prepare: float = _curve(t, PackedVector2Array([Vector2(0,0),Vector2(0.11,1),Vector2(CAST_RELEASE,0),Vector2(1,0)]))
		var release: float = _curve(t, PackedVector2Array([Vector2(0,0),Vector2(0.11,0),Vector2(CAST_RELEASE,1),Vector2(0.32,1),Vector2(0.82,0),Vector2(1,0)]))
		pose["torso"]["position"] += direction * (-1.0 * prepare + 1.4 * release)
		pose["cast_arm"]["position"] += direction * (-3.0 * prepare + 7.0 * release)
		pose["cast_hand"]["position"] += direction * (-2.0 * prepare + 5.0 * release)
		# The orb is a catalyst: the shadow projectile releases from it. It
		# stays with the palm; the original ember paint is not recolored.
		pose["orb"]["position"] += Vector2(0, -2.0 * prepare)
	elif clip == "attack":
		var prepare: float = _curve(t, PackedVector2Array([Vector2(0,0),Vector2(0.28,1),Vector2(0.34,1),Vector2(MELEE_CONTACT,0),Vector2(1,0)]))
		var contact: float = _curve(t, PackedVector2Array([Vector2(0,0),Vector2(0.34,0),Vector2(MELEE_CONTACT,1),Vector2(0.52,1),Vector2(0.92,0),Vector2(1,0)]))
		pose["torso"]["position"] += direction * (-1.2 * prepare + 2.0 * contact)
		# The free skeletal hand gives a short claw thrust. Rear paint hides
		# that hand, so its occupied sleeve makes the same restrained cue.
		pose["strike_arm"]["position"] += direction * (-3.0 * prepare + 8.0 * contact)
		pose["strike_hand"]["position"] += direction * (-2.0 * prepare + 8.0 * contact)
	return pose

static func walk_cycle_info(_layout: Dictionary, facing: String) -> Dictionary:
	var direction: Vector2 = (Vector2(1, -0.5) if facing == "rear" else Vector2(-1, 0.5)).normalized()
	return {"direction": direction, "stride_px": STRIDE, "stance_fraction": STANCE,
		"travel_per_cycle": direction * STRIDE / STANCE, "foot_lift_px": 3.0}

static func walk_foot_state(phase: float, foot: String, layout: Dictionary, facing: String) -> Dictionary:
	var info: Dictionary = walk_cycle_info(layout, facing)
	var t: float = fposmod(phase + (0.5 if foot == "support_l" else 0.0), 1.0)
	var contact: bool = t <= STANCE
	var distance: float = STRIDE * (0.5 - t / STANCE)
	var lift: float = 0.0
	if not contact:
		var u: float = (t - STANCE) / (1.0 - STANCE)
		var tangent: float = -STRIDE * (1.0 - STANCE) / STANCE
		distance = lerpf(-STRIDE * 0.5, STRIDE * 0.5, u*u*(3.0-2.0*u)) + tangent*(2.0*u*u*u-3.0*u*u+u)
		lift = 3.0 * pow(sin(PI*u), 1.5)
	var target: Vector2 = _point(layout, foot) + Vector2(info["direction"]) * distance - Vector2(0,lift)
	return {"target": target, "ground_contact": target + Vector2(0,lift), "contact": contact, "cycle_phase": t, "lift_px": lift}

static func _curve(t: float, keys: PackedVector2Array) -> float:
	for index: int in range(1, keys.size()):
		if t <= keys[index].x:
			var u: float = inverse_lerp(keys[index-1].x, keys[index].x, t)
			return lerpf(keys[index-1].y, keys[index].y, smoothstep(0.0,1.0,u))
	return keys[-1].y

static func _parent(layout: Dictionary, name: String) -> String:
	var value: Variant = layout["joints"][name].get("parent")
	return "" if value == null else str(value)

static func _point(layout: Dictionary, name: String) -> Vector2:
	if name.is_empty():
		return Vector2.ZERO
	var value: Array = layout["joints"][name]["position"]
	return Vector2(float(value[0]), float(value[1]))

static func _world(pose: Dictionary, layout: Dictionary, name: String) -> Transform2D:
	if name.is_empty():
		return Transform2D.IDENTITY
	var value: Dictionary = pose[name]
	var local := Transform2D(float(value.get("rotation",0.0)), value.get("scale",Vector2.ONE), float(value.get("skew",0.0)), value["position"])
	return _world(pose, layout, _parent(layout,name)) * local
