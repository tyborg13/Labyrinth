extends RefCounted

## Shale Bloomer: a mineral trunk pulls itself over three spreading root contacts.
## Crown petals articulate only during attacks; idle never rotates painted plates.
const STANCE: float = 0.70
const STRIDE: float = 84.0
const MARK_PREPARE_SECONDS: float = 0.28
const MARK_EFFECT_SECONDS: float = 0.704
const MARK_DURATION: float = MARK_PREPARE_SECONDS + MARK_EFFECT_SECONDS
const MARK_RELEASE: float = (MARK_PREPARE_SECONDS + 0.064) / MARK_DURATION
const MARK_CONTACT: float = (MARK_PREPARE_SECONDS + 0.256) / MARK_DURATION
const BURST_RELEASE: float = 0.38

static func sample_pose(clip: String, phase: float, layout: Dictionary, facing: String) -> Dictionary:
	var pose: Dictionary = {}
	for name: String in layout["joints"]:
		pose[name] = {"position": _point(layout, name) - _point(layout, _parent(layout, name)),
			"rotation": 0.0, "scale": Vector2.ONE, "skew": 0.0, "visible": true}
	pose["hidden_calyx"]["visible"] = false
	pose["hidden_roots"]["visible"] = clip == "walk"
	var t: float = clampf(phase, 0.0, 1.0)
	var upper_offset := Vector2.ZERO
	var aim: Vector2 = Vector2(1.0, -0.5) if facing == "rear" else Vector2(-1.0, 0.5)
	if clip == "idle":
		# One coordinated rigid bob, with every ground contact counter-translated.
		upper_offset = Vector2(0.0, -1.2 * (0.5 - 0.5 * cos(TAU * t)))
	elif clip == "walk":
		# Roots draw back against true board displacement, then lift six pixels
		# for a slower, visible reach. Rigid root tips never stretch their basis.
		upper_offset = Vector2(0.0, -1.8 * (0.5 - 0.5 * cos(TAU * 3.0 * t)))
		for name: String in pose:
			if name.begins_with("tendril_"):
				pose[name]["rotation"] = (0.035 if name.ends_with("l") else -0.035) * sin(TAU * t)
	elif clip == "burst":
		var brace: float = _curve(t, PackedVector2Array([Vector2(0, 0), Vector2(0.26, 1), Vector2(0.34, 1), Vector2(BURST_RELEASE, 0), Vector2(1, 0)]))
		var opened: float = _curve(t, PackedVector2Array([Vector2(0, 0), Vector2(0.26, 0.2), Vector2(0.34, 0.25), Vector2(BURST_RELEASE, 1), Vector2(0.55, 1), Vector2(0.9, 0), Vector2(1, 0)]))
		upper_offset = Vector2(0, 3.0 * brace - 2.0 * opened)
		pose["bloom"]["position"] += Vector2(0, -3.0 * opened)
		_open_crown(pose, opened, 1.0)
		for name: String in pose:
			if name.begins_with("tendril_"):
				pose[name]["rotation"] = (0.085 if name.ends_with("l") else -0.085) * (0.6 * brace + opened)
	elif clip == "mark":
		var aimed: float = _curve(t, PackedVector2Array([Vector2(0, 0), Vector2(0.27, 1), Vector2(MARK_RELEASE, 1), Vector2(MARK_CONTACT, 0.75), Vector2(0.92, 0), Vector2(1, 0)]))
		var released: float = _curve(t, PackedVector2Array([Vector2(0, 0), Vector2(MARK_RELEASE - 0.045, 0), Vector2(MARK_RELEASE, 1), Vector2(MARK_CONTACT, 0.45), Vector2(0.8, 0), Vector2(1, 0)]))
		upper_offset = Vector2(0, 1.8 * aimed)
		pose["bloom"]["position"] += aim * (5.0 * aimed - 3.0 * released)
		_open_crown(pose, 0.40 * aimed + 0.45 * released, 0.7)
		pose["core"]["position"] += aim * (2.5 * released)
	pose["trunk"]["position"] += upper_offset
	for contact: String in ["root_l", "root_c", "root_r"]:
		pose[contact]["position"] -= upper_offset
		if clip == "walk":
			var state: Dictionary = walk_foot_state(t, contact, layout, facing)
			pose[contact]["position"] += Vector2(state["target"]) - _point(layout, contact)
	return pose

static func _open_crown(pose: Dictionary, opened: float, near_weight: float) -> void:
	pose["petal_far_l"]["rotation"] = -0.17 * opened
	pose["petal_far_r"]["rotation"] = 0.17 * opened
	pose["petal_near_l"]["rotation"] = -0.13 * opened * near_weight
	pose["petal_near_r"]["rotation"] = 0.13 * opened * near_weight
	pose["petal_near_l"]["position"] += Vector2(-2.0, 1.0) * opened
	pose["petal_near_r"]["position"] += Vector2(2.0, 1.0) * opened
	pose["hidden_calyx"]["visible"] = opened > 0.05

static func walk_cycle_info(_layout: Dictionary, facing: String) -> Dictionary:
	var direction: Vector2 = (Vector2(1.0, -0.5) if facing == "rear" else Vector2(-1.0, 0.5)).normalized()
	return {"direction": direction, "stride_px": STRIDE, "stance_fraction": STANCE,
		"travel_per_cycle": direction * STRIDE / STANCE, "foot_lift_px": 6.0}

static func walk_foot_state(phase: float, foot: String, layout: Dictionary, facing: String) -> Dictionary:
	var offset: float = 0.0 if foot == "root_l" else 1.0 / 3.0 if foot == "root_c" else 2.0 / 3.0
	var t: float = fposmod(phase + offset, 1.0)
	var contact: bool = t <= STANCE
	var distance: float = STRIDE * (0.5 - t / STANCE)
	var lift: float = 0.0
	if not contact:
		var u: float = (t - STANCE) / (1.0 - STANCE)
		var tangent: float = -STRIDE * (1.0 - STANCE) / STANCE
		distance = lerpf(-STRIDE * 0.5, STRIDE * 0.5, u * u * (3.0 - 2.0 * u)) + tangent * (2.0 * u * u * u - 3.0 * u * u + u)
		lift = 6.0 * pow(sin(PI * u), 1.5)
	var direction: Vector2 = walk_cycle_info(layout, facing)["direction"]
	var target: Vector2 = _point(layout, foot) + direction * distance - Vector2(0, lift)
	return {"target": target, "ground_contact": _sole(layout, foot) + direction * distance,
		"contact": contact, "cycle_phase": t, "lift_px": lift, "angle": 0.0}

static func _sole(layout: Dictionary, foot: String) -> Vector2:
	var point: Array = layout["landmarks"]["sole_" + foot.trim_prefix("root_")]
	return Vector2(float(point[0]), float(point[1]))

static func _point(layout: Dictionary, name: String) -> Vector2:
	if name.is_empty():
		return Vector2.ZERO
	var point: Array = layout["joints"][name]["position"]
	return Vector2(float(point[0]), float(point[1]))

static func _parent(layout: Dictionary, name: String) -> String:
	var parent: Variant = layout["joints"][name]["parent"]
	return "" if parent == null else str(parent)

static func _curve(t: float, keys: PackedVector2Array) -> float:
	for index: int in range(1, keys.size()):
		if t <= keys[index].x:
			var u: float = inverse_lerp(keys[index - 1].x, keys[index].x, t)
			return lerpf(keys[index - 1].y, keys[index].y, u * u * (3.0 - 2.0 * u))
	return keys[-1].y
