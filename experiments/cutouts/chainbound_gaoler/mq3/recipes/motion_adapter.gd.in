extends RefCounted

## Production sampler is copied byte-for-byte; this adapter supplies its known
## semantic bones without changing timing, phase curves, tuning or source paint.
const Gaoler = preload("gaoler_motion.gd")

static func _sampler_layout(layout: Dictionary) -> Dictionary:
	var result: Dictionary = layout.duplicate(true)
	var joints: Dictionary = result["joints"]
	var chain: Vector2 = _point(layout, "chain")
	joints["chain_a"] = {"position": [chain.x, chain.y], "parent": "hand_hook"}
	# The registered chain is partitioned at production link fractions.
	joints["chain_b"]["parent"] = "chain_a"
	joints["hook"]["parent"] = "chain_c"
	# Production's restraint drape is absent from this painting. Keep the
	# unmodified solver well-defined using its original (unpainted) landmarks.
	var compatibility: Dictionary = layout["motion_compatibility"]
	for name: String in compatibility["joints"]:
		joints[name] = compatibility["joints"][name]
	result["landmarks"]["drape_end"] = compatibility["drape_end"]
	return result

static func sample_pose(clip: String, phase: float, layout: Dictionary, facing: String) -> Dictionary:
	assert(clip in ["rest", "idle", "walk", "strike", "hit", "death", "chain_reel", "manacle_pin"], "Unknown gaoler clip")
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

static func sample_draw_order(clip: String, _phase: float, layout: Dictionary, facing: String) -> Dictionary:
	var result: Dictionary = {}
	if facing != "rear" or clip not in ["strike", "manacle_pin"]:
		return result
	# All fist-arm paint, including hidden support, passes behind both occluders.
	var behind: int = 4095
	var arm_front: int = -4096
	for part: Dictionary in layout["parts"]:
		if part["bone"] in ["torso", "head"]:
			behind = mini(behind, int(part["z_index"]) - 1)
		if part["bone"] in ["upper_fist", "fore_fist", "hand_fist"]:
			arm_front = maxi(arm_front, int(part["z_index"]))
	var shift: int = maxi(0, arm_front - behind)
	for part: Dictionary in layout["parts"]:
		if part["bone"] in ["upper_fist", "fore_fist", "hand_fist"]:
			result[str(part["name"])] = int(part["z_index"]) - shift
	return result
