extends "res://tests/rr46/clock_scene.gd"

class WalkCounter extends RefCounted:
	var starts: int = 0
	var arrivals: int = 0
	func walk_start(_unit: Dictionary) -> void: starts += 1
	func walk_tile(_unit: Dictionary) -> void: arrivals += 1

var reduced: bool = false
var stride: int = 1

func _ensure_sfx_bank() -> void: _sfx_router = WalkCounter.new()
func _reduced_motion_enabled() -> bool: return reduced

func _play_timed_animation_frames(count: int, seconds: float, render: Callable) -> void:
	scheduled.append({"frames": count, "frame_seconds": seconds, "seconds": count * roundi(seconds * 1000000.0) / 1000000.0})
	for frame: int in range(1, count + 1, stride): render.call(frame)
	if (count - 1) % stride != 0: render.call(count)
