extends "res://scripts/run_scene.gd"
## Observe the production board after each reflection submission.

var proof_step_frames: bool = true
var proof_clock: Vector2
var proof_effect: Dictionary
var proof_observer: Callable

func _play_timed_animation_frames(count: int, seconds: float, render_frame: Callable) -> void:
	if not proof_step_frames:
		await super._play_timed_animation_frames(count, seconds, render_frame)
		return
	proof_clock = Vector2(count, seconds)
	for frame: int in range(1, count + 1):
		render_frame.call(frame)
		await get_tree().process_frame

func _render_board_state(state: Dictionary, shown: Dictionary, stable: bool = false) -> void:
	super._render_board_state(state, shown, stable)
	var effect: Dictionary = shown.get("effect", {})
	if effect.get("action_type") == "reflected_projectile":
		proof_effect = effect
		if proof_observer.is_valid():
			proof_observer.call(board_view.presentation)
