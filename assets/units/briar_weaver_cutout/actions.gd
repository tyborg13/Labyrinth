extends RefCounted

## Reuse bramble growth and heal feedback at the protected contact. Ranged
## lash stays on the existing attack/SFX pipeline and generic contact mapping.
const Action = preload("res://scripts/maquette_cutout_runtime/action.gd")
const Bramble = preload("res://scripts/enemy_mechanics/bramble_view.gd")
const Floating = preload("res://scripts/floating_combat_text.gd")
const Sfx = preload("res://scripts/attack_sfx_library.gd")

static func handles(step: Dictionary, actor: Dictionary) -> bool:
	return not bool(step.get("cancelled", false)) and Action.clip_for(step, actor) in ["thornwall", "mend"]

static func phase_at(frame: int, count: int, contact: float) -> float:
	return Action.contact_phase(float(frame - 1) / maxi(1, count - 1), ceilf(contact * maxi(1, count - 1)) / maxi(1, count - 1), contact)

static func animate(scene: Control, state: Dictionary, step: Dictionary, actor: Dictionary) -> void:
	if step.has("move_step"):
		await scene._animate_move_step(state, step["move_step"])
		state.merge(step["move_after"].duplicate(true), true)
	var type: String = str(actor["type"])
	var clip: String = Action.clip_for(step, actor)
	var definition: Dictionary = Action.data_for(type)["clips"][clip]
	var seconds: float = float(definition["seconds"])
	var contact: float = float(definition["contact"])
	var reduced: bool = scene._reduced_motion_enabled()
	var count: int = 1 if reduced else Action.frames_for(type, clip)
	var before: Dictionary = state.duplicate(true)
	var key: String = str(step.get("source_actor_key", step["actor_key"]))
	var direction: Vector2i = step.get("to", state["player"]["pos"]) - actor["pos"]
	var feedback: Dictionary = scene._enemy_phase_status_presentation(step) if clip == "mend" else {}
	var texts: Array[Dictionary]
	texts.assign(feedback.get("floating_texts", []))
	var fired: Dictionary = {"contact": false}
	scene._set_action_banner("%s: %s" % [str(step.get("actor_name", "Enemy")), str(step.get("label", ""))])
	await scene._play_timed_animation_frames(count, 0.0 if reduced else seconds / count, func(frame: int) -> void:
		var phase: float = 1.0 if reduced else phase_at(frame, count, contact)
		var elapsed: float = maxf(0.0, (phase - contact) * seconds)
		if phase >= contact and not fired["contact"]:
			fired["contact"] = true
			scene._apply_animation_step(state, step)
			if clip == "thornwall": scene._play_sfx(Sfx.entry_for_enemy_action({"type": "ranged", "element": "earth"}))
		var shown: Dictionary = {"maquette_explicit_clip": true,
			type + "_motion": {key: {"clip": clip, "phase": phase, "direction": direction}}}
		if phase >= contact:
			if clip == "thornwall": shown.merge(Bramble.presentation_for_step(step, clampf(elapsed / Bramble.TRANSITION_SECONDS, 0.0, 1.0), reduced), true)
			else:
				shown.merge(feedback, true)
				shown["effect_progress"] = 1.0 if reduced else clampf(elapsed / Floating.ANIMATION_DURATION_SECONDS, 0.0, 1.0)
				shown["floating_texts"] = Floating.animate_entries(texts, elapsed, reduced)
		scene._render_board_state(state, scene._attack_feedback_death_hold_presentation(before, state, shown), true)
	)
	if not texts.is_empty():
		await scene._animate_floating_text_presentation(state, scene._death_hold_presentation(before, state, {"floating_texts": texts}), seconds * (1.0 - contact))
	scene._render_board_state(state, {})
