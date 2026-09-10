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
