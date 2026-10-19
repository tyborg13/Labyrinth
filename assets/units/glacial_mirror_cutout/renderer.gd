extends "res://scripts/maquette_cutout_runtime/renderer.gd"

const Rig = preload("rig.gd")
const REST_PATH: String = "res://assets/units/glacial_mirror_cutout/humanoid_v2/front/rest.png"
const WALK_FRAME_SECONDS: float = 1.0 / 60.0
const WALK_CYCLE_SECONDS: float = 0.85 # Protected rr-18 move duration.

func _init() -> void:
	character_id = "glacial_mirror"

static func walk_segment_frames(_source_distance: float) -> int:
	return roundi(WALK_CYCLE_SECONDS / WALK_FRAME_SECONDS)

func _new_rig() -> Node2D:
	return Rig.new()

func motion_data() -> Dictionary:
	return Motion.data_for({"motion_data": "res://assets/units/glacial_mirror_cutout/humanoid_v2/compiled_motion.json"})
