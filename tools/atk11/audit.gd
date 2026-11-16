extends "res://tools/atk06/audit.gd"
## Same real-scene audit and in-run pairing, with accelerated headless presentation
## only. Rule execution, cursor slices, source states, measurements and native
## captures use their production paths. These are debug-only harness defaults.
const PROOF_TIME_SCALE: float = 64.0
const PROOF_MAX_FPS: int = 0
func _initialize() -> void:
	super._initialize()
	Engine.time_scale = PROOF_TIME_SCALE
	Engine.max_fps = PROOF_MAX_FPS
