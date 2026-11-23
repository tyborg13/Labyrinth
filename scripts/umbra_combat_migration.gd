extends RefCounted
## Existing in-flight effects keep their remaining turns. Placed Light persists
## for the rest of the fight, even if a legacy source had one turn left.

const GameData = preload("res://scripts/game_data.gd")
const RiteRules = preload("res://scripts/rite_rules.gd")

static func migrate_run(run: Dictionary) -> void:
	if run.get("combat_state") is Dictionary:
		migrate(run["combat_state"])
	for checkpoint: Variant in run.get("pending_combat_checkpoints", []):
		if checkpoint is Dictionary and checkpoint.get("state") is Dictionary:
			migrate(checkpoint["state"])

static func vision_turns(umbra: Dictionary) -> int:
	if umbra.has("vision_activations"):
		return int(umbra["vision_activations"])
	var sight: int = int(umbra.get("truesight_activations", 0))
	var bonus: int = int(umbra.get("vision_bonus_activations", 0))
	return -1 if sight < 0 or bonus < 0 else maxi(sight, bonus)

static func lasting_sources(umbra: Dictionary) -> Array:
	var sources: Array = (umbra.get("light_sources", []) as Array).duplicate(true)
	for source: Variant in sources:
		if source is Dictionary:
			source["remaining_activations"] = -1
	return sources

static func migrate(combat: Dictionary) -> void:
	for rite: Variant in RiteRules.active_rites(combat):
		if not (rite is Dictionary and str(rite.get("card_id", "")) == "rite_of_noon" and rite.get("effects") is Array):
			continue
		var effects: Array = rite["effects"]
		var kept: Array = effects.filter(func(effect: Variant) -> bool:
			return not (effect is Dictionary and str(effect.get("type", "")) == "target_state_action_mod"
				and effect.get("conditions") == {"target_in_light": true} and effect.get("add") == {"damage": 2})
		)
		if kept.size() != effects.size():
			rite["effects"] = kept
			rite["description"] = GameData.card_def("rite_of_noon")["description"]
	if not combat.get("umbra") is Dictionary:
		return
	var umbra: Dictionary = combat["umbra"]
	if not umbra.has("vision_activations"):
		umbra["vision_activations"] = vision_turns(umbra)
	if umbra.has("light_sources"):
		umbra["light_sources"] = lasting_sources(umbra)
	umbra.erase("truesight_activations")
	umbra.erase("vision_bonus")
	umbra.erase("vision_bonus_activations")
