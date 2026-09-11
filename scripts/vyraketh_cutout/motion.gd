extends RefCounted

## Vyraketh's own crouched dragon anatomy: four planted claws, a flexible neck,
## two broad wing membranes and a resting tail. No humanoid weapon poses.
const LIMBS = ["fore_far", "fore_near", "hind_far", "hind_near"]
const STANCE: float = 0.72
const STRIDE: float = 64.0
const CONTACT_PHASE: float = 0.55

static func sample_pose(clip: String, phase: float, layout: Dictionary, facing: String) -> Dictionary:
	var pose: Dictionary = {}
	for name: String in layout["joints"]:
		pose[name] = {"position": _point(layout, name) - _point(layout, _parent(layout, name)),
			"rotation": 0.0, "scale": Vector2.ONE, "skew": 0.0}
	var t: float = clampf(phase, 0.0, 1.0)
	var rear: bool = facing == "rear"
	var lane: Vector2 = (Vector2(1, -0.5) if rear else Vector2(-1, 0.5)).normalized()
	var sign: float = -1.0 if rear else 1.0
	if clip == "idle":
		# One coordinated upper-body bob, with unchanged bases and fixed limbs.
		# The coiled tail stays on its support surface instead of shimmering.
		var bob := Vector2(0, -1.35 * (0.5 - 0.5 * cos(TAU * t)))
		pose["body"]["position"] += bob
		for limb: String in LIMBS:
			pose[limb]["position"] -= bob
		return pose
	if clip == "rest":
		return pose
	if clip == "walk":
		pose["body"]["position"] += Vector2(0, -1.8 * pow(sin(TAU * t), 2.0))
		pose["tail"]["position"] += Vector2(0, -3.0)
		pose["neck"]["position"] += Vector2(0, -0.8 * pow(sin(TAU * t), 2.0))
	elif clip in ["maw", "kindle", "crownfire", "cinderfall"]:
		var gather: float = _curve(t, PackedVector2Array([Vector2(0,0),Vector2(0.32,1),Vector2(0.43,1),Vector2(0.55,0),Vector2(1,0)]))
		var release: float = _curve(t, PackedVector2Array([Vector2(0,0),Vector2(0.43,0),Vector2(0.55,1),Vector2(0.65,0.85),Vector2(1,0)]))
		var neck_move := Vector2.ZERO
		match clip:
			"maw":
				# Pull back with open jaws, thrust the long neck forward, close at
				# contact, then withdraw. The claws support the weight throughout.
				neck_move = lane * (-7.0 * gather + 24.0 * release)
				pose["body"]["position"] += lane * (2.0 * release) + Vector2(0, gather)
				pose["jaw"]["rotation"] = -sign * (0.36 * gather - 0.035 * release)
				pose["wing_near"]["rotation"] = sign * 0.045 * gather
				pose["wing_far"]["rotation"] = -sign * 0.045 * gather
			"kindle":
				# A low breath directed into the board seeds the existing marks.
				neck_move = lane * (5.0 * gather + 10.0 * release) + Vector2(0, 6.0 * gather + 3.0 * release)
				pose["jaw"]["rotation"] = -sign * (0.18 * gather + 0.25 * release)
				pose["wing_near"]["rotation"] = sign * (0.07 * gather - 0.055 * release)
				pose["wing_far"]["rotation"] = -sign * (0.07 * gather - 0.055 * release)
			"crownfire":
				# Lift the crown, spread both wings, then settle as marked tiles
				# detonate. This is a radial command, not a forward bite.
				neck_move = Vector2(0, -8.0 * gather - 3.0 * release)
				pose["body"]["position"] += Vector2(0, -2.0 * gather + 1.8 * release)
				pose["wing_near"]["rotation"] = -sign * (0.15 * gather + 0.035 * release)
				pose["wing_far"]["rotation"] = sign * (0.15 * gather + 0.035 * release)
				pose["jaw"]["rotation"] = -sign * 0.22 * release
			"cinderfall":
				# Gather high, then drive both wings downward to release area fire.
				neck_move = Vector2(0, -11.0 * gather) + lane * (9.0 * release)
				pose["body"]["position"] += Vector2(0, -2.5 * gather + 3.0 * release)
				pose["wing_near"]["rotation"] = -sign * 0.07 * gather + sign * 0.20 * release
				pose["wing_far"]["rotation"] = sign * 0.07 * gather - sign * 0.20 * release
				pose["jaw"]["rotation"] = -sign * (0.10 * gather + 0.30 * release)
		pose["neck"]["position"] += neck_move * 0.40
		pose["head"]["position"] += neck_move * 0.60
	else:
		return pose
	for limb: String in LIMBS:
		var target: Vector2 = _point(layout, "claw_" + limb)
		var lift: float = 0.0
		if clip == "walk":
			var step: Dictionary = walk_foot_state(t, "claw_" + limb, layout, facing)
			target = step["target"]
			lift = float(step["lift_px"])
		_solve_limb(pose, layout, limb, target, lift)
	return pose

static func walk_cycle_info(_layout: Dictionary, facing: String) -> Dictionary:
	var lane: Vector2 = (Vector2(1, -0.5) if facing == "rear" else Vector2(-1, 0.5)).normalized()
	return {"direction": lane, "stride_px": STRIDE, "stance_fraction": STANCE,
		"travel_per_cycle": lane * STRIDE / STANCE, "foot_lift_px": 5.5}

static func walk_foot_state(phase: float, foot: String, layout: Dictionary, facing: String) -> Dictionary:
	# A four-beat crawl with long overlapping support. The front and hind feet
	# retain their original lanes instead of collapsing to a humanoid centerline.
	var offsets: Dictionary = {"claw_hind_far":0.0, "claw_fore_far":0.25,
		"claw_hind_near":0.5, "claw_fore_near":0.75}
	var t: float = fposmod(phase + float(offsets[foot]), 1.0)
	var contact: bool = t <= STANCE
	var distance: float = STRIDE * (0.5 - t / STANCE)
	var lift: float = 0.0
	if not contact:
		var u: float = (t - STANCE) / (1.0 - STANCE)
		var tangent: float = -STRIDE * (1.0 - STANCE) / STANCE
		distance = lerpf(-STRIDE * 0.5, STRIDE * 0.5, u*u*(3.0-2.0*u)) + tangent*(2.0*u*u*u-3.0*u*u+u)
		lift = 5.5 * pow(sin(PI * u), 1.5)
	var lane: Vector2 = walk_cycle_info(layout, facing)["direction"]
	var target: Vector2 = _point(layout, foot) + lane * distance - Vector2(0, lift)
	return {"target":target, "ground_contact":target+Vector2(0,lift), "contact":contact,
		"cycle_phase":t, "lift_px":lift, "angle":0.0}

static func _solve_limb(pose: Dictionary, layout: Dictionary, limb: String, target: Vector2, lift: float) -> void:
	var bend: String = "bend_" + limb
	var claw: String = "claw_" + limb
	var hip_bind: Vector2 = _point(layout, limb)
	var knee_bind: Vector2 = _point(layout, bend)
	var claw_bind: Vector2 = _point(layout, claw)
	var parent: Transform2D = _world(pose, layout, _parent(layout, limb))
	var hip: Vector2 = _world(pose, layout, limb).origin
	# Each segment changes only projected length; its perpendicular paint width
	# remains one. The claws are returned to their exact rigid world basis.
	var knee: Vector2 = knee_bind + (hip-hip_bind)*0.5 + (target-claw_bind)*0.5
	knee.y -= lift * 0.25
	var upper: Transform2D = _segment(knee_bind-hip_bind, knee-hip, hip)
	var lower: Transform2D = _segment(claw_bind-knee_bind, target-knee, knee)
	_store(pose, limb, parent.affine_inverse()*upper)
	_store(pose, bend, upper.affine_inverse()*lower)
	_store(pose, claw, lower.affine_inverse()*Transform2D(0.0,target))

static func _segment(original: Vector2, projected: Vector2, origin: Vector2) -> Transform2D:
	var a: Vector2 = original.normalized()
	var b: Vector2 = projected.normalized()
	var result: Transform2D = Transform2D(projected/original.length(), b.orthogonal(), Vector2.ZERO) * Transform2D(a, a.orthogonal(), Vector2.ZERO).affine_inverse()
	result.origin = origin
	return result

static func _store(pose: Dictionary, name: String, transform: Transform2D) -> void:
	pose[name] = {"position":transform.origin,"rotation":transform.get_rotation(),"scale":transform.get_scale(),"skew":transform.get_skew()}

static func _point(layout: Dictionary, name: String) -> Vector2:
	if name.is_empty(): return Vector2.ZERO
	var p: Array = layout["joints"][name]["position"]
	return Vector2(float(p[0]),float(p[1]))

static func _parent(layout: Dictionary, name: String) -> String:
	var parent: Variant = layout["joints"][name]["parent"]
	return "" if parent == null else str(parent)

static func _world(pose: Dictionary, layout: Dictionary, name: String) -> Transform2D:
	if name.is_empty(): return Transform2D.IDENTITY
	var p: Dictionary = pose[name]
	return _world(pose,layout,_parent(layout,name))*Transform2D(float(p["rotation"]),Vector2(p["scale"]),float(p["skew"]),Vector2(p["position"]))

static func _curve(t: float, keys: PackedVector2Array) -> float:
	for i: int in range(1,keys.size()):
		if t <= keys[i].x:
			var u: float = inverse_lerp(keys[i-1].x,keys[i].x,t)
			return lerpf(keys[i-1].y,keys[i].y,u*u*(3.0-2.0*u))
	return keys[-1].y
