extends RefCounted

## Guardian skeletons use their own source-authored anatomy. Painted soles,
## claws, hands and weapons retain a rigid world basis. Flexible limbs absorb
## projected reach; contact targets remain stationary in the traveling clip.
const GAITS: Dictionary = {
 "ash_hound": [100.0, 0.40, 0.30], "rime_whelp": [100.0, 0.40, 0.30],
 "rime_spitter": [100.0, 0.40, 0.30], "stoneback_mite": [84.0, 0.55, 0.28],
 "bell_tender": [92.0, 0.54, 0.30], "wick_shade": [92.0, 0.54, 0.30],
 "roc_fledgling": [90.0, 0.50, 0.28]
}
const CHALLENGE_IDS = ["ashen_reaver", "storm_cantor", "last_lamplighter", "rimejaw", "craghide", "gallows_roc"]
const CHALLENGE_SECONDS: float = 1.50
const CHALLENGE_CUE_SECONDS: float = 0.36
static func gait(character_id: String) -> Array:
	return GAITS.get(character_id, [68.0, 0.58, 0.32])


static func sample_pose(clip: String, phase: float, layout: Dictionary, facing: String, reduced_motion: bool = false) -> Dictionary:
	if clip == "challenge": return _challenge_pose(phase, layout, facing, reduced_motion)
	if clip in ["hit", "death"]: return _reaction_pose(clip,phase,layout,facing)
	if clip not in ["rest","idle","walk"]: return _action_pose(clip,phase,layout,facing)
	var pose: Dictionary = {}
	for name: String in layout["joints"]:
		pose[name] = {"position": _point(layout, name) - _point(layout, _parent(layout, name)), "rotation": 0.0, "scale": Vector2.ONE, "skew": 0.0}
	if clip == "rest":
		return pose
	var t: float = clampf(phase, 0.0, 1.0)
	var wave: float = sin(TAU * t)
	var rear: bool = facing == "rear"
	var forward: Vector2 = (Vector2(1, -0.5) if rear else Vector2(-1, 0.5)).normalized()
	var family: String = str(layout.get("family", "biped"))
	var character: String = str(layout.get("character_id", ""))
	var breath: float = (1.0 - cos(TAU * t)) * 0.5
	var prepare: float = _curve(t, PackedVector2Array([Vector2(0,0),Vector2(0.25,1),Vector2(0.40,0),Vector2(1,0)]))
	var impact: float = _curve(t, PackedVector2Array([Vector2(0,0),Vector2(0.30,0),Vector2(0.46,1),Vector2(0.60,0.9),Vector2(1,0)]))
	var settle: float = _curve(t, PackedVector2Array([Vector2(0,0),Vector2(0.22,1),Vector2(0.68,1),Vector2(1,0)]))
	var body: Vector2 = Vector2.ZERO
	if clip == "idle":
		body.y = -1.6 * breath
	elif clip == "walk":
		body.y = -1.5 * (1.0 - cos(TAU * 2.0 * t))
	elif clip == "strike":
		body = forward * (-2.0 * prepare + 7.0 * impact) + Vector2(0, -1.5 * impact)
	elif clip == "cast":
		body = Vector2(0, -3.0 * settle) + forward * 2.0 * impact
	elif clip == "brace":
		body = Vector2(0, 3.0 * settle) - forward * 2.0 * prepare
	pose["pelvis"]["position"] += body
	if pose.has("head"):
		var head_turn: float = 0.0
		if clip == "idle": head_turn = 0.0
		elif clip == "walk": head_turn = 0.012 * sin(TAU * t - 0.3)
		elif clip == "strike": head_turn = (0.06 if rear else -0.06) * impact
		elif clip == "cast": head_turn = (0.04 if rear else -0.04) * settle
		pose["head"]["rotation"] = head_turn
	if pose.has("drape"):
		pose["drape"]["rotation"] = 0.016 * sin(TAU * t - 0.4) if clip == "walk" else 0.0 if clip == "idle" else (0.015 if rear else -0.015) * impact
	if pose.has("tail"):
		pose["tail"]["rotation"] = (0.025 if family == "bird" else 0.035) * wave if clip == "walk" else 0.0
	if pose.has("throat"):
		# A separate throat sac expands during the Spitter's visible charge.
		pose["throat"]["scale"] = Vector2.ONE + Vector2(0.035, 0.055) * (settle if clip == "cast" else 0.0)
	for chain: Dictionary in layout.get("chains", []):
		var kind: String = str(chain["kind"])
		var names: Array = chain["bones"]
		if kind == "leg":
			var foot: String = str(names[2])
			var target: Vector2 = _point(layout, foot)
			var lift: float = 0.0
			if clip == "walk":
				var state: Dictionary = walk_foot_state(t, foot, layout, facing)
				target = state["target"]
				lift = float(state["lift_px"])
			_solve_chain(pose, layout, names, target, lift, true)
		elif kind == "arm":
			var hand: String = str(names[2])
			var delta: Vector2 = Vector2.ZERO
			var near: bool = str(chain["name"]) == "near"
			if clip == "walk":
				delta = forward * 2.0 * sin(TAU * t + (0.0 if near else PI))
			elif clip == "strike":
				delta = -forward * 4.0 * prepare + forward * (15.0 if near else 6.0) * impact + Vector2(0, -8.0 * prepare)
			elif clip == "cast":
				delta = Vector2(0, -7.0 * settle) + forward * 3.0 * impact
			elif clip == "brace":
				delta = Vector2(0, -3.0 * settle)
			# The Tender's two hands maintain their fixed grip on one staff.
			if character == "bell_tender": delta = Vector2(0, -2.5 * settle) if clip in ["cast", "strike"] else Vector2.ZERO
			_solve_chain(pose, layout, names, _point(layout, hand) + body + delta, 0.0, false)
		elif kind == "wing":
			# Dorsal roots stay attached while the folded wing opens slightly.
			var side: float = 1.0 if str(chain["name"]) == "near" else -1.0
			var angle: float = 0.0 if clip == "idle" else 0.035 * sin(TAU*t+0.3) if clip == "walk" else -0.10 * prepare + 0.13 * impact if clip == "strike" else 0.065 * settle
			pose[str(names[0])]["rotation"] = side * angle
			pose[str(names[1])]["rotation"] = side * angle * -0.32
			pose[str(names[2])]["rotation"] = side * angle * 0.20
	# Weapon bases follow the gripping hand, with deliberate intent-specific
	# follow-through. The hilt remains connected to the hand throughout.
	for weapon: String in ["blade", "spear", "lantern"]:
		if not pose.has(weapon): continue
		var turn: float = 0.0
		if weapon == "blade" and clip == "strike": turn = (0.11 if rear else -0.11) * prepare + (-0.13 if rear else 0.13) * impact
		if weapon == "spear" and clip == "cast": turn = (0.025 if rear else -0.025) * settle
		if weapon == "lantern": turn = 0.035 * sin(TAU*t-0.5) if clip == "walk" else 0.065 * impact if clip in ["strike","cast"] else 0.0
		pose[weapon]["rotation"] = turn
	return pose

static func walk_cycle_info(layout: Dictionary, facing: String) -> Dictionary:
	var direction: Vector2 = (Vector2(1, -0.5) if facing == "rear" else Vector2(-1, 0.5)).normalized()
	var values: Array = gait(str(layout.get("character_id", "")))
	return {"direction": direction, "travel_per_cycle": direction * float(values[0]), "stance_fraction": float(values[1]), "stride_px": float(values[0])*float(values[1]), "foot_lift_px": 5.0}

static func walk_foot_state(phase: float, foot: String, layout: Dictionary, facing: String) -> Dictionary:
	var offset: float = 0.0
	for chain: Dictionary in layout.get("chains", []):
		if str(chain["kind"]) == "leg" and str(chain["bones"][2]) == foot:
			offset = float(chain.get("phase", 0.0))
	var t: float = fposmod(phase + offset, 1.0)
	var values: Array = gait(str(layout.get("character_id", "")))
	var stance: float = float(values[1])
	var contact: bool = t <= stance
	var stride: float = float(values[0])*stance
	var distance: float = stride * (0.5 - t / stance)
	var lift: float = 0.0
	if not contact:
		var u: float = (t - stance) / (1.0 - stance)
		var tangent: float = -stride * (1.0 - stance) / stance
		distance = lerpf(-stride * 0.5, stride * 0.5, u*u*(3.0-2.0*u)) + tangent*(2.0*u*u*u-3.0*u*u+u)
		lift = 5.0 * pow(sin(PI*u), 1.5)
	var ground: Vector2 = _point(layout, foot) + Vector2(walk_cycle_info(layout, facing)["direction"]) * distance
	return {"target": ground - Vector2(0,lift), "ground_contact": ground, "contact": contact, "cycle_phase": t, "lift_px": lift, "angle": 0.0}

static func sample_draw_order(_clip: String, _phase: float, layout: Dictionary, _facing: String) -> Dictionary:
	# Authored depth is stable: a folded wing does not cross through a torso,
	# and the broad stance keeps opposite-side feet on their own floor tracks.
	var order: Dictionary = {}
	for part: Dictionary in layout.get("parts", []):
		order[str(part.get("paint_node", part["name"]))] = int(part.get("z_index", 0))
	return order

static func _solve_chain(pose: Dictionary, layout: Dictionary, names: Array, target: Vector2, lift: float, leg: bool, preserve_bend: bool = false) -> void:
	var upper: String = str(names[0])
	var lower: String = str(names[1])
	var end: String = str(names[2])
	var a: Vector2 = _point(layout, upper)
	var b: Vector2 = _point(layout, lower)
	var c: Vector2 = _point(layout, end)
	var origin: Vector2 = _world(pose, layout, upper).origin
	var bend: Vector2 = b + (origin-a)*0.5 + (target-c)*0.5
	if leg: bend += Vector2(0, -0.22 * lift)
	if preserve_bend:
		# Rimejaw's almost-straight, occluded hind-far knee crosses its bind
		# bend during the gather. Retain its bind-side knee clearance rather
		# than a numerically unstable straight knee. Authored targets survive.
		var axis: Vector2 = (target-origin).normalized()
		var normal: Vector2 = axis.orthogonal()
		var rest_clearance: float = (b-a).dot((c-a).normalized().orthogonal())
		var clearance: float = (bend-origin).dot(normal)
		if clearance * signf(rest_clearance) < absf(rest_clearance):
			bend += normal * (rest_clearance-clearance)
	var upper_world: Transform2D = _segment(b-a, bend-origin, origin)
	var lower_world: Transform2D = _segment(c-b, target-bend, bend)
	_store(pose, upper, _world(pose, layout, _parent(layout, upper)).affine_inverse()*upper_world)
	_store(pose, lower, upper_world.affine_inverse()*lower_world)
	_store(pose, end, lower_world.affine_inverse()*Transform2D(0, target))

static func _segment(original: Vector2, projected: Vector2, origin: Vector2) -> Transform2D:
	var a: Vector2 = original.normalized()
	var b: Vector2 = projected.normalized()
	var result: Transform2D = Transform2D(projected/maxf(0.001,original.length()),b.orthogonal(),Vector2.ZERO)*Transform2D(a,a.orthogonal(),Vector2.ZERO).affine_inverse()
	result.origin = origin
	return result

static func _point(layout: Dictionary, name: String) -> Vector2:
	if name.is_empty(): return Vector2.ZERO
	var value: Array = layout["joints"][name]["position"]
	return Vector2(float(value[0]),float(value[1]))

static func _parent(layout: Dictionary, name: String) -> String:
	var value: Variant = layout["joints"][name]["parent"]
	return "" if value == null else str(value)

static func _world(pose: Dictionary, layout: Dictionary, name: String) -> Transform2D:
	if name.is_empty(): return Transform2D.IDENTITY
	var p: Dictionary = pose[name]
	return _world(pose,layout,_parent(layout,name))*Transform2D(float(p["rotation"]),Vector2(p["scale"]),float(p["skew"]),Vector2(p["position"]))

static func _store(pose: Dictionary, name: String, transform: Transform2D) -> void:
	pose[name] = {"position":transform.origin,"rotation":transform.get_rotation(),"scale":transform.get_scale(),"skew":transform.get_skew()}

static func _curve(t: float, keys: PackedVector2Array) -> float:
	for i: int in range(1, keys.size()):
		if t <= keys[i].x:
			var u: float = inverse_lerp(keys[i-1].x, keys[i].x, t)
			return lerpf(keys[i-1].y, keys[i].y, u*u*(3.0-2.0*u))
	return keys[-1].y

## Encounter opening only. Keep the ordinary actions and shared helper rigs
## on their existing samplers; all planted supports retain their source targets.
static func _challenge_pose(phase: float, layout: Dictionary, facing: String, reduced_motion: bool) -> Dictionary:
	var pose: Dictionary = sample_pose("rest", 0.0, layout, facing)
	var id: String = str(layout.get("character_id", ""))
	if not CHALLENGE_IDS.has(id): return pose
	var t: float = clampf(phase, 0.0, 1.0)
	var gather: float = _curve(t, PackedVector2Array([Vector2(0, 0), Vector2(0.24, 1), Vector2(0.30, 0), Vector2(1, 0)]))
	var peak: float = _curve(t, PackedVector2Array([Vector2(0, 0), Vector2(0.24, 0), Vector2(0.30, 1), Vector2(0.72, 1), Vector2(1, 0)]))
	var rear: bool = facing == "rear"
	var sign: float = -1.0 if rear else 1.0
	var forward := (Vector2(1, -0.5) if rear else Vector2(-1, 0.5)).normalized()
	var family: String = str(layout["family"])
	var tremble: float = _challenge_tremble(t, reduced_motion)
	var body: Vector2
	# Production bipeds use their humanoid_v2 director clips. Their legacy
	# poses below stay unreachable through Renderer.handles().
	if family == "biped":
		body = -forward * 2.0 * gather + forward * 3.0 * peak + Vector2(0, 3.0 * gather - 5.0 * peak)
		pose["head"]["rotation"] = sign * (-0.05 * gather + 0.10 * peak) + tremble
	elif family == "quadruped":
		body = -forward * 5.0 * gather + forward * 9.0 * peak + Vector2(0, 3.0 * gather - 14.0 * peak)
		pose["head"]["position"] += (forward * 12.0 + Vector2(0, -6.0)) * peak
		pose["head"]["rotation"] = sign * (-0.08 * gather + 0.30 * peak) + tremble
		if pose.has("tail"): pose["tail"]["rotation"] = -sign * 0.18 * peak
	else:
		body = Vector2(0, 3.0 * gather - 12.0 * peak)
		pose["head"]["position"] += (forward * 8.0 + Vector2(0, -12.0)) * peak
		pose["head"]["rotation"] = sign * (-0.04 * gather + 0.30 * peak) + tremble
		pose["tail"]["rotation"] = -sign * 0.12 * peak
	pose["pelvis"]["position"] += body
	for chain: Dictionary in layout.get("chains", []):
		var names: Array = chain["bones"]
		var kind: String = str(chain["kind"])
		var near: bool = str(chain["name"]) == "near"
		if kind == "leg":
			var target: Vector2 = _point(layout, str(names[2]))
			var lift: float = 0.0
			if family == "quadruped" and str(chain["name"]) in ["fore_near", "front_near"] and not bool(chain.get("occluded", false)):
				lift = 36.0 * peak
				target += forward * 14.0 * peak + Vector2(0, -lift)
			_solve_chain(pose, layout, names, target, lift, true, id == "rimejaw" and str(chain["name"]) == "hind_far")
		elif kind == "arm":
			var delta: Vector2 = Vector2.ZERO
			if id == "ashen_reaver":
				delta = -forward * 6.0 * gather + (-forward * 4.0 + Vector2(0, -34.0)) * peak if near else (forward * 12.0 + Vector2(0, -10.0)) * peak
			elif id == "storm_cantor":
				# Half the strike's preparation; one rigid staff follows its grip.
				delta = (-forward * 2.5 + Vector2(0, -7.0)) * gather + Vector2(0, -26.0) * peak if near else Vector2(0, -9.5) * gather + (forward * 6.0 + Vector2(0, -20.0)) * peak
			elif id == "last_lamplighter":
				delta = (forward * 14.0 + Vector2(0, -8.0)) * peak if near else Vector2(0, 4.0) * gather + (forward * 10.0 + Vector2(0, -30.0)) * peak
			_solve_chain(pose, layout, names, _point(layout, str(names[2])) + body + delta, 0.0, false)
		elif kind == "wing":
			var side: float = 1.0 if near else -1.0
			var spread: float = -0.10 * gather + 0.70 * peak
			pose[str(names[0])]["rotation"] = side * spread
			pose[str(names[1])]["rotation"] = -side * 0.70 * 0.18 * peak
	if id == "ashen_reaver": pose["blade"]["rotation"] = sign * 1.35 * peak + tremble
	elif id == "storm_cantor": pose["spear"]["rotation"] = sign * (-0.085 * gather - 0.20 * peak) + tremble
	elif id == "last_lamplighter": pose["lantern"]["rotation"] = sign * -0.30 * peak + tremble
	return pose

static func _challenge_tremble(phase: float, reduced_motion: bool) -> float:
	if reduced_motion or phase < 0.30 or phase > 0.72: return 0.0
	var seconds_since_cue: float = phase * CHALLENGE_SECONDS - CHALLENGE_CUE_SECONDS
	return 0.02 * sin(TAU * 12.0 * seconds_since_cue) * (1.0 - inverse_lerp(0.30, 0.72, phase))

# Three actual action families per creature. Idle and locomotion are separate:
# a sword cuts through space, a beak travels to contact, and a raised foreclaw
# leaves the floor while the other supports stay planted. No undulating mesh
# motion is used as a substitute for preparation/contact/recovery.
static func _action_pose(clip: String, phase: float, layout: Dictionary, facing: String) -> Dictionary:
	var pose: Dictionary = sample_pose("rest",0.0,layout,facing)
	var t: float = clampf(phase,0.0,1.0)
	var rear: bool = facing=="rear"
	var sign: float = -1.0 if rear else 1.0
	var forward := (Vector2(1,-.5) if rear else Vector2(-1,.5)).normalized()
	var id: String = str(layout.get("character_id",""))
	var family: String = str(layout.get("family","biped"))
	var prep: float = _curve(t,PackedVector2Array([Vector2(0,0),Vector2(.26,1),Vector2(.39,0),Vector2(1,0)]))
	var hit: float = _curve(t,PackedVector2Array([Vector2(0,0),Vector2(.31,0),Vector2(.46,1),Vector2(.57,.85),Vector2(.91,0),Vector2(1,0)]))
	var lift: float = _curve(t,PackedVector2Array([Vector2(0,0),Vector2(.24,1),Vector2(.46,.65),Vector2(.72,0),Vector2(1,0)]))
	var body: Vector2 = -forward*3.5*prep+forward*8.0*hit
	if clip=="cast": body=Vector2(0,-3.0*prep+2.0*hit)+forward*3.0*hit
	elif clip=="brace": body=Vector2(0,-4.0*prep+5.0*hit)
	pose["pelvis"]["position"]+=body
	if pose.has("head"):
		if family=="bird":
			# Wind back, then drive the rigid skull and beak into a visible peck.
			pose["head"]["position"]+=-forward*7.0*prep+forward*22.0*hit+Vector2(0,-6.0*prep+3.0*hit)
			pose["head"]["rotation"]=sign*(.18*prep-.28*hit)
		elif family=="quadruped" and id in ["ash_hound","rime_spitter"]:
			pose["head"]["position"]+=-forward*6.0*prep+forward*17.0*hit
			pose["head"]["rotation"]=sign*(.10*prep-.14*hit)
		else:
			pose["head"]["rotation"]=sign*(.04*prep-.06*hit)
	if pose.has("throat") and clip=="cast":
		pose["throat"]["scale"]=Vector2.ONE+Vector2(.09,.13)*prep
	var staff_turn: float = sign*(-.17*prep+.28*hit) if clip=="strike" else sign*(.10*prep-.12*hit)
	var staff_delta: Vector2 = -forward*5.0*prep+forward*16.0*hit+Vector2(0,-14.0*prep)
	for chain: Dictionary in layout.get("chains",[]):
		var names: Array = chain["bones"]
		var kind: String = str(chain["kind"])
		var near: bool = str(chain["name"])=="near"
		if kind=="leg":
			var target: Vector2 = _point(layout,str(names[2]))
			var foreclaw: bool = str(chain["name"]) in ["fore_near","front_near"] and not bool(chain.get("occluded",false))
			var claw_lift: float = 0.0
			if foreclaw and id in ["craghide","stoneback_mite","rimejaw","rime_whelp"]:
				claw_lift=25.0*lift if clip=="strike" else 15.0*prep
				target+=-forward*7.0*prep+forward*(25.0 if clip=="strike" else 8.0)*hit+Vector2(0,-claw_lift)
			_solve_chain(pose,layout,names,target,claw_lift,true)
		elif kind=="arm":
			var hand: String = str(names[2])
			var delta: Vector2 = Vector2.ZERO
			if id=="ashen_reaver":
				delta=Vector2(0,-32.0*prep)+forward*(-8.0*prep+22.0*hit) if near else -forward*6.0*hit+Vector2(0,-8.0*prep)
			elif id=="bell_tender":
				# Both grips follow one rigid staff transform, including the offset
				# far grip. This avoids shearing the staff between independent arms.
				var grip: Vector2 = _point(layout,"hand_near")
				delta=(_point(layout,hand)-grip).rotated(staff_turn)-(_point(layout,hand)-grip)+staff_delta
			elif id=="storm_cantor":
				delta=staff_delta if near else Vector2(0,-19.0*prep)+forward*9.0*hit
			elif id=="last_lamplighter":
				delta=Vector2(0,-22.0*prep)+forward*18.0*hit if not near else Vector2(0,-17.0*prep)+forward*(-8.0*prep+28.0*hit)
			elif id=="wick_shade":
				delta=Vector2(0,-19.0*prep)+forward*(-6.0*prep+(30.0 if near else 15.0)*hit)
			else: delta=Vector2(0,-15.0*prep)+forward*18.0*hit
			if clip=="brace" and id!="bell_tender": delta=Vector2(0,-10.0*prep-4.0*hit)
			_solve_chain(pose,layout,names,_point(layout,hand)+body+delta,0.0,false)
		elif kind=="wing":
			var side: float = 1.0 if near else -1.0
			# A deliberate single wing stroke for wind attacks. Folded wings brace
			# a beak strike; they do not ripple independently along the feather chain.
			var angle: float = (-.23*prep+.30*hit) if clip=="cast" else (-.08*prep+.09*hit)
			pose[str(names[0])]["rotation"]=side*angle
			pose[str(names[1])]["rotation"]=-side*angle*.18
			pose[str(names[2])]["rotation"]=0.0
	if pose.has("blade"):
		pose["blade"]["rotation"]=sign*(1.35*prep-.65*hit)
	if pose.has("spear"):
		pose["spear"]["rotation"]=staff_turn
		if id=="bell_tender":
			# The rear staff pivot is offset from the near palm. Rotate that
			# offset too, so both grips follow the same source-space transform.
			pose["spear"]["position"]=(_point(layout,"spear")-_point(layout,"hand_near")).rotated(staff_turn)
	if pose.has("lantern"):
		pose["lantern"]["rotation"]=sign*(-.22*prep+.42*hit)
	return pose

## A short recoil recovers into the same bind stance. Defeat folds the actual
## support graph: knees for bipeds/birds, four paws for beasts, six for the mite.
## Terminal soles, claws, hands and weapons keep a rigid painted basis.
static func _reaction_pose(clip: String, phase: float, layout: Dictionary, facing: String) -> Dictionary:
	var pose: Dictionary = sample_pose("rest",0.0,layout,facing)
	var t: float = clampf(phase,0.0,1.0)
	var toward: float = 1.0 if facing == "rear" else -1.0
	var family: String = str(layout.get("family","biped"))
	var id: String = str(layout.get("character_id",""))
	var impact: float = _curve(t,PackedVector2Array([Vector2(0,0),Vector2(.15,1),Vector2(.44,.38),Vector2(1,0)]))
	var fall: float = smoothstep(.12,.78,t) if clip == "death" else 0.0
	if clip == "death": impact *= 1.0-smoothstep(.15,.48,t)
	var depth: float = 26.0 if family == "biped" else 20.0 if family == "bird" else 18.0 if family == "quadruped" else 12.0
	var shift := Vector2(toward*(-3.5*impact+3.0*fall),1.6*impact+depth*fall)
	pose["pelvis"]["position"] += shift
	# Turn around the painted torso attachment, never by translating a skull
	# away from the neck. Wide animal torsos keep their native orientation.
	if family == "biped":
		pose["torso"]["rotation"] = toward*(-.045*impact+.13*fall)
	if pose.has("head"):
		pose["head"]["rotation"] = toward*((.06 if family == "biped" else .10)*fall-.025*impact)
	for chain: Dictionary in layout.get("chains",[]):
		var names: Array = chain["bones"]
		var kind: String = str(chain["kind"])
		if kind == "leg":
			_solve_chain(pose,layout,names,_point(layout,str(names[2])),0.0,true)
		elif kind == "arm":
			var hand: String = str(names[2])
			var target: Vector2 = _world(pose,layout,hand).origin
			# The Tender's two grips follow the same rigid staff transform;
			# counter-rotate both hands together to preserve their source offsets.
			if id == "bell_tender": target = _point(layout,hand)+shift
			_solve_chain(pose,layout,names,target,0.0,false)
		elif kind == "wing":
			# One restrained shoulder fold, with elbow and feather tips attached.
			var side: float = 1.0 if str(chain["name"]) == "near" else -1.0
			pose[str(names[0])]["rotation"] = side*(.05*impact+.11*fall)
	if pose.has("tail"):
		pose["tail"]["rotation"] = toward*.045*fall
	return pose
