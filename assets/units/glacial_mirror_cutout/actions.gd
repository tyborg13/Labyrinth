extends RefCounted

## Bind the existing ward/Refraction feedback to the protected contact key.
## Resolver snapshots, effect art, sound entries and outcomes remain authoritative.
const Action = preload("res://scripts/maquette_cutout_runtime/action.gd")
const Reflect = preload("res://scripts/enemy_mechanics/reflect_view.gd")
const Floating = preload("res://scripts/floating_combat_text.gd")
const Sfx = preload("res://scripts/attack_sfx_library.gd")

static func clip_for(step: Dictionary, actor: Dictionary) -> String:
	# Existing resolver snapshots call the beam "refraction" and address a
	# single-target ward to its recipient. Normalize selection only; render
	# and apply the untouched resolver step.
	var selector: Dictionary = step.duplicate(false)
	if str(step.get("action_type", "")) == "refraction": selector["action_type"] = "aoe"
	elif str(step.get("kind", "")) == "block": selector["action_type"] = "guard_ally"
	return Action.clip_for(selector, actor)

static func handles(step: Dictionary, actor: Dictionary) -> bool:
	return not bool(step.get("cancelled", false)) and str(actor.get("type", "")) == "glacial_mirror" and clip_for(step, actor) in ["refraction", "guard"]

static func phase_at(frame: int, count: int, contact: float) -> float:
	var intervals: int = maxi(1, count - 1)
	return Action.contact_phase(float(frame - 1) / intervals, ceilf(contact * intervals) / intervals, contact)

static func animate(scene: Control, state: Dictionary, step: Dictionary, actor: Dictionary) -> void:
	var type: String = str(actor["type"])
	var clip: String = clip_for(step, actor)
	var definition: Dictionary = Action.data_for(type)["clips"][clip]
	var duration: float = float(definition["seconds"])
	var contact: float = float(definition["contact"])
	var reduced: bool = scene._reduced_motion_enabled()
	var count: int = 1 if reduced else Action.frames_for(type, clip)
	var before: Dictionary = state.duplicate(true)
	var key: String = str(step.get("source_actor_key", step["actor_key"]))
	var direction: Vector2i = step.get("to", step.get("tile", state["player"]["pos"])) - step.get("from", actor.get("pos", Vector2i.ZERO))
	var feedback: Dictionary = scene._enemy_phase_status_presentation(step)
	var texts: Array[Dictionary]
	if clip == "refraction": texts.assign(scene._floating_texts_for_target_losses(step.get("target_losses", [])))
	else: texts.assign(feedback.get("floating_texts", []))
	var fired: Dictionary = {"contact": false}
	scene._set_action_banner("%s: %s" % [str(step.get("actor_name", "Enemy")), str(step.get("label", ""))])
	await scene._play_timed_animation_frames(count, 0.0 if reduced else duration / count, func(frame: int) -> void:
		var phase: float = 1.0 if reduced else phase_at(frame, count, contact)
		var elapsed: float = maxf(0.0, (phase - contact) * duration)
		if phase >= contact and not fired["contact"]:
			fired["contact"] = true
			scene._apply_animation_step(state, step)
			scene._play_sfx(Sfx.entry_for_enemy_step(step))
		var presentation: Dictionary = {"maquette_explicit_clip": true,
			type + "_motion": {key: {"clip": clip, "phase": phase, "direction": direction}}}
		if phase >= contact:
			presentation["floating_texts"] = Floating.animate_entries(texts, elapsed, reduced)
			if clip == "guard" or reduced or elapsed < Reflect.BEAM_SECONDS:
				presentation["effect"] = step
				presentation["effect_progress"] = 0.0 if reduced else elapsed / (Reflect.BEAM_SECONDS if clip == "refraction" else Floating.ANIMATION_DURATION_SECONDS)
		scene._render_board_state(state, scene._attack_feedback_death_hold_presentation(before, state, presentation), true)
	)
	if not texts.is_empty():
		await scene._animate_floating_text_presentation(state, scene._death_hold_presentation(before, state, {"floating_texts": texts}), duration * (1.0 - contact))
	scene._render_board_state(state, {})
