extends "res://scripts/maquette_cutout_runtime/rig.gd"

const ShaftSegments = preload("shaft_segments.gd")
var _shaft_segments: RefCounted

func _init() -> void:
	character_id = "frostglass_lancer"

func base_path() -> String:
	return "res://assets/units/frostglass_lancer_cutout/humanoid_v2"

func apply_pose(clip_name: String, phase_value: float) -> void:
	super.apply_pose(clip_name, phase_value)
	if _shaft_segments == null: _shaft_segments = ShaftSegments.new()
	_shaft_segments.apply(self, clip_name, phase_value)

func apply_authored_pose(clip_name: String, phase_value: float) -> void:
	if _shaft_segments != null: _shaft_segments.restore()
	super.apply_authored_pose(clip_name, phase_value)
