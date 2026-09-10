extends RefCounted

## Presentation only. Preparation precedes the existing effect clock; the
## resolver, result boundaries, ranged flight, surfaces and analytics stay intact.
const Fx = preload("res://scripts/attack_fx_library.gd")
const PREPARE_SECONDS: Dictionary = {"talon":0.32,"lance":0.24,"storm":0.36}

static func clip_for_effect(effect: Dictionary, actor: Dictionary) -> String:
	if str(actor.get("type","")) != "iskaldra":
		return ""
	match str(effect.get("kind","")):
		"melee": return "talon"
		"ranged": return "lance"
		"aoe": return "storm"
		"status": return "mantle" if str(effect.get("action_type","")) == "frost_armor" else ""
	return ""

static func uses_attack(effect: Dictionary, actor: Dictionary) -> bool:
	return clip_for_effect(effect,actor) in ["talon","lance","storm"]

static func direction(effect: Dictionary, actor: Dictionary, player_tile: Vector2i) -> Vector2i:
	var origin: Vector2i = actor.get("pos",effect.get("from",Vector2i.ZERO))
	var target: Vector2i = effect.get("to",player_tile)
	if str(effect.get("kind","")) in ["aoe","status"] and int(effect.get("range",0)) <= 0:
		target = player_tile
	# Doubled coordinates preserve the half-tile center of the 2x2 boss.
	var footprint: Vector2i = actor.get("footprint",Vector2i(2,2))
	return target * 2 - (origin * 2 + footprint - Vector2i.ONE)

static func motion_for_effect(effect: Dictionary, actor: Dictionary, progress: float, player_tile: Vector2i) -> Dictionary:
	var action: String = clip_for_effect(effect,actor)
	if action.is_empty():
		return {}
	var p: float = clampf(progress,0.0,1.0)
	var phase: float = p
	if action == "lance":
		var release: float = Fx.anticipation_end_progress(Fx.STYLE_ICE_SHARDS)
		var contact: float = Fx.travel_end_progress(Fx.STYLE_ICE_SHARDS)
		if p <= release:
			phase = lerpf(0.35,0.45,p/release)
		elif p <= contact:
			phase = lerpf(0.45,0.65,(p-release)/(contact-release))
		else:
			phase = lerpf(0.65,1.0,(p-contact)/(1.0-contact))
	elif action in ["talon","storm"]:
		var contact: float = 0.42 if action == "talon" else 0.38
		phase = lerpf(0.35,0.5,p/contact) if p <= contact else lerpf(0.5,1.0,(p-contact)/(1.0-contact))
	return {"clip":"attack","action":action,"phase":phase,"direction":direction(effect,actor,player_tile)}

static func prepare(host: Node, before_state: Dictionary, effect: Dictionary) -> void:
	var actor_key: String = str(effect.get("actor_key",""))
	var actor: Dictionary = host.call("_animation_actor_unit",before_state,actor_key)
	var action: String = clip_for_effect(effect,actor)
	if not PREPARE_SECONDS.has(action) or bool(host.call("_reduced_motion_enabled")):
		return
	var duration: float = float(PREPARE_SECONDS[action])
	var frames: int = ceili(duration * 60.0)
	var player_tile: Vector2i = (before_state.get("player",{}) as Dictionary).get("pos",Vector2i.ZERO)
	await host.call("_play_timed_animation_frames",frames,duration/float(frames),func(frame: int) -> void:
		var presentation: Dictionary = {"focus_actor_keys":[actor_key],
			"iskaldra_motion":{actor_key:{"clip":"attack","action":action,
				"phase":0.35*float(frame)/float(frames),"direction":direction(effect,actor,player_tile)}}}
		host.call("_render_board_state",before_state,presentation,true)
	)
