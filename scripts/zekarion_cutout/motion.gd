extends RefCounted

## Crouched dragon: four supports, aimed neck/maw and broad wing gestures.
## No combat resolution lives here. All positions use registered source pixels.
const STANCE: float = 0.64
const STRIDE: float = 64.0
const FEET: Array = ["claw_near", "claw_far", "foot_near", "foot_far"]

static func sample_pose(clip: String, phase: float, layout: Dictionary, facing: String) -> Dictionary:
	var pose: Dictionary = {}
	for name: String in layout["joints"]:
		pose[name] = {"position": _point(layout, name) - _point(layout, _parent(layout, name)), "rotation": 0.0, "scale": Vector2.ONE, "skew": 0.0}
	var rear: bool = facing == "rear"
	var sx: float = -1.0 if rear else 1.0
	var t: float = clampf(phase, 0.0, 1.0)
	if clip == "idle":
		# One rigid upper-body settle; legs and grounded tail remain in bind.
		var bob := Vector2(0, -1.2 * (0.5 - 0.5 * cos(TAU * t)))
		pose["torso"]["position"] += bob
		pose["upper_near"]["position"] -= bob
		pose["upper_far"]["position"] -= bob
		return pose
	if clip == "rest":
		return pose
	var claw_target: Vector2 = _point(layout, "claw_near")
	var claw_angle: float = 0.0
	if clip == "walk":
		pose["torso"]["position"] += Vector2(0, -2.0 * pow(sin(TAU * t), 2.0))
		pose["neck"]["rotation"] = sx * 0.035 * sin(TAU * t)
		pose["wing_near"]["rotation"] = -0.045 * sin(TAU * t)
		pose["wing_far"]["rotation"] = 0.035 * sin(TAU * t)
		pose["tail_mid"]["rotation"] = sx * 0.035 * sin(TAU * t - 0.4)
	elif clip in ["claw", "breath", "charge", "call"]:
		var prep: float = _curve(t, PackedVector2Array([Vector2(0,0),Vector2(0.30,1),Vector2(0.42,1),Vector2(0.55,0),Vector2(1,0)]))
		var release: float = _curve(t, PackedVector2Array([Vector2(0,0),Vector2(0.42,0),Vector2(0.55,1),Vector2(0.68,1),Vector2(1,0)]))
		var charge: float = _curve(t, PackedVector2Array([Vector2(0,0),Vector2(0.34,1),Vector2(0.55,1),Vector2(1,0)]))
		match clip:
			"claw":
				pose["torso"]["position"] += Vector2(sx*(3.0*prep-4.0*release), -2.0*prep+release)
				claw_target += Vector2(sx*(10.0*prep-26.0*release), -23.0*prep+3.0*release)
				claw_angle = sx*(-0.25*prep+0.18*release)
				pose["neck"]["rotation"] = sx*(0.06*prep-0.06*release)
				pose["wing_near"]["rotation"] = -0.10*prep+0.07*release
				pose["wing_far"]["rotation"] = 0.05*prep-0.03*release
			"breath":
				# Coil, then drive the intact maw toward the resolved ranged target.
				pose["torso"]["position"] += Vector2(sx*(2.0*prep-3.0*release), charge)
				pose["neck"]["rotation"] = sx*(0.13*prep-0.18*release)
				pose["jaw"]["rotation"] = sx*(-0.08*prep-0.24*release)
				pose["wing_near"]["rotation"] = -0.08*charge
				pose["wing_far"]["rotation"] = 0.06*charge
			"charge":
				# Skybreak charges overhead while the four supports stay grounded.
				pose["torso"]["position"] += Vector2(0, -4.0*charge)
				pose["neck"]["rotation"] = sx*0.30*charge
				pose["jaw"]["rotation"] = -sx*0.20*release
				pose["wing_near"]["rotation"] = -0.18*charge
				pose["wing_far"]["rotation"] = 0.16*charge
			"call":
				# A distinct wide-wing call, without a strike or body lunge.
				pose["torso"]["position"] += Vector2(0, -2.5*charge)
				pose["neck"]["rotation"] = sx*0.10*charge
				pose["jaw"]["rotation"] = -sx*0.25*release
				pose["wing_near"]["rotation"] = -0.24*charge
				pose["wing_far"]["rotation"] = 0.23*charge
	for foot: String in FEET:
		var target: Vector2 = claw_target if foot == "claw_near" else _point(layout, foot)
		var lift: float = 0.0
		if clip == "walk":
			var state: Dictionary = walk_foot_state(t, foot, layout, facing)
			target = state["target"]
			lift = state["lift_px"]
		_solve_leg(pose, layout, foot, target, lift, claw_angle if foot == "claw_near" else 0.0, rear)
	return pose

static func walk_cycle_info(_layout: Dictionary, facing: String) -> Dictionary:
	var direction: Vector2 = (Vector2(1,-0.5) if facing == "rear" else Vector2(-1,0.5)).normalized()
	return {"direction":direction,"stride_px":STRIDE,"stance_fraction":STANCE,"travel_per_cycle":direction*STRIDE/STANCE,"foot_lift_px":7.0}

static func walk_foot_state(phase: float, foot: String, layout: Dictionary, facing: String) -> Dictionary:
	var info: Dictionary = walk_cycle_info(layout, facing)
	var diagonal: bool = foot in ["claw_far", "foot_near"]
	var t: float = fposmod(phase+STANCE*0.5+(0.5 if diagonal else 0.0),1.0)
	var contact: bool = t <= STANCE
	var distance: float = STRIDE*(0.5-t/STANCE)
	var lift: float = 0.0
	if not contact:
		var u: float = (t-STANCE)/(1.0-STANCE)
		var tangent: float = -STRIDE*(1.0-STANCE)/STANCE
		distance = lerpf(-STRIDE*0.5,STRIDE*0.5,u*u*(3.0-2.0*u))+tangent*(2.0*u*u*u-3.0*u*u+u)
		lift = 7.0*pow(sin(PI*u),1.5)
	var contact_point: Vector2 = _point(layout,foot)+Vector2(info["direction"])*distance
	return {"target":contact_point-Vector2(0,lift),"ground_contact":contact_point,"contact":contact,"cycle_phase":t,"lift_px":lift,"angle":0.0}

static func _solve_leg(pose: Dictionary, layout: Dictionary, foot: String, target: Vector2, lift: float, angle: float, rear: bool) -> void:
	var lower: String = _parent(layout,foot)
	var upper: String = _parent(layout,lower)
	var bind_hip: Vector2 = _point(layout,upper)
	var bind_knee: Vector2 = _point(layout,lower)
	var bind_foot: Vector2 = _point(layout,foot)
	var parent: Transform2D = _world(pose,layout,_parent(layout,upper))
	var hip: Vector2 = _world(pose,layout,upper).origin
	var knee: Vector2 = bind_knee+(hip-bind_hip)*0.5+(target-bind_foot)*0.5
	knee += Vector2((-0.20 if rear else 0.20)*lift,-0.18*lift)
	var upper_world: Transform2D = _segment(bind_knee-bind_hip,knee-hip,hip)
	var lower_world: Transform2D = _segment(bind_foot-bind_knee,target-knee,knee)
	_store(pose,upper,parent.affine_inverse()*upper_world)
	_store(pose,lower,upper_world.affine_inverse()*lower_world)
	_store(pose,foot,lower_world.affine_inverse()*Transform2D(angle,target))

static func _segment(original: Vector2, projected: Vector2, origin: Vector2) -> Transform2D:
	# Axis length can project differently; the perpendicular paint width stays unit.
	var a: Vector2 = original.normalized()
	var b: Vector2 = projected.normalized()
	var transform: Transform2D = Transform2D(projected/original.length(),b.orthogonal(),Vector2.ZERO)*Transform2D(a,a.orthogonal(),Vector2.ZERO).affine_inverse()
	transform.origin = origin
	return transform

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
