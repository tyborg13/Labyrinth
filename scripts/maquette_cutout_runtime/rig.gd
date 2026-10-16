extends "res://scripts/protagonist_cutout/rig.gd"

const SemanticMotion = preload("motion.gd")
var character_id: String = "shale_bloomer"
var case_directory: String = ""

func base_path() -> String:
	return case_directory if not case_directory.is_empty() else "res://assets/units/" + character_id + "_cutout"

func _layout_path(which: String) -> String:
	return base_path().path_join("layouts/" + which + ".json" if not case_directory.is_empty() else which + ".json")

func _resolve(path: String) -> String:
	return path if path.begins_with("res://") or path.begins_with("user://") or path.is_absolute_path() else base_path().path_join(path)

func apply_pose(clip_name: String, phase_value: float) -> void:
	layout["motion_data"] = base_path().path_join("compiled_motion.json")
	var pose: Dictionary = SemanticMotion.sample_pose(clip_name, phase_value, layout, facing)
	_apply_sampled_pose(pose, true)
	for bone: String in bones:
		(bones[bone] as Bone2D).modulate.a = float(pose.get(bone, {}).get("alpha", 1.0))
