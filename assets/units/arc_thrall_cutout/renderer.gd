extends "res://scripts/maquette_cutout_runtime/renderer.gd"

const Rig = preload("rig.gd")
const REST_PATH: String = "res://assets/units/arc_thrall_cutout/front/rest.png"
const WALK_FRAME_SECONDS: float = 1.0 / 60.0
const WALK_CYCLE_SECONDS: float = 0.85 # Protected rr-07 move duration.

func _init() -> void:
	character_id = "arc_thrall"

static func walk_segment_frames(_source_distance: float) -> int:
	return roundi(WALK_CYCLE_SECONDS / WALK_FRAME_SECONDS)
