extends RefCounted

static func animate(scene: Control, state: Dictionary, step: Dictionary) -> void:
	var from: Vector2i = step["from"]
	var to: Vector2i = step["to"]
	if from != to:
		# Ambush enters this view on the action clock, but its blink travels at
		# the same movement speed as Fade. Restore action speed for the strike.
		var resume_action: bool = scene._combat_pacing.begin_movement(str(step["actor_key"]))
		var effect: Dictionary = {"kind": "blink", "from": from, "to": to, "actor_key": step["actor_key"]}
		await scene._play_timed_animation_frames(scene.ATTACK_FRAMES, scene.ATTACK_FRAME_SECONDS, func(frame: int) -> void:
			scene._render_board_state(state, {"effect": effect, "effect_progress": float(frame) / float(scene.ATTACK_FRAMES)}, true)
		)
		scene._combat_pacing.end_movement(resume_action)
	state.merge(step["blink_after"].duplicate(true), true)
	if step.has("strike_step") and not (step["strike_step"] as Dictionary).is_empty():
		await scene._animate_enemy_phase_steps(state, [step["strike_step"]])
	scene._apply_animation_step(state, step)
	scene._render_board_state(state, {})
