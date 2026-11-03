extends "res://experiments/cutouts/chainbound_gaoler/rr49/fixtures/submission_2bd5ea39a/legacy_rig.gd"

func _init() -> void:
	character_id = "hollow_mimic"

func apply_pose(clip_name: String, phase_value: float) -> void:
	super.apply_pose(clip_name, phase_value)
	if not layout.is_empty(): preload("res://assets/units/hollow_mimic_cutout/draw_order.gd").apply(self, clip_name)
