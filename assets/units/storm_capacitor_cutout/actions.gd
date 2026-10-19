extends RefCounted

## Presentation only: resolver snapshots, chain hops, VFX and sounds stay owned
## by their existing systems. The director contact starts those same effects.
const Action = preload("res://scripts/maquette_cutout_runtime/action.gd")
const Rules = preload("res://scripts/enemy_mechanics/capacitor.gd")
const Floating = preload("res://scripts/floating_combat_text.gd")
const Sfx = preload("res://scripts/attack_sfx_library.gd")
const TYPE: String = "storm_capacitor"

static func handles(step: Dictionary, actor: Dictionary) -> bool:
	return str(actor.get("type", "")) == TYPE and not bool(step.get("cancelled", false)) and Action.clip_for(step, actor) in ["charge", "discharge"]

static func motion_for(key: String, clip: String, phase: float, direction: Vector2i) -> Dictionary:
	return {"maquette_explicit_clip": true, TYPE + "_motion": {key: {"clip": clip, "phase": phase, "direction": direction}}}

static func phase_at(frame: int, count: int, contact: float) -> float:
	var intervals: int = maxi(1, count - 1)
	return Action.contact_phase(float(frame - 1) / intervals, ceilf(contact * intervals) / intervals, contact)

static func animate(scene: Control, state: Dictionary, step: Dictionary, actor: Dictionary) -> void:
	var clip: String = Action.clip_for(step, actor)
	var definition: Dictionary = Action.data_for(TYPE)["clips"][clip]
	var seconds: float = float(definition["seconds"])
	var contact: float = float(definition["contact"])
	var key: String = str(step["actor_key"])
	var direction: Vector2i = state["player"]["pos"] - actor["pos"]
	var reduced: bool = scene._reduced_motion_enabled()
	var hits: Array = step.get("chain_hits", [])
	var feedback: Dictionary = scene._enemy_phase_status_presentation(step) if clip == "charge" else {}
	var texts: Array = feedback.get("floating_texts", [])
	var clock: Dictionary = {"contact": false, "started_hop": -1, "completed_hops": 0}
	var count: int = 1 if reduced else Action.frames_for(TYPE, clip)
	scene._set_action_banner("%s: %s" % [str(step.get("actor_name", "Enemy")), str(step.get("label", ""))])
	await scene._play_timed_animation_frames(count, 0.0 if reduced else seconds / count, func(frame: int) -> void:
		var phase: float = 1.0 if reduced else phase_at(frame, count, contact)
		var elapsed: float = maxf(0.0, (phase - contact) * seconds)
		var shown: Dictionary = motion_for(key, clip, phase, direction)
		if phase >= contact:
			if clip == "charge":
				if not clock["contact"]: scene._apply_animation_step(state, step)
				shown.merge(feedback, true)
				shown["effect_progress"] = 1.0 if reduced else clampf(elapsed / Floating.ANIMATION_DURATION_SECONDS, 0.0, 1.0)
				shown["floating_texts"] = Floating.animate_entries(texts, elapsed, reduced)
			else: chain_frame(scene, state, step, hits, clock, elapsed, shown)
			clock["contact"] = true
		scene._render_board_state(state, shown, true)
	)
	if clip == "charge":
		feedback.merge(motion_for(key, clip, 1.0, direction), true)
		await scene._animate_floating_text_presentation(state, feedback, seconds * (1.0 - contact))
	else:
		# A long chain may outlast the rig recovery. Keep its terminal recovery
		# while the existing hop duration and damage/popup order finish.
		var remaining: float = maxf(0.0, hits.size() * Rules.HOP_SECONDS - seconds * (1.0 - contact))
		if remaining > 0.0:
			var tail_count: int = maxi(1, ceili(remaining * Action.FPS))
			await scene._play_timed_animation_frames(tail_count, remaining / tail_count, func(frame: int) -> void:
				var shown: Dictionary = motion_for(key, clip, 1.0, direction)
				chain_frame(scene, state, step, hits, clock, seconds * (1.0 - contact) + remaining * float(frame) / tail_count, shown)
				scene._render_board_state(state, shown, true)
			)
		finish_hops(scene, state, hits, clock, hits.size())
		scene._apply_animation_step(state, step)
	scene._render_board_state(state, {})

static func finish_hops(scene: Control, state: Dictionary, hits: Array, clock: Dictionary, count: int) -> void:
	while int(clock["completed_hops"]) < count:
		var hit: Dictionary = hits[int(clock["completed_hops"])]
		state.merge(hit["state"].duplicate(true), true)
		scene._queue_player_popup_group(scene._floating_texts_for_target_losses(hit.get("target_losses", [])), 0.0)
		clock["completed_hops"] = int(clock["completed_hops"]) + 1

static func chain_frame(scene: Control, state: Dictionary, step: Dictionary, hits: Array, clock: Dictionary, elapsed: float, shown: Dictionary) -> void:
	var index: int = mini(hits.size(), int(floor(elapsed / Rules.HOP_SECONDS)))
	finish_hops(scene, state, hits, clock, index)
	if index >= hits.size(): return
	var hit: Dictionary = hits[index]
	if int(clock["started_hop"]) != index:
		scene._play_sfx(Sfx.entry_for_enemy_step({"kind": "ranged", "element": "lightning"}))
		clock["started_hop"] = index
	shown["effect"] = {"kind": "chain", "from": hit["from"], "to": hit["to"], "element": "lightning", "actor_key": step["actor_key"]}
	shown["effect_progress"] = fposmod(elapsed, Rules.HOP_SECONDS) / Rules.HOP_SECONDS
