extends RefCounted

## Cinder Ooze: one rigid crusted mass over six soft contact lobes.
## No humanoid joints or independent plate rotations.
const STANCE: float = 0.72
const STRIDE: float = 72.0
const CONTACT_NAMES := ["left_outer", "front_left", "front_mid", "near_right", "right_outer", "far_right"]
const CONTACT_PHASES := [0.0, 0.5, 0.1666666667, 0.6666666667, 0.3333333333, 0.8333333333]

static func sample_pose(clip: String, phase: float, layout: Dictionary, facing: String) -> Dictionary:
	var pose: Dictionary = {}
	for name: String in layout["joints"]:
		pose[name] = {"position": _point(layout, name) - _point(layout, _parent(layout, name)),
			"rotation": 0.0, "scale": Vector2.ONE, "skew": 0.0}
	var t: float = clampf(phase, 0.0, 1.0)
	var mass_shift := Vector2.ZERO
	var direction: Vector2 = walk_cycle_info(layout, facing)["direction"]
	if clip == "idle":
		# One quiet settle; all hard plates share this exact translation.
		mass_shift = Vector2(0, -1.1 * (0.5 - 0.5 * cos(TAU * t)))
	elif clip == "walk":
		mass_shift = Vector2(0, -1.5 * (0.5 - 0.5 * cos(TAU * t)))
	elif clip == "attack":
		# Gather backwards then drive the mass and leading tendrils forward.
		var prep: float = _curve(t, PackedVector2Array([Vector2(0,0),Vector2(0.25,1),Vector2(0.33,1),Vector2(0.42,0),Vector2(1,0)]))
		var hit: float = _curve(t, PackedVector2Array([Vector2(0,0),Vector2(0.33,0),Vector2(0.42,1),Vector2(0.56,0.82),Vector2(1,0)]))
		mass_shift = direction * (-5.0 * prep + 14.0 * hit) + Vector2(0, 2.0 * prep)
	elif clip == "bloom":
		# Keep shell plates rigid through the outward molten release.
		var prep: float = _curve(t, PackedVector2Array([Vector2(0,0),Vector2(0.27,1),Vector2(0.38,0),Vector2(1,0)]))
		var release: float = _curve(t, PackedVector2Array([Vector2(0,0),Vector2(0.29,0),Vector2(0.38,1),Vector2(0.54,0.72),Vector2(1,0)]))
		mass_shift = Vector2(0, 3.0 * prep - 6.0 * release)
	pose["mass"]["position"] += mass_shift
	for index: int in range(CONTACT_NAMES.size()):
		var name: String = CONTACT_NAMES[index]
		var contact: String = "contact_" + name
		var bend: String = "bend_" + name
		var contact_shift := Vector2.ZERO
		if clip == "walk":
			contact_shift = Vector2(walk_foot_state(t, contact, layout, facing)["target"]) - _point(layout, contact)
		elif clip == "attack":
			var thrust: float = _curve(t, PackedVector2Array([Vector2(0,0),Vector2(0.33,0),Vector2(0.42,1),Vector2(0.56,0.75),Vector2(1,0)]))
			var leading: bool = index < 3 if facing == "front" else index >= 4
			if leading:
				contact_shift = direction * (16.0 * thrust)
		elif clip == "bloom":
			var release: float = _curve(t, PackedVector2Array([Vector2(0,0),Vector2(0.29,0),Vector2(0.38,1),Vector2(0.54,0.72),Vector2(1,0)]))
			# Alternating lobes spread; three unchanged contacts brace the mass.
			if index % 2 == 0:
				var radial: Vector2 = (_point(layout, contact) - Vector2(128, 180)).normalized()
				contact_shift = radial * (8.0 * release)
		pose[contact]["position"] += contact_shift
		pose[bend]["position"] += mass_shift * 0.65 + contact_shift * 0.35
	return pose

static func walk_cycle_info(_layout: Dictionary, facing: String) -> Dictionary:
	var direction: Vector2 = (Vector2(1, -0.5) if facing == "rear" else Vector2(-1, 0.5)).normalized()
	return {"direction": direction, "stride_px": STRIDE, "stance_fraction": STANCE,
		"travel_per_cycle": direction * STRIDE / STANCE, "foot_lift_px": 2.5}

static func walk_foot_state(phase: float, foot: String, layout: Dictionary, facing: String) -> Dictionary:
	var index: int = CONTACT_NAMES.find(foot.trim_prefix("contact_"))
	var offset: float = float(CONTACT_PHASES[maxi(index, 0)])
	var t: float = fposmod(phase + offset, 1.0)
	var contact: bool = t <= STANCE
	var distance: float = STRIDE * (0.5 - t / STANCE)
	var lift: float = 0.0
	if not contact:
		var u: float = (t - STANCE) / (1.0 - STANCE)
		var tangent: float = -STRIDE * (1.0 - STANCE) / STANCE
		distance = lerpf(-STRIDE * 0.5, STRIDE * 0.5, u*u*(3.0-2.0*u)) + tangent*(2.0*u*u*u-3.0*u*u+u)
		lift = 2.5 * pow(sin(PI*u), 1.5)
	var direction: Vector2 = walk_cycle_info(layout, facing)["direction"]
	var ground_contact: Vector2 = _point(layout, foot) + direction * distance
	return {"target": ground_contact - Vector2(0,lift), "ground_contact": ground_contact,
		"contact": contact, "cycle_phase": t, "lift_px": lift, "angle": 0.0}

static func _curve(t: float, keys: PackedVector2Array) -> float:
	for i: int in range(1, keys.size()):
		if t <= keys[i].x:
			var u: float = inverse_lerp(keys[i-1].x, keys[i].x, t)
			return lerpf(keys[i-1].y, keys[i].y, smoothstep(0.0,1.0,u))
	return keys[-1].y

static func _point(layout: Dictionary, name: String) -> Vector2:
	if name.is_empty(): return Vector2.ZERO
	var p: Array = layout["joints"][name]["position"]
	return Vector2(float(p[0]),float(p[1]))

static func _parent(layout: Dictionary, name: String) -> String:
	var parent: Variant = layout["joints"][name].get("parent")
	return "" if parent == null else str(parent)

static func _world(pose: Dictionary, layout: Dictionary, name: String) -> Transform2D:
	if name.is_empty(): return Transform2D.IDENTITY
	var local := Transform2D(0.0, Vector2(pose[name]["position"]))
	return _world(pose, layout, _parent(layout,name)) * local
