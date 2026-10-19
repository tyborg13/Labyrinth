extends RefCounted

## Case-authored tie-breaks for straight legs. Bent legs keep their rest side.
const COLLINEAR_EPSILON: float = 0.000001

static func leg_policy(joints: Dictionary, policies: Dictionary, side: String, facing: String, knee_policy: Dictionary = {}) -> Dictionary:
	var a := Vector2(joints["thigh_" + side]["position"][0], joints["thigh_" + side]["position"][1])
	var b := Vector2(joints["shin_" + side]["position"][0], joints["shin_" + side]["position"][1])
	var c := Vector2(joints["foot_" + side]["position"][0], joints["foot_" + side]["position"][1])
	var lengths: float = a.distance_to(b) * b.distance_to(c)
	var tag: String = "legs.%s.%s.bend_side" % [side, facing]
	if lengths <= 0.0: return {"error": tag + ": zero-length rest segment"}
	var cross: float = (c - a).cross(b - a)
	var rest_side: float = signf(cross) if absf(cross) > COLLINEAR_EPSILON * lengths else 0.0
	var threshold: float = float(knee_policy.get("near_straight_deg", 0.0))
	if threshold > 0.0 and absf(rad_to_deg((b - a).angle_to(c - b))) <= threshold:
		rest_side = 0.0
	var authored: Variant = policies.get(side, {}).get(facing, {}).get("bend_side")
	if authored != null and (typeof(authored) not in [TYPE_INT, TYPE_FLOAT] or float(authored) not in [-1.0, 1.0]):
		return {"error": tag + ": expected explicit -1 or 1"}
	if rest_side == 0.0 and authored == null:
		return {"error": tag + ": required for straight rest leg"}
	if rest_side != 0.0 and authored != null and float(authored) != rest_side:
		return {"error": tag + ": disagrees with rest bend side"}
	return {"bend_side": rest_side if rest_side != 0.0 else float(authored)}
