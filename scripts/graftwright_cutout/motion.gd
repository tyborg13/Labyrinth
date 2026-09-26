extends RefCounted
## A single coordinated breathing beat over the fixed bench and lower body.
## Head, lantern and occupied hand inherit it without separate undulation.
static func sample_pose(clip: String, phase: float, layout: Dictionary, _facing: String) -> Dictionary:
	if clip == "graft": return _graft_pose(phase, layout)
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
		if name == "chest": point.y -= 1.4 * breath
		pose[name] = {"position": point}
	return pose

## Elbow-led presentation, held while the card travels, then a soft recovery.
## Rotate the occupied forearm about its painted cuff; never translate the root.
static func _graft_pose(phase: float, layout: Dictionary) -> Dictionary:
	var seconds: float = clampf(phase, 0.0, 1.0) * 2.96
	var reach: float = smoothstep(0.02, 0.43, seconds) * (1.0 - smoothstep(2.20, 2.91, seconds))
	var angle: float = 0.40 * reach
	var pose: Dictionary = {}
	for name: String in layout["joints"]:
		var joint: Dictionary = layout["joints"][name]
		var point := Vector2(joint["position"][0], joint["position"][1])
		var parent_position := Vector2.ZERO
		if joint["parent"] != null:
			var parent: Array = layout["joints"][joint["parent"]]["position"]
			parent_position = Vector2(parent[0], parent[1])
		if name == "needle_hand":
			var elbow := Vector2(140, 146)
			point = elbow + (point - elbow).rotated(angle)
		pose[name] = {"position": point - parent_position, "rotation": angle if name == "needle_hand" else 0.0}
	return pose

# The occupied hand crosses the workbench frame only during the deliberate
# gesture. Returning to idle restores the ordinary NPC/bench ordering.
static func sample_draw_order(clip: String, _phase: float, _layout: Dictionary, _facing: String) -> Dictionary:
	return {"Skin_needle_hand": 3 if clip == "graft" else 0}
