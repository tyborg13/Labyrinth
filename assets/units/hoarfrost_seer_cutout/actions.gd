extends RefCounted

## rr-07 special mechanics retain their existing FX, sound entries and outcomes.
## Only the acting unit's cutout clock and the existing feedback start are bound
## to the protected clip contact. No resolver or analytics call originates here.
const Action = preload("res://scripts/maquette_cutout_runtime/action.gd")
const Icefall = preload("res://scripts/enemy_mechanics/icefall_view.gd")
const Tether = preload("res://scripts/enemy_mechanics/tether_view.gd")
const Sfx = preload("res://scripts/attack_sfx_library.gd")
const Floating = preload("res://scripts/floating_combat_text.gd")
const Wind = preload("res://scripts/enemy_mechanics/wind_view.gd")

static func handles(step: Dictionary, actor: Dictionary) -> bool:
	if bool(step.get("cancelled", false)): return false
	var type: String = str(actor.get("type", ""))
	var clip: String = Action.clip_for(step, actor)
	return (type == "hoarfrost_seer" and clip in ["mark", "land", "ward"]) or (type == "arc_thrall" and clip == "tether")

static func phase_at(frame: int, count: int, contact: float) -> float:
	return Action.contact_phase(float(frame) / count, ceilf(contact * count) / count, contact)

static func animate(scene: Control, state: Dictionary, step: Dictionary, actor: Dictionary) -> void:
	if step.has("move_step"):
		await scene._animate_move_step(state, step["move_step"])
		state.merge(step["move_after"].duplicate(true), true)
	var type: String = str(actor["type"])
	var clip: String = Action.clip_for(step, actor)
	var definition: Dictionary = Action.data_for(type)["clips"][clip]
	var duration: float = float(definition["seconds"])
	var contact: float = float(definition["contact"])
	var contact_seconds: float = duration * contact
	var reduced: bool = scene._reduced_motion_enabled()
	var count: int = 1 if reduced else Action.frames_for(type, clip)
	var before: Dictionary = state.duplicate(true)
	var key: String = str(step["actor_key"])
	var direction: Vector2i = step.get("to", state["player"]["pos"]) - step.get("from", actor.get("pos", Vector2i.ZERO))
	var fired: Dictionary = {"contact": false}
	var texts: Array[Dictionary]
	if clip == "land": texts.assign(Wind.damage_texts(scene, step))
	elif clip == "tether": texts.assign(scene._floating_texts_for_target_losses(step.get("target_losses", [])))
	else: texts.assign(scene._enemy_phase_status_presentation(step).get("floating_texts", []))
	step["icefall_puff_seconds"] = Icefall.PUFF_SECONDS
	scene._set_action_banner("%s: %s" % [str(step.get("actor_name", "Enemy")), str(step.get("label", ""))])
	await scene._play_timed_animation_frames(count, 0.0 if reduced else duration / count, func(frame: int) -> void:
		var phase: float = 1.0 if reduced else phase_at(frame, count, contact)
		var elapsed: float = phase * duration
		if phase >= contact and not fired["contact"]:
			fired["contact"] = true
			if clip in ["mark", "land"]:
				state.clear()
				state.merge(step["en02_state_after"].duplicate(true), true)
			else: scene._apply_animation_step(state, step)
			if clip == "land": scene._play_sfx(Sfx.entry_for_enemy_step(step))
			elif clip == "tether": scene._play_sfx(Sfx.entry_for_enemy_step({"kind": "ranged", "element": "lightning", "enemy_type": type}))
		var presentation: Dictionary = {"maquette_explicit_clip": true,
			type + "_motion": {key: {"clip": clip, "phase": phase, "direction": direction}}}
		if clip == "land" and (reduced or (elapsed >= contact_seconds - Icefall.FALL_SECONDS and elapsed < contact_seconds + Icefall.PUFF_SECONDS)):
			step["icefall_phase"] = "fall" if phase < contact else "puff"
			presentation["effect"] = step
			presentation["effect_progress"] = (elapsed - contact_seconds + Icefall.FALL_SECONDS) / (Icefall.FALL_SECONDS + Icefall.PUFF_SECONDS)
		elif clip == "tether" and phase >= contact and (reduced or elapsed < contact_seconds + Tether.BEAM_SECONDS + Tether.FADE_SECONDS):
			presentation["effect"] = step
			presentation["effect_progress"] = 0.0 if reduced else (elapsed - contact_seconds) / (Tether.BEAM_SECONDS + Tether.FADE_SECONDS)
		if phase >= contact:
			presentation["floating_texts"] = Floating.animate_entries(texts, elapsed - contact_seconds, reduced)
		scene._render_board_state(state, scene._attack_feedback_death_hold_presentation(before, state, presentation), true)
	)
	if clip == "land": await scene._animate_turn_order_alongside_defeats(before, state)
	if not texts.is_empty():
		await scene._animate_floating_text_presentation(state, scene._death_hold_presentation(before, state, {"floating_texts": texts}), duration - contact_seconds)
	scene._render_board_state(state, {})
	if clip in ["mark", "land"]: Wind.refresh_chip(scene, state)
