extends "res://scripts/combat_pacing.gd"

## Deterministic wall ticks, integrated through the installed production scale.
const WALL_STEP_USEC: int = 4000
var now_usec: int = 5000000
var wall_usec: int = 0
func presentation_usec() -> int: return now_usec
func present_turn_order(_before: Array, _after: Array, _defeated: Dictionary = {}) -> void: pass
func _process(_delta: float) -> void:
	wall_usec += WALL_STEP_USEC
	now_usec += roundi(WALL_STEP_USEC * Engine.time_scale)
