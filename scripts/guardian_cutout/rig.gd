extends "res://scripts/protagonist_cutout/rig.gd"
const GuardianMotion = preload("res://scripts/guardian_cutout/motion.gd")
var character_id: String = ""
func _layout_path(which: String) -> String:
	return "res://assets/units/guardians/%s/%s.json" % [character_id, which]
func _resolve(path: String) -> String:
	return path if path.begins_with("res://") else "res://assets/units/guardians/%s/%s" % [character_id, path]
func apply_pose(clip_name: String, phase_value: float) -> void:
	var pose: Dictionary = GuardianMotion.sample_pose(clip_name, phase_value, layout, facing)
	_apply_sampled_pose(pose)
