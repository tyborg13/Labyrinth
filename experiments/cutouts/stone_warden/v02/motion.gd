extends RefCounted

## Stone Warden study: planted heavy armor, deliberate preparation, one mace contact.
## These timings describe the art preview only; no combat resolver timing changes.
const STANCE: float = 0.62
const STRIDE: float = 48.0

static func sample_pose(clip: String, phase: float, layout: Dictionary, facing: String) -> Dictionary:
	var pose: Dictionary = {}
	for name: String in layout["joints"]:
		var parent: String = _parent(layout, name)
		pose[name] = {"position": _point(layout, name) - _point(layout, parent), "rotation": 0.0, "scale": Vector2.ONE, "skew": 0.0}
	var rear: bool = facing == "rear"
	var direction: float = -1.0 if rear else 1.0
	var t: float = clampf(phase, 0.0, 1.0)
	if clip == "idle":
		pose["pelvis"]["position"] += Vector2(0.0, -1.4 * (0.5 - 0.5 * cos(TAU * t)))
		pose["fore_r"]["rotation"] = direction * 0.016 * sin(TAU * t)
		pose["weapon_r"]["rotation"] = direction * 0.018 * sin(TAU * t - 0.25)
		pose["tabard"]["rotation"] = 0.012 * sin(TAU * t)
	elif clip == "walk":
		pose["pelvis"]["position"] += Vector2(1.1 * sin(TAU * t), 1.4 * (1.0 - cos(TAU * 2.0 * t)))
		pose["upper_r"]["rotation"] = direction * 0.075 * sin(TAU * t)
		pose["upper_l"]["rotation"] = -direction * 0.035 * sin(TAU * t)
		pose["weapon_r"]["rotation"] = direction * 0.045 * sin(TAU * t - 0.45)
		pose["tabard"]["rotation"] = 0.040 * sin(TAU * t - 0.6)
	elif clip == "attack":
		# Pose keys: rest / wind-up / held preparation / contact / follow-through / rest.
		var prep: float = _curve(t, PackedVector2Array([Vector2(0,0),Vector2(0.32,1),Vector2(0.42,1),Vector2(0.55,0),Vector2(1,0)]))
		var hit: float = _curve(t, PackedVector2Array([Vector2(0,0),Vector2(0.42,0),Vector2(0.55,1),Vector2(0.65,1),Vector2(1,0)]))
		pose["pelvis"]["position"] += Vector2((4.0 * prep - 6.0 * hit) * direction, -1.0 * prep + 3.0 * hit)
		pose["upper_r"]["rotation"] = direction * (0.95 * prep + 0.85 * hit)
		pose["fore_r"]["rotation"] = direction * ((1.55 if rear else 1.90) * prep - 0.25 * hit)
		pose["weapon_r"]["rotation"] = direction * ((0.10 if rear else -0.25) * prep + (-0.10 if rear else -0.80) * hit)
		pose["upper_l"]["rotation"] = -direction * (0.045 * prep + 0.06 * hit)
		pose["shield_l"]["rotation"] = direction * (0.025 * prep + 0.035 * hit)
		pose["head"]["rotation"] = direction * 0.025 * hit
		pose["tabard"]["rotation"] = direction * (0.025 * prep - 0.055 * hit)
	if clip in ["idle", "walk", "attack"]:
		for side: String in ["r", "l"]:
			var target: Vector2 = _point(layout, "foot_" + side)
			var lift: float = 0.0
			if clip == "walk":
				var state: Dictionary = walk_foot_state(t, "foot_" + side, layout, facing)
				target = state["target"]
				lift = state["lift_px"]
			_solve_projected_leg(pose, layout, side, target, lift, rear)
	return pose

static func walk_cycle_info(_layout: Dictionary, facing: String) -> Dictionary:
	var direction: Vector2 = (Vector2(1, -0.5) if facing == "rear" else Vector2(-1, 0.5)).normalized()
	return {"direction": direction, "stride_px": STRIDE, "stance_fraction": STANCE, "travel_per_cycle": direction * STRIDE / STANCE, "foot_lift_px": 5.0}

static func walk_foot_state(phase: float, foot: String, layout: Dictionary, facing: String) -> Dictionary:
	var info: Dictionary = walk_cycle_info(layout, facing)
	var t: float = fposmod(phase + (0.5 if foot == "foot_l" else 0.0), 1.0)
	var contact: bool = t <= STANCE
	var distance: float = STRIDE * (0.5 - t / STANCE)
	var lift: float = 0.0
	if not contact:
		var u: float = (t - STANCE) / (1.0 - STANCE)
		var tangent: float = -STRIDE * (1.0 - STANCE) / STANCE
		distance = lerpf(-STRIDE * 0.5, STRIDE * 0.5, u * u * (3.0 - 2.0 * u)) + tangent * (2.0*u*u*u - 3.0*u*u + u)
		lift = 5.0 * pow(sin(PI * u), 1.5)
	# The painted rest already staggers the feet along the travel direction.
	# Center that stagger before adding gait stride, while preserving each lateral lane.
	# Otherwise the stride adds onto the resting split and produces an exaggerated stance.
	var direction: Vector2 = info["direction"]
	var center: Vector2 = (_point(layout, "foot_r") + _point(layout, "foot_l")) * 0.5
	var anchor: Vector2 = _point(layout, foot)
	anchor -= direction * (anchor - center).dot(direction)
	var target: Vector2 = anchor + direction * distance - Vector2(0, lift)
	# Feet keep the original rigid basis, so the painted sole contour stays level.
	return {"target": target, "contact": contact, "cycle_phase": t, "lift_px": lift, "angle": 0.0}

static func _solve_projected_leg(pose: Dictionary, layout: Dictionary, side: String, target: Vector2, lift: float, rear: bool) -> void:
	var upper: String = "thigh_" + side
	var lower: String = "shin_" + side
	var foot: String = "foot_" + side
	var bind_hip: Vector2 = _point(layout, upper)
	var bind_knee: Vector2 = _point(layout, lower)
	var bind_foot: Vector2 = _point(layout, foot)
	var parent: Transform2D = _world(pose, layout, _parent(layout, upper))
	var hip: Vector2 = _world(pose, layout, upper).origin
	# Two independent projected lengths preserve plate width and keep the target exact.
	# The shallow bend follows this creature's short armored legs, not protagonist IK.
	var knee: Vector2 = bind_knee + (hip-bind_hip)*0.5 + (target-bind_foot)*0.5
	knee += Vector2((-0.35 if rear else 0.35) * lift, -0.20 * lift)
	var upper_world: Transform2D = _segment(bind_knee-bind_hip, knee-hip, hip)
	var lower_world: Transform2D = _segment(bind_foot-bind_knee, target-knee, knee)
	_store(pose, upper, parent.affine_inverse() * upper_world)
	_store(pose, lower, upper_world.affine_inverse() * lower_world)
	_store(pose, foot, lower_world.affine_inverse() * Transform2D(0.0, target))

static func _segment(original: Vector2, projected: Vector2, origin: Vector2) -> Transform2D:
	var a: Vector2 = original.normalized()
	var b: Vector2 = projected.normalized()
	var transform: Transform2D = Transform2D(projected/original.length(), b.orthogonal(), Vector2.ZERO) * Transform2D(a, a.orthogonal(), Vector2.ZERO).affine_inverse()
	transform.origin = origin
	return transform

static func _store(pose: Dictionary, name: String, transform: Transform2D) -> void:
	pose[name] = {"position":transform.origin,"rotation":transform.get_rotation(),"scale":transform.get_scale(),"skew":transform.get_skew()}

static func _point(layout: Dictionary, name: String) -> Vector2:
	if name.is_empty():
		return Vector2.ZERO
	var p: Array = layout["joints"][name]["position"]
	return Vector2(float(p[0]),float(p[1]))

static func _parent(layout: Dictionary, name: String) -> String:
	var parent: Variant = layout["joints"][name]["parent"]
	return "" if parent == null else str(parent)

static func _world(pose: Dictionary, layout: Dictionary, name: String) -> Transform2D:
	if name.is_empty():
		return Transform2D.IDENTITY
	var p: Dictionary = pose[name]
	return _world(pose, layout, _parent(layout,name)) * Transform2D(float(p["rotation"]),Vector2(p["scale"]),float(p["skew"]),Vector2(p["position"]))

static func _curve(t: float, keys: PackedVector2Array) -> float:
	for i: int in range(1,keys.size()):
		if t <= keys[i].x:
			var u: float = inverse_lerp(keys[i-1].x,keys[i].x,t)
			return lerpf(keys[i-1].y,keys[i].y,u*u*(3.0-2.0*u))
	return keys[-1].y
