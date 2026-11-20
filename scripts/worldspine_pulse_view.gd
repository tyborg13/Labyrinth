extends RefCounted

const OutcomeFeedback = preload("res://scripts/combat_outcome_feedback.gd")

static func animate(scene: Node, animated_state: Dictionary, step: Dictionary) -> void:
	var before: Dictionary = animated_state.duplicate(true)
	before.merge(step["pulse_before"], true)
	animated_state.merge((step["pulse_after"] as Dictionary).duplicate(true), true)
	scene._burst_playback.prepare(before, animated_state)
	var shown: Dictionary = feedback(scene, before, animated_state, step["pulse_event"])
	var visible_before: Dictionary = scene._visible_turn_start_defeat_source(before)
	if shown["surface_feedback_events"].is_empty() and shown["floating_texts"].is_empty():
		scene._render_board_state(animated_state, {})
	else:
		scene._play_outcome_sounds(shown["surface_feedback_events"])
		await scene._animate_floating_text_presentation(animated_state, scene._death_hold_presentation(visible_before, animated_state, shown))
	await scene._animate_turn_order_alongside_defeats(visible_before, animated_state)

static func feedback(scene: Node, before: Dictionary, after: Dictionary, pulse: Dictionary) -> Dictionary:
	var visible_tiles: Array[Vector2i] = scene._visible_umbra_action_tiles(before, pulse.get("tiles", []))
	var events: Array[Dictionary]
	if not visible_tiles.is_empty():
		events = OutcomeFeedback.prepare([{"kind": pulse["kind"], "tiles": visible_tiles}])
	var texts: Array[Dictionary] = scene._visible_umbra_floating_texts(before, scene._player_action_floating_texts(before, after), true)
	return {"surface_feedback_events": events, "floating_texts": texts}
