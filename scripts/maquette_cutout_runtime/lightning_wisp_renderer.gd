extends "renderer.gd"

const Rig = preload("lightning_wisp_rig.gd")
const REST_PATH: String = "res://assets/units/lightning_wisp_cutout/front/rest.png"
# See shale_bloomer_renderer.gd: preserve travel queries without changing the
# compiled action clock or constructing a legacy presentation renderer.
const Travel = preload("res://scripts/lightning_wisp_cutout/renderer.gd")
const WALK_CYCLE_SECONDS: float = Travel.WALK_CYCLE_SECONDS
const WALK_FRAME_SECONDS: float = Travel.WALK_FRAME_SECONDS

func _init() -> void:
	character_id = "lightning_wisp"

static func walk_cycle_distance() -> float:
	return Travel.walk_cycle_distance()

static func walk_segment_frames(source_distance: float) -> int:
	return Travel.walk_segment_frames(source_distance)
