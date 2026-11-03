extends RefCounted

const Data = preload("res://scripts/game_data.gd")
const Identity = preload("res://scripts/enemy_identity.gd")
const CAST_ACTIONS: Dictionary = {
	"briar_weaver": ["upheaval_mark"],
	"arc_thrall": ["lightning_strikes"],
	"hoarfrost_seer": ["icefall_mark", "icefall_land"],
}

# Battlefield-rule adapters still present the enemy's authored cast. Keep this
# metadata on the step so all playback paths use the same name and label.
static func decorate(step: Dictionary, enemy: Dictionary) -> Dictionary:
	var type: String = str(enemy.get("type", ""))
	if bool(step.get("cancelled", false)) or not (CAST_ACTIONS.get(type, []) as Array).has(str(step.get("action_type", ""))): return step
	var intent_id: String = str(enemy.get("intent", {}).get("id", ""))
	for authored: Dictionary in Data.enemy_def(type)["intents"]:
		if str(authored["id"]) != intent_id: continue
		var result: Dictionary = step.duplicate(false)
		result["actor_name"] = Identity.display_name(enemy)
		result["label"] = authored["name"]
		result["intent_id"] = intent_id
		return result
	return step
