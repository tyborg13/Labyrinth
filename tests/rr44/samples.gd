extends "res://tests/rr38/samples.gd"

## Include independent lag-input samples for the generated held-item gate.
func record(rig: Node2D, view: String, clip: String, phase: float, frame: int, kind: String) -> Dictionary:
	var row: Dictionary = super.record(rig, view, clip, phase, frame, kind)
	if clip != "move": return row
	var data: Dictionary = Motion.data_for(rig.layout)
	var director: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(rig.case_directory.path_join("director_motion.json")))
	var follow: Dictionary = director["chainbound_gaoler"]["clips"]["move"]["held_follow"]
	var definition: Dictionary = data["clips"][clip]
	var delayed: float = phase - float(follow["lag_s"]) / float(definition["seconds"])
	var reference: Dictionary = {"phase": delayed, "displacement_world": 0.0, "displacement_moving_root": 0.0}
	if delayed >= 0.0:
		var prior: Dictionary = preload("res://scripts/maquette_cutout_runtime/humanoid_motion.gd").world_transforms(data, clip, delayed, rig.layout, view, false, false)
		var forward: Vector2 = Motion.point(data["projection"][view]["forward"])
		var delta: Vector2 = (prior[follow["grip"]] as Transform2D).origin - Motion.point(rig.layout["joints"][follow["grip"]]["position"])
		reference["displacement_world"] = delta.dot(forward)
		delta -= (prior["root"] as Transform2D).origin - Motion.point(rig.layout["joints"]["root"]["position"])
		reference["displacement_moving_root"] = delta.dot(forward)
		# Keep raw delayed transforms for the independent Python body oracle.
		reference["body_hand"] = matrix(prior[follow["grip"]])
		reference["body_torso"] = matrix(prior["torso"])
	row["held_follow_reference"] = reference
	return row
