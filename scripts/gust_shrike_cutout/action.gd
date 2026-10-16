extends RefCounted

## Presentation adapter only; resolved steps, damage and analytics stay owned
## by the existing combat paths. Dive contact is its flight END, not ranged FX.
const Renderer = preload("renderer.gd")
const Data = preload("motion_data.gd")
const Fx = preload("res://scripts/attack_fx_library.gd")

static func action_for_effect(effect: Dictionary, actor: Dictionary) -> String:
	if str(actor.get("type", "")) != "gust_shrike" or bool(effect.get("cancelled", false)): return ""
	if str(effect.get("action_type", "")) == "dive_line": return "dive"
	if str(effect.get("kind", "")) == "melee": return "talon_rake"
	if str(effect.get("kind", "")) == "block": return "hover"
	return ""

static func contact_phase(progress: float, boundary: float, authored_contact: float) -> float:
	if authored_contact <= 0 or authored_contact >= 1: return 0.0
	if progress <= boundary:
		return authored_contact * clampf(progress / maxf(boundary, 0.000001), 0.0, 1.0)
	return lerpf(authored_contact, 1.0, clampf((progress - boundary) / maxf(1.0 - boundary, 0.000001), 0.0, 1.0))

static func effect_contact_boundary(effect: Dictionary, frame_count: int) -> float:
	var boundary: float = Fx.feedback_start_progress(effect)
	return ceilf(boundary * frame_count) / frame_count if frame_count > 0 else boundary

static func motion_for_effect(effect: Dictionary, actor: Dictionary, progress: float, frame_count: int = 0) -> Dictionary:
	var action: String = action_for_effect(effect, actor)
	if action.is_empty(): return {}
	var sampled: float = progress
	if action != "hover":
		var boundary: float = 1.0 if action == "dive" else effect_contact_boundary(effect, frame_count)
		sampled = contact_phase(progress, boundary, float(Data.CONTACT_PHASES[action]))
	return {"clip": action, "phase": sampled,
		"direction": (effect.get("to", actor.get("pos", Vector2i.ZERO)) as Vector2i) - (effect.get("from", actor.get("pos", Vector2i.ZERO)) as Vector2i)}

static func decorate(state: Dictionary, presentation: Dictionary) -> void:
	if not Renderer.available(): return
	var effect: Dictionary = presentation.get("effect", {})
	var key: String = str(effect.get("actor_key", ""))
	var actor: Dictionary = actor_for(state, key)
	var motion: Dictionary = motion_for_effect(effect, actor, float(presentation.get("effect_progress", 1.0)), int(presentation.get("effect_frame_count", 0)))
	var motions: Dictionary = (presentation.get("gust_shrike_motion", {}) as Dictionary).duplicate(false)
	# Explicit movement/recovery wins over the still-present effect descriptor.
	if not motion.is_empty() and str(motions.get(key, {}).get("clip", "idle")) in ["idle", "hit"]: motions[key] = motion
	for target: String in motions:
		if str(motions[target].get("clip", "")) != "hit": continue
		motions[target] = motions[target].duplicate(false)
		motions[target]["recoil_direction"] = Vector2.ZERO
		if not effect.has("from"): continue
		var unit: Dictionary = actor_for(state, target)
		var away: Vector2i = (unit.get("pos", Vector2i.ZERO) as Vector2i) - (effect["from"] as Vector2i)
		# Same 2:1 projection as the board; normalize in source pixels.
		var recoil := Vector2(away.x - away.y, (away.x + away.y) * 0.5).normalized()
		motions[target]["recoil_direction"] = recoil
	if not motions.is_empty(): presentation["gust_shrike_motion"] = motions

static func actor_for(state: Dictionary, key: String) -> Dictionary:
	for unit: Dictionary in state.get("enemies", []):
		if key == "enemy_%d" % int(unit.get("id", -1)): return unit
	return {}

static func dive_recovery_phase(frame: int, contact: float) -> float:
	# Frame 1 is the contact flare; frame 6 reaches rest and holds for one tick.
	return lerpf(contact, 1.0, clampf(float(frame - 1) / float(Data.DIVE_RECOVERY_FRAMES), 0.0, 1.0))

static func recover_dive(scene: Control, state: Dictionary, step: Dictionary) -> void:
	if not Renderer.available() or bool(step.get("cancelled", false)) or scene._reduced_motion_enabled(): return
	var actor: Dictionary = actor_for(state, str(step.get("actor_key", "")))
	if action_for_effect(step, actor) != "dive": return
	var start: float = float(Data.CONTACT_PHASES["dive"])
	await scene._play_timed_animation_frames(Data.DIVE_RECOVERY_FRAMES, Data.DIVE_RECOVERY_FRAME_SECONDS,
		func(frame: int) -> void:
			scene._render_board_state(state, {"gust_shrike_motion": {str(step["actor_key"]): {
				"clip": "dive", "phase": dive_recovery_phase(frame, start)}}}, true))
