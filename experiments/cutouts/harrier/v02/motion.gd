extends RefCounted

## Bone Harrier: thin projected bone chains, rigid spear and distinct thrust/cast.
## Source-space joints belong to this creature; only the affine segment math is shared practice.
const STANCE: float = 0.62
const STRIDE: float = 54.0

static func sample_pose(clip: String, phase: float, layout: Dictionary, facing: String) -> Dictionary:
	var pose: Dictionary = {}
	for name: String in layout["joints"]:
		pose[name] = {"position": _point(layout, name) - _point(layout, _parent(layout, name)), "rotation": 0.0, "scale": Vector2.ONE, "skew": 0.0}
	var t: float = clampf(phase, 0.0, 1.0)
	var rear: bool = facing == "rear"
	if clip == "idle":
		var bob := Vector2(0, -1.15 * (0.5 - 0.5 * cos(TAU * t)))
		pose["pelvis"]["position"] += bob
		pose["thigh_r"]["position"] -= bob
		pose["thigh_l"]["position"] -= bob
		return _registered(pose, layout)
	if clip in ["walk", "retreat"]:
		pose["pelvis"]["position"] += Vector2(0, -1.6 * (0.5 - 0.5 * cos(TAU * 2 * t)))
		if clip == "retreat":
			# A guarded withdrawal follows the resolved lane, then returns to watch the player.
			var away := Vector2(1, -0.5) if rear else Vector2(-1, 0.5)
			pose["torso"]["position"] -= away * 1.5
			_solve_arm(pose, layout, "r", _point(layout,"fore_r") - away * 2, _point(layout,"hand_r") - away * 4 + Vector2(0,-2), 0)
	elif clip in ["attack", "cast"]:
		var prep: float = _curve(t, PackedVector2Array([Vector2(0,0),Vector2(0.30,1),Vector2(0.40,1),Vector2(0.55,0),Vector2(1,0)]))
		var hit: float = _curve(t, PackedVector2Array([Vector2(0,0),Vector2(0.40,0),Vector2(0.55,1),Vector2(0.66,1),Vector2(1,0)]))
		var direction := Vector2(1,-0.5) if rear else Vector2(-1,0.5)
		pose["pelvis"]["position"] += direction * (3.0 * hit - 2.0 * prep)
		var bind_hand: Vector2 = _point(layout, "hand_r")
		var bind_elbow: Vector2 = _point(layout, "fore_r")
		var prepared_hand: Vector2
		var prepared_elbow: Vector2
		var contact_hand: Vector2
		var contact_elbow: Vector2
		var preparation_angle: float
		if clip == "cast":
			# Keep the raised rear spear beyond the fixed health-bar ornament.
			prepared_hand = Vector2(195,52) if rear else Vector2(106,60)
			prepared_elbow = Vector2(173,82) if rear else Vector2(111,87)
			contact_hand = Vector2(212,70) if rear else Vector2(63,94)
			contact_elbow = Vector2(185,90) if rear else Vector2(88,101)
			preparation_angle = -0.75 if rear else 1.60
		else:
			prepared_hand = Vector2(173,89) if rear else Vector2(96,85)
			prepared_elbow = Vector2(163,114) if rear else Vector2(108,109)
			contact_hand = Vector2(211,82) if rear else Vector2(56,101)
			contact_elbow = Vector2(184,101) if rear else Vector2(86,105)
			preparation_angle = 0.10 if rear else -0.08
		var target: Vector2 = bind_hand + (prepared_hand-bind_hand)*prep + (contact_hand-bind_hand)*hit
		var elbow: Vector2 = bind_elbow + (prepared_elbow-bind_elbow)*prep + (contact_elbow-bind_elbow)*hit
		var tip: Array = layout["landmarks"]["weapon_tip"]
		var spear_vector := Vector2(float(tip[0]),float(tip[1])) - bind_hand
		var aim_angle: float = spear_vector.angle_to(direction)
		_solve_arm(pose,layout,"r",elbow,target,preparation_angle*prep+aim_angle*hit)
		# Free hand braces as a single restrained skeletal chain; no borrowed mace pose.
		var free_elbow: Vector2 = _point(layout,"fore_l") + direction * (-2.0*prep-3.0*hit)
		var free_hand: Vector2 = _point(layout,"hand_l") + direction * (-4.0*prep-5.0*hit) + Vector2(0,-3*hit)
		_solve_arm(pose,layout,"l",free_elbow,free_hand,0)
	if clip in ["walk","retreat","attack","cast"]:
		for side: String in ["r","l"]:
			var target: Vector2 = _point(layout,"foot_"+side)
			var lift: float = 0
			if clip in ["walk", "retreat"]:
				var state: Dictionary = walk_foot_state(t,"foot_"+side,layout,facing)
				target = Vector2(state["target"]) - registration_offset(layout)
				lift = float(state["lift_px"])
			_solve_leg(pose,layout,side,target,lift,rear)
	return _registered(pose, layout)

# Keep the midpoint of the two soles fixed when swapping or reflecting painted
# views. Source ownership and joint coordinates remain in their original pixels.
static func registration_offset(layout: Dictionary) -> Vector2:
	return Vector2(127.5, 209.5) - (_sole(layout, "foot_r") + _sole(layout, "foot_l")) * 0.5

static func _registered(pose: Dictionary, layout: Dictionary) -> Dictionary:
	pose["root"]["position"] += registration_offset(layout)
	return pose

static func walk_cycle_info(_layout: Dictionary, facing: String) -> Dictionary:
	var direction: Vector2 = (Vector2(1,-0.5) if facing == "rear" else Vector2(-1,0.5)).normalized()
	return {"direction":direction,"stride_px":STRIDE,"stance_fraction":STANCE,"travel_per_cycle":direction*STRIDE/STANCE,"foot_lift_px":6.0}

static func walk_foot_state(phase: float, foot: String, layout: Dictionary, facing: String) -> Dictionary:
	var t: float = fposmod(phase+(0.5 if foot == "foot_l" else 0.0),1.0)
	var contact: bool = t <= STANCE
	var distance: float = STRIDE*(0.5-t/STANCE)
	var lift: float = 0
	if not contact:
		var u: float = (t-STANCE)/(1.0-STANCE)
		var tangent: float = -STRIDE*(1.0-STANCE)/STANCE
		distance = lerpf(-STRIDE*0.5,STRIDE*0.5,u*u*(3-2*u))+tangent*(2*u*u*u-3*u*u+u)
		lift = 6.0*pow(sin(PI*u),1.5)
	var sole: Vector2 = _sole(layout,foot)
	var center: Vector2 = (_sole(layout,"foot_r")+_sole(layout,"foot_l"))*0.5
	var offset: Vector2 = sole-center
	var lane := Vector2(1,0.5)*(0.5*offset.x+offset.y)*0.85
	var contact_point: Vector2 = center+lane+Vector2(walk_cycle_info(layout,facing)["direction"])*distance+registration_offset(layout)
	return {"target":contact_point-(sole-_point(layout,foot))-Vector2(0,lift),"ground_contact":contact_point,"contact":contact,"cycle_phase":t,"lift_px":lift,"angle":0.0}

static func sample_draw_order(clip: String,phase: float,layout: Dictionary,facing: String) -> Dictionary:
	if clip not in ["walk", "retreat"]:return {}
	var r: Dictionary = walk_foot_state(phase,"foot_r",layout,facing)
	var l: Dictionary = walk_foot_state(phase,"foot_l",layout,facing)
	var near_r: bool = Vector2(r["ground_contact"]).y >= Vector2(l["ground_contact"]).y
	var result: Dictionary = {}
	for side: String in ["r","l"]:
		var near: bool = near_r if side=="r" else not near_r
		result["Skin_leg_"+side] = 4 if near else 2
		result["Skin_hip_cap_"+side] = 3 if near else 1
		result["Skin_thigh_fill_"+side] = 3 if near else 1
		result["foot_"+side] = 5 if near else 3
	return result

static func _solve_arm(pose:Dictionary,layout:Dictionary,side:String,elbow:Vector2,hand:Vector2,hand_angle:float)->void:
	var upper: String = "upper_"+side
	var lower: String = "fore_"+side
	var terminal: String = "hand_"+side
	var shoulder: Vector2 = _world(pose,layout,upper).origin
	var parent: Transform2D = _world(pose,layout,_parent(layout,upper))
	var a: Transform2D = _segment(_point(layout,lower)-_point(layout,upper),elbow-shoulder,shoulder)
	var b: Transform2D = _segment(_point(layout,terminal)-_point(layout,lower),hand-elbow,elbow)
	_store(pose,upper,parent.affine_inverse()*a)
	_store(pose,lower,a.affine_inverse()*b)
	_store(pose,terminal,b.affine_inverse()*Transform2D(hand_angle,hand))

static func _solve_leg(pose:Dictionary,layout:Dictionary,side:String,target:Vector2,lift:float,rear:bool)->void:
	var upper: String = "thigh_"+side
	var lower: String = "shin_"+side
	var foot: String = "foot_"+side
	var hip: Vector2 = _world(pose,layout,upper).origin
	var knee: Vector2 = _point(layout,lower)+(hip-_point(layout,upper))*0.5+(target-_point(layout,foot))*0.48
	knee += Vector2((-0.45 if rear else 0.45)*lift,-0.3*lift)
	var parent: Transform2D = _world(pose,layout,_parent(layout,upper))
	var a: Transform2D = _segment(_point(layout,lower)-_point(layout,upper),knee-hip,hip)
	var b: Transform2D = _segment(_point(layout,foot)-_point(layout,lower),target-knee,knee)
	_store(pose,upper,parent.affine_inverse()*a)
	_store(pose,lower,a.affine_inverse()*b)
	_store(pose,foot,b.affine_inverse()*Transform2D(0,target))

static func _segment(original:Vector2,projected:Vector2,origin:Vector2)->Transform2D:
	var a: Vector2 = original.normalized()
	var b: Vector2 = projected.normalized()
	var transform: Transform2D = Transform2D(projected/original.length(),b.orthogonal(),Vector2.ZERO)*Transform2D(a,a.orthogonal(),Vector2.ZERO).affine_inverse()
	transform.origin=origin
	return transform
static func _store(pose:Dictionary,name:String,t:Transform2D)->void:
	pose[name]={"position":t.origin,"rotation":t.get_rotation(),"scale":t.get_scale(),"skew":t.get_skew()}
static func _point(layout:Dictionary,name:String)->Vector2:
	if name.is_empty():return Vector2.ZERO
	var p: Array = layout["joints"][name]["position"]
	return Vector2(float(p[0]),float(p[1]))
static func _parent(layout:Dictionary,name:String)->String:
	var p: Variant=layout["joints"][name]["parent"]
	return "" if p==null else str(p)
static func _world(pose:Dictionary,layout:Dictionary,name:String)->Transform2D:
	if name.is_empty():return Transform2D.IDENTITY
	var p: Dictionary=pose[name]
	return _world(pose,layout,_parent(layout,name))*Transform2D(float(p["rotation"]),Vector2(p["scale"]),float(p["skew"]),Vector2(p["position"]))
static func _sole(layout:Dictionary,foot:String)->Vector2:
	var p: Array=layout["landmarks"]["sole_"+foot.trim_prefix("foot_")]
	return Vector2(float(p[0]),float(p[1]))
static func _curve(t:float,keys:PackedVector2Array)->float:
	for i: int in range(1,keys.size()):
		if t<=keys[i].x:
			var u: float=inverse_lerp(keys[i-1].x,keys[i].x,t)
			return lerpf(keys[i-1].y,keys[i].y,u*u*(3-2*u))
	return keys[-1].y
