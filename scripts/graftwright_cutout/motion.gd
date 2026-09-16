extends RefCounted
## A single breathing beat; local offsets separate the head and occupied hand
## without a traveling cloth wave or whole-paint translation.
static func sample_pose(clip: String, phase: float, layout: Dictionary, _facing: String) -> Dictionary:
	if clip != "idle": return {}
	var beat: float = TAU * phase
	var breath: float = (1.0 - cos(beat)) * 0.5
	var pose: Dictionary = {}
	for name: String in layout["joints"]:
		var joint: Dictionary = layout["joints"][name]
		var point: Vector2 = Vector2(joint["position"][0], joint["position"][1])
		if joint["parent"] != null:
			var parent: Array = layout["joints"][joint["parent"]]["position"]
			point -= Vector2(parent[0], parent[1])
		match name:
			"chest": point.y -= 1.4 * breath
			"head": point.y -= 0.9 * breath
			"needle_hand": point.y -= 1.2 * (1.0 - cos(beat - 0.28)) * 0.5
			"lantern": point.y -= 0.24 * (1.0 - cos(beat - 0.14)) * 0.5
		pose[name] = {"position": point}
	return pose
