extends RefCounted

## A low molten body on five articulated tendril bundles. The iron cap and
## facial crust belong to one rigid core; the flexible flesh bears the motion.
const TENDRILS: PackedStringArray = ["left_outer", "left_inner", "center", "right_inner", "right_outer"]
const STANCE: float = 0.68
const STRIDE: float = 48.0
const IDLE_BOB: float = 1.2

static func sample_pose(clip: String, phase: float, layout: Dictionary, facing: String) -> Dictionary:
	var pose: Dictionary = {}
	for name: String in layout["joints"]:
		pose[name] = {"position": _point(layout, name) - _point(layout, _parent(layout, name)),
			"rotation": 0.0, "scale": Vector2.ONE, "skew": 0.0}
	var t: float = clampf(phase, 0.0, 1.0)
	var bob := Vector2.ZERO
	if clip == "idle":
		# One coordinated translation. No armor/face rotation, scaling or ripple.
		bob.y = -IDLE_BOB * (0.5 - 0.5 * cos(TAU * t))
		pose["core"]["position"] += bob
		for tendril: String in TENDRILS:
			# Only the soft neck of each tendril settles; terminal contacts stay put.
			pose[tendril + "_bend"]["position"] -= bob * 0.5
			pose[tendril + "_tip"]["position"] -= bob * 0.5
		return pose
	if clip not in ["walk", "retreat", "attack"]:
		return pose
	var walk_phase: float = fposmod(-phase if clip == "retreat" else phase, 1.0)
	var travel: Vector2 = walk_cycle_info(layout, facing)["direction"]
	var prepare: float = 0.0
	var strike: float = 0.0
	if clip in ["walk", "retreat"]:
		bob.y = -1.6 * pow(sin(TAU * walk_phase), 2.0)
	else:
		# Draw the leading tendrils inward, lash low into contact, then settle.
		prepare = _curve(t, PackedVector2Array([Vector2(0,0),Vector2(.30,1),Vector2(.38,1),Vector2(.52,0),Vector2(1,0)]))
		strike = _curve(t, PackedVector2Array([Vector2(0,0),Vector2(.38,0),Vector2(.52,1),Vector2(.63,.72),Vector2(1,0)]))
		bob = travel * (-4.0 * prepare + 9.0 * strike) + Vector2(0, -2.0 * prepare + 1.4 * strike)
	pose["core"]["position"] += bob
	for tendril: String in TENDRILS:
		var target: Vector2 = _point(layout, tendril + "_tip")
		var lift: float = 0.0
		if clip in ["walk", "retreat"]:
			var state: Dictionary = walk_foot_state(walk_phase, tendril + "_tip", layout, facing)
			target = state["target"]
			lift = float(state["lift_px"])
		else:
			var leading: bool = tendril in (["right_inner", "right_outer"] if facing == "rear" else ["left_inner", "left_outer"])
			if leading:
				var reach: float = 56.0 if tendril.ends_with("inner") else 43.0
				target += travel * (-8.0 * prepare + reach * strike) - Vector2(0, 6.0 * prepare + 3.0 * strike)
				lift = 6.0 * prepare + 3.0 * strike
		_solve_tendril(pose, layout, tendril, target, lift)
	return pose

static func walk_cycle_info(_layout: Dictionary, facing: String) -> Dictionary:
	var direction: Vector2 = (Vector2(1,-.5) if facing == "rear" else Vector2(-1,.5)).normalized()
	return {"direction": direction, "stride_px": STRIDE, "stance_fraction": STANCE,
		"travel_per_cycle": direction * STRIDE / STANCE, "foot_lift_px": 5.0}

static func walk_foot_state(phase: float, foot: String, layout: Dictionary, facing: String) -> Dictionary:
	var tendril: String = foot.trim_suffix("_tip")
	# Alternating bundles keep at least three supports while the others recover.
	var offsets: Dictionary = {"left_outer":0.0,"right_inner":.2,"center":.4,"left_inner":.6,"right_outer":.8}
	var t: float = fposmod(phase + float(offsets[tendril]), 1.0)
	var contact: bool = t <= STANCE
	var distance: float = STRIDE * (0.5 - t / STANCE)
	var lift: float = 0.0
	if not contact:
		var u: float = (t - STANCE) / (1.0 - STANCE)
		var tangent: float = -STRIDE * (1.0 - STANCE) / STANCE
		distance = lerpf(-STRIDE*.5, STRIDE*.5, u*u*(3.0-2.0*u)) + tangent*(2.0*u*u*u-3.0*u*u+u)
		lift = 5.0 * pow(sin(PI*u), 1.5)
	var direction: Vector2 = walk_cycle_info(layout, facing)["direction"]
	var ground: Vector2 = _point(layout, foot) + direction * distance
	return {"target": ground - Vector2(0,lift), "ground_contact": ground,
		"contact": contact, "cycle_phase": t, "lift_px": lift, "angle":0.0}

static func _solve_tendril(pose: Dictionary, layout: Dictionary, name: String, target: Vector2, lift: float) -> void:
	var base: String = name + "_base"
	var bend: String = name + "_bend"
	var tip: String = name + "_tip"
	var bind_base: Vector2 = _point(layout, base)
	var bind_bend: Vector2 = _point(layout, bend)
	var bind_tip: Vector2 = _point(layout, tip)
	var parent: Transform2D = _world(pose, layout, "core")
	var socket: Vector2 = _world(pose, layout, base).origin
	var middle: Vector2 = bind_bend + (socket-bind_base)*.5 + (target-bind_tip)*.5 - Vector2(0,lift*.15)
	# Project length along each tendril while retaining its painted cross-width.
	var upper: Transform2D = _segment(bind_bend-bind_base, middle-socket, socket)
	var lower: Transform2D = _segment(bind_tip-bind_bend, target-middle, middle)
	_store(pose, base, parent.affine_inverse()*upper)
	_store(pose, bend, upper.affine_inverse()*lower)
	_store(pose, tip, lower.affine_inverse()*Transform2D(0.0,target))

static func _segment(original: Vector2, projected: Vector2, origin: Vector2) -> Transform2D:
	var a: Vector2 = original.normalized()
	var b: Vector2 = projected.normalized()
	var result: Transform2D = Transform2D(projected/original.length(),b.orthogonal(),Vector2.ZERO) * Transform2D(a,a.orthogonal(),Vector2.ZERO).affine_inverse()
	result.origin = origin
	return result

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
	return _world(pose, layout, _parent(layout,name))*Transform2D(float(p["rotation"]),Vector2(p["scale"]),float(p["skew"]),Vector2(p["position"]))

static func _curve(t: float, keys: PackedVector2Array) -> float:
	for index: int in range(1,keys.size()):
		if t <= keys[index].x:
			var u: float = inverse_lerp(keys[index-1].x,keys[index].x,t)
			return lerpf(keys[index-1].y,keys[index].y,u*u*(3.0-2.0*u))
	return keys[-1].y
