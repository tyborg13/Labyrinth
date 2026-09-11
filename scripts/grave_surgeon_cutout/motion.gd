extends RefCounted

## A lean wrapped surgeon: quiet breathing, measured steps, a short bone-saw
## thrust/rake, and vial-hand support feedback. All coordinates are source pixels.
const STANCE: float = 0.62
const STRIDE: float = 72.0
const IDLE_BOB: float = 1.2
const SAW_CONTACT: float = 0.42

static func sample_pose(clip: String, phase: float, layout: Dictionary, facing: String) -> Dictionary:
	var pose: Dictionary = {}
	for name: String in layout["joints"]:
		pose[name] = {"position": _point(layout, name) - _point(layout, _parent(layout, name)),
			"rotation": 0.0, "scale": Vector2.ONE, "skew": 0.0}
	var rear: bool = facing == "rear"
	var t: float = clampf(phase, 0.0, 1.0)
	if clip == "idle":
		# One translation for the whole upper body. There are no independent
		# cloth/head/tool rotations or scale changes, and both legs remain fixed.
		var bob := Vector2(0.0, -IDLE_BOB * (0.5 - 0.5 * cos(TAU * t)))
		pose["pelvis"]["position"] += bob
		pose["thigh_r"]["position"] -= bob
		pose["thigh_l"]["position"] -= bob
		return pose
	if clip == "walk":
		pose["pelvis"]["position"] += Vector2(0.65 * sin(TAU*t), -1.8 * pow(sin(TAU*t), 2.0))
		var pulse: float = sin(TAU*t)
		for arm: String in ["saw", "vial"]:
			var offset := Vector2((1.8 if arm == "saw" else -1.4) * pulse, 0.7 * pulse)
			var shift: Vector2 = _world(pose, layout, "torso").origin - _point(layout, "torso")
			_solve_arm(pose, layout, arm, _point(layout,"fore_"+arm)+shift+offset*0.4,
				_point(layout,"wrist_"+arm)+shift+offset, 0.0)
	elif clip == "attack":
		# Short preparation, one forward contact, then a shallow toothed rake.
		# Rear paint needs the wrist to turn the down-carried blade toward the
		# upper-right target; it never borrows an overhead mace swing.
		var prep: float = _curve(t, PackedVector2Array([Vector2(0,0),Vector2(.23,1),Vector2(.34,1),Vector2(.42,0),Vector2(1,0)]))
		var hit: float = _curve(t, PackedVector2Array([Vector2(0,0),Vector2(.34,0),Vector2(.42,1),Vector2(.53,1),Vector2(.72,.35),Vector2(1,0)]))
		var rake: float = _curve(t, PackedVector2Array([Vector2(0,0),Vector2(.42,0),Vector2(.53,1),Vector2(.72,.4),Vector2(1,0)]))
		pose["pelvis"]["position"] += Vector2(-3,0)*prep+Vector2(4,-2)*hit if rear else Vector2(4,-1)*prep+Vector2(-5,2)*hit
		var elbow: Vector2 = _point(layout,"fore_saw")
		var wrist: Vector2 = _point(layout,"wrist_saw")
		var angle: float
		if rear:
			elbow += Vector2(-4,-4)*prep+Vector2(4,-14)*hit
			wrist += Vector2(-4,-5)*prep+Vector2(11,-22)*hit+Vector2(4,-1)*rake
			angle = -.35*prep-1.15*hit-.10*rake
		else:
			elbow += Vector2(3,-4)*prep+Vector2(-10,-1)*hit+Vector2(-1,1)*rake
			wrist += Vector2(6,-6)*prep+Vector2(-12,1)*hit+Vector2(-2,4)*rake
			angle = -.08*prep+.48*hit+.08*rake
		_solve_arm(pose,layout,"saw",elbow,wrist,angle)
	elif clip in ["treat", "ward"]:
		# These are restrained responses alongside existing immediate ally
		# outcomes, not delayed projectile attacks. No result is authored here.
		var cue: float = pow(sin(PI*t), 2.0)
		var ward: bool = clip == "ward"
		var forward: float = 1.0 if rear else -1.0
		var wrist_offset := Vector2(forward*(5.0 if ward else 3.0), -7.0 if ward else -10.0)*cue
		var elbow_offset := Vector2(forward*2.0, -3.0)*cue
		_solve_arm(pose,layout,"vial",_point(layout,"fore_vial")+elbow_offset,
			_point(layout,"wrist_vial")+wrist_offset, forward*(.12 if ward else -.12)*cue)
	if clip in ["walk", "attack"]:
		for side: String in ["r","l"]:
			var target: Vector2 = _point(layout,"foot_"+side)
			var lift: float = 0.0
			if clip == "walk":
				var state: Dictionary = walk_foot_state(t,"foot_"+side,layout,facing)
				target = state["target"]
				lift = float(state["lift_px"])
			_solve_leg(pose,layout,side,target,lift,rear)
	return pose

static func walk_cycle_info(_layout: Dictionary, facing: String) -> Dictionary:
	var direction: Vector2 = (Vector2(1,-.5) if facing == "rear" else Vector2(-1,.5)).normalized()
	return {"direction":direction,"stride_px":STRIDE,"stance_fraction":STANCE,
		"travel_per_cycle":direction*STRIDE/STANCE,"foot_lift_px":5.0}

static func walk_foot_state(phase: float, foot: String, layout: Dictionary, facing: String) -> Dictionary:
	var info: Dictionary = walk_cycle_info(layout,facing)
	var t: float = fposmod(phase+(.5 if foot == "foot_l" else 0.0),1.0)
	var contact: bool = t <= STANCE
	var distance: float = STRIDE*(.5-t/STANCE)
	var lift: float = 0.0
	if not contact:
		var u: float = (t-STANCE)/(1.0-STANCE)
		var tangent: float = -STRIDE*(1.0-STANCE)/STANCE
		distance = lerpf(-STRIDE*.5,STRIDE*.5,u*u*(3.0-2.0*u))+tangent*(2.0*u*u*u-3.0*u*u+u)
		lift = 5.0*pow(sin(PI*u),1.5)
	var sole: Vector2 = _sole(layout,foot)
	var center: Vector2 = (_sole(layout,"foot_r")+_sole(layout,"foot_l"))*.5
	var offset: Vector2 = sole-center
	# Retain each projected lateral lane while the soles alternate along travel.
	var lateral: Vector2 = Vector2(1,.5)*(.5*offset.x+offset.y)*.70
	var ground: Vector2 = center+lateral+Vector2(info["direction"])*distance
	return {"target":ground-(sole-_point(layout,foot))-Vector2(0,lift),"ground_contact":ground,
		"contact":contact,"cycle_phase":t,"lift_px":lift,"angle":0.0}

static func sample_draw_order(clip: String, phase: float, layout: Dictionary, facing: String) -> Dictionary:
	if clip != "walk":
		return {}
	var right: Dictionary = walk_foot_state(phase,"foot_r",layout,facing)
	var left: Dictionary = walk_foot_state(phase,"foot_l",layout,facing)
	var right_near: bool = Vector2(right["ground_contact"]).y >= Vector2(left["ground_contact"]).y
	var layers: Dictionary = {}
	for side: String in ["r","l"]:
		var near: bool = right_near if side == "r" else not right_near
		layers["Skin_thigh_fill_"+side] = 4 if near else 0
		layers["Skin_leg_"+side] = 5 if near else 1
		layers["foot_"+side] = 6 if near else 2
	return layers

static func _solve_arm(pose: Dictionary, layout: Dictionary, arm: String, elbow: Vector2, wrist: Vector2, wrist_angle: float) -> void:
	var upper: String = "upper_"+arm
	var lower: String = "fore_"+arm
	var hand: String = "wrist_"+arm
	var shoulder: Vector2 = _world(pose,layout,upper).origin
	var upper_world: Transform2D = _segment(_point(layout,lower)-_point(layout,upper),elbow-shoulder,shoulder)
	var lower_world: Transform2D = _segment(_point(layout,hand)-_point(layout,lower),wrist-elbow,elbow)
	_store(pose,upper,_world(pose,layout,_parent(layout,upper)).affine_inverse()*upper_world)
	_store(pose,lower,upper_world.affine_inverse()*lower_world)
	# The hand and tool share this rigid transform, with separate paint owners.
	# Their source-space grip offset is invariant even as the sleeve deforms.
	_store(pose,hand,lower_world.affine_inverse()*Transform2D(wrist_angle,wrist))

static func _solve_leg(pose: Dictionary, layout: Dictionary, side: String, target: Vector2, lift: float, rear: bool) -> void:
	var upper: String = "thigh_"+side
	var lower: String = "shin_"+side
	var foot: String = "foot_"+side
	var hip: Vector2 = _world(pose,layout,upper).origin
	var knee: Vector2 = _point(layout,lower)+(hip-_point(layout,upper))*.5+(target-_point(layout,foot))*.5
	# Modest forward knee flexion fits the narrow wrapped trouser drawing.
	knee += Vector2(.20 if rear else -.20,-.28)*lift
	var upper_world: Transform2D = _segment(_point(layout,lower)-_point(layout,upper),knee-hip,hip)
	var lower_world: Transform2D = _segment(_point(layout,foot)-_point(layout,lower),target-knee,knee)
	_store(pose,upper,_world(pose,layout,_parent(layout,upper)).affine_inverse()*upper_world)
	_store(pose,lower,upper_world.affine_inverse()*lower_world)
	_store(pose,foot,lower_world.affine_inverse()*Transform2D(0.0,target))

static func _segment(original: Vector2, projected: Vector2, origin: Vector2) -> Transform2D:
	var a: Vector2 = original.normalized()
	var b: Vector2 = projected.normalized()
	# Change projected length along the limb only. Its painted width remains one.
	var result: Transform2D = Transform2D(projected/original.length(),b.orthogonal(),Vector2.ZERO)*Transform2D(a,a.orthogonal(),Vector2.ZERO).affine_inverse()
	result.origin = origin
	return result

static func _store(pose: Dictionary, name: String, value: Transform2D) -> void:
	pose[name] = {"position":value.origin,"rotation":value.get_rotation(),"scale":value.get_scale(),"skew":value.get_skew()}

static func _point(layout: Dictionary, name: String) -> Vector2:
	if name.is_empty():
		return Vector2.ZERO
	var point: Array = layout["joints"][name]["position"]
	return Vector2(float(point[0]),float(point[1]))

static func _parent(layout: Dictionary, name: String) -> String:
	var parent: Variant = layout["joints"][name]["parent"]
	return "" if parent == null else str(parent)

static func _world(pose: Dictionary, layout: Dictionary, name: String) -> Transform2D:
	if name.is_empty():
		return Transform2D.IDENTITY
	var p: Dictionary = pose[name]
	return _world(pose,layout,_parent(layout,name))*Transform2D(float(p["rotation"]),Vector2(p["scale"]),float(p["skew"]),Vector2(p["position"]))

static func _sole(layout: Dictionary, foot: String) -> Vector2:
	var p: Array = layout["landmarks"]["sole_"+foot.trim_prefix("foot_")]
	return Vector2(float(p[0]),float(p[1]))

static func _curve(t: float, keys: PackedVector2Array) -> float:
	for index: int in range(1,keys.size()):
		if t <= keys[index].x:
			var u: float = inverse_lerp(keys[index-1].x,keys[index].x,t)
			return lerpf(keys[index-1].y,keys[index].y,u*u*(3.0-2.0*u))
	return keys[-1].y
