extends RefCounted
## One coordinated upper-body breath over the planted lower silhouette.
## The occupied hand, pack and lantern share the chest motion without ripple.
const IDLE_SECONDS: float = 1.8
static func sample_pose(clip: String, phase: float, layout: Dictionary, _facing: String) -> Dictionary:
	if clip != "idle": return {}
	var beat: float = TAU * phase
	var breath: float = (1.0 - cos(beat)) * 0.5
	var pose: Dictionary = {}
	for name: String in layout["joints"]:
		var joint: Dictionary = layout["joints"][name]
		var point := Vector2(joint["position"][0], joint["position"][1])
		if joint["parent"] != null:
			var parent: Array = layout["joints"][joint["parent"]]["position"]
			point -= Vector2(parent[0], parent[1])
		if name == "chest": point.y -= 1.2 * breath
		pose[name] = {"position": point, "rotation": 0.0}
	return pose
