extends RefCounted

## New creatures begin with their own joint graph. Add only requested clips;
## the humanoid protagonist's bone names and dimensions are not prerequisites.
static func sample_pose(_clip: String, _phase: float, layout: Dictionary, _facing: String) -> Dictionary:
	var result: Dictionary = {}
	for bone_name: String in layout["joints"]:
		var joint: Dictionary = layout["joints"][bone_name]
		var point: Vector2 = Vector2(joint["position"][0], joint["position"][1])
		if joint.get("parent") != null:
			var parent_point: Array = layout["joints"][joint["parent"]]["position"]
			point -= Vector2(parent_point[0], parent_point[1])
		result[bone_name] = {"position": point, "rotation": 0.0}
	return result

static func walk_cycle_info(_layout: Dictionary, _facing: String) -> Dictionary:
	return {"travel_per_cycle": Vector2(16, 0)}
