extends RefCounted

## Preparation precedes the existing projectile clock. The six default effect
## frames, elemental clocks, resolver results and analytics boundaries stay intact.
const Fx = preload("res://scripts/attack_fx_library.gd")
const PREPARE_FRAMES: int = 18
const PREPARE_FRAME_SECONDS: float = 1.0 / 60.0

static func direction(effect: Dictionary) -> Vector2i:
	return (effect.get("to", Vector2i.ZERO) as Vector2i) - (effect.get("from", Vector2i.ZERO) as Vector2i)

static func motion_for_effect(effect: Dictionary, progress: float) -> Dictionary:
	var family: String = str(effect.get("kind", "melee"))
	if family != "ranged":
		return {"clip":"attack","family":"melee","phase":progress,"direction":direction(effect)}
	var style: String = Fx.style_for_effect(effect)
	var release: float = 0.18 if style == Fx.STYLE_DEFAULT else Fx.anticipation_end_progress(style)
	var contact: float = 0.66 if style == Fx.STYLE_DEFAULT else Fx.travel_end_progress(style)
	var phase: float
	if progress <= release:
		phase = lerpf(0.40,0.55,clampf(progress/release,0,1))
	elif progress <= contact:
		phase = lerpf(0.55,0.70,(progress-release)/(contact-release))
	else:
		phase = lerpf(0.70,1.0,clampf((progress-contact)/(1.0-contact),0,1))
	return {"clip":"attack","family":"ranged","phase":phase,"authored_phase":true,"effect_progress":progress,"release":release,"contact":contact,"direction":direction(effect)}

static func prepare(host: Node, before_state: Dictionary, effect: Dictionary) -> void:
	if str(effect.get("kind","")) != "ranged" or bool(host.call("_reduced_motion_enabled")):
		return
	var actor: String = str(effect.get("actor_key",""))
	await host.call("_play_timed_animation_frames",PREPARE_FRAMES,PREPARE_FRAME_SECONDS,func(frame: int) -> void:
		var presentation: Dictionary = {"focus_actor_keys":[actor],"harrier_motion":{actor:{"clip":"attack","family":"ranged","phase":0.40*float(frame)/PREPARE_FRAMES,"authored_phase":true,"direction":direction(effect)}}}
		host.call("_render_board_state",before_state,presentation,true)
	)
