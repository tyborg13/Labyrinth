extends "res://scripts/maquette_cutout_runtime/humanoid_renderer.gd"

## Front-only proof adapter, never production-facing fallback policy.
func _init() -> void:
	character_id = "hoarfrost_seer"
	humanoid_case = "res://experiments/cutouts/hoarfrost_seer/rr10"

func _apply_pose() -> void:
	facing = "front"
	mirrored = false
	super._apply_pose()
