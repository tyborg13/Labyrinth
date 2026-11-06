extends RefCounted
## Additive presentation counters, separate from gameplay analytics. Cumulative
## losses identify a paid Bleed tick even when an action also hurts the hero.
const PLAYER_BLEED_KEY: String = "player_bleed_loss_totals"
const LOSS_FIELDS: Array = ["hp", "block", "stoneskin"]

static func record_player_bleed(state: Dictionary, before: Dictionary) -> void:
	var totals: Dictionary = (state.get(PLAYER_BLEED_KEY, {}) as Dictionary).duplicate()
	var after: Dictionary = state.get("player", {})
	for field: String in LOSS_FIELDS:
		totals[field] = int(totals.get(field, 0)) + maxi(0, int(before.get(field, 0)) - int(after.get(field, 0)))
	state[PLAYER_BLEED_KEY] = totals

static func player_bleed_loss(before: Dictionary, after: Dictionary, field: String) -> int:
	return maxi(0, int(after.get(PLAYER_BLEED_KEY, {}).get(field, 0)) - int(before.get(PLAYER_BLEED_KEY, {}).get(field, 0)))
