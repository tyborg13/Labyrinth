extends RefCounted

const Fixture = preload("res://tests/helpers/card_display_fixture.gd")
const CARD: String = "seers_candle"
const SKILL: String = "long_dawn"
const RELIC_CARD: String = "nail_bomb"
const RELICS: Array = ["alchemists_retort"]

static func state(card_id: String = CARD) -> Dictionary:
	var result: Dictionary = Fixture.shop(preload("res://scripts/run_engine.gd").new())
	result["relics"] = RELICS.duplicate() if card_id == RELIC_CARD else []
	result["skill_ids"] = [SKILL]
	result["progression"]["skill_ids"] = [SKILL]
	result["equipped_items"] = [card_id]
	result["item_inventory"] = [card_id]
	return result
