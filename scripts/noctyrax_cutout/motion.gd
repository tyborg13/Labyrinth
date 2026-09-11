extends RefCounted

## Noctyrax: crouched quadruped. Source-space contact targets follow the 2:1
## projected lane; terminal claws stay rigid and the torso owns all chest paint.
const STANCE: float = 0.65
const STRIDE: float = 56.0
const LIMBS = ["fore_near", "hind_far", "fore_far", "hind_near"]

static func sample_pose(clip: String, phase: float, layout: Dictionary, facing: String) -> Dictionary:
	var pose: Dictionary = {}
	for name: String in layout["joints"]:
		pose[name] = {"position": _point(layout,name)-_point(layout,_parent(layout,name)), "rotation":0.0,"scale":Vector2.ONE,"skew":0.0}
	var t: float = clampf(phase,0.0,1.0)
	var rear: bool = facing == "rear"
	var sign_x: float = 1.0 if rear else -1.0
	if clip == "idle":
		# A single settle translation, with all four legs counter-translated.
		# No independent idle rotations, scale, skew or surface rippling.
		var bob := Vector2(0,-1.5*(0.5-0.5*cos(TAU*t)))
		pose["body"]["position"] += bob
		for side: String in LIMBS:
			pose["upper_"+side]["position"] -= bob
		return pose
	if clip == "rest":
		return pose
	var prep: float = _curve(t,PackedVector2Array([Vector2(0,0),Vector2(0.30,1),Vector2(0.40,1),Vector2(0.50,0),Vector2(1,0)]))
	var release: float = _curve(t,PackedVector2Array([Vector2(0,0),Vector2(0.40,0),Vector2(0.50,1),Vector2(0.63,1),Vector2(1,0)]))
	var claw_target: Vector2 = _point(layout,"claw_fore_near")
	if clip == "walk":
		pose["body"]["position"] += Vector2(0,-1.5*(1.0-cos(TAU*2.0*t)))
		pose["tail_mid"]["rotation"] = 0.035*sin(TAU*t)
	elif clip == "claw":
		# Lift and draw the near claw back, then rake forward and across.
		pose["body"]["position"] += Vector2(sign_x*(-3.0*prep+4.0*release),-2.0*prep+1.5*release)
		claw_target += Vector2(sign_x*(-10.0*prep+20.0*release),-22.0*prep-7.0*release)
		pose["neck"]["rotation"] = sign_x*(-0.05*prep+0.06*release)
		pose["wing_near"]["rotation"] = sign_x*0.065*prep
	elif clip == "breath":
		# Neck compresses before the maw aims and extends at projectile release.
		pose["body"]["position"] += Vector2(-sign_x*3.0*prep+sign_x*2.0*release,-2.0*prep)
		pose["neck"]["rotation"] = sign_x*(-0.14*prep+0.20*release)
		pose["head"]["rotation"] = sign_x*(0.08*prep-0.12*release)
		pose["wing_near"]["rotation"] = sign_x*0.07*prep
		pose["wing_far"]["rotation"] = -sign_x*0.06*prep
	elif clip == "coil":
		# Close the wings, curl the tail inward and lower the trunk into a brace
		# as the existing radial pull resolves. Feet remain planted throughout.
		pose["body"]["position"] += Vector2(0,3.0*prep+4.0*release)
		pose["neck"]["rotation"] = sign_x*(-0.08*prep-0.12*release)
		pose["wing_near"]["rotation"] = sign_x*(0.10*prep+0.13*release)
		pose["wing_far"]["rotation"] = -sign_x*(0.08*prep+0.10*release)
		pose["tail"]["rotation"] = -sign_x*(0.025*prep+0.03*release)
		pose["tail_mid"]["rotation"] = -sign_x*(0.04*prep+0.07*release)
		pose["tail_tip"]["rotation"] = -sign_x*(0.06*prep+0.10*release)
	elif clip == "eclipse":
		# Gather under folded wings, then spread and lift the neck at eclipse.
		pose["body"]["position"] += Vector2(0,2.0*prep-4.0*release)
		pose["neck"]["rotation"] = sign_x*(-0.08*prep-0.16*release)
		pose["head"]["rotation"] = sign_x*(0.08*prep+0.06*release)
		pose["wing_near"]["rotation"] = sign_x*(0.12*prep-0.13*release)
		pose["wing_far"]["rotation"] = -sign_x*(0.10*prep-0.11*release)
		pose["tail_mid"]["rotation"] = sign_x*0.06*prep
	for side: String in LIMBS:
		var target: Vector2 = _point(layout,"claw_"+side)
		var lift: float = 0.0
		if clip == "walk":
			var state: Dictionary = walk_foot_state(t,"claw_"+side,layout,facing)
			target = state["target"]
			lift = state["lift_px"]
		elif clip == "claw" and side == "fore_near":
			target = claw_target
		_solve_limb(pose,layout,side,target,lift,sign_x)
	return pose

static func walk_cycle_info(_layout: Dictionary, facing: String) -> Dictionary:
	var direction: Vector2 = (Vector2(1,-0.5) if facing == "rear" else Vector2(-1,0.5)).normalized()
	return {"direction":direction,"stride_px":STRIDE,"stance_fraction":STANCE,"travel_per_cycle":direction*STRIDE/STANCE,"foot_lift_px":5.0}

static func walk_foot_state(phase: float, foot: String, layout: Dictionary, facing: String) -> Dictionary:
	var info: Dictionary = walk_cycle_info(layout,facing)
	# Diagonal pairs form a measured low crawl. Each claw has a full support interval.
	var offset: float = 0.5 if foot in ["claw_fore_far","claw_hind_near"] else 0.0
	var t: float = fposmod(phase+offset,1.0)
	var contact: bool = t <= STANCE
	var distance: float = STRIDE*(0.5-t/STANCE)
	var lift: float = 0.0
	if not contact:
		var u: float = (t-STANCE)/(1.0-STANCE)
		distance = lerpf(-STRIDE*0.5,STRIDE*0.5,u*u*(3.0-2.0*u))
		lift = 5.0*sin(PI*u)
	var ground: Vector2 = _point(layout,foot)+Vector2(info["direction"])*distance
	return {"target":ground-Vector2(0,lift),"ground_contact":ground,"contact":contact,"cycle_phase":t,"lift_px":lift}

static func _solve_limb(pose: Dictionary, layout: Dictionary, side: String, target: Vector2, lift: float, sign_x: float) -> void:
	var upper: String = "upper_"+side
	var lower: String = "lower_"+side
	var foot: String = "claw_"+side
	var bind_hip: Vector2 = _point(layout,upper)
	var bind_knee: Vector2 = _point(layout,lower)
	var bind_foot: Vector2 = _point(layout,foot)
	var parent: Transform2D = _world(pose,layout,_parent(layout,upper))
	var hip: Vector2 = _world(pose,layout,upper).origin
	var knee: Vector2 = bind_knee+(hip-bind_hip)*0.5+(target-bind_foot)*0.5+Vector2(-sign_x*lift*0.25,-lift*0.25)
	var upper_world: Transform2D = _segment(bind_knee-bind_hip,knee-hip,hip)
	var lower_world: Transform2D = _segment(bind_foot-bind_knee,target-knee,knee)
	_store(pose,upper,parent.affine_inverse()*upper_world)
	_store(pose,lower,upper_world.affine_inverse()*lower_world)
	_store(pose,foot,lower_world.affine_inverse()*Transform2D(0,target))

static func _segment(original: Vector2, projected: Vector2, origin: Vector2) -> Transform2D:
	var a: Vector2 = original.normalized()
	var b: Vector2 = projected.normalized()
	var result: Transform2D = Transform2D(projected/original.length(),b.orthogonal(),Vector2.ZERO)*Transform2D(a,a.orthogonal(),Vector2.ZERO).affine_inverse()
	result.origin = origin
	return result

static func _store(pose: Dictionary, name: String, value: Transform2D) -> void:
	pose[name] = {"position":value.origin,"rotation":value.get_rotation(),"scale":value.get_scale(),"skew":value.get_skew()}

static func _point(layout: Dictionary, name: String) -> Vector2:
	if name.is_empty(): return Vector2.ZERO
	var p: Array = layout["joints"][name]["position"]
	return Vector2(float(p[0]),float(p[1]))

static func _parent(layout: Dictionary, name: String) -> String:
	var p: Variant = layout["joints"][name]["parent"]
	return "" if p == null else str(p)

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
