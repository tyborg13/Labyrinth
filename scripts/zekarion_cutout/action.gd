extends RefCounted

## Presentation only: action families and the resolved summon snapshot.
const Cutout = preload("res://scripts/zekarion_cutout/renderer.gd")

static func motion_for_effect(effect: Dictionary, progress: float, actor: Dictionary, player: Dictionary, contact: float) -> Dictionary:
	var origin: Vector2i = actor.get("pos",Vector2i.ZERO)
	var target: Vector2i = effect.get("to",player.get("pos",origin))
	# The boss occupies 2x2; face from its footprint center, not its top corner.
	return {"clip":"attack", "action":Cutout.action_for_effect(effect), "phase":progress,
		"contact":contact,"direction":target*2-origin*2-Vector2i.ONE}

static func append_resolved_summons(display_state: Dictionary, step: Dictionary) -> void:
	var enemies: Array = (display_state.get("enemies",[]) as Array).duplicate(true)
	var known: Dictionary = {}
	for enemy: Dictionary in enemies:
		known[int(enemy.get("id",-1))] = true
	for enemy: Dictionary in step.get("spawned_enemies",[]):
		if not known.has(int(enemy.get("id",-1))):
			enemies.append(enemy.duplicate(true))
			known[int(enemy.get("id",-1))] = true
	display_state["enemies"] = enemies

static func play_summon(scene: Node, animated_state: Dictionary, step: Dictionary) -> void:
	var reduced: bool = scene.call("_reduced_motion_enabled")
	var frames: int = 1 if reduced else Cutout.action_frames(step)
	var seconds: float = 0.0 if reduced else Cutout.ATTACK_FRAME_SECONDS
	var key: String = str(step.get("actor_key",""))
	var after: Dictionary = animated_state.duplicate(true)
	append_resolved_summons(after,step)
	scene.call("_set_action_banner", "%s: Call Wisps" % str(step.get("actor_name","Zekarion")))
	await scene.call("_play_timed_animation_frames", frames, seconds, func(frame: int) -> void:
		var progress: float = float(frame)/float(frames)
		var visible_state: Dictionary = after if progress >= 0.5 else animated_state
		scene.call("_render_board_state",visible_state,{"effect":step,"effect_progress":progress,
			"focus_actor_keys":[key]},true)
	)
	append_resolved_summons(animated_state,step)
	scene.call("_render_board_state",animated_state,{})
