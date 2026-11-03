extends RefCounted

# Keep the existing status banner, damage styling and death/surface cues, while
# applying the complete owning snapshot and submitting its popup exactly once.
static func animate(scene: Control, state: Dictionary, step: Dictionary) -> void:
	var before: Dictionary = state.duplicate(true)
	scene._apply_animation_step(state, step)
	scene._set_action_banner("%s: %s" % [str(step.get("actor_name", "Enemy")), str(step.get("label", ""))])
	var presentation: Dictionary = scene._enemy_phase_status_presentation(step)
	var events: Array[Dictionary] = preload("res://scripts/combat_outcome_feedback.gd").prepare(scene._dictionary_array(step.get("surface_events", [])))
	if not events.is_empty():
		presentation["surface_feedback_events"] = events
		scene._play_outcome_sounds(events)
	await scene._animate_floating_text_presentation(state, scene._death_hold_presentation(before, state, presentation))
	await scene._animate_turn_order_alongside_defeats(before, state)
