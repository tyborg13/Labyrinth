extends RefCounted

## A rigid energy core carries its entire lightning envelope during hover.
## Outer branch meshes blend to the fixed core at their roots, so gathering
## electricity exposes no missing paint and never deforms the aperture.
static func _bind(layout: Dictionary, name: String) -> Vector2:
	var joint: Dictionary = layout["joints"][name]
	var point := Vector2(joint["position"][0], joint["position"][1])
	var parent: Variant = joint.get("parent")
	if parent != null:
		var origin: Array = layout["joints"][str(parent)]["position"]
		point -= Vector2(origin[0], origin[1])
	return point

static func _curve(phase: float, keys: PackedVector2Array) -> float:
	for i: int in range(1, keys.size()):
		if phase <= keys[i].x:
			var t: float = smoothstep(keys[i - 1].x, keys[i].x, phase)
			return lerpf(keys[i - 1].y, keys[i].y, t)
	return keys[-1].y

static func walk_cycle_info(_layout: Dictionary, facing: String) -> Dictionary:
	return {"travel_per_cycle": Vector2(-160, 80) if facing == "front" else Vector2(160, -80)}

static func sample_pose(clip: String, phase: float, layout: Dictionary, facing: String) -> Dictionary:
	var pose: Dictionary = {}
	for name: String in layout["joints"]:
		pose[name] = {"position": _bind(layout, name)}
	if clip in ["hit", "death"]:
		return _contextual_pose(pose,layout,facing,clip,clampf(phase,0.0,1.0))
	var core_offset := Vector2.ZERO
	var gather: float = 0.0
	var release: float = 0.0
	var aimed := Vector2(-1, .5) if facing == "front" else Vector2(1, -.5)
	match clip:
		"idle":
			core_offset.y = -2.4 * (1.0 - cos(TAU * phase)) * .5
		"walk":
			# Distance-driven coherent flight, with no pseudo-footsteps or ripple.
			core_offset.y = -1.6 * (1.0 - cos(TAU * phase)) * .5
		"attack":
			var dart: float = _curve(phase, PackedVector2Array([Vector2(0,0),Vector2(.28,-5),Vector2(.42,18),Vector2(.57,14),Vector2(1,0)]))
			core_offset = aimed * dart
			gather = _curve(phase, PackedVector2Array([Vector2(0,0),Vector2(.28,1),Vector2(.42,0),Vector2(1,0)]))
			release = _curve(phase, PackedVector2Array([Vector2(0,0),Vector2(.28,0),Vector2(.42,1),Vector2(.7,0),Vector2(1,0)]))
		"cast":
			gather = _curve(phase, PackedVector2Array([Vector2(0,0),Vector2(.36,1),Vector2(.5,0),Vector2(1,0)]))
			release = _curve(phase, PackedVector2Array([Vector2(0,0),Vector2(.36,0),Vector2(.5,1),Vector2(.68,.5),Vector2(1,0)]))
			core_offset = -aimed * (4.0 * gather + 2.0 * release)
	pose["core"]["position"] += core_offset
	for name: String in ["crown", "tail", "arc_left", "arc_right"]:
		var inward: Vector2 = -_bind(layout, name).normalized()
		pose[name]["position"] += inward * gather * 6.0 + aimed * release * 9.0
	return pose

static func _contextual_pose(pose: Dictionary, layout: Dictionary, facing: String, clip: String, t: float) -> Dictionary:
	var amount: float = _reaction_amount(clip, t)
	var forward := Vector2(-1,.5) if facing == "front" else Vector2(1,-.5)
	var fallen: bool = clip == "death"
	# The aperture stays rigid as its connected electric branches gutter inward.
	# The extinguishing body sinks toward its shadow before the dissolve takes it.
	pose["core"]["position"] += Vector2(0,24) * amount if fallen else -forward * 9.0 * amount
	for name: String in ["crown","tail","arc_left","arc_right"]:
		pose[name]["position"] += -_bind(layout,name).normalized() * (6.0 if fallen else 4.0) * amount
	return pose

# The recoil peaks at impact and fully recovers. Defeat settles before its final
# sample, so the board can hold this pose throughout the existing shadow dissolve.
static func _reaction_amount(clip: String, t: float) -> float:
	if clip == "death":
		return _curve(t, PackedVector2Array([Vector2(0,0),Vector2(0.18,0.12),Vector2(0.66,0.96),Vector2(0.84,1),Vector2(1,1)]))
	return _curve(t, PackedVector2Array([Vector2(0,0),Vector2(0.15,1),Vector2(0.48,0.28),Vector2(0.76,-0.08),Vector2(1,0)]))
