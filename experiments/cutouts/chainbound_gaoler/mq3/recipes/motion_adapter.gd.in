extends RefCounted

## Production sampler is copied byte-for-byte; this adapter supplies its known
## semantic bones without changing timing, phase curves, tuning or source paint.
const Gaoler = preload("gaoler_motion.gd")

static func _sampler_layout(layout: Dictionary) -> Dictionary:
	var result: Dictionary = layout.duplicate(true)
	var joints: Dictionary = result["joints"]
	var chain: Vector2 = _point(layout, "chain")
	joints["chain_a"] = {"position": [chain.x, chain.y], "parent": "hand_hook"}
	# The requested clips only rotate chain_a. The two unpainted compatibility
	# joints may coincide with it; their length does not affect these five clips.
	# No three-link chain-reel animation is claimed for the one-piece maquette.
	joints["chain_b"] = {"position": [chain.x, chain.y], "parent": "chain_a"}
	joints["chain_c"] = {"position": [chain.x, chain.y], "parent": "chain_b"}
	joints["hook"]["parent"] = "chain_c"
	# Production's restraint drape is absent from this painting. Keep the
	# unmodified solver well-defined using its original (unpainted) landmarks.
	var compatibility: Dictionary = layout["motion_compatibility"]
	for name: String in compatibility["joints"]:
		joints[name] = compatibility["joints"][name]
	result["landmarks"]["drape_end"] = compatibility["drape_end"]
	return result

static func sample_pose(clip: String, phase: float, layout: Dictionary, facing: String) -> Dictionary:
	assert(clip in ["rest", "idle", "walk", "strike", "hit", "death"], "This case has no painted topology for the other gaoler actions")
	var compatible: Dictionary = _sampler_layout(layout)
	var sampled: Dictionary = Gaoler.sample_pose(clip, phase, compatible, facing)
	var pose: Dictionary = {}
	for name: String in layout["joints"]:
		pose[name] = sampled["chain_a" if name == "chain" else name]
	return pose

static func walk_cycle_info(layout: Dictionary, facing: String) -> Dictionary:
	return Gaoler.walk_cycle_info(layout, facing)

static func walk_foot_state(phase: float, foot: String, layout: Dictionary, facing: String) -> Dictionary:
	return Gaoler.walk_foot_state(phase, foot, layout, facing)

static func _point(layout: Dictionary, name: String) -> Vector2:
	var point: Array = layout["joints"][name]["position"]
	return Vector2(float(point[0]), float(point[1]))
