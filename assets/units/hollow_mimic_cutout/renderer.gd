extends "res://scripts/maquette_cutout_runtime/renderer.gd"

const Rig = preload("rig.gd")
const REST_PATH: String = "res://assets/units/hollow_mimic_cutout/front/rest.png"
const WALK_FRAME_SECONDS: float = 1.0 / 60.0

func _init() -> void:
	character_id = "hollow_mimic"

static func walk_segment_frames(_source_distance: float) -> int:
	return preload("res://scripts/maquette_cutout_runtime/action.gd").frames_for("hollow_mimic", "move")

func _new_rig() -> Node2D:
	return Rig.new()
