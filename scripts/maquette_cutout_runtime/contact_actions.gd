extends RefCounted

## Opt-in contact playback for existing resolver effects. Declarations select
## clips; this adapter retains their effect, cue and outcome payloads.
const Action = preload("action.gd")
const Floating = preload("res://scripts/floating_combat_text.gd")

static func handles(step: Dictionary, actor: Dictionary) -> bool:
	var clips: Array = Action.Presentation.integration_for(str(actor.get("type", ""))).get("contact_playback_clips", [])
	return not bool(step.get("cancelled", false)) and (Action.clip_for(step, actor) in clips or (str(actor.get("type", "")) == "arc_thrall" and Action.clip_for(step, actor) == "tether"))

static func animate(scene: Control, state: Dictionary, step: Dictionary, actor: Dictionary) -> void:
	if step.has("move_step"):
		await scene._animate_move_step(state, step["move_step"])
		state.merge(step["move_after"].duplicate(true), true)
	var before_hit: Dictionary = state.duplicate(true) if step.has("en06_after") else {}
	var type: String = str(actor["type"])
	var key: String = str(step["actor_key"])
	var clip: String = Action.clip_for(step, actor)
	var definition: Dictionary = Action.data_for(type)["clips"][clip]
	var seconds: float = float(definition["seconds"])
	var contact: float = float(definition["contact"])
	var reduced: bool = scene._reduced_motion_enabled()
	var count: int = 1 if reduced else Action.frames_for(type, clip)
	var presented_actor: Dictionary = Action.actor_for(state, key)
	var origin: Vector2i = presented_actor.get("pos", actor["pos"])
	var target: Vector2i = step.get("to", state["player"]["pos"])
	if target == origin: target = state["player"]["pos"]
	var direction: Vector2i = target - origin
	var clock: Dictionary = {"contact": false}
	var feedback: Dictionary = scene._enemy_phase_status_presentation(step) if str(step.get("kind", "")) == "block" else {}
	var texts: Array = feedback.get("floating_texts", scene._floating_texts_for_step(step))
	scene._set_action_banner("%s: %s" % [str(step.get("actor_name", "Enemy")), str(step.get("label", ""))])
	await scene._play_timed_animation_frames(count, 0.0 if reduced else seconds / count, func(frame: int) -> void:
		var intervals: int = maxi(1, count - 1)
		var phase: float = 1.0 if reduced else Action.contact_phase(float(frame - 1) / intervals, ceilf(contact * intervals) / intervals, contact)
		var shown: Dictionary = {"maquette_explicit_clip": true,
			type + "_motion": {key: {"clip": clip, "phase": phase, "direction": direction}}}
		if phase >= contact:
			if not clock["contact"]:
				scene._apply_animation_step(state, step)
				var cue: String = Action.contact_cue_for(step, actor)
				if not cue.is_empty(): scene._sfx_router.request(cue)
				# Existing combat pacing emits the effect/status cue on the first
				# contact submission. A direct cue here would play it twice.
				clock["contact"] = true
			var elapsed: float = (phase - contact) * seconds
			shown.merge(feedback, true)
			if feedback.is_empty(): shown["effect"] = step
			shown["effect_progress"] = lerpf(Action.Fx.feedback_start_progress(step), 1.0, (phase - contact) / maxf(1.0 - contact, 0.000001))
			shown["floating_texts"] = Floating.animate_entries(texts, elapsed, reduced)
		if step.has("en06_after"): shown = scene._death_hold_presentation(before_hit, state, shown)
		scene._render_board_state(state, shown, true)
	)
	feedback.merge({"maquette_explicit_clip": true, type + "_motion": {key: {"clip": clip, "phase": 1.0, "direction": direction}}, "floating_texts": texts}, true)
	if step.has("en06_after"): feedback = scene._death_hold_presentation(before_hit, state, feedback)
	await scene._animate_floating_text_presentation(state, feedback, seconds * (1.0 - contact))
	if step.has("en06_after"): await scene._animate_turn_order_alongside_defeats(before_hit, state)
	scene._render_board_state(state, {})
