extends RefCounted

## Presentation only. Consume existing resolver snapshots exactly once; the
## buried state, marked landing, damage, saves and analytics remain unchanged.
const Action = preload("res://scripts/maquette_cutout_runtime/action.gd")
const Burrow = preload("res://scripts/enemy_mechanics/burrow_view.gd")
const Outcome = preload("res://scripts/combat_outcome_feedback.gd")
const Floating = preload("res://scripts/floating_combat_text.gd")
const Sfx = preload("res://scripts/attack_sfx_library.gd")
# Existing RunScene surface feedback clock, retained by this presentation hook.
const SURFACE_FEEDBACK_SECONDS: float = 0.36

static func handles(step: Dictionary, actor: Dictionary) -> bool:
	if bool(step.get("cancelled", false)): return false
	var type: String = str(actor.get("type", ""))
	return (type == "burrow_grub" and str(step.get("kind", "")) in ["burrow", "erupt"]) or (type == "ember_tick" and Action.clip_for(step, actor) == "kindle")

static func phase_at(frame: int, count: int, contact: float) -> float:
	var intervals: int = maxi(1, count - 1)
	return Action.contact_phase(float(frame - 1) / intervals, ceilf(contact * intervals) / intervals, contact)

static func animate(scene: Node, state: Dictionary, step: Dictionary, actor: Dictionary) -> void:
	var type: String = str(actor["type"])
	var clip: String = str(step["kind"]) if type == "burrow_grub" else "kindle"
	var definition: Dictionary = Action.data_for(type)["clips"][clip]
	var duration: float = float(definition["seconds"])
	var contact: float = float(definition.get("contact", 1.0))
	var reduced: bool = scene._reduced_motion_enabled()
	var count: int = 1 if reduced else Action.frames_for(type, clip)
	var before: Dictionary = state.duplicate(true)
	var after: Dictionary = step["state_after"] if type == "burrow_grub" else state.duplicate(true)
	if type == "ember_tick": scene._apply_animation_step(after, step)
	var rising: Dictionary = Burrow.rise_state(before, step) if clip == "erupt" else before
	var events: Array[Dictionary]
	var texts: Array[Dictionary]
	if clip == "erupt":
		events.assign(Outcome.prepare(scene._surface_events_between(before, after)))
		texts.assign(scene._player_action_floating_texts(before, after))
	elif clip == "kindle": texts.assign(scene._enemy_phase_status_presentation(step).get("floating_texts", []))
	var key: String = str(step["actor_key"])
	var fired: Dictionary = {"contact": false}
	if clip == "kindle": scene._set_action_banner("%s: %s" % [str(step.get("actor_name", "Enemy")), str(step.get("label", ""))])
	await scene._play_timed_animation_frames(count, 0.0 if reduced else duration / count, func(frame: int) -> void:
		var phase: float = 1.0 if reduced else phase_at(frame, count, contact)
		var elapsed: float = (phase - contact) * duration
		if phase >= contact and not fired["contact"]:
			fired["contact"] = true
			state.clear()
			state.merge(after.duplicate(true), true)
			if clip == "erupt":
				scene._play_sfx(Sfx.entry_for_enemy_action({"type": "aoe", "element": "earth"}))
				scene._play_outcome_sounds(events)
		var presentation: Dictionary = {"maquette_explicit_clip": true,
			type + "_motion": {key: {"clip": clip, "phase": phase}}}
		if phase >= contact and clip != "burrow":
			presentation["floating_texts"] = Floating.animate_entries(texts, elapsed, reduced)
			if clip == "kindle":
				presentation["effect"] = step
				presentation["effect_progress"] = clampf(elapsed / maxf(duration * (1.0 - contact), 0.000001), 0.0, 1.0)
			elif clip == "erupt":
				if elapsed <= SURFACE_FEEDBACK_SECONDS:
					presentation["surface_feedback_events"] = events
					presentation["surface_feedback_progress"] = clampf(elapsed / SURFACE_FEEDBACK_SECONDS, 0.0, 1.0)
				if not reduced and elapsed < Burrow.DUST_SECONDS:
					presentation["en01_erupt_dust"] = {"actor_key": key, "tile": step["to"], "progress": elapsed / Burrow.DUST_SECONDS}
		var displayed: Dictionary = rising if clip == "erupt" and phase < contact else state
		scene._render_board_state(displayed, scene._attack_feedback_death_hold_presentation(before, state, presentation), true)
	)
	if clip == "erupt":
		scene._queue_player_popup_group(texts, duration * (1.0 - contact))
		await scene._animate_turn_order_alongside_defeats(before, state)
	elif clip == "kindle" and not texts.is_empty():
		await scene._animate_floating_text_presentation(state, scene._death_hold_presentation(before, state, {"floating_texts": texts}), duration * (1.0 - contact))
	scene._render_board_state(state, {})
