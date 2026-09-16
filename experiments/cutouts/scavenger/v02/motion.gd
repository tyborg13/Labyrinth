extends RefCounted
## A coordinated breath with counter-moving arms, a planted lower body and a
## short settling delay at the grip/sack. No whole-rig or cloth-wave movement.
const IDLE_SECONDS: float = 1.8
static func sample_pose(clip: String, phase: float, layout: Dictionary, _facing: String) -> Dictionary:
	if clip != "idle": return {}
	var beat: float = TAU * phase
	var breath: float = (1.0 - cos(beat)) * 0.5
	var follow: float = (cos(0.28) - cos(beat - 0.28)) * 0.5
	var pose: Dictionary = {}
	for name: String in layout["joints"]:
		var joint: Dictionary = layout["joints"][name]
		var point := Vector2(joint["position"][0], joint["position"][1])
		if joint["parent"] != null:
			var parent: Array = layout["joints"][joint["parent"]]["position"]
			point -= Vector2(parent[0], parent[1])
		var angle: float = 0.0
		match name:
			"chest": point.y -= 0.65 * breath
			"head":
				point += Vector2(0.25, -1.45) * breath
				angle = -0.020 * breath
			"grip_shoulder": point.y += 0.7 * breath
			"grip_forearm": point += Vector2(0.5, 1.7) * follow
			"grip_hand": point += Vector2(-0.25, -0.9) * follow
			"hanging_shoulder": point.y += 1.0 * follow
			"hanging_forearm": point.y += 0.9 * follow
			"hanging_hand": point.y -= 0.4 * follow
			"lantern": point.y += 0.3 * follow
			"pack": point.y += 1.0 * follow
		pose[name] = {"position": point, "rotation": angle}
	return pose
