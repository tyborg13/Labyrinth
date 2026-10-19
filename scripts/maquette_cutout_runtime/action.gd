extends RefCounted

## Presentation adapter. Exact intent/action selectors come from protected data;
## the existing gameplay feedback boundary remains the sound/VFX contact clock.
const Presentation = preload("presentation.gd")
const Motion = preload("motion.gd")
const Fx = preload("res://scripts/attack_fx_library.gd")
const FPS: float = 60.0

static func handles(type: String) -> bool:
	return Presentation.handles(type)

static func data_for(type: String) -> Dictionary:
	if not handles(type): return {}
	var directory: String = Presentation.asset_directory(type)
	return Motion.data_for({"motion_data": directory.path_join("compiled_motion.json")})

static func clip_for(effect: Dictionary, actor: Dictionary) -> String:
	var data: Dictionary = data_for(str(actor.get("type", "")))
	if data.is_empty() or bool(effect.get("cancelled", false)): return ""
	# Compound resolver steps keep their copied action_type. A case can map
	# their existing marker to a clip without changing gameplay descriptors.
	var selectors: Dictionary = Presentation.integration_for(str(actor.get("type", ""))).get("step_selectors", {})
	for flag: String in selectors:
		if bool(effect.get(flag, false)): return str(selectors[flag])
	var intent: String = str(effect.get("intent_id", actor.get("intent", {}).get("id", "")))
	var verb: String = str(effect.get("action_type", effect.get("kind", "")))
	# The existing Kindle resolver emits a status snapshot. Normalize only its
	# presentation selector; preserve the resolver step and protected clip data.
	if str(actor.get("type", "")) == "ember_tick" and intent == "kindle" and verb == "status" and effect.has("enemy_after"):
		verb = "kindle"
	for clip: String in data["clips"]:
		for selector: String in data["clips"][clip].get("intents", []):
			if selector == intent or selector == intent + ":" + verb: return clip
	return ""

static func seconds_for(type: String, clip: String) -> float:
	return float(data_for(type).get("clips", {}).get(clip, {}).get("seconds", 0.0))

static func frames_for(type: String, clip: String) -> int:
	return maxi(1, roundi(seconds_for(type, clip) * FPS))

static func movement_frame(presentation: Dictionary, type: String, key: String, origin: Vector2, target: Vector2, direction: Vector2i, phase: float, reduced: bool) -> void:
	var step: float = origin.distance_to(target)
	presentation[type + "_motion"] = {key: {"clip": "move", "direction": direction, "phase": phase, "step_distance_px": step}}
	if reduced: return
	# The live canvas contains authored root travel. Anchor only that texture at
	# the segment origin; HUD/shadows follow the same eased/lifted body root.
	presentation["unit_texture_origins"] = {key: origin}
	presentation["unit_world_positions"] = {key: origin + Motion.root_offset(data_for(type), "move", phase, direction, step)}

static func contact_phase(progress: float, boundary: float, contact: float) -> float:
	if progress <= boundary: return contact * clampf(progress / maxf(boundary, 0.000001), 0.0, 1.0)
	return lerpf(contact, 1.0, clampf((progress - boundary) / maxf(1.0 - boundary, 0.000001), 0.0, 1.0))

static func actor_for(state: Dictionary, key: String) -> Dictionary:
	for unit: Dictionary in state.get("enemies", []):
		if key == "enemy_%d" % int(unit.get("id", -1)): return unit
	return {}

static func decorate(state: Dictionary, presentation: Dictionary) -> void:
	if bool(presentation.get("maquette_explicit_clip", false)): return
	var effect: Dictionary = presentation.get("effect", {})
	# Utility clips already run on their authored clock before outcome feedback.
	# The following status popup must not replay that same clip a second time.
	if str(effect.get("kind", "")) not in ["melee", "ranged", "aoe"]: return
	var key: String = str(effect.get("actor_key", ""))
	var actor: Dictionary = actor_for(state, key)
	var type: String = str(actor.get("type", ""))
	var clip: String = clip_for(effect, actor)
	if clip.is_empty() or clip == "move": return
	var motions: Dictionary = (presentation.get(type + "_motion", {}) as Dictionary).duplicate(false)
	# Deliberate movement/terminal state cannot be replaced by a lingering effect.
	if str(motions.get(key, {}).get("clip", "idle")) in ["move", "death"]: return
	var progress: float = float(presentation.get("effect_progress", presentation.get("impact_progress", 1.0)))
	var definition: Dictionary = data_for(type)["clips"][clip]
	if definition.has("contact"):
		var count: int = int(presentation.get("effect_frame_count", 0))
		var boundary: float = Fx.feedback_start_progress(effect)
		if count > 0: boundary = ceilf(boundary * count) / count
		progress = contact_phase(progress, boundary, float(definition["contact"]))
	var origin: Vector2i = effect.get("from", actor.get("pos", Vector2i.ZERO))
	var target: Vector2i = effect.get("to", state.get("player", {}).get("pos", origin))
	if target == origin: target = state.get("player", {}).get("pos", origin)
	motions[key] = {"clip": clip, "phase": progress, "direction": target - origin}
	presentation[type + "_motion"] = motions

static func play_utility(scene: Control, state: Dictionary, step: Dictionary) -> void:
	var key: String = str(step.get("actor_key", ""))
	var actor: Dictionary = actor_for(state, key)
	var type: String = str(actor.get("type", ""))
	var clip: String = clip_for(step, actor)
	if clip.is_empty() or clip == "move" or scene._reduced_motion_enabled(): return
	await scene._play_timed_animation_frames(frames_for(type, clip), 1.0 / FPS, func(frame: int) -> void:
		scene._render_board_state(state, {type + "_motion": {key: {"clip": clip, "phase": float(frame) / frames_for(type, clip)}}}, true))
