extends RefCounted

## The existing resolver snapshots, marks, landing effect, damage text and
## surface/death ordering remain authoritative. Only their contact clock moves.
const Action = preload("res://scripts/maquette_cutout_runtime/action.gd")
const Lob = preload("res://scripts/enemy_mechanics/lob_view.gd")
const Floating = preload("res://scripts/floating_combat_text.gd")
const Sfx = preload("res://scripts/attack_sfx_library.gd")
const TYPE: String = "slag_mortar"

static func handles(step: Dictionary, actor: Dictionary) -> bool:
	return not bool(step.get("cancelled", false)) and Action.clip_for(step, actor) in ["lob", "land", "brace"]

static func motion_for(key: String, clip: String, phase: float, direction: Vector2i) -> Dictionary:
	return {"maquette_explicit_clip": true, TYPE + "_motion": {key: {"clip": clip, "phase": phase, "direction": direction}}}

static func animate(scene: Control, state: Dictionary, step: Dictionary, actor: Dictionary) -> void:
	var clip: String = Action.clip_for(step, actor)
	var definition: Dictionary = Action.data_for(TYPE)["clips"][clip]
	var seconds: float = float(definition["seconds"])
	var contact: float = float(definition["contact"])
	var key: String = str(step["actor_key"])
	var direction: Vector2i = state["player"]["pos"] - actor["pos"]
	var reduced: bool = scene._reduced_motion_enabled()
	var before: Dictionary = state.duplicate(true)
	var clock: Dictionary = {"contact": false, "surfaces": {}}
	var feedback: Dictionary = scene._enemy_phase_status_presentation(step) if clip == "brace" else {}
	var texts: Array = feedback.get("floating_texts", []) if clip == "brace" else preload("res://scripts/enemy_mechanics/wind_view.gd").damage_texts(scene, step) if clip == "land" else []
	var count: int = 1 if reduced else Action.frames_for(TYPE, clip)
	scene._set_action_banner("%s: %s" % [str(step.get("actor_name", "Enemy")), str(step.get("label", ""))])
	await scene._play_timed_animation_frames(count, 0.0 if reduced else seconds / count, func(frame: int) -> void:
		var intervals: int = maxi(1, count - 1)
		var phase: float = 1.0 if reduced else Action.contact_phase(float(frame - 1) / intervals, ceilf(contact * intervals) / intervals, contact)
		var elapsed: float = maxf(0.0, (phase - contact) * seconds)
		var shown: Dictionary = motion_for(key, clip, phase, direction)
		if phase >= contact:
			if not clock["contact"]:
				if clip == "land": scene._play_sfx(Sfx.entry_for_enemy_step(step))
				scene._apply_animation_step(state, step)
				if clip == "land":
					clock["surfaces"] = state.get("surfaces", {}).duplicate(true)
					state["surfaces"] = before.get("surfaces", {}).duplicate(true)
			clock["contact"] = true
			shown.merge(feedback, true)
			shown["floating_texts"] = Floating.animate_entries(texts, elapsed, reduced)
			shown["effect_progress"] = 1.0 if reduced else clampf(elapsed / Floating.ANIMATION_DURATION_SECONDS, 0.0, 1.0)
		if clip == "land":
			shown["effect"] = step
			# Existing arc in preparation, existing splash starting at contact.
			shown["effect_progress"] = ((Lob.ARC_SECONDS * phase / contact) if phase < contact else Lob.ARC_SECONDS + minf(elapsed, Lob.SPLASH_SECONDS)) / (Lob.ARC_SECONDS + Lob.SPLASH_SECONDS)
			shown = scene._attack_feedback_death_hold_presentation(before, state, shown)
		scene._render_board_state(state, shown, true)
	)
	if clip == "land": state["surfaces"] = clock["surfaces"]
	if not texts.is_empty():
		var tail: Dictionary = motion_for(key, clip, 1.0, direction)
		tail["floating_texts"] = texts
		await scene._animate_floating_text_presentation(state, scene._death_hold_presentation(before, state, tail), seconds * (1.0 - contact))
	if clip == "land": await scene._animate_turn_order_alongside_defeats(before, state)
	scene._render_board_state(state, {})
