extends RefCounted

## Report the existing action adapters' callback schedules, including the
## first frame's t=0 submission. No production contact boundaries change.
const Action = preload("res://scripts/maquette_cutout_runtime/action.gd")
const Data = preload("res://scripts/game_data.gd")
const Fx = preload("res://scripts/attack_fx_library.gd")
const Ooze = preload("res://scripts/cinder_ooze_cutout/renderer.gd")

static func measure(type: String) -> Dictionary:
	var result: Dictionary = {}
	var data: Dictionary = Action.data_for(type)
	for intent: Dictionary in Data.enemy_def(type).get("intents", []):
		for action: Dictionary in intent["actions"]:
			if str(action["type"]) not in ["melee", "ranged", "aoe"] and data.is_empty(): continue
			var effect: Dictionary = action.duplicate(true)
			effect.merge({"kind":action["type"],"action_type":action["type"],"intent_id":intent["id"]},true)
			var actor: Dictionary = {"type":type,"intent":{"id":intent["id"]}}
			var clip: String = Action.clip_for(effect,actor)
			if clip == "move" or (not data.is_empty() and clip.is_empty()): continue
			# The resolver marks Fade as compound Veil. Preserve that selector
			# when measuring its visual contact instead of the generic fallback.
			if type == "gloam_stalker" and clip == "fade": effect["en03_veil"] = true
			var count: int = Action.frames_for(type,clip) if not clip.is_empty() else Ooze.attack_frame_count(effect) if type == "cinder_ooze" else 6
			var period: float = 1.0/60.0 if type == "cinder_ooze" or not clip.is_empty() else 0.04
			var contact: float = float(data.get("clips",{}).get(clip,{}).get("contact", Fx.feedback_start_progress(effect)))
			var adapter: Script = Action.playback_adapter(effect,actor)
			var first: int
			var route: String
			if adapter != null:
				route = adapter.resource_path
				first = ceili(contact * count) if route.ends_with("hoarfrost_seer_cutout/actions.gd") else ceili(contact * maxi(1,count-1))+1
			else:
				route = "RunScene/AttackFxLibrary"
				first = ceili(Fx.feedback_start_progress(effect) * count)
			var key: String = clip if not clip.is_empty() else str(intent["id"])
			result[key] = {"clip_seconds":count*period,"contact_seconds":maxi(0,first-1)*period,"authored_contact_seconds":contact*count*period,"contact_phase":contact,"contact_frame":first,"route":route}
	# Gloam's compound Veil selects Fade outside the ordinary intent action.
	if type == "gloam_stalker" and not result.has("fade"):
		var count: int = Action.frames_for(type,"fade")
		var contact: float = float(data["clips"]["fade"]["contact"])
		result["fade"] = {"clip_seconds":count/60.0,"contact_seconds":ceilf(contact*(count-1))/60.0,"authored_contact_seconds":contact*count/60.0,"contact_phase":contact,"route":"assets/units/gloam_stalker_cutout/actions.gd (compound Veil)"}
	return result
