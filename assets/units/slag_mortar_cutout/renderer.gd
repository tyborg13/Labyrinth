extends "res://scripts/maquette_cutout_runtime/renderer.gd"

const Rig = preload("rig.gd")
const Action = preload("res://scripts/maquette_cutout_runtime/action.gd")
const WALK_FRAME_SECONDS: float = 1.0 / Action.FPS
const REST_PATH: String = "res://assets/units/slag_mortar_cutout/humanoid_v2/front/rest.png"

func _init() -> void:
	character_id = "slag_mortar"

static func walk_segment_frames(_source_distance: float) -> int:
	return Action.frames_for("slag_mortar", "move")

func _new_rig() -> Node2D:
	return Rig.new()

func motion_data() -> Dictionary:
	return Motion.data_for({"motion_data": "res://assets/units/slag_mortar_cutout/humanoid_v2/compiled_motion.json"})
