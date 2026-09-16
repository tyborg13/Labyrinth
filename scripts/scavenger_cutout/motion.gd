extends RefCounted
## Small coordinated breath with planted lower body, carried pack and steady grip.
static func sample_pose(clip: String, phase: float, layout: Dictionary, _facing: String) -> Dictionary:
	if clip != "idle": return {}
	var breath: float = (1.0 - cos(TAU * phase)) * 0.5
	var pose: Dictionary = {}
	for name: String in layout["joints"]:
		var joint: Dictionary = layout["joints"][name]
		var point := Vector2(joint["position"][0], joint["position"][1])
		if joint["parent"] != null:
			var parent: Array = layout["joints"][joint["parent"]]["position"]
			point -= Vector2(parent[0], parent[1])
		if name == "chest": point.y -= 0.9 * breath
		if name == "head": point.y -= 0.65 * breath
		pose[name] = {"position": point}
	return pose
