extends RefCounted

const Data = preload("res://scripts/game_data.gd")
const Run = preload("res://scripts/run_engine.gd")
const Events = preload("res://scripts/event_rules.gd")
const Boons = preload("res://scripts/opening_boon_rules.gd")

static func collect() -> Dictionary:
	var run := Run.new()
	var starter: Array = Data.starting_deck()
	var legacy: Array = Data.compile_deck_cards(Data.starting_equipped_equipment(true), Data.starting_magic_cards(true))
	var reward: Array = []
	for cards: Array in Data.reward_card_pool_by_rarity("", true).values():
		reward.append_array(cards)
	var gear: Array = _gear_cards(Data.equipment_ids())
	var shop: Array = run._available_merchant_magic_ids({})
	shop.append_array(run._available_merchant_item_ids())
	shop.append_array(_gear_cards(run._available_merchant_equipment_ids({})))
	var events: Array = []
	_event_cards(Data.events(), reward, events)
	var boons: Array = Boons.spell_pool(str(Boons.definitions()["boons"]["elemental_gift"]["rarity"]))
	var legacy_ids: Array = []
	for id: String in Data.cards():
		if not str((Data.cards()[id] as Dictionary).get("replacement_id", "")).is_empty():
			legacy_ids.append(id)
	return {
		"starter": _unique(starter), "reward_pool": _unique(reward), "shop": _unique(shop),
		"events": _unique(events), "equipment": _unique(gear), "upgraded": [],
		"opening_boon_spells": _unique(boons), "legacy_starter": _unique(legacy),
		"legacy_replacement_ids": _unique(legacy_ids),
	}

static func _event_cards(value: Variant, reward: Array, result: Array) -> void:
	if value is Array:
		for child: Variant in value: _event_cards(child, reward, result)
	elif value is Dictionary:
		match str(value.get("type", "")):
			"item":
				result.append_array(Data.item_card_ids())
			"transform_magic":
				result.append_array(reward)
			"equipment", "reforge":
				for id: String in Data.equipment_ids():
					if not Data.equipment_is_pool_eligible(id): continue
					var gear: Dictionary = Data.equipment_def(id)
					if value.has("slot") and gear.get("slot") != value["slot"]: continue
					if value.has("rarity") and gear.get("rarity") != value["rarity"]: continue
					result.append_array(Data.equipment_cards(id))
			"card", "card_choice":
				var filter: String = str(value.get("element", "any"))
				var elements: Array = [""] if filter in ["any", "section", "shadow"] else [filter]
				for element: String in elements:
					var tiers: Array = Data.CARD_RARITY_TIERS
					var start: int = tiers.find(str(value.get("rarity", "common")))
					if value["type"] == "card":
						for index: int in range(start, -1, -1):
							var pool: Array[String] = Events._magic_pool(element, tiers[index])
							if pool.is_empty(): continue
							result.append_array(pool)
							break
					else:
						for index: int in range(tiers.find(str(value.get("min_rarity", "common"))), tiers.size()):
							result.append_array(Events._magic_pool(element, tiers[index]))
		for child: Variant in value.values(): _event_cards(child, reward, result)

static func _gear_cards(ids: Array) -> Array:
	var result: Array = []
	for id: String in ids: result.append_array(Data.equipment_cards(id))
	return result

static func _unique(ids: Array) -> Array:
	var distinct: Dictionary = {}
	for id: String in ids: distinct[id] = true
	var result: Array = distinct.keys()
	result.sort()
	return result
