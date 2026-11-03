extends RefCounted

## Gloam-owned adapter for the existing compound Veil resolver snapshots.
## Damage, visibility, saves and analytics stay in the existing resolver.
const Action = preload("res://scripts/maquette_cutout_runtime/action.gd")
const Contact = preload("res://scripts/maquette_cutout_runtime/contact_actions.gd")

static func handles(step: Dictionary, actor: Dictionary) -> bool:
	return str(actor.get("type", "")) == "gloam_stalker" and bool(step.get("en03_veil", false)) and not bool(step.get("cancelled", false))

static func animate(scene: Control, state: Dictionary, step: Dictionary, actor: Dictionary) -> void:
	if step.has("strike_step"):
		# Retain the existing blink travel before Ambush's strike. The strike
		# runs once on its authored contact clock, with its original payload.
		await _blink(scene, state, step)
		var strike: Dictionary = (step["strike_step"] as Dictionary).duplicate(true)
		if strike.has("kind") and strike.has("actor_key"):
			strike["intent_id"] = str(actor.get("intent", {}).get("id", "ambush"))
			await Contact.animate(scene, state, strike, Action.actor_for(state, str(step["actor_key"])))
		else:
			# A snapshot-only strike has no effect or actor identity. Preserve
			# the legacy scene dispatch rather than adding a contact animation.
			await scene._animate_enemy_phase_steps(state, [strike])
		scene._apply_animation_step(state, step)
		scene._render_board_state(state, {})
		return
	var type: String = str(actor["type"])
	var key: String = str(step["actor_key"])
	var clip: String = Action.clip_for(step, actor)
	var definition: Dictionary = Action.data_for(type)["clips"][clip]
	var seconds: float = float(definition["seconds"])
	var contact: float = float(definition["contact"])
	var reduced: bool = scene._reduced_motion_enabled()
	var count: int = 1 if reduced else Action.frames_for(type, clip)
	var direction: Vector2i = state["player"]["pos"] - actor["pos"]
	var clock: Dictionary = {"applied": false}
	var effect: Dictionary = {"kind": "blink", "from": step["from"], "to": step["to"], "actor_key": key}
	var blink_seconds: float = scene.ATTACK_FRAMES * scene.ATTACK_FRAME_SECONDS
	scene._set_action_banner("%s: %s" % [str(step.get("actor_name", "Enemy")), str(step.get("label", ""))])
	await scene._play_timed_animation_frames(count, 0.0 if reduced else seconds / count, func(frame: int) -> void:
		var intervals: int = maxi(1, count - 1)
		var phase: float = 1.0 if reduced else Action.contact_phase(float(frame - 1) / intervals, ceilf(contact * intervals) / intervals, contact)
		var shown: Dictionary = {"maquette_explicit_clip": true,
			type + "_motion": {key: {"clip": clip, "phase": phase, "direction": direction}}}
		if phase >= contact:
			var progress: float = 1.0 if reduced else clampf((phase - contact) * seconds / blink_seconds, 0.0, 1.0)
			if step["from"] != step["to"]:
				shown["effect"] = effect
				shown["effect_progress"] = progress
			if progress >= 1.0 and not clock["applied"]:
				state.merge(step["blink_after"].duplicate(true), true)
				scene._apply_animation_step(state, step)
				clock["applied"] = true
		scene._render_board_state(state, shown, true)
	)
	if not clock["applied"]:
		state.merge(step["blink_after"].duplicate(true), true)
		scene._apply_animation_step(state, step)
	scene._render_board_state(state, {})

static func _blink(scene: Control, state: Dictionary, step: Dictionary) -> void:
	if step["from"] != step["to"]:
		var resume_action: bool = scene._combat_pacing.begin_movement(str(step["actor_key"]))
		var effect: Dictionary = {"kind": "blink", "from": step["from"], "to": step["to"], "actor_key": step["actor_key"]}
		await scene._play_timed_animation_frames(scene.ATTACK_FRAMES, scene.ATTACK_FRAME_SECONDS, func(frame: int) -> void:
			scene._render_board_state(state, {"effect": effect, "effect_progress": float(frame) / scene.ATTACK_FRAMES}, true)
		)
		scene._combat_pacing.end_movement(resume_action)
	state.merge(step["blink_after"].duplicate(true), true)
