extends "res://tests/fixtures/gust_shrike_capture_scene.gd"

## Headless proof controls elapsed time only. All production move callbacks,
## sound routing and combat-pacing phase hooks execute normally.
var walk_proof_active: bool = false
var walk_proof_frames: Array[Dictionary]
var walk_proof_clocks: Array[Dictionary]
var walk_proof_cues: Array[Dictionary]
var walk_proof_frame: int = 0
var walk_proof_seconds: float = 0.0

func _play_timed_animation_frames(frame_count: int, frame_seconds: float, render_frame: Callable) -> void:
	if not walk_proof_active:
		await super._play_timed_animation_frames(frame_count, frame_seconds, render_frame)
		return
	walk_proof_clocks.append({"count": frame_count, "frame_seconds": frame_seconds})
	for frame: int in range(1, frame_count + 1):
		walk_proof_frame = frame
		walk_proof_seconds = frame * frame_seconds
		render_frame.call(frame)
		_combat_pacing.fixed_usec += roundi(frame_seconds * 1000000.0)
	await get_tree().process_frame

func _render_board_state(display_state: Dictionary, presentation: Dictionary, stable: bool = false) -> void:
	if not walk_proof_active:
		super._render_board_state(display_state, presentation, stable)
		return
	if not presentation.has("last_lamplighter_motion"): return
	var position: Vector2 = presentation["unit_world_positions"]["enemy_1"]
	walk_proof_frames.append({"frame": walk_proof_frame, "seconds": walk_proof_seconds,
		"position": [position.x, position.y], "phase": _combat_pacing._phase})

func walk_proof_cue(cue: String, _result: String) -> void:
	if walk_proof_active and cue.begins_with("step.enemy."):
		walk_proof_cues.append({"frame": walk_proof_frame, "seconds": walk_proof_seconds, "cue": cue})
