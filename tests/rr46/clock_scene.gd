extends "res://scripts/run_scene.gd"

## Execute the production path planner without sleeping, rendering or audio.
## The scheduled microseconds are the same ones consumed by the live runner.
class SilentRouter extends RefCounted:
	func walk_start(_unit: Dictionary) -> void: pass
	func walk_tile(_unit: Dictionary) -> void: pass

var scheduled: Array[Dictionary]
var submissions: Array[Dictionary]

func _ready() -> void: pass
func _ensure_sfx_bank() -> void: _sfx_router = SilentRouter.new()
func _render_board_state(_state: Dictionary, shown: Dictionary, _validated: bool = false) -> void:
	submissions.append(shown)

func _play_timed_animation_frames(count: int, seconds: float, render: Callable) -> void:
	scheduled.append({"frames": count, "frame_seconds": seconds, "seconds": count * roundi(seconds * 1000000.0) / 1000000.0})
	for frame: int in range(1, count + 1): render.call(frame)
