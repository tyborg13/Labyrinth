extends RefCounted

## Dust Acolyte: a planted robed caster, with a single open-hand ember.
## No weapon graph, weapon rotation or independent idle cloth oscillation.
const STANCE: float = 0.60
const STRIDE: float = 72.0
const RELEASE: float = 0.18
const CONTACT: float = 0.66

static func sample_pose(clip: String, phase: float, layout: Dictionary, facing: String) -> Dictionary:
	var pose: Dictionary = {}
	for name: String in layout["joints"]:
		pose[name] = {"position": point(layout, name) - point(layout, parent(layout, name)),
			"rotation": 0.0, "scale": Vector2.ONE, "skew": 0.0}
	var t: float = clampf(phase, 0.0, 1.0)
	var toward: float = 1.0 if facing == "rear" else -1.0
	if clip == "idle":
		# One upper-body translation settles the continuous robe against fixed
		# hem controls. Hood, sleeves, hands and ember never rotate separately.
		pose["torso"]["position"].y -= 1.2 * (0.5 - 0.5 * cos(TAU * t))
	elif clip == "walk":
		pose["torso"]["position"] += Vector2(0.6 * sin(TAU * t), -1.8 * (0.5 - 0.5 * cos(2.0 * TAU * t)))
		for hem: String in ["hem_l", "hem_r"]:
			var state: Dictionary = walk_foot_state(t, hem, layout, facing)
			pose[hem]["position"] = Vector2(state["target"]) - point(layout, "root")
	elif clip in ["dust_bolt", "siphon"]:
		var gather: float = curve(t, PackedVector2Array([Vector2(0, 0), Vector2(0.12, 1), Vector2(0.15, 1), Vector2(RELEASE, 0), Vector2(1, 0)]))
		var release: float = curve(t, PackedVector2Array([Vector2(0, 0), Vector2(0.15, 0), Vector2(RELEASE, 1), Vector2(0.36, 0.85), Vector2(CONTACT, 0.45), Vector2(1, 0)]))
		var draw_back: float = 0.0
		if clip == "siphon":
			# The ranged outcome remains at CONTACT. Only then does the open
			# palm gather back toward the chest before the existing heal step.
			draw_back = curve(t, PackedVector2Array([Vector2(0, 0), Vector2(CONTACT, 0), Vector2(0.83, 1), Vector2(1, 0)]))
		pose["torso"]["position"] += Vector2(toward * (1.5 * release - draw_back), -0.8 * gather)
		pose["cast_hand"]["position"] += Vector2(toward * (-7.0 * gather + 13.0 * release - 10.0 * draw_back), -6.0 * gather - 2.0 * release - 5.0 * draw_back)
		pose["orb"]["position"] += Vector2(toward * 2.0 * release, 5.0 * gather - 2.0 * release + 3.0 * draw_back)
		pose["orb"]["scale"] = Vector2.ONE * (1.0 + 0.14 * gather - 0.12 * release + 0.16 * draw_back)
	return pose

static func walk_cycle_info(_layout: Dictionary, facing: String) -> Dictionary:
	var direction: Vector2 = (Vector2(1, -0.5) if facing == "rear" else Vector2(-1, 0.5)).normalized()
	return {"direction": direction, "stride_px": STRIDE, "stance_fraction": STANCE,
		"travel_per_cycle": direction * STRIDE / STANCE, "foot_lift_px": 3.0}

static func walk_foot_state(phase: float, hem: String, layout: Dictionary, facing: String) -> Dictionary:
	var t: float = fposmod(phase + (0.5 if hem == "hem_l" else 0.0), 1.0)
	var contact: bool = t <= STANCE
	var distance: float = STRIDE * (0.5 - t / STANCE)
	var lift: float = 0.0
	if not contact:
		var u: float = (t - STANCE) / (1.0 - STANCE)
		var tangent: float = -STRIDE * (1.0 - STANCE) / STANCE
		distance = lerpf(-STRIDE * 0.5, STRIDE * 0.5, u * u * (3.0 - 2.0 * u)) + tangent * (2.0*u*u*u - 3.0*u*u + u)
		lift = 3.0 * pow(sin(PI * u), 1.5)
	var ground: Vector2 = point(layout, hem) + Vector2(walk_cycle_info(layout, facing)["direction"]) * distance
	return {"target": ground - Vector2(0, lift), "ground_contact": ground,
		"contact": contact, "cycle_phase": t, "lift_px": lift, "angle": 0.0}

static func point(layout: Dictionary, name: String) -> Vector2:
	if name.is_empty():
		return Vector2.ZERO
	var p: Array = layout["joints"][name]["position"]
	return Vector2(float(p[0]), float(p[1]))

static func parent(layout: Dictionary, name: String) -> String:
	var value: Variant = layout["joints"][name]["parent"]
	return "" if value == null else str(value)

static func curve(t: float, keys: PackedVector2Array) -> float:
	for index: int in range(1, keys.size()):
		if t <= keys[index].x:
			var u: float = inverse_lerp(keys[index-1].x, keys[index].x, t)
			return lerpf(keys[index-1].y, keys[index].y, u*u*(3.0-2.0*u))
	return keys[-1].y
