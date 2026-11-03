extends RefCounted

## Stable synthetic cards keep dormant Flurry coverage independent of the pool.
const Data = preload("res://scripts/game_data.gd")
const RANGED_ID: String = "flu_test_ranged"
const MELEE_ID: String = "flu_test_melee"

static func definitions() -> Dictionary:
	return {
		RANGED_ID: {
			"name": "Synthetic Flurry Shot", "rarity": "rare", "element": "fire",
			"time": 5, "burn": false, "health_cost": 0, "reward_pool": false,
			"flurry": true, "actions": [{"type": "ranged", "damage": 2, "range": 3, "surface": "fire", "element": "fire"}]
		},
		MELEE_ID: {
			"name": "Synthetic Flurry Guard", "rarity": "epic", "time": 4,
			"burn": false, "health_cost": 0, "reward_pool": false, "flurry": true,
			"art_path": "res://assets/art/cards/blade_dance.png",
			"actions": [{"type": "block", "amount": 2}, {"type": "melee", "damage": 4, "range": 1, "element": "none"}]
		}
	}

static func install() -> void:
	Data.cards().merge(definitions(), true)

static func remove() -> void:
	for card_id: String in definitions():
		Data.cards().erase(card_id)
