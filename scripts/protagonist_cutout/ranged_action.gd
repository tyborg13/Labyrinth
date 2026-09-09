extends RefCounted

## Presentation only: preparation precedes the existing effect clock. Resolver,
## damage/contact fractions, chain hops, and append-only analytics are untouched.
const Fx = preload("res://scripts/attack_fx_library.gd")
const Sfx = preload("res://scripts/attack_sfx_library.gd")
const PREPARE_FRAMES: int = 12
const PREPARE_FRAME_SECONDS: float = 1.0 / 60.0

static func clip_for_action(action: Dictionary) -> String:
	if Sfx.category_for_action(action) != "ranged":
		return ""
	var element: String = str(action.get("element", action.get("_card_element", "none")))
	return "cast" if element in ["fire", "earth", "air", "lightning", "ice"] else "shoot"

static func direction(effect: Dictionary) -> Vector2i:
	return (effect.get("to", Vector2i.ZERO) as Vector2i) - (effect.get("protagonist_origin", effect.get("from", Vector2i.ZERO)) as Vector2i)

static func motion_for_effect(effect: Dictionary, progress: float) -> Dictionary:
	var style: String = Fx.style_for_effect(effect)
	var release: float = 0.18 if style == Fx.STYLE_DEFAULT else Fx.anticipation_end_progress(style)
	var contact: float = 0.66 if style == Fx.STYLE_DEFAULT else Fx.travel_end_progress(style)
	var phase: float
	if progress <= release:
		phase = lerpf(0.35, 0.42, clampf(progress / release, 0.0, 1.0))
	elif progress <= contact:
		phase = lerpf(0.42, 0.62, (progress - release) / (contact - release))
	else:
		phase = lerpf(0.62, 1.0, clampf((progress - contact) / (1.0 - contact), 0.0, 1.0))
	return {"clip": str(effect.get("protagonist_ranged", "idle")), "phase": phase, "direction": direction(effect)}

static func prepare(host: Node, before_state: Dictionary, effect: Dictionary, base: Dictionary) -> void:
	var clip: String = str(effect.get("protagonist_ranged", ""))
	if clip.is_empty() or bool(host.call("_reduced_motion_enabled")):
		return
	await host.call("_play_timed_animation_frames", PREPARE_FRAMES, PREPARE_FRAME_SECONDS, func(frame: int) -> void:
		var t: float = float(frame) / float(PREPARE_FRAMES)
		var presentation: Dictionary = base.duplicate(false)
		presentation["protagonist_motion"] = {
			"clip": clip, "phase": 0.35 * t, "direction": direction(effect),
			"charge": smoothstep(0.45, 1.0, t) if clip == "cast" else 0.0,
			"element": str(effect.get("element", "none")),
		}
		host.call("_render_board_state", before_state, presentation, true)
	)
