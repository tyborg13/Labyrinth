extends RefCounted

## Tharokh: four planted claw contacts, a rock-heavy crawl, a foreclaw rake,
## a four-foot brace and an earth-release stamp. All coordinates are source pixels.
const STANCE: float = 0.76
const STRIDE: float = 36.0
const LEGS = ["fore_near", "fore_far", "hind_near", "hind_far"]
const FOOT_PHASES: Dictionary = {"fore_near": 0.0, "hind_far": 0.25, "fore_far": 0.5, "hind_near": 0.75}

static func sample_pose(clip: String, phase: float, layout: Dictionary, facing: String) -> Dictionary:
	var pose: Dictionary = {}
	for name: String in layout["joints"]:
		pose[name] = {"position": _point(layout, name) - _point(layout, _parent(layout, name)),
			"rotation": 0.0, "scale": Vector2.ONE, "skew": 0.0}
	var t: float = clampf(phase, 0.0, 1.0)
	var direction: Vector2 = walk_cycle_info(layout, facing)["direction"]
	if clip == "idle":
		# One rigid bob only. Every leg and the resting tail keep their bind
		# transforms; rock plates, wings and head never shimmer independently.
		var bob := Vector2(0.0, -1.2 * (0.5 - 0.5 * cos(TAU * t)))
		pose["torso"]["position"] += bob
		for leg: String in LEGS:
			pose["upper_" + leg]["position"] -= bob
		pose["tail_base"]["position"] -= bob
		return pose
	if clip == "rest":
		return pose
	var prep: float = _curve(t, PackedVector2Array([Vector2(0,0),Vector2(0.32,1),Vector2(0.42,1),Vector2(0.55,0),Vector2(1,0)]))
	var hit: float = _curve(t, PackedVector2Array([Vector2(0,0),Vector2(0.42,0),Vector2(0.55,1),Vector2(0.65,1),Vector2(1,0)]))
	var rake_target: Vector2 = _point(layout, "claw_fore_near")
	var rake_angle: float = 0.0
	if clip == "walk":
		pose["torso"]["position"] += Vector2(0, -1.7 * (0.5 - 0.5 * cos(TAU * t * 4.0)))
		pose["tail_tip"]["rotation"] = 0.028 * sin(TAU * t)
	elif clip == "claw":
		# Load the three supporting limbs, draw back the near foreclaw, then
		# rake forward and across. The claw is rigid and has no weapon transform.
		pose["torso"]["position"] += direction * (-5.0 * prep + 7.0 * hit) + Vector2(0, 2.5 * hit)
		rake_target += -direction * 7.0 * prep + Vector2(0, -28.0 * prep)
		rake_target += direction * 29.0 * hit + Vector2(0, -10.0 * hit)
		rake_angle = (0.22 * prep - 0.14 * hit) * (-1.0 if facing == "rear" else 1.0)
	elif clip == "brace":
		# Claws stay grounded while the whole chest deliberately loads the floor
		# and rises at the terrain-creation release. No decorative wing flapping.
		pose["torso"]["position"] += Vector2(0, 5.0 * prep - 1.8 * hit)
	elif clip == "faultline":
		pose["torso"]["position"] += -direction * 2.5 * prep + Vector2(0, -2.5 * prep + 5.0 * hit)
		rake_target += Vector2(0, -19.0 * prep)
	for leg: String in LEGS:
		var target: Vector2 = _point(layout, "claw_" + leg)
		var lift: float = 0.0
		var angle: float = 0.0
		if clip == "walk":
			var state: Dictionary = walk_foot_state(t, "claw_" + leg, layout, facing)
			target = state["target"]
			lift = float(state["lift_px"])
		elif leg == "fore_near" and clip in ["claw", "faultline"]:
			target = rake_target
			lift = 28.0 * prep if clip == "claw" else 19.0 * prep
			angle = rake_angle
		_solve_leg(pose, layout, leg, target, lift, angle, direction)
	return pose

static func walk_cycle_info(_layout: Dictionary, facing: String) -> Dictionary:
	var direction: Vector2 = (Vector2(1, -0.5) if facing == "rear" else Vector2(-1, 0.5)).normalized()
	return {"direction": direction, "stride_px": STRIDE, "stance_fraction": STANCE,
		"travel_per_cycle": direction * STRIDE / STANCE, "foot_lift_px": 6.0}

static func walk_foot_state(phase: float, foot: String, layout: Dictionary, facing: String) -> Dictionary:
	var leg: String = foot.trim_prefix("claw_")
	var t: float = fposmod(phase + float(FOOT_PHASES[leg]), 1.0)
	var contact: bool = t <= STANCE
	var distance: float = STRIDE * (0.5 - t / STANCE)
	var lift: float = 0.0
	if not contact:
		var u: float = (t - STANCE) / (1.0 - STANCE)
		var tangent: float = -STRIDE * (1.0 - STANCE) / STANCE
		distance = lerpf(-STRIDE * 0.5, STRIDE * 0.5, u*u*(3.0-2.0*u)) + tangent*(2.0*u*u*u-3.0*u*u+u)
		lift = 6.0 * pow(sin(PI * u), 1.5)
	var direction: Vector2 = walk_cycle_info(layout, facing)["direction"]
	var ground: Vector2 = _sole(layout, foot) + direction * distance
	return {"target": _point(layout, foot) + direction * distance - Vector2(0, lift),
		"ground_contact": ground, "contact": contact, "cycle_phase": t, "lift_px": lift, "angle": 0.0}

static func _solve_leg(pose: Dictionary, layout: Dictionary, leg: String, target: Vector2, lift: float, angle: float, direction: Vector2) -> void:
	var upper: String = "upper_" + leg
	var lower: String = "lower_" + leg
	var claw: String = "claw_" + leg
	var hip_bind: Vector2 = _point(layout, upper)
	var knee_bind: Vector2 = _point(layout, lower)
	var foot_bind: Vector2 = _point(layout, claw)
	var parent: Transform2D = _world(pose, layout, _parent(layout, upper))
	var hip: Vector2 = _world(pose, layout, upper).origin
	var knee: Vector2 = knee_bind + (hip - hip_bind) * 0.55 + (target - foot_bind) * 0.45
	# Elbows fold back beneath the chest; hocks fold forward under the haunch.
	knee += direction * lift * (-0.14 if leg.begins_with("fore") else 0.12)
	var first: Transform2D = _segment(knee_bind - hip_bind, knee - hip, hip)
	var second: Transform2D = _segment(foot_bind - knee_bind, target - knee, knee)
	_store(pose, upper, parent.affine_inverse() * first)
	_store(pose, lower, first.affine_inverse() * second)
	_store(pose, claw, second.affine_inverse() * Transform2D(angle, target))

static func _segment(original: Vector2, projected: Vector2, origin: Vector2) -> Transform2D:
	var a: Vector2 = original.normalized()
	var b: Vector2 = projected.normalized()
	# Preserve perpendicular paint width while accounting for projected length.
	var value: Transform2D = Transform2D(projected / original.length(), b.orthogonal(), Vector2.ZERO) * Transform2D(a, a.orthogonal(), Vector2.ZERO).affine_inverse()
	value.origin = origin
	return value

static func _store(pose: Dictionary, name: String, value: Transform2D) -> void:
	pose[name] = {"position": value.origin, "rotation": value.get_rotation(), "scale": value.get_scale(), "skew": value.get_skew()}

static func _point(layout: Dictionary, name: String) -> Vector2:
	if name.is_empty():
		return Vector2.ZERO
	var point: Array = layout["joints"][name]["position"]
	return Vector2(float(point[0]), float(point[1]))

static func _sole(layout: Dictionary, foot: String) -> Vector2:
	var point: Array = layout["landmarks"]["sole_" + foot.trim_prefix("claw_")]
	return Vector2(float(point[0]), float(point[1]))

static func _parent(layout: Dictionary, name: String) -> String:
	var parent: Variant = layout["joints"][name]["parent"]
	return "" if parent == null else str(parent)

static func _world(pose: Dictionary, layout: Dictionary, name: String) -> Transform2D:
	if name.is_empty():
		return Transform2D.IDENTITY
	var p: Dictionary = pose[name]
	return _world(pose, layout, _parent(layout, name)) * Transform2D(float(p["rotation"]), Vector2(p["scale"]), float(p["skew"]), Vector2(p["position"]))

static func _curve(t: float, keys: PackedVector2Array) -> float:
	for index: int in range(1, keys.size()):
		if t <= keys[index].x:
			var u: float = inverse_lerp(keys[index - 1].x, keys[index].x, t)
			return lerpf(keys[index - 1].y, keys[index].y, u*u*(3.0-2.0*u))
	return keys[-1].y
