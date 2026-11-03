extends RefCounted

## Optional constrained presentation rounding. Independent rounding can invert
## a straight chain even when the continuous solve has the declared bend side.
## Select the nearest legal elbow from the same one-pixel rounding lattice.
static func apply(world: Dictionary, authored: Dictionary, joints: Dictionary, policy: Dictionary, facing: String, forward: Vector2) -> void:
	if not facing in policy.get("views", []): return
	var flex_sign: float = -signf(forward.x)
	for side: String in ["near", "far"]:
		if not side in policy.get("sides", []): continue
		var upper: String = "upper_" + side
		var fore: String = "fore_" + side
		var hand: String = "hand_" + side
		var a: Vector2 = (world[upper] as Transform2D).origin
		var c: Vector2 = (world[hand] as Transform2D).origin
		var b: Vector2 = (world[fore] as Transform2D).origin
		var limit: float = -float(policy["max_hyperextension_deg"])
		if flexion(a, b, c, flex_sign) >= limit: continue
		var bind: Vector2 = Vector2(joints[fore]["position"][0], joints[fore]["position"][1])
		var target: Vector2 = (authored[fore] as Transform2D).origin
		var closest: Vector2 = b
		var distance: float = INF
		# Adjacent lattice points exhaust the presentation rounding error box.
		for dx: int in [-1, 0, 1]:
			for dy: int in [-1, 0, 1]:
				var candidate: Vector2 = bind + (b - bind).round() + Vector2(dx, dy)
				if flexion(a, candidate, c, flex_sign) < limit: continue
				var error: float = target.distance_squared_to(candidate)
				if error < distance:
					closest = candidate
					distance = error
		if is_inf(distance):
			push_error("elbow_policy: no legal adjacent rounding for " + side)
			continue
		var changed: Transform2D = world[fore]
		changed.origin = closest
		world[fore] = changed

static func flexion(a: Vector2, b: Vector2, c: Vector2, flex_sign: float) -> float:
	return rad_to_deg((b - a).angle_to(c - b)) * flex_sign
