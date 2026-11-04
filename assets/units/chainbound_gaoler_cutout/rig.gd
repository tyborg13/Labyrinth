extends "res://scripts/maquette_cutout_runtime/rig.gd"

func _init() -> void:
	character_id = "chainbound_gaoler"

func base_path() -> String:
	return case_directory if not case_directory.is_empty() else "res://assets/units/chainbound_gaoler_cutout/humanoid_v2"

func apply_authored_pose(clip_name: String, phase_value: float) -> void:
	super.apply_authored_pose(clip_name, phase_value)
	preload("held_contract.gd").apply(self, clip_name, phase_value)

func apply_pose(clip_name: String, phase_value: float) -> void:
	super.apply_pose(clip_name, phase_value)
	preload("held_contract.gd").apply(self, clip_name, phase_value)
