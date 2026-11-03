extends RefCounted

## Presentation adapter. Exact intent/action selectors come from protected data;
## the existing gameplay feedback boundary remains the sound/VFX contact clock.
const Presentation = preload("presentation.gd")
const Motion = preload("motion.gd")
const Fx = preload("res://scripts/attack_fx_library.gd")
const FPS: float = 60.0
# El-02 replaced these actions, while the approved clips and their bound
# intent selectors remain unchanged. Aliases affect presentation selection only.
const ELEMENT_ACTION_SELECTORS: Dictionary = {
	"briar_weaver": {"upheaval_mark": "grow_bramble"},
}

# Echo reuses Shade Bolt while approved rig/clip files remain byte-identical.
const INTENT_SELECTORS: Dictionary = {"hollow_mimic": {"echo": "shade_bolt"}}

static func handles(type: String) -> bool:
	return Presentation.handles(type)

## An optional case adapter may insert presentation-only gestures around the
## existing steps. The resolver snapshots and their order remain unchanged.
static func presentation_steps(state: Dictionary, steps: Array) -> Array:
	var result: Array = steps
	for actor: Dictionary in state.get("enemies", []):
		var path: String = str(Presentation.integration_for(str(actor.get("type", ""))).get("action_adapter", ""))
		if path.is_empty(): continue
		var adapter: Script = load(path) as Script
		if adapter != null and adapter.has_method("presentation_steps"):
			result = adapter.presentation_steps(actor, result)
	return result

## A declared contact cue replaces that cue's legacy action-start submission.
## Undeclared clips retain their existing SFX schedule.
static func contact_cue_for(step: Dictionary, actor: Dictionary) -> String:
	var integration: Dictionary = Presentation.integration_for(str(actor.get("type", "")))
	return str(integration.get("contact_cues", {}).get(clip_for(step, actor), ""))

## Case-owned playback takes priority over declared shared contact clips.
## The integration record owns the resource path ("action_adapter").
static func playback_adapter(step: Dictionary, actor: Dictionary) -> Script:
	var type: String = str(actor.get("type", ""))
	var integration: Dictionary = Presentation.integration_for(type)
	var path: String = str(integration.get("action_adapter", ""))
	if not path.is_empty():
		var adapter: Script = load(path) as Script
		if adapter != null and adapter.handles(step, actor): return adapter
	# Runtime loading avoids a preload cycle: contact_actions uses this clock.
	var contact: Script = load("res://scripts/maquette_cutout_runtime/contact_actions.gd") as Script
	return contact if contact.handles(step, actor) else null

static func data_for(type: String) -> Dictionary:
	if not handles(type): return {}
	var directory: String = Presentation.asset_directory(type)
	return Motion.data_for({"motion_data": directory.path_join("compiled_motion.json")})

static func clip_for(effect: Dictionary, actor: Dictionary) -> String:
	var data: Dictionary = data_for(str(actor.get("type", "")))
	if data.is_empty() or bool(effect.get("cancelled", false)): return ""
	# The approved cast clip keeps its asset identity; Arc Bolt uses ordinary ranged FX.
	if str(actor.get("type", "")) == "arc_thrall" and str(effect.get("action_type", effect.get("kind", ""))) == "ranged" and str(effect.get("element", "")) == "lightning": return "tether"
	# Compound resolver steps keep their copied action_type. A case can map
	# their existing marker to a clip without changing gameplay descriptors.
	var selectors: Dictionary = Presentation.integration_for(str(actor.get("type", ""))).get("step_selectors", {})
	for flag: String in selectors:
		if bool(effect.get(flag, false)): return str(selectors[flag])
	var intent: String = str(effect.get("intent_id", actor.get("intent", {}).get("id", "")))
	intent = str(INTENT_SELECTORS.get(str(actor.get("type", "")), {}).get(intent, intent))
	var verb: String = str(effect.get("action_type", effect.get("kind", "")))
	verb = str(Presentation.integration_for(str(actor.get("type", ""))).get("action_aliases", {}).get(verb, verb))
	verb = str(ELEMENT_ACTION_SELECTORS.get(str(actor.get("type", "")), {}).get(verb, verb))
	# The existing Kindle resolver emits a status snapshot. Normalize only its
	# presentation selector; preserve the resolver step and protected clip data.
	if str(actor.get("type", "")) in ["ember_tick", "ember_hoarder"] and intent == "kindle" and verb == "status" and effect.has("enemy_after"):
		verb = "kindle"
	for clip: String in data["clips"]:
		for selector: String in data["clips"][clip].get("intents", []):
			if selector == intent or selector == intent + ":" + verb: return clip
	return ""

static func seconds_for(type: String, clip: String) -> float:
	return float(data_for(type).get("clips", {}).get(clip, {}).get("seconds", 0.0))

static func frames_for(type: String, clip: String) -> int:
	return maxi(1, roundi(seconds_for(type, clip) * FPS))

static func movement_frame(presentation: Dictionary, type: String, key: String, origin: Vector2, target: Vector2, direction: Vector2i, phase: float, reduced: bool, root_override: Dictionary = {}) -> void:
	var step: float = origin.distance_to(target)
	presentation[type + "_motion"] = {key: {"clip": "move", "direction": direction, "phase": phase, "step_distance_px": step}}
	if reduced: return
	if not root_override.is_empty():
		presentation[type + "_motion"][key]["root_forward_override"] = root_override
		presentation["unit_footprint_world_positions"] = {key: origin + (root_override["axis"] as Vector2) * float(root_override["forward_px"])}
	# The live canvas contains authored root travel. Anchor only that texture at
	# the segment origin; HUD/shadows follow the same eased/lifted body root.
	presentation["unit_texture_origins"] = {key: origin}
	presentation["unit_world_positions"] = {key: origin + Motion.root_offset(data_for(type), "move", phase, direction, step, root_override)}

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
