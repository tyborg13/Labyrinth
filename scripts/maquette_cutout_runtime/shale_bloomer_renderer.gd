extends "renderer.gd"

const Rig = preload("shale_bloomer_rig.gd")
const REST_PATH: String = "res://assets/units/shale_bloomer_cutout/front/rest.png"
# Retain the travel query API used outside presentation. Gameplay's maquette
# action adapter still owns the approved compiled move duration.
const Travel = preload("res://scripts/bile_bloomer_cutout/renderer.gd")
const WALK_CYCLE_SECONDS: float = Travel.WALK_CYCLE_SECONDS
const WALK_FRAME_SECONDS: float = Travel.WALK_FRAME_SECONDS

func _init() -> void:
	character_id = "shale_bloomer"

static func walk_cycle_distance() -> float:
	return Travel.walk_cycle_distance()

static func walk_segment_frames(source_distance: float) -> int:
	return Travel.walk_segment_frames(source_distance)
