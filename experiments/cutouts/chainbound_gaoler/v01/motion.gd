extends RefCounted

## Gaoler: a hook arm, a separate restraint/fist arm, and two articulated chains.
## One source-space step matches one existing 0.36s board tile movement.
const STANCE: float = 0.60
const TRAVEL: float = 255.0 * 0.559016994375 / (1.03 * 0.9)
const STRIDE: float = TRAVEL * STANCE

static func sample_pose(clip: String, phase: float, layout: Dictionary, facing: String) -> Dictionary:
	var pose: Dictionary = {}
	for name: String in layout["joints"]:
		pose[name] = {"position": _point(layout, name) - _point(layout, _parent(layout, name)), "rotation": 0.0, "scale": Vector2.ONE, "skew": 0.0}
	var t: float = clampf(phase, 0.0, 1.0)
	var rear: bool = facing == "rear"
	var forward: Vector2 = Vector2(1, -0.5) if rear else Vector2(-1, 0.5)
	if clip == "rest":
		return pose
	if clip == "idle":
		# One rigid upper-body bob. No local rotations or fluctuating bases.
		var bob := Vector2(0, -1.2 * (0.5 - 0.5 * cos(TAU * t)))
		pose["pelvis"]["position"] += bob
		pose["thigh_hook"]["position"] -= bob
		pose["thigh_fist"]["position"] -= bob
		return pose
	var hook_delta := Vector2.ZERO
	var fist_delta := Vector2.ZERO
	var hand_roll: float = 0.0
	if clip == "walk":
		pose["pelvis"]["position"] += Vector2(0, -2.0 * (1.0 - cos(TAU * 2.0 * t)))
		hook_delta = Vector2(2.0 * sin(TAU * t), 1.0 * sin(TAU * t))
		fist_delta = forward * -5.0 * sin(TAU * t)
		pose["coat_hook"]["rotation"] = 0.045 * sin(TAU * t)
		pose["coat_fist"]["rotation"] = -0.045 * sin(TAU * t)
	elif clip == "strike":
		var prep: float = _curve(t, PackedVector2Array([Vector2(0,0),Vector2(0.22,1),Vector2(0.30,1),Vector2(0.42,0),Vector2(1,0)]))
		var hit: float = _curve(t, PackedVector2Array([Vector2(0,0),Vector2(0.30,0),Vector2(0.42,1),Vector2(0.56,1),Vector2(1,0)]))
		pose["pelvis"]["position"] += forward * (-2.0 * prep + 4.0 * hit)
		fist_delta = -forward * 9.0 * prep + Vector2(0,-24) * prep + (forward * (36.0 if rear else 72.0) + Vector2(0,-47 if rear else -62)) * hit
		hook_delta = -forward * 2.0 * hit
		hand_roll = (-0.10 if rear else 0.10) * hit
	elif clip == "manacle_pin":
		# Existing air effect releases at 4/38 and contacts at 12/38.
		var prep: float = _curve(t, PackedVector2Array([Vector2(0,0),Vector2(0.08,1),Vector2(4.0/38.0,0),Vector2(1,0)]))
		var cast: float = _curve(t, PackedVector2Array([Vector2(0,0),Vector2(0.08,0),Vector2(4.0/38.0,1),Vector2(12.0/38.0,1),Vector2(0.65,0.55),Vector2(1,0)]))
		pose["pelvis"]["position"] += forward * 2.0 * cast
		fist_delta = -forward * 5.0 * prep + Vector2(0,-24) * prep + forward * 43.0 * cast + Vector2(0,-39) * cast
		hand_roll = (0.18 if rear else -0.18) * cast
	elif clip == "chain_reel":
		var prep: float = _curve(t, PackedVector2Array([Vector2(0,0),Vector2(0.18,1),Vector2(0.34,0),Vector2(1,0)]))
		var cast: float = _curve(t, PackedVector2Array([Vector2(0,0),Vector2(0.18,0),Vector2(0.34,1),Vector2(0.48,1),Vector2(0.70,0),Vector2(1,0)]))
		var reel: float = _curve(t, PackedVector2Array([Vector2(0,0),Vector2(0.48,0),Vector2(0.70,1),Vector2(1,0)]))
		pose["pelvis"]["position"] += forward * (2.0 * cast - 3.0 * reel)
		hook_delta = -forward * 9.0 * prep + Vector2(0,-7) * prep + forward * 8.0 * cast - forward * 18.0 * reel
		fist_delta = forward * 4.0 * cast
	for side: String in ["hook", "fist"]:
		var bind: Vector2 = _point(layout, "hand_" + side)
		var parent_shift: Vector2 = _world(pose, layout, "torso").origin - _point(layout, "torso")
		_solve_arm(pose, layout, side, bind + parent_shift + (hook_delta if side == "hook" else fist_delta), hand_roll if side == "fist" else 0.0)
		var foot: Vector2 = _point(layout, "foot_" + side)
		var lift: float = 0.0
		if clip == "walk":
			var state: Dictionary = walk_foot_state(t, "foot_" + side, layout, facing)
			foot = state["target"]
			lift = float(state["lift_px"])
		_solve_leg(pose, layout, side, foot, lift, rear)
	if clip == "chain_reel":
		var taut: float = _curve(t, PackedVector2Array([Vector2(0,0),Vector2(0.18,0.0),Vector2(0.34,1),Vector2(0.70,1),Vector2(1,0)]))
		var wind: float = _curve(t, PackedVector2Array([Vector2(0,0),Vector2(0.18,1),Vector2(0.34,0),Vector2(1,0)]))
		var cast_angle: float = -2.03444394 if rear else 1.10714872
		var angles: PackedFloat32Array = PackedFloat32Array([cast_angle * taut + (0.28 if rear else -0.28) * wind, cast_angle * taut + (0.48 if rear else -0.48) * wind, cast_angle * taut + (0.65 if rear else -0.65) * wind])
		pose["chain_a"]["rotation"] = angles[0]
		pose["chain_b"]["rotation"] = angles[1] - angles[0]
		pose["chain_c"]["rotation"] = angles[2] - angles[1]
		pose["hook"]["rotation"] = 0.0
	elif clip == "walk":
		# The heavy hanging hook follows the stride with one small broad swing.
		pose["chain_a"]["rotation"] = 0.055 * sin(TAU * t - 0.3)
	_solve_drape(pose, layout)
	return pose

static func walk_cycle_info(_layout: Dictionary, facing: String) -> Dictionary:
	var direction: Vector2 = (Vector2(1, -0.5) if facing == "rear" else Vector2(-1, 0.5)).normalized()
	return {"direction": direction, "stride_px": STRIDE, "stance_fraction": STANCE, "travel_per_cycle": direction * TRAVEL, "foot_lift_px": 7.0}

static func walk_foot_state(phase: float, foot: String, layout: Dictionary, facing: String) -> Dictionary:
	var info: Dictionary = walk_cycle_info(layout, facing)
	var t: float = fposmod(phase + (0.5 if foot == "foot_fist" else 0.0), 1.0)
	var contact: bool = t <= STANCE
	var distance: float = STRIDE * (0.5 - t / STANCE)
	var lift: float = 0.0
	if not contact:
		var u: float = (t - STANCE) / (1.0 - STANCE)
		var tangent: float = -STRIDE * (1.0 - STANCE) / STANCE
		distance = lerpf(-STRIDE * 0.5, STRIDE * 0.5, u*u*(3.0-2.0*u)) + tangent*(2.0*u*u*u-3.0*u*u+u)
		lift = 7.0 * pow(sin(PI*u), 1.5)
	var sole_a: Vector2 = _sole(layout, "foot_hook")
	var sole_b: Vector2 = _sole(layout, "foot_fist")
	var center: Vector2 = (sole_a + sole_b) * 0.5
	var sole: Vector2 = _sole(layout, foot)
	var offset: Vector2 = sole - center
	var lateral := Vector2(1,0.5) * (0.5 * offset.x + offset.y) * 0.65
	var ground: Vector2 = center + lateral + Vector2(info["direction"]) * distance
	return {"target":ground-(sole-_point(layout,foot))-Vector2(0,lift),"ground_contact":ground,"contact":contact,"cycle_phase":t,"lift_px":lift,"angle":0.0}

static func sample_draw_order(clip: String, phase: float, layout: Dictionary, facing: String) -> Dictionary:
	if clip != "walk":
		# The far fist passes behind the back harness in rear-facing casts.
		return {"hand_fist": 11} if facing == "rear" and clip in ["strike", "manacle_pin"] else {}
	var a: Dictionary = walk_foot_state(phase, "foot_hook", layout, facing)
	var b: Dictionary = walk_foot_state(phase, "foot_fist", layout, facing)
	var hook_near: bool = Vector2(a["ground_contact"]).y >= Vector2(b["ground_contact"]).y
	var layers: Dictionary = {"hand_fist": 15}
	for side: String in ["hook", "fist"]:
		var near: bool = hook_near if side == "hook" else not hook_near
		layers["Skin_leg_" + side] = 5 if near else 2
		layers["Skin_thigh_" + side + "_under"] = 4 if near else 1
		layers["foot_" + side] = 6 if near else 3
	return layers

static func _solve_arm(pose: Dictionary, layout: Dictionary, side: String, target: Vector2, hand_roll: float) -> void:
	var upper: String = "upper_"+side
	var fore: String = "fore_"+side
	var hand: String = "hand_"+side
	var a: Vector2 = _point(layout,upper)
	var b: Vector2 = _point(layout,fore)
	var c: Vector2 = _point(layout,hand)
	var origin: Vector2 = _world(pose,layout,upper).origin
	var delta: Vector2 = target-origin
	var l1: float = a.distance_to(b)
	var l2: float = b.distance_to(c)
	var distance: float = clampf(delta.length(),absf(l1-l2)+0.01,l1+l2-0.01)
	target = origin+delta.normalized()*distance
	var angle: float = acos(clampf((l1*l1+distance*distance-l2*l2)/(2.0*l1*distance),-1,1))
	var sign_bend: float = signf((b-a).cross(c-a))
	var elbow: Vector2 = origin+Vector2.from_angle(delta.angle()-sign_bend*angle)*l1
	var up_world := Transform2D((elbow-origin).angle()-(b-a).angle(),origin)
	var fore_world := Transform2D((target-elbow).angle()-(c-b).angle(),elbow)
	_store(pose,upper,_world(pose,layout,_parent(layout,upper)).affine_inverse()*up_world)
	_store(pose,fore,up_world.affine_inverse()*fore_world)
	_store(pose,hand,fore_world.affine_inverse()*Transform2D(hand_roll,target))

static func _solve_leg(pose: Dictionary, layout: Dictionary, side: String, target: Vector2, lift: float, rear: bool) -> void:
	var thigh: String = "thigh_"+side
	var shin: String = "shin_"+side
	var foot: String = "foot_"+side
	var a: Vector2 = _point(layout,thigh)
	var b: Vector2 = _point(layout,shin)
	var c: Vector2 = _point(layout,foot)
	var hip: Vector2 = _world(pose,layout,thigh).origin
	var knee: Vector2 = b+(hip-a)*0.48+(target-c)*0.52+Vector2((-0.20 if rear else 0.20)*lift,-0.15*lift)
	var thigh_world: Transform2D = _segment(b-a,knee-hip,hip)
	var shin_world: Transform2D = _segment(c-b,target-knee,knee)
	_store(pose,thigh,_world(pose,layout,_parent(layout,thigh)).affine_inverse()*thigh_world)
	_store(pose,shin,thigh_world.affine_inverse()*shin_world)
	_store(pose,foot,shin_world.affine_inverse()*Transform2D(0,target))

static func _solve_drape(pose: Dictionary, layout: Dictionary) -> void:
	var names: PackedStringArray = ["drape_a","drape_b","drape_c","drape_d"]
	var bind: PackedVector2Array = PackedVector2Array()
	for name: String in names:
		bind.append(_point(layout,name))
	var end_values: Array = layout["landmarks"]["drape_end"]
	bind.append(Vector2(float(end_values[0]),float(end_values[1])))
	var first: Vector2 = _world(pose,layout,"hand_hook")*(bind[0]-_point(layout,"hand_hook"))
	var last: Vector2 = _world(pose,layout,"pelvis")*(bind[4]-_point(layout,"pelvis"))
	var points: PackedVector2Array = PackedVector2Array()
	var lengths: PackedFloat32Array = PackedFloat32Array()
	for i: int in range(5):
		points.append(bind[i]+(first-bind[0]).lerp(last-bind[4],float(i)/4.0))
		if i<4:
			lengths.append(bind[i].distance_to(bind[i+1]))
	for iteration: int in range(12):
		points[4]=last
		for i: int in range(3,-1,-1):
			points[i]=points[i+1]+(points[i]-points[i+1]).normalized()*lengths[i]
		points[0]=first
		for i: int in range(4):
			points[i+1]=points[i]+(points[i+1]-points[i]).normalized()*lengths[i]
	for i: int in range(4):
		var transform := Transform2D((points[i+1]-points[i]).angle()-(bind[i+1]-bind[i]).angle(),points[i])
		_store(pose,names[i],_world(pose,layout,_parent(layout,names[i])).affine_inverse()*transform)

static func _segment(original: Vector2, projected: Vector2, origin: Vector2) -> Transform2D:
	var a: Vector2 = original.normalized()
	var b: Vector2 = projected.normalized()
	var transform: Transform2D = Transform2D(projected/original.length(),b.orthogonal(),Vector2.ZERO)*Transform2D(a,a.orthogonal(),Vector2.ZERO).affine_inverse()
	transform.origin=origin
	return transform

static func _sole(layout: Dictionary, name: String) -> Vector2:
	var v: Array = layout["landmarks"]["sole_"+name.trim_prefix("foot_")]
	return Vector2(float(v[0]),float(v[1]))

static func _point(layout: Dictionary, name: String) -> Vector2:
	if name.is_empty():return Vector2.ZERO
	var value: Array = layout["joints"][name]["position"]
	return Vector2(float(value[0]),float(value[1]))

static func _parent(layout: Dictionary, name: String) -> String:
	var value: Variant = layout["joints"][name]["parent"]
	return "" if value==null else str(value)

static func _world(pose: Dictionary, layout: Dictionary, name: String) -> Transform2D:
	if name.is_empty():return Transform2D.IDENTITY
	var p: Dictionary=pose[name]
	return _world(pose,layout,_parent(layout,name))*Transform2D(float(p["rotation"]),Vector2(p["scale"]),float(p["skew"]),Vector2(p["position"]))

static func _store(pose: Dictionary, name: String, transform: Transform2D) -> void:
	pose[name]={"position":transform.origin,"rotation":transform.get_rotation(),"scale":transform.get_scale(),"skew":transform.get_skew()}

static func _curve(t: float, keys: PackedVector2Array) -> float:
	for i: int in range(1,keys.size()):
		if t<=keys[i].x:
			var u: float=inverse_lerp(keys[i-1].x,keys[i].x,t)
			return lerpf(keys[i-1].y,keys[i].y,u*u*(3.0-2.0*u))
	return keys[-1].y
