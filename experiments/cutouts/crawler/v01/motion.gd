extends RefCounted

## Crawler: a low four-contact skitter and hooked claw rake, in registered pixels.
## Hands and toes keep a rigid basis; the narrow limb shafts project along their
## length only. Idle is a single upper-body bob with all four limbs counter-shifted.
const STANCE: float = 0.70
const STRIDE: float = 56.0
const CONTACT_PHASE: float = 0.52

static func sample_pose(clip: String, phase: float, layout: Dictionary, facing: String) -> Dictionary:
	var pose: Dictionary = {}
	for name: String in layout["joints"]:
		pose[name] = {"position": _point(layout, name) - _point(layout, _parent(layout,name)), "rotation": 0.0, "scale": Vector2.ONE, "skew": 0.0}
	var t: float = clampf(phase, 0.0, 1.0)
	var rear: bool = facing == "rear"
	var forward: Vector2 = Vector2(1,-0.5).normalized() if rear else Vector2(-1,0.5).normalized()
	if clip == "idle":
		var bob := Vector2(0, -1.25 * (0.5 - 0.5 * cos(TAU*t)))
		pose["body"]["position"] += bob
		for root: String in ["upper_near","upper_far","thigh_near","thigh_far"]:
			pose[root]["position"] -= bob
		return pose
	if not clip in ["walk","attack","lunge","coil"]:
		return pose
	var prep: float = _curve(t, PackedVector2Array([Vector2(0,0),Vector2(0.30,1),Vector2(0.40,1),Vector2(CONTACT_PHASE,0),Vector2(1,0)]))
	var hit: float = _curve(t, PackedVector2Array([Vector2(0,0),Vector2(0.40,0),Vector2(CONTACT_PHASE,1),Vector2(0.65,0.85),Vector2(1,0)]))
	var curl: float = sin(PI*t) * sin(PI*t)
	if clip == "walk":
		pose["body"]["position"] += Vector2(0, -1.5 * (0.5 - 0.5*cos(TAU*2*t)))
	elif clip in ["attack","lunge"]:
		var commitment: float = 13.0 if clip == "lunge" else 4.0
		pose["body"]["position"] += -forward*3.0*prep + forward*commitment*hit + Vector2(0, -2.5*prep + 1.5*hit)
		# The head follows the hunch as one translation; no local idle-like ripple.
		pose["head"]["position"] += forward * (2.0 if clip == "lunge" else 0.5) * hit
	else:
		pose["body"]["position"] += Vector2(0,3.0*curl)
		pose["head"]["position"] -= forward*3.0*curl
	for terminal: String in ["claw_near","claw_far","foot_near","foot_far"]:
		var target: Vector2 = _point(layout, terminal)
		var lift: float = 0.0
		var angle: float = 0.0
		if clip == "walk":
			var state: Dictionary = walk_foot_state(t,terminal,layout,facing)
			target = state["target"]
			lift = float(state["lift_px"])
		elif clip in ["attack","lunge"] and terminal == "claw_near":
			# Hook back/up at the wrist, rake forward through the target space,
			# then recover. The stronger intent commits the whole hunch farther.
			target += -forward*12.0*prep + Vector2(0,-28.0*prep)
			target += forward*(76.0 if clip == "lunge" else 64.0)*hit + Vector2(0,-18.0*hit)
			angle = (1.0 if rear else -1.0) * (0.24*prep - 0.32*hit)
		elif clip == "coil" and terminal.begins_with("claw"):
			target -= forward*3.0*curl
			target += Vector2(0,-2.0*curl)
		_solve_limb(pose,layout,terminal,target,lift,angle)
	return pose

static func walk_cycle_info(_layout: Dictionary, facing: String) -> Dictionary:
	var direction: Vector2 = (Vector2(1,-0.5) if facing == "rear" else Vector2(-1,0.5)).normalized()
	return {"direction":direction,"stride_px":STRIDE,"stance_fraction":STANCE,"travel_per_cycle":direction*STRIDE/STANCE,"foot_lift_px":5.0}

static func walk_foot_state(phase: float, terminal: String, layout: Dictionary, facing: String) -> Dictionary:
	# Diagonal hand/foot pairs overlap support. Four phase offsets keep the
	# creature's characteristic skitter instead of importing a humanoid walk.
	var offsets: Dictionary = {"claw_near":0.0,"foot_far":0.15,"claw_far":0.50,"foot_near":0.65}
	var t: float = fposmod(phase + float(offsets[terminal]),1.0)
	var contact: bool = t <= STANCE
	var distance: float = STRIDE*(0.5-t/STANCE)
	var lift: float = 0.0
	if not contact:
		var u: float = (t-STANCE)/(1.0-STANCE)
		var tangent: float = -STRIDE*(1.0-STANCE)/STANCE
		distance = lerpf(-STRIDE*0.5,STRIDE*0.5,u*u*(3.0-2.0*u)) + tangent*(2*u*u*u-3*u*u+u)
		lift = (6.0 if terminal.begins_with("claw") else 4.0)*pow(sin(PI*u),1.5)
	var info: Dictionary = walk_cycle_info(layout,facing)
	var delta: Vector2 = Vector2(info["direction"])*distance
	var contact_point: Array = layout["landmarks"]["contacts"][terminal]
	var ground: Vector2 = Vector2(float(contact_point[0]),float(contact_point[1])) + delta
	return {"target":_point(layout,terminal)+delta-Vector2(0,lift),"ground_contact":ground,"contact":contact,"cycle_phase":t,"lift_px":lift,"angle":0.0}

static func _solve_limb(pose: Dictionary, layout: Dictionary, terminal: String, target: Vector2, lift: float, angle: float) -> void:
	var side: String = "near" if terminal.ends_with("near") else "far"
	var arm: bool = terminal.begins_with("claw")
	var upper: String = ("upper_" if arm else "thigh_") + side
	var lower: String = ("fore_" if arm else "shin_") + side
	var bind_root: Vector2 = _point(layout,upper)
	var bind_middle: Vector2 = _point(layout,lower)
	var bind_tip: Vector2 = _point(layout,terminal)
	var parent: Transform2D = _world(pose,layout,_parent(layout,upper))
	var root: Vector2 = _world(pose,layout,upper).origin
	# Project the elbow/knee between moving support and body. Its original
	# bend remains, and only length changes; the orthogonal width stays one.
	var middle: Vector2 = bind_middle+(root-bind_root)*0.55+(target-bind_tip)*0.45-Vector2(0,lift*0.25)
	var upper_world: Transform2D = _segment(bind_middle-bind_root,middle-root,root)
	var lower_world: Transform2D = _segment(bind_tip-bind_middle,target-middle,middle)
	_store(pose,upper,parent.affine_inverse()*upper_world)
	_store(pose,lower,upper_world.affine_inverse()*lower_world)
	_store(pose,terminal,lower_world.affine_inverse()*Transform2D(angle,target))

static func _segment(original: Vector2, projected: Vector2, origin: Vector2) -> Transform2D:
	var a: Vector2 = original.normalized()
	var b: Vector2 = projected.normalized()
	var transform: Transform2D = Transform2D(projected/original.length(),b.orthogonal(),Vector2.ZERO)*Transform2D(a,a.orthogonal(),Vector2.ZERO).affine_inverse()
	transform.origin=origin
	return transform

static func _store(pose: Dictionary, name: String, transform: Transform2D) -> void:
	pose[name]={"position":transform.origin,"rotation":transform.get_rotation(),"scale":transform.get_scale(),"skew":transform.get_skew()}

static func _point(layout: Dictionary, name: String) -> Vector2:
	if name.is_empty():return Vector2.ZERO
	var p: Array=layout["joints"][name]["position"]
	return Vector2(float(p[0]),float(p[1]))

static func _parent(layout: Dictionary, name: String) -> String:
	var parent: Variant=layout["joints"][name]["parent"]
	return "" if parent==null else str(parent)

static func _world(pose: Dictionary, layout: Dictionary, name: String) -> Transform2D:
	if name.is_empty():return Transform2D.IDENTITY
	var p: Dictionary=pose[name]
	return _world(pose,layout,_parent(layout,name))*Transform2D(float(p["rotation"]),Vector2(p["scale"]),float(p["skew"]),Vector2(p["position"]))

static func _curve(t: float, keys: PackedVector2Array) -> float:
	for i: int in range(1,keys.size()):
		if t<=keys[i].x:
			var u: float=inverse_lerp(keys[i-1].x,keys[i].x,t)
			return lerpf(keys[i-1].y,keys[i].y,u*u*(3.0-2.0*u))
	return keys[-1].y
