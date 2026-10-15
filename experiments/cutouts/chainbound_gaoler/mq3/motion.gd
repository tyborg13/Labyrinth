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
	var lean: Dictionary = layout.get("rear_torso_lean", {})
	if facing == "rear" and clip in lean.get("clips", []):
		var envelopes: Vector2 = _punch_envelopes(clip, phase)
		var shoulder: Array = lean["shoulder_offset_per_prep"]
		sampled["torso"]["rotation"] += float(lean["rotation_rad_per_hit"]) * envelopes.y
		sampled["upper_fist"]["position"] += Vector2(float(shoulder[0]), float(shoulder[1])) * envelopes.x
	if facing == "rear" and clip in ["strike", "manacle_pin"]:
		var curve: Array = layout.get("rear_fist_constraint", {}).get("clips", {}).get(clip, [])
		if not curve.is_empty():
			var offset: Vector2 = _constraint_offset(curve, phase)
			var parent: Transform2D = Gaoler._world(sampled, compatible, "torso")
			sampled["upper_fist"]["position"] += parent.basis_xform_inv(offset)
	var pose: Dictionary = {}
	for name: String in layout["joints"]:
		pose[name] = sampled["chain_a" if name == "chain" else name]
	return pose

static func _punch_envelopes(clip: String, phase: float) -> Vector2:
	# Reuse production timing. Pin calls its punch envelope "cast".
	if clip == "strike":
		return Vector2(
			Gaoler._curve(phase, PackedVector2Array([Vector2(0,0),Vector2(0.22,1),Vector2(0.30,1),Vector2(0.42,0),Vector2(1,0)])),
			Gaoler._curve(phase, PackedVector2Array([Vector2(0,0),Vector2(0.30,0),Vector2(0.42,1),Vector2(0.56,1),Vector2(1,0)])))
	return Vector2(
		Gaoler._curve(phase, PackedVector2Array([Vector2(0,0),Vector2(0.08,1),Vector2(4.0/38.0,0),Vector2(1,0)])),
		Gaoler._curve(phase, PackedVector2Array([Vector2(0,0),Vector2(0.08,0),Vector2(4.0/38.0,1),Vector2(12.0/38.0,1),Vector2(0.65,0.55),Vector2(1,0)])))

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
	# All fist-arm paint, including hidden support, passes behind the body union.
	var behind: int = 4095
	var arm_front: int = -4096
	for part: Dictionary in layout["parts"]:
		if part.get("logical_part", part["name"]) in ["torso", "head", "coat_near", "coat_far"]:
			behind = mini(behind, int(part["z_index"]) - 1)
		if part["bone"] in ["upper_fist", "fore_fist", "hand_fist"]:
			arm_front = maxi(arm_front, int(part["z_index"]))
	var shift: int = maxi(0, arm_front - behind)
	for part: Dictionary in layout["parts"]:
		if part["bone"] in ["upper_fist", "fore_fist", "hand_fist"]:
			result[str(part["name"])] = int(part["z_index"]) - shift
	return result

static func _constraint_offset(curve: Array, phase: float) -> Vector2:
	for index: int in range(1, curve.size()):
		if phase <= float(curve[index]["phase"]):
			var a: Array = curve[index - 1]["offset"]
			var b: Array = curve[index]["offset"]
			var weight: float = inverse_lerp(float(curve[index - 1]["phase"]), float(curve[index]["phase"]), phase)
			return Vector2(float(a[0]), float(a[1])).lerp(Vector2(float(b[0]), float(b[1])), weight)
	var last: Array = curve[-1]["offset"]
	return Vector2(float(last[0]), float(last[1]))
