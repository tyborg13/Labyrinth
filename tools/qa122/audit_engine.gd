extends "res://scripts/combat_engine.gd"
## Legacy card growth was removed from the live run. Inject only the production
## preview definition for these hypothetical cases; inherited gameplay resolves it.
const AuditData = preload("res://scripts/game_data.gd")

func card_def(card_id: String, state: Dictionary = {}) -> Dictionary:
	var mods: Array = state.get("qa122_card_mods", {}).get(card_id, [])
	if mods.is_empty(): return super.card_def(card_id, state)
	return AuditData.card_def_with_card_mods(card_id, {card_id: mods})
