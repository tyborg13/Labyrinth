extends RefCounted

static func present(renderer: Node, motion: Dictionary) -> bool:
	var requested: String = str(motion.get("clip", ""))
	if requested not in ["hit", "block", "death"]:
		return false
	if not bool(renderer.get("active")) and requested != "death":
		return false
	# Reactions preserve the last facing, including the death's entire dissolve.
	renderer.set("clip", requested)
	renderer.set("phase", clampf(float(motion.get("phase", 0.0)), 0.0, 1.0))
	renderer.call("_apply_pose")
	return true

static func apply_pose(rig: Node2D, clip: String, phase: float, reduced: bool) -> void:
	var reaction: bool = clip in ["hit", "block", "death"]
	if not reaction or reduced:
		if rig.has_meta("reaction_blend"):
			rig.remove_meta("reaction_blend")
		rig.call("apply_pose", clip, phase)
		return
	var state: Dictionary = rig.get_meta("reaction_blend", {})
	if str(state.get("clip", "")) != clip or phase + 0.001 < float(state.get("phase", 0.0)):
		var transforms: Dictionary = {}
		for bone_name: String in rig.get("bones"):
			transforms[bone_name] = (rig.get("bones")[bone_name] as Bone2D).transform
		state = {"clip": clip, "source": transforms}
	state["phase"] = phase
	rig.set_meta("reaction_blend", state)
	rig.call("apply_pose", clip, phase)
	# Blend out of the actual preceding pose, rather than snapping from an
	# interrupted swing or recoil to the reaction's neutral first key.
	var weight: float = smoothstep(0.0, 0.12, phase)
	if weight < 1.0:
		var source: Dictionary = state["source"]
		for bone_name: String in source:
			var bone: Bone2D = rig.get("bones")[bone_name]
			bone.transform = (source[bone_name] as Transform2D).interpolate_with(bone.transform, weight)
