extends RefCounted

## Presentation timing only. Preparation precedes the existing effect clock;
## contact/release use its original fractions and resolution stays in RunScene.
const Fx = preload("res://scripts/attack_fx_library.gd")
const FRAME_SECONDS: float = 1.0 / 60.0

static func action_for_effect(effect: Dictionary, actor: Dictionary) -> String:
	if str(actor.get("type", "")) != "frostglass_lancer":
		return ""
	var kind: String = str(effect.get("kind", ""))
	if kind == "aoe":
		return "thrust"
	if kind != "ranged":
		return ""
	# Intent identity survives elemental room transformations of Spear Cast.
	var intent: String = str((actor.get("intent", {}) as Dictionary).get("id", ""))
	if intent == "spear_cast":
		return "cast"
	if intent == "frost_pin":
		return "pin"
	return "pin" if str(effect.get("element", "none")) == "ice" else "cast"

static func direction(effect: Dictionary) -> Vector2i:
	return (effect.get("to", Vector2i.ZERO) as Vector2i) - (effect.get("from", Vector2i.ZERO) as Vector2i)

static func frame_count(effect: Dictionary, action: String, reduce: bool) -> int:
	if reduce:
		return 1
	if action == "thrust":
		return 42
	return Fx.animation_frame_count(effect, 36, false)

static func frame_seconds(effect: Dictionary, action: String, reduce: bool) -> float:
	if reduce:
		return 0.0
	return FRAME_SECONDS if action == "thrust" else Fx.animation_frame_seconds(effect, FRAME_SECONDS, false)

static func preparation_seconds(action: String) -> float:
	return 0.0 if action == "thrust" else 0.28 if action == "cast" else 0.22

static func release_progress(effect: Dictionary) -> float:
	var style: String = Fx.style_for_effect(effect)
	return 0.18 if style == Fx.STYLE_DEFAULT else Fx.anticipation_end_progress(style)

static func motion_for_effect(effect: Dictionary, action: String, progress: float, contact: float) -> Dictionary:
	var keys: PackedVector2Array
	if action == "thrust":
		keys = PackedVector2Array([Vector2(0,0), Vector2(contact*0.75,0.32),
			Vector2(contact,0.5), Vector2(lerpf(contact,1.0,0.32),0.65), Vector2(1,1)])
	else:
		keys = PackedVector2Array([Vector2(0,0.32), Vector2(release_progress(effect),0.5),
			Vector2(contact,0.65), Vector2(1,1)])
	return {"clip":"attack", "action":action, "phase":_phase(progress,keys), "direction":direction(effect)}

static func prepare(host: Node, state: Dictionary, effect: Dictionary, action: String, base: Dictionary) -> void:
	var duration: float = preparation_seconds(action)
	if action.is_empty() or duration <= 0.0 or bool(host.call("_reduced_motion_enabled")):
		return
	var frames: int = ceili(duration / FRAME_SECONDS)
	await host.call("_play_timed_animation_frames",frames,duration / float(frames),func(frame: int) -> void:
		var presentation: Dictionary = base.duplicate(false)
		presentation["frostglass_motion"] = {str(effect.get("actor_key", "")): {
			"clip":"attack", "action":action, "phase":0.32 * float(frame) / float(frames), "direction":direction(effect)}}
		host.call("_render_board_state",state,presentation,true)
	)

static func _phase(progress: float, keys: PackedVector2Array) -> float:
	for index: int in range(1,keys.size()):
		if progress <= keys[index].x:
			return lerpf(keys[index-1].y,keys[index].y,
				inverse_lerp(keys[index-1].x,keys[index].x,clampf(progress,0.0,1.0)))
	return 1.0
