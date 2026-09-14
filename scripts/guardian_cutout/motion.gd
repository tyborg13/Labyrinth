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
static func gait(character_id: String) -> Array:
	return GAITS.get(character_id, [68.0, 0.58, 0.32])


static func sample_pose(clip: String, phase: float, layout: Dictionary, facing: String) -> Dictionary:
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
		body.y = -0.8 * breath if family == "biped" else -1.1 * breath
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
		if clip == "idle": head_turn = 0.008 * wave
		elif clip == "walk": head_turn = 0.012 * sin(TAU * t - 0.3)
		elif clip == "strike": head_turn = (0.06 if rear else -0.06) * impact
		elif clip == "cast": head_turn = (0.04 if rear else -0.04) * settle
		pose["head"]["rotation"] = head_turn
	if pose.has("drape"):
		pose["drape"]["rotation"] = 0.016 * sin(TAU * t - 0.4) if clip == "walk" else 0.008 * wave if clip == "idle" else (0.015 if rear else -0.015) * impact
	if pose.has("tail"):
		pose["tail"]["rotation"] = (0.025 if family == "bird" else 0.035) * wave if clip in ["idle", "walk"] else 0.045 * impact
	if pose.has("throat"):
		# A separate throat sac expands during the Spitter's visible charge.
		pose["throat"]["scale"] = Vector2.ONE + Vector2(0.035, 0.055) * (settle if clip == "cast" else 0.25 * breath)
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
			var angle: float = 0.018 * wave if clip == "idle" else 0.035 * sin(TAU*t+0.3) if clip == "walk" else -0.10 * prepare + 0.13 * impact if clip == "strike" else 0.065 * settle
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
		if weapon == "lantern": turn = 0.035 * sin(TAU*t-0.5) if clip == "walk" else 0.065 * impact if clip in ["strike","cast"] else 0.012 * wave
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

static func _solve_chain(pose: Dictionary, layout: Dictionary, names: Array, target: Vector2, lift: float, leg: bool) -> void:
	var upper: String = str(names[0])
	var lower: String = str(names[1])
	var end: String = str(names[2])
	var a: Vector2 = _point(layout, upper)
	var b: Vector2 = _point(layout, lower)
	var c: Vector2 = _point(layout, end)
	var origin: Vector2 = _world(pose, layout, upper).origin
	var bend: Vector2 = b + (origin-a)*0.5 + (target-c)*0.5
	if leg: bend += Vector2(0, -0.22 * lift)
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
