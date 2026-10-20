extends "res://scripts/maquette_cutout_runtime/rig.gd"

func _init() -> void:
	character_id = "hollow_mimic"

func apply_pose(clip_name: String, phase_value: float) -> void:
	super.apply_pose(clip_name, phase_value)
	if not layout.is_empty(): preload("draw_order.gd").apply(self, clip_name)
