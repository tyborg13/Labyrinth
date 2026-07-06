extends RefCounted
class_name GameData

const ElementData = preload("res://scripts/element_data.gd")

const CARDS_PATH: String = "res://data/cards.json"
const ENEMIES_PATH: String = "res://data/enemies.json"
const EQUIPMENT_PATH: String = "res://data/equipment.json"
const NPCS_PATH: String = "res://data/npcs.json"
const RELICS_PATH: String = "res://data/relics.json"
const UPGRADES_PATH: String = "res://data/upgrades.json"
const PROGRESSION_LEVELS_PATH: String = "res://data/progression_levels.json"
const PROGRESSION_STATS_PATH: String = "res://data/stats.json"
const FIXED_POINT_SCALE: int = 10
const ATTACK_ACTION_TYPES: Array[String] = ["melee", "ranged", "aoe", "push", "pull"]
const FIXED_POINT_ATTACK_ACTION_TYPES: Array[String] = ["melee", "ranged", "aoe", "push", "pull", "lightning_strikes"]
const STATUS_UPGRADE_FIELDS: Array[String] = ["burn", "poison", "freeze", "shock"]
const PROGRESSION_STAT_IDS: Array[String] = [
	"might",
	"dexterity",
	"agility",
	"vigor",
	"guard",
	"focus",
	"fire_magick",
	"ice_magick",
	"lightning_magick",
	"air_magick",
	"earth_magick"
]
const ELEMENT_MAGICK_STAT_IDS := {
	ElementData.FIRE: "fire_magick",
	ElementData.ICE: "ice_magick",
	ElementData.LIGHTNING: "lightning_magick",
	ElementData.AIR: "air_magick",
	ElementData.EARTH: "earth_magick"
}
const FIXED_RELIC_STAT_BONUS_KEYS: Array[String] = [
	"max_hp",
	"start_combat_block",
	"start_combat_stoneskin",
	"first_attack_bonus"
]
const RELIC_RARITY_ACCENTS := {
	"common": "#8f9499",
	"rare": "#4b84d8",
	"epic": "#9b62d6",
	"legendary": "#d9862f"
}
const RELIC_RARITY_OFFER_WEIGHTS := {
	"common": 12,
	"rare": 6,
	"epic": 3,
	"legendary": 1
}
const EQUIPMENT_SLOTS: Array[String] = ["weapon", "offhand", "armor", "boots", "trinket"]
const MAGIC_LOADOUT_LIMIT: int = 6
const ITEM_LOADOUT_LIMIT: int = 2
const STARTING_MAGIC_CARDS: Array[String] = [
	"pale_spark",
	"pale_spark",
	"dull_bolt",
	"dull_bolt",
	"waning_pulse",
	"waning_pulse"
]
const STARTING_EQUIPMENT_BY_SLOT := {
	"weapon": "training_sword",
	"offhand": "splintered_shield",
	"armor": "patched_cloak",
	"boots": "skirmisher_boots",
	"trinket": "cracked_lantern"
}

static var _cache: Dictionary = {}

static func cards() -> Dictionary:
	return _load_json_dict(CARDS_PATH)

static func enemies() -> Dictionary:
	return _load_json_dict(ENEMIES_PATH)

static func equipment() -> Dictionary:
	return _load_json_dict(EQUIPMENT_PATH)

static func npcs() -> Dictionary:
	return _load_json_dict(NPCS_PATH)

static func relics() -> Dictionary:
	return _load_json_dict(RELICS_PATH)

static func upgrades() -> Dictionary:
	return _load_json_dict(UPGRADES_PATH)

static func progression_levels() -> Dictionary:
	return _load_json_dict(PROGRESSION_LEVELS_PATH)

static func progression_stat_defs() -> Dictionary:
	return _load_json_dict(PROGRESSION_STATS_PATH)

static func card_def(card_id: String) -> Dictionary:
	return _scale_card_fixed_point(_raw_card_def(card_id))

static func card_def_with_upgrades(card_id: String, card_upgrades: Dictionary) -> Dictionary:
	var entry: Variant = card_upgrades.get(card_id, "")
	if typeof(entry) == TYPE_ARRAY:
		return card_def_with_card_mods(card_id, {card_id: entry})
	var upgrade_id: String = str(entry)
	if not upgrade_id.is_empty():
		var upgraded: Dictionary = upgraded_card_def(upgrade_id)
		return upgraded if not upgraded.is_empty() else card_def(card_id)
	return card_def(card_id)

static func card_def_with_card_mods(card_id: String, card_mods: Dictionary) -> Dictionary:
	var card: Dictionary = _raw_card_def(card_id)
	if card.is_empty():
		return {}
	var mods: Array = (card_mods.get(card_id, []) as Array).duplicate(true)
	card = _apply_card_mods(card, mods)
	card = _scale_card_fixed_point(card)
	if not mods.is_empty():
		card["base_card_id"] = card_id
		card["upgraded"] = true
		card["upgrade_count"] = mods.size()
	return card

static func card_def_for_progression(card_id: String, progression: Dictionary) -> Dictionary:
	var card: Dictionary = _raw_card_def_for_progression(card_id, progression)
	var mods: Array = ((progression.get("card_mods", {}) as Dictionary).get(card_id, []) as Array).duplicate(true)
	card = _apply_card_mods(card, mods)
	card = _scale_card_fixed_point(card)
	card = _apply_relic_card_effects(card, progression.get("relics", []))
	card = _apply_progression_stat_effects(card, progression)
	card = _tag_card_actions_for_combat(card)
	var total_count: int = card_upgrade_count(progression, card_id)
	if total_count > 0:
		card["base_card_id"] = card_id
		card["upgraded"] = true
		card["upgrade_count"] = total_count
	return card

static func enemy_def(enemy_type: String) -> Dictionary:
	return _scale_enemy_fixed_point(_duplicate_dict(enemies().get(enemy_type, {})))

static func npc_def(npc_id: String) -> Dictionary:
	return _duplicate_dict(npcs().get(npc_id, {}))

static func relic_def(relic_id: String) -> Dictionary:
	var relic: Dictionary = _duplicate_dict(relics().get(relic_id, {}))
	if relic.is_empty():
		return relic
	relic["description"] = _format_relic_description(relic)
	return relic

static func upgrade_def(upgrade_id: String) -> Dictionary:
	return _duplicate_dict(upgrades().get(upgrade_id, {}))

static func upgraded_card_def(upgrade_id: String) -> Dictionary:
	return _scale_card_fixed_point(_raw_upgraded_card_def(upgrade_id))

static func _raw_upgraded_card_def(upgrade_id: String) -> Dictionary:
	var upgrade: Dictionary = upgrade_def(upgrade_id)
	var card_id: String = str(upgrade.get("card_id", ""))
	var card: Dictionary = _raw_card_def(card_id)
	if card.is_empty():
		return {}
	var overrides: Dictionary = upgrade.get("card_overrides", {}) as Dictionary
	for key_var: Variant in overrides.keys():
		var key: String = str(key_var)
		card[key] = _duplicate_variant(overrides[key_var])
	card["base_card_id"] = card_id
	card["upgrade_id"] = upgrade_id
	card["upgraded"] = true
	return card

static func _raw_card_def(card_id: String) -> Dictionary:
	return _duplicate_dict(cards().get(card_id, {}))

static func _raw_card_def_for_progression(card_id: String, progression: Dictionary) -> Dictionary:
	var entry: Variant = (progression.get("card_upgrades", {}) as Dictionary).get(card_id, "")
	if typeof(entry) == TYPE_ARRAY:
		return _raw_card_def(card_id)
	var upgrade_id: String = str(entry)
	if not upgrade_id.is_empty():
		var upgraded: Dictionary = _raw_upgraded_card_def(upgrade_id)
		return upgraded if not upgraded.is_empty() else _raw_card_def(card_id)
	return _raw_card_def(card_id)

static func starting_deck() -> Array:
	return compile_deck_cards(starting_equipped_equipment(), starting_magic_cards())

static func magic_loadout_limit() -> int:
	return MAGIC_LOADOUT_LIMIT

static func item_loadout_limit() -> int:
	return ITEM_LOADOUT_LIMIT

static func starting_magic_cards() -> Array:
	return STARTING_MAGIC_CARDS.duplicate()

static func reward_card_pool_by_rarity(element_filter: String = "", elemental_only: bool = false) -> Dictionary:
	var result: Dictionary = {
		"common": [],
		"uncommon": [],
		"rare": []
	}
	for card_id: String in cards().keys():
		var card: Dictionary = cards()[card_id]
		if not bool(card.get("reward_pool", true)):
			continue
		var rarity: String = str(card.get("rarity", "common"))
		if rarity == "starter":
			continue
		var card_element: String = card_element_from_def(card)
		if elemental_only and not ElementData.is_elemental(card_element):
			continue
		if not element_filter.is_empty() and card_element != element_filter:
			continue
		if not result.has(rarity):
			result[rarity] = []
		(result[rarity] as Array).append(card_id)
	return result

static func card_element(card_id: String) -> String:
	return card_element_from_def(card_def(card_id))

static func card_element_from_def(card: Dictionary) -> String:
	var element_id: String = str(card.get("element", ElementData.NONE))
	return element_id if ElementData.ELEMENTS.has(element_id) else ElementData.NONE

static func card_has_action_type(card_id: String, action_type: String) -> bool:
	var card: Dictionary = card_def(card_id)
	for action_var: Variant in card.get("actions", []):
		var action: Dictionary = action_var
		if str(action.get("type", "")) == action_type:
			return true
	return false

static func reward_offer_weight(card_id: String) -> int:
	return 1 if card_has_action_type(card_id, "heal") else 3

static func item_card_ids() -> Array:
	var result: Array = []
	for card_id: String in cards().keys():
		if card_is_item(card_id):
			result.append(card_id)
	result.sort()
	return result

static func card_is_item(card_id: String) -> bool:
	var card: Dictionary = _raw_card_def(card_id)
	return bool(card.get("item", false))

static func card_consumes_on_play(card_id: String) -> bool:
	var card: Dictionary = _raw_card_def(card_id)
	return bool(card.get("consume_on_play", false))

static func item_offer_weight(card_id: String) -> int:
	var rarity: String = str(_raw_card_def(card_id).get("rarity", "common"))
	match rarity:
		"rare":
			return 3
		"uncommon":
			return 6
	return 12

static func equipment_slots() -> Array[String]:
	return EQUIPMENT_SLOTS.duplicate()

static func equipment_ids() -> Array:
	return equipment().keys()

static func equipment_def(equipment_id: String) -> Dictionary:
	return _duplicate_dict(equipment().get(equipment_id, {}))

static func equipment_slot(equipment_id: String) -> String:
	var slot: String = str(equipment_def(equipment_id).get("slot", ""))
	return slot if EQUIPMENT_SLOTS.has(slot) else ""

static func equipment_rarity(equipment_id: String) -> String:
	var rarity: String = str(equipment_def(equipment_id).get("rarity", "common"))
	return rarity if RELIC_RARITY_ACCENTS.has(rarity) else "common"

static func equipment_rarity_accent(rarity: String) -> String:
	return relic_rarity_accent(rarity)

static func equipment_accent(equipment_id: String) -> String:
	var item: Dictionary = equipment_def(equipment_id)
	return str(item.get("accent", equipment_rarity_accent(equipment_rarity(equipment_id))))

static func equipment_offer_weight(equipment_id: String) -> int:
	return int(RELIC_RARITY_OFFER_WEIGHTS.get(equipment_rarity(equipment_id), RELIC_RARITY_OFFER_WEIGHTS["common"]))

static func starting_equipped_equipment() -> Dictionary:
	return STARTING_EQUIPMENT_BY_SLOT.duplicate(true)

static func starter_equipment_ids() -> Array:
	var result: Array = []
	for slot: String in EQUIPMENT_SLOTS:
		var equipment_id: String = str(STARTING_EQUIPMENT_BY_SLOT.get(slot, ""))
		if not equipment_id.is_empty():
			result.append(equipment_id)
	return result

static func equipment_cards(equipment_id: String) -> Array:
	var item: Dictionary = equipment_def(equipment_id)
	var result: Array = []
	var raw_cards: Array = item.get("cards", [])
	for entry_var: Variant in raw_cards:
		if typeof(entry_var) == TYPE_STRING:
			result.append(str(entry_var))
			continue
		if typeof(entry_var) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_var as Dictionary
		var card_id: String = str(entry.get("id", entry.get("card_id", "")))
		if card_id.is_empty():
			continue
		var count: int = maxi(1, int(entry.get("count", 1)))
		for _copy_index: int in range(count):
			result.append(card_id)
	return result

static func compile_deck_cards(equipped_equipment: Dictionary, magic_cards: Array, item_cards: Array = []) -> Array:
	var result: Array = []
	for slot: String in EQUIPMENT_SLOTS:
		var equipment_id: String = str(equipped_equipment.get(slot, ""))
		if equipment_id.is_empty():
			continue
		result.append_array(equipment_cards(equipment_id))
	for card_id_var: Variant in magic_cards:
		var card_id: String = str(card_id_var)
		if not card_id.is_empty():
			result.append(card_id)
	for card_id_var: Variant in item_cards:
		var card_id: String = str(card_id_var)
		if card_is_item(card_id):
			result.append(card_id)
	return result

static func relic_ids() -> Array:
	return relics().keys()

static func relic_rarity(relic_id: String) -> String:
	var rarity: String = str(relic_def(relic_id).get("rarity", "common"))
	return rarity if RELIC_RARITY_ACCENTS.has(rarity) else "common"

static func relic_rarity_accent(rarity: String) -> String:
	return str(RELIC_RARITY_ACCENTS.get(str(rarity), RELIC_RARITY_ACCENTS["common"]))

static func relic_accent(relic_id: String) -> String:
	var relic: Dictionary = relic_def(relic_id)
	return str(relic.get("accent", relic_rarity_accent(relic_rarity(relic_id))))

static func relic_offer_weight(relic_id: String) -> int:
	return int(RELIC_RARITY_OFFER_WEIGHTS.get(relic_rarity(relic_id), RELIC_RARITY_OFFER_WEIGHTS["common"]))

static func relic_effects(relic_id: String) -> Array[Dictionary]:
	var relic: Dictionary = relic_def(relic_id)
	var result: Array[Dictionary] = []
	var raw_effects: Array = relic.get("effects", [])
	for effect_var: Variant in raw_effects:
		if typeof(effect_var) != TYPE_DICTIONARY:
			continue
		var effect: Dictionary = (effect_var as Dictionary).duplicate(true)
		effect["relic_id"] = relic_id
		result.append(effect)
	var legacy_effect: String = str(relic.get("effect", ""))
	if result.is_empty() and not legacy_effect.is_empty():
		result.append({
			"type": legacy_effect,
			"value": int(relic.get("value", 0)),
			"relic_id": relic_id
		})
	return result

static func relic_effects_for_ids(relic_ids_list: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for relic_id_var: Variant in relic_ids_list:
		result.append_array(relic_effects(str(relic_id_var)))
	return result

static func upgrade_ids() -> Array:
	return upgrades().keys()

static func card_upgrade_ids() -> Array:
	var result: Array = []
	for upgrade_id: String in upgrade_ids():
		if not str(upgrade_def(upgrade_id).get("card_id", "")).is_empty():
			result.append(upgrade_id)
	result.sort_custom(func(a: Variant, b: Variant) -> bool:
		var a_card: Dictionary = card_def(str(upgrade_def(str(a)).get("card_id", "")))
		var b_card: Dictionary = card_def(str(upgrade_def(str(b)).get("card_id", "")))
		var a_rarity: int = _rarity_sort_index(str(a_card.get("rarity", "common")))
		var b_rarity: int = _rarity_sort_index(str(b_card.get("rarity", "common")))
		if a_rarity == b_rarity:
			return str(a_card.get("name", a)) < str(b_card.get("name", b))
		return a_rarity < b_rarity
	)
	return result

static func upgrade_card_id(upgrade_id: String) -> String:
	return str(upgrade_def(upgrade_id).get("card_id", ""))

static func upgrade_cost(upgrade_id: String) -> int:
	var upgrade: Dictionary = upgrade_def(upgrade_id)
	if upgrade.has("cost") and int(upgrade.get("cost", 0)) > 0:
		return int(upgrade.get("cost", 0))
	var card_id: String = str(upgrade.get("card_id", ""))
	if card_id.is_empty():
		return int(upgrade.get("cost", 0))
	var base_card: Dictionary = card_def(card_id)
	var upgraded_card: Dictionary = upgraded_card_def(upgrade_id)
	if base_card.is_empty() or upgraded_card.is_empty():
		return 0
	var delta: float = maxf(1.0, _card_value(upgraded_card) - _card_value(base_card))
	var rarity_floor: int = _upgrade_floor_for_rarity(str(base_card.get("rarity", "common")))
	var scaled_cost: int = ceili(delta * 8.0 / 5.0) * 5
	return maxi(rarity_floor, scaled_cost)

static func upgrade_delta_summary(upgrade_id: String) -> String:
	var card_id: String = upgrade_card_id(upgrade_id)
	var base_card: Dictionary = card_def(card_id)
	var upgraded_card: Dictionary = upgraded_card_def(upgrade_id)
	if base_card.is_empty() or upgraded_card.is_empty():
		return ""
	var base_value: float = _card_value(base_card)
	var upgraded_value: float = _card_value(upgraded_card)
	return "+%.1f value" % maxf(0.0, upgraded_value - base_value)

static func upgradeable_card_ids() -> Array:
	var result: Array = []
	for card_id: String in cards().keys():
		if card_is_item(card_id):
			continue
		result.append(card_id)
	result.sort_custom(func(a: Variant, b: Variant) -> bool:
		var a_card: Dictionary = card_def(str(a))
		var b_card: Dictionary = card_def(str(b))
		var a_rarity: int = _rarity_sort_index(str(a_card.get("rarity", "common")))
		var b_rarity: int = _rarity_sort_index(str(b_card.get("rarity", "common")))
		if a_rarity == b_rarity:
			return str(a_card.get("name", a)) < str(b_card.get("name", b))
		return a_rarity < b_rarity
	)
	return result

static func upgradeable_elements_for_card(card_id: String, progression: Dictionary) -> Array:
	var card: Dictionary = card_def_for_progression(card_id, progression)
	var elements: Array = []
	var actions: Array = (card.get("actions", []) as Array).duplicate(true)
	for index: int in range(actions.size()):
		if typeof(actions[index]) != TYPE_DICTIONARY:
			continue
		var action: Dictionary = actions[index]
		var action_type: String = str(action.get("type", ""))
		if action.has("damage"):
			_append_upgrade_element_if_available(elements, card_id, progression, {
				"key": "stat:%d:damage" % index,
				"kind": "stat",
				"action_index": index,
				"field": "damage",
				"label": "Damage"
			})
		if action.has("range"):
			var range_label: String = "Move Range" if action_type == "move" else "Blink Range" if action_type == "blink" else "Illusion Range" if action_type == "illusion" else "Attack Range"
			_append_upgrade_element_if_available(elements, card_id, progression, {
				"key": "stat:%d:range" % index,
				"kind": "stat",
				"action_index": index,
				"field": "range",
				"label": range_label
			})
		if action.has("amount"):
			_append_upgrade_element_if_available(elements, card_id, progression, {
				"key": "stat:%d:amount" % index,
				"kind": "stat",
				"action_index": index,
				"field": "amount",
				"label": _amount_upgrade_label(action_type)
			})
		if action.has("health"):
			_append_upgrade_element_if_available(elements, card_id, progression, {
				"key": "stat:%d:health" % index,
				"kind": "stat",
				"action_index": index,
				"field": "health",
				"label": "Illusion Health" if action_type == "illusion" else "Health"
			})
		if action_type in ATTACK_ACTION_TYPES:
			for status_field: String in STATUS_UPGRADE_FIELDS:
				_append_upgrade_element_if_available(elements, card_id, progression, {
					"key": "status:%d:%s" % [index, status_field],
					"kind": "status",
					"action_index": index,
					"field": status_field,
					"label": "%s Effect" % _status_label(status_field)
				})
		if action_type == "aoe":
			_append_upgrade_element_if_available(elements, card_id, progression, {
				"key": "pattern:%d" % index,
				"kind": "pattern",
				"action_index": index,
				"field": "pattern",
				"label": "Area Pattern"
			})
	_append_upgrade_element_if_available(elements, card_id, progression, {
		"key": "action:new",
		"kind": "action",
		"label": "New Action"
	})
	return elements

static func upgrade_options_for_element(card_id: String, element: Dictionary, progression: Dictionary) -> Array:
	var card: Dictionary = card_def_for_progression(card_id, progression)
	var actions: Array = card.get("actions", [])
	var options: Array = []
	if str(element.get("kind", "")) == "action":
		options = _action_upgrade_options(card, element)
		for option: Dictionary in options:
			option["cost"] = card_mod_cost(card_id, option, progression)
		return options
	var action_index: int = int(element.get("action_index", -1))
	if action_index < 0 or action_index >= actions.size() or typeof(actions[action_index]) != TYPE_DICTIONARY:
		return []
	var action: Dictionary = actions[action_index]
	match str(element.get("kind", "")):
		"stat":
			options = _stat_upgrade_options(action, element)
		"status":
			options = _status_upgrade_options(action, element)
		"pattern":
			options = _pattern_upgrade_options(action, element)
	for option: Dictionary in options:
		option["cost"] = card_mod_cost(card_id, option, progression)
	return options

static func preview_card_with_mod(card_id: String, mod: Dictionary, progression: Dictionary) -> Dictionary:
	var card: Dictionary = card_def_for_progression(card_id, progression)
	var preview: Dictionary = _apply_card_mod(card, mod)
	preview["upgraded"] = true
	return preview

static func card_mod_cost(card_id: String, mod: Dictionary, progression: Dictionary) -> int:
	var current_card: Dictionary = card_def_for_progression(card_id, progression)
	var preview_card: Dictionary = _apply_card_mod(current_card, mod)
	var value_delta: float = maxf(0.1, _card_value(preview_card) - _card_value(current_card))
	var value_cost: int = ceili(value_delta * 120.0 / 10.0) * 10
	var base_cost: int = maxi(int(mod.get("cost_base", 180)), value_cost)
	var rarity_multiplier: float = _rarity_cost_multiplier(str(card_def(card_id).get("rarity", "common")))
	var upgrade_count: int = card_upgrade_count(progression, card_id)
	var stack_multiplier: float = 1.0 + float(upgrade_count) * 0.65 + float(upgrade_count * upgrade_count) * 0.22
	return ceili(float(base_cost) * rarity_multiplier * stack_multiplier / 10.0) * 10

static func card_upgrade_count(progression: Dictionary, card_id: String) -> int:
	var total: int = 0
	if not str((progression.get("card_upgrades", {}) as Dictionary).get(card_id, "")).is_empty():
		total += 1
	total += ((progression.get("card_mods", {}) as Dictionary).get(card_id, []) as Array).size()
	return total

static func progression_stat_ids() -> Array[String]:
	return PROGRESSION_STAT_IDS.duplicate()

static func progression_stat_def(stat_id: String) -> Dictionary:
	return _duplicate_dict(progression_stat_defs().get(stat_id, {}))

static func default_progression_stats() -> Dictionary:
	var result: Dictionary = {}
	for stat_id: String in PROGRESSION_STAT_IDS:
		result[stat_id] = 0
	return result

static func normalized_progression_stats(stats_value: Variant) -> Dictionary:
	var source: Dictionary = {}
	if typeof(stats_value) == TYPE_DICTIONARY:
		source = stats_value as Dictionary
	var result: Dictionary = {}
	var cap: int = progression_stat_cap()
	for stat_id: String in PROGRESSION_STAT_IDS:
		result[stat_id] = clampi(int(source.get(stat_id, 0)), 0, cap)
	return result

static func spent_progression_stat_points(stats_value: Variant) -> int:
	var total: int = 0
	var stats: Dictionary = normalized_progression_stats(stats_value)
	for stat_id: String in PROGRESSION_STAT_IDS:
		total += int(stats.get(stat_id, 0))
	return total

static func max_progression_level() -> int:
	return maxi(1, int(progression_levels().get("max_level", 20)))

static func progression_stat_cap() -> int:
	return maxi(1, int(progression_levels().get("stat_cap", 10)))

static func progression_stat_points_per_level() -> int:
	return maxi(1, int(progression_levels().get("stat_points_per_level", 1)))

static func progression_stat_points_for_level(level: int) -> int:
	return maxi(0, clampi(level, 1, max_progression_level()) - 1) * progression_stat_points_per_level()

static func progression_level_cost(target_level: int) -> int:
	var max_level: int = max_progression_level()
	if target_level <= 1 or target_level > max_level:
		return 0
	var costs: Dictionary = progression_levels().get("costs", {}) as Dictionary
	return maxi(0, int(costs.get(str(target_level), 0)))

static func progression_level_total_cost(level: int) -> int:
	var total: int = 0
	for target_level: int in range(2, mini(level, max_progression_level()) + 1):
		total += progression_level_cost(target_level)
	return total

static func stat_value(progression: Dictionary, stat_id: String) -> int:
	return int(normalized_progression_stats(progression.get("stats", {})).get(stat_id, 0))

static func vigor_max_hp_bonus(progression: Dictionary) -> int:
	return stat_value(progression, "vigor") * FIXED_POINT_SCALE

static func stat_bonus_from_upgrades(progression: Dictionary, effect_key: String) -> int:
	var total: int = 0
	for upgrade_id_var: Variant in progression.get("purchased_upgrades", []):
		var upgrade_id: String = str(upgrade_id_var)
		var upgrade: Dictionary = upgrades().get(upgrade_id, {})
		if str(upgrade.get("effect", "")) == effect_key:
			total += int(upgrade.get("value", 0))
	return total

static func stat_bonus_from_relics(relic_ids_list: Array, effect_key: String) -> int:
	var total: int = 0
	for effect: Dictionary in relic_effects_for_ids(relic_ids_list):
		if str(effect.get("type", "")) == effect_key:
			total += int(effect.get("value", 0))
	if effect_key in FIXED_RELIC_STAT_BONUS_KEYS:
		total *= FIXED_POINT_SCALE
	return total

static func fixed_point_amount(amount: int) -> int:
	return amount * FIXED_POINT_SCALE

static func status_tick_reduction(status_id: String) -> int:
	return FIXED_POINT_SCALE if status_id in ["burn", "poison"] else 1

static func action_field_uses_fixed_point(action_type: String, field: String) -> bool:
	if field in ["damage", "self_damage", "burn", "bleed", "expose", "sunder", "poison"]:
		return action_type in FIXED_POINT_ATTACK_ACTION_TYPES or action_type in ["trap", "all_enemies_damage", "all_enemies_status"]
	if field == "amount":
		return action_type in ["block", "stoneskin", "heal", "heal_self", "heal_ally", "guard_ally"]
	if field == "health":
		return action_type == "illusion"
	return false

static func scaled_action_field_delta(action_type: String, field: String, amount: int) -> int:
	return amount * FIXED_POINT_SCALE if action_field_uses_fixed_point(action_type, field) else amount

static func _format_relic_description(relic: Dictionary) -> String:
	var template: String = str(relic.get("description", ""))
	if template.is_empty():
		return template
	var values: Dictionary = _relic_description_values(relic)
	for key_var: Variant in values.keys():
		var key: String = str(key_var)
		template = template.replace("{%s}" % key, str(values.get(key, "")))
	return template

static func _relic_description_values(relic: Dictionary) -> Dictionary:
	var values: Dictionary = {}
	var raw_effects: Variant = relic.get("effects", [])
	if typeof(raw_effects) != TYPE_ARRAY:
		return values
	var effects: Array = raw_effects as Array
	for effect_index: int in range(effects.size()):
		if typeof(effects[effect_index]) != TYPE_DICTIONARY:
			continue
		var effect: Dictionary = effects[effect_index] as Dictionary
		for key_var: Variant in effect.keys():
			var key: String = str(key_var)
			var display_value: Variant = _relic_effect_display_value(effect, key)
			_store_relic_description_value(values, "%d.%s" % [effect_index, key], display_value)
			if effect_index == 0:
				_store_relic_description_value(values, key, display_value)
		if str(effect.get("type", "")) == "prevent_lethal_once":
			_store_relic_description_value(values, "%d.lethal_health" % effect_index, FIXED_POINT_SCALE)
			if effect_index == 0:
				_store_relic_description_value(values, "lethal_health", FIXED_POINT_SCALE)
		_append_relic_action_description_values(values, effect, effect_index)
		_append_relic_reward_description_values(values, effect, effect_index)
	return values

static func _append_relic_action_description_values(values: Dictionary, effect: Dictionary, effect_index: int) -> void:
	var raw_action: Variant = effect.get("action", {})
	if typeof(raw_action) != TYPE_DICTIONARY:
		return
	var action: Dictionary = raw_action as Dictionary
	for key_var: Variant in action.keys():
		var key: String = str(key_var)
		var display_value: Variant = _relic_action_display_value(action, key)
		_store_relic_description_value(values, "%d.action.%s" % [effect_index, key], display_value)
		if effect_index == 0:
			_store_relic_description_value(values, "action.%s" % key, display_value)

static func _append_relic_reward_description_values(values: Dictionary, effect: Dictionary, effect_index: int) -> void:
	var raw_rewards: Variant = effect.get("rewards", [])
	var rewards: Array = []
	if typeof(raw_rewards) == TYPE_ARRAY:
		rewards = raw_rewards as Array
	elif typeof(raw_rewards) == TYPE_DICTIONARY:
		rewards = [raw_rewards]
	for reward_index: int in range(rewards.size()):
		if typeof(rewards[reward_index]) != TYPE_DICTIONARY:
			continue
		var reward: Dictionary = rewards[reward_index] as Dictionary
		for key_var: Variant in reward.keys():
			var key: String = str(key_var)
			var display_value: Variant = _relic_reward_display_value(reward, key)
			_store_relic_description_value(values, "%d.reward%d.%s" % [effect_index, reward_index, key], display_value)
			if effect_index == 0:
				_store_relic_description_value(values, "reward%d.%s" % [reward_index, key], display_value)

static func _store_relic_description_value(values: Dictionary, key: String, value: Variant) -> void:
	values[key] = value
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return
	var dot_index: int = key.rfind(".")
	var abs_key: String = "abs_%s" % key
	if dot_index >= 0:
		abs_key = "%sabs_%s" % [key.substr(0, dot_index + 1), key.substr(dot_index + 1)]
	values[abs_key] = absi(int(value))

static func _relic_effect_display_value(effect: Dictionary, key: String) -> Variant:
	var raw_value: Variant = effect.get(key, "")
	if typeof(raw_value) != TYPE_INT and typeof(raw_value) != TYPE_FLOAT:
		return raw_value
	var amount: int = int(raw_value)
	var effect_type: String = str(effect.get("type", ""))
	match effect_type:
		"max_hp", "first_attack_bonus", "start_combat_stoneskin", "start_combat_block", "damage_vs_status", "kill_status_heal", "glass_attack_bonus", "stoneskin_thorns":
			if key == "value":
				return fixed_point_amount(amount)
		"prevent_lethal_once":
			if key == "burn_all_enemies":
				return fixed_point_amount(amount)
		"start_combat_stoneskin_per_deck_element":
			if key == "value" or key == "max_value":
				return fixed_point_amount(amount)
		"card_action_mod":
			if (key == "amount" or key == "value") and _relic_card_action_mod_uses_fixed_point(effect):
				return fixed_point_amount(amount)
	return amount

static func _relic_action_display_value(action: Dictionary, key: String) -> Variant:
	var raw_value: Variant = action.get(key, "")
	if typeof(raw_value) != TYPE_INT and typeof(raw_value) != TYPE_FLOAT:
		return raw_value
	var amount: int = int(raw_value)
	return scaled_action_field_delta(str(action.get("type", "")), key, amount)

static func _relic_reward_display_value(reward: Dictionary, key: String) -> Variant:
	var raw_value: Variant = reward.get(key, "")
	if typeof(raw_value) != TYPE_INT and typeof(raw_value) != TYPE_FLOAT:
		return raw_value
	var amount: int = int(raw_value)
	if key != "amount" and key != "value":
		return amount
	match str(reward.get("type", "")):
		"block", "stoneskin", "heal", "all_enemies_damage":
			return fixed_point_amount(amount)
		"all_enemies_status":
			var status_id: String = str(reward.get("status", ""))
			return fixed_point_amount(amount) if status_id in ["burn", "poison"] else amount
		_:
			return amount

static func _relic_card_action_mod_uses_fixed_point(effect: Dictionary) -> bool:
	var field: String = str(effect.get("field", ""))
	var raw_action_types: Variant = effect.get("action_types", [])
	if typeof(raw_action_types) != TYPE_ARRAY:
		return false
	for action_type_var: Variant in raw_action_types as Array:
		if action_field_uses_fixed_point(str(action_type_var), field):
			return true
	return false

static func shuffle_cards(card_ids: Array, rng: RandomNumberGenerator) -> Array[String]:
	var result: Array[String] = []
	for card_id_var: Variant in card_ids:
		result.append(str(card_id_var))
	if rng == null:
		return result
	for index: int in range(result.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, index)
		var tmp: String = result[index]
		result[index] = result[swap_index]
		result[swap_index] = tmp
	return result

static func _load_json_dict(path: String) -> Dictionary:
	if _cache.has(path):
		return _cache[path]
	if not FileAccess.file_exists(path):
		push_error("Missing data file: %s" % path)
		_cache[path] = {}
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Unable to open data file: %s" % path)
		_cache[path] = {}
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Expected dictionary JSON in %s" % path)
		_cache[path] = {}
		return {}
	_cache[path] = (parsed as Dictionary).duplicate(true)
	return _cache[path]

static func _duplicate_dict(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(true)

static func _duplicate_variant(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			return (value as Dictionary).duplicate(true)
		TYPE_ARRAY:
			return (value as Array).duplicate(true)
		_:
			return value

static func _scale_card_fixed_point(card: Dictionary) -> Dictionary:
	var next_card: Dictionary = card.duplicate(true)
	if next_card.is_empty():
		return next_card
	if next_card.has("health_cost"):
		next_card["health_cost"] = int(next_card.get("health_cost", 0)) * FIXED_POINT_SCALE
	var actions: Array = []
	for action_var: Variant in next_card.get("actions", []):
		if typeof(action_var) != TYPE_DICTIONARY:
			continue
		actions.append(_scale_action_fixed_point(action_var as Dictionary))
	next_card["actions"] = actions
	return next_card

static func _scale_enemy_fixed_point(enemy: Dictionary) -> Dictionary:
	var next_enemy: Dictionary = enemy.duplicate(true)
	if next_enemy.is_empty():
		return next_enemy
	if next_enemy.has("max_hp"):
		next_enemy["max_hp"] = int(next_enemy.get("max_hp", 0)) * FIXED_POINT_SCALE
	var intents: Array = []
	for intent_var: Variant in next_enemy.get("intents", []):
		if typeof(intent_var) != TYPE_DICTIONARY:
			continue
		var intent: Dictionary = (intent_var as Dictionary).duplicate(true)
		var actions: Array = []
		for action_var: Variant in intent.get("actions", []):
			if typeof(action_var) != TYPE_DICTIONARY:
				continue
			actions.append(_scale_action_fixed_point(action_var as Dictionary))
		intent["actions"] = actions
		intents.append(intent)
	next_enemy["intents"] = intents
	return next_enemy

static func _scale_action_fixed_point(action: Dictionary) -> Dictionary:
	var next_action: Dictionary = action.duplicate(true)
	var action_type: String = str(next_action.get("type", ""))
	for field: String in ["damage", "self_damage", "burn", "bleed", "expose", "sunder", "poison", "amount", "health"]:
		if next_action.has(field) and action_field_uses_fixed_point(action_type, field):
			next_action[field] = int(next_action.get(field, 0)) * FIXED_POINT_SCALE
	if typeof(next_action.get("intensity_bonus", {})) == TYPE_DICTIONARY:
		var bonus: Dictionary = (next_action.get("intensity_bonus", {}) as Dictionary).duplicate(true)
		for field: String in ["damage", "self_damage", "burn", "bleed", "expose", "sunder", "poison", "amount", "health"]:
			if bonus.has(field) and action_field_uses_fixed_point(action_type, field):
				bonus[field] = int(bonus.get(field, 0)) * FIXED_POINT_SCALE
		next_action["intensity_bonus"] = bonus
	return next_action

static func _rarity_sort_index(rarity: String) -> int:
	match rarity:
		"starter":
			return 0
		"common":
			return 1
		"uncommon":
			return 2
		"rare":
			return 3
		_:
			return 4

static func _upgrade_floor_for_rarity(rarity: String) -> int:
	match rarity:
		"starter":
			return 15
		"common":
			return 20
		"uncommon":
			return 30
		"rare":
			return 45
		_:
			return 20

static func _rarity_cost_multiplier(rarity: String) -> float:
	match rarity:
		"starter":
			return 1.0
		"common":
			return 1.12
		"uncommon":
			return 1.28
		"rare":
			return 1.48
		_:
			return 1.12

static func _append_upgrade_element_if_available(elements: Array, card_id: String, progression: Dictionary, element: Dictionary) -> void:
	if not upgrade_options_for_element(card_id, element, progression).is_empty():
		elements.append(element)

static func _amount_upgrade_label(action_type: String) -> String:
	match action_type:
		"block":
			return "Block"
		"stoneskin":
			return "Stoneskin"
		"heal":
			return "Healing"
		"draw":
			return "Draw"
		"card_play":
			return "Card Play"
		_:
			return "Amount"

static func _status_label(status_field: String) -> String:
	match status_field:
		"burn":
			return "Burn"
		"poison":
			return "Poison"
		"freeze":
			return "Freeze"
		"shock":
			return "Shock"
		"immobilize":
			return "Immobilize"
		_:
			return status_field.capitalize()

static func _stat_upgrade_options(action: Dictionary, element: Dictionary) -> Array:
	var action_index: int = int(element.get("action_index", -1))
	var field: String = str(element.get("field", ""))
	var action_type: String = str(action.get("type", ""))
	var options: Array = []
	match field:
		"damage":
			var base_cost: int = 190 if action_type == "aoe" else 130
			for amount: int in [1, 2, 3]:
				options.append(_stat_mod(action_index, field, amount, "Damage +%d" % amount, base_cost * amount * amount))
		"range":
			if action_type in ["move", "blink", "illusion"]:
				var base_cost: int = 150 if action_type == "move" else 170 if action_type == "illusion" else 190
				for amount: int in [1, 2]:
					options.append(_stat_mod(action_index, field, amount, "Range +%d" % amount, base_cost * amount * amount))
			elif action_type in ATTACK_ACTION_TYPES:
				var attack_base: int = 210 if action_type == "aoe" else 170
				options.append(_stat_mod(action_index, field, 1, "Range +1", attack_base))
				if action_type in ["ranged", "aoe"]:
					options.append(_stat_mod(action_index, field, 2, "Range +2", attack_base * 4))
		"amount":
			match action_type:
				"block":
					for amount: int in [2, 4]:
						options.append(_stat_mod(action_index, field, amount, "Block +%d" % amount, 75 * amount))
				"stoneskin":
					for amount: int in [1, 2]:
						options.append(_stat_mod(action_index, field, amount, "Stoneskin +%d" % amount, 170 * amount * amount))
				"heal":
					for amount: int in [1, 2]:
						options.append(_stat_mod(action_index, field, amount, "Heal +%d" % amount, 210 * amount * amount))
				"draw":
					options.append(_stat_mod(action_index, field, 1, "Draw +1", 520))
		"health":
			if action_type == "illusion":
				for amount: int in [1, 2]:
					options.append(_stat_mod(action_index, field, amount, "Health +%d" % amount, 130 * amount * amount))
	return options

static func _status_upgrade_options(action: Dictionary, element: Dictionary) -> Array:
	var action_index: int = int(element.get("action_index", -1))
	var field: String = str(element.get("field", ""))
	var current: int = int(action.get(field, 0))
	var options: Array = []
	match field:
		"burn":
			for amount: int in [1, 2]:
				options.append(_stat_mod(action_index, field, amount, "Burn +%d" % amount, 250 * amount * amount, "status"))
		"poison":
			for amount: int in [2, 4]:
				options.append(_stat_mod(action_index, field, amount, "Poison +%d" % amount, 95 * amount * amount, "status"))
		"freeze":
			if current <= 0:
				options.append(_stat_mod(action_index, field, 1, "Add Freeze", 760, "status"))
		"shock":
			if current <= 0:
				options.append(_stat_mod(action_index, field, 1, "Add Shock", 620, "status"))
	return options

static func _pattern_upgrade_options(action: Dictionary, element: Dictionary) -> Array:
	var action_index: int = int(element.get("action_index", -1))
	var pattern: Array = (action.get("pattern", []) as Array).duplicate(true)
	var options: Array = []
	var diagonal_offsets: Array = [[1, 1], [1, -1], [-1, 1], [-1, -1]]
	if _missing_offsets(pattern, diagonal_offsets).size() > 0:
		options.append({
			"kind": "pattern_add",
			"action_index": action_index,
			"label": "Add diagonals",
			"offsets": diagonal_offsets,
			"cost_base": 920
		})
	var extended_cross: Array = [[2, 0], [-2, 0], [0, 2], [0, -2]]
	if _missing_offsets(pattern, extended_cross).size() > 0:
		options.append({
			"kind": "pattern_add",
			"action_index": action_index,
			"label": "Extend cross",
			"offsets": extended_cross,
			"cost_base": 1080
		})
	return options

static func _action_upgrade_options(card: Dictionary, _element: Dictionary) -> Array:
	if (card.get("actions", []) as Array).size() >= 4:
		return []
	return [
		{
			"kind": "action_add",
			"label": "Add Move 1",
			"action": {"type": "move", "range": 1},
			"cost_base": 360
		},
		{
			"kind": "action_add",
			"label": "Add Block 3",
			"action": {"type": "block", "amount": 3},
			"cost_base": 360
		},
		{
			"kind": "action_add",
			"label": "Add Draw 1",
			"action": {"type": "draw", "amount": 1},
			"cost_base": 680
		}
	]

static func _stat_mod(action_index: int, field: String, amount: int, label: String, cost_base: int, kind: String = "stat") -> Dictionary:
	return {
		"kind": kind,
		"action_index": action_index,
		"field": field,
		"amount": amount,
		"label": label,
		"cost_base": cost_base
	}

static func _apply_card_mods(card: Dictionary, mods: Array) -> Dictionary:
	var next_card: Dictionary = card.duplicate(true)
	for mod_var: Variant in mods:
		if typeof(mod_var) != TYPE_DICTIONARY:
			continue
		next_card = _apply_card_mod(next_card, mod_var as Dictionary)
	return next_card

static func _apply_relic_card_effects(card: Dictionary, relic_ids_list: Array) -> Dictionary:
	var next_card: Dictionary = card.duplicate(true)
	if relic_ids_list.is_empty():
		return next_card
	for effect: Dictionary in relic_effects_for_ids(relic_ids_list):
		match str(effect.get("type", "")):
			"card_action_mod":
				next_card = _apply_relic_action_mod(next_card, effect)
			"card_append_action":
				next_card = _apply_relic_append_action(next_card, effect)
	return next_card

static func _apply_progression_stat_effects(card: Dictionary, progression: Dictionary) -> Dictionary:
	var next_card: Dictionary = card.duplicate(true)
	if next_card.is_empty():
		return next_card
	var stats: Dictionary = normalized_progression_stats(progression.get("stats", {}))
	var vigor: int = int(stats.get("vigor", 0))
	var health_cost: int = int(next_card.get("health_cost", 0))
	if health_cost > 0 and vigor > 0:
		var before_cost: int = health_cost
		var min_cost: int = ceili(float(before_cost) * 0.5)
		health_cost = maxi(min_cost, before_cost - vigor)
		next_card["health_cost"] = health_cost
	var actions: Array = (next_card.get("actions", []) as Array).duplicate(true)
	var appended_actions: Array = []
	for index: int in range(actions.size()):
		if typeof(actions[index]) != TYPE_DICTIONARY:
			continue
		var action: Dictionary = (actions[index] as Dictionary).duplicate(true)
		var action_type: String = str(action.get("type", ""))
		action = _apply_progression_stats_to_action(action, stats, health_cost > 0)
		actions[index] = action
		if action_type == "blink" and int(stats.get("air_magick", 0)) > 0:
			appended_actions.append(_stat_appended_action(
				{"type": "block", "amount": int(stats.get("air_magick", 0)) * 2},
				"Air Magick",
				"+%d block after blink" % (int(stats.get("air_magick", 0)) * 2)
			))
		if int(action.get("freeze", 0)) > 0 and int(stats.get("ice_magick", 0)) > 0:
			appended_actions.append(_stat_appended_action(
				{"type": "block", "amount": int(stats.get("ice_magick", 0)) * 2},
				"Ice Magick",
				"+%d block after freeze" % (int(stats.get("ice_magick", 0)) * 2)
			))
	for appended_action: Dictionary in appended_actions:
		actions.append(appended_action)
	next_card["actions"] = actions
	return next_card

static func _apply_progression_stats_to_action(action: Dictionary, stats: Dictionary, has_health_cost: bool) -> Dictionary:
	var next_action: Dictionary = action.duplicate(true)
	var action_type: String = str(next_action.get("type", ""))
	if action_type == "melee":
		next_action = _add_stat_action_delta(next_action, "damage", int(stats.get("might", 0)) * 2, "Might")
	if action_type in ["ranged", "aoe"]:
		next_action = _add_stat_action_delta(next_action, "damage", int(stats.get("dexterity", 0)) * 2, "Dexterity")
	if action_type in ["push", "pull"]:
		next_action = _add_stat_action_delta(next_action, "damage", int(stats.get("air_magick", 0)) * 2, "Air Magick")
	if action_type in ATTACK_ACTION_TYPES and has_health_cost:
		next_action = _add_stat_action_delta(next_action, "damage", int(stats.get("fire_magick", 0)) * 2, "Fire Magick")
	if action_type in ATTACK_ACTION_TYPES and (int(next_action.get("shock", 0)) > 0 or int(next_action.get("chain", 0)) > 0):
		next_action = _add_stat_action_delta(next_action, "damage", int(stats.get("lightning_magick", 0)) * 2, "Lightning Magick")
	if next_action.has("burn"):
		next_action = _add_stat_action_delta(next_action, "burn", int(stats.get("fire_magick", 0)) * 2, "Fire Magick")
	if next_action.has("poison"):
		next_action = _add_stat_action_delta(next_action, "poison", int(stats.get("earth_magick", 0)) * 2, "Earth Magick")
	match action_type:
		"block":
			next_action = _add_stat_action_delta(next_action, "amount", int(stats.get("guard", 0)) * 2, "Guard")
		"stoneskin":
			next_action = _add_stat_action_delta(next_action, "amount", int(stats.get("guard", 0)), "Guard")
			next_action = _add_stat_action_delta(next_action, "amount", int(stats.get("earth_magick", 0)), "Earth Magick")
		"heal":
			next_action = _add_stat_action_delta(next_action, "amount", int(stats.get("vigor", 0)) * 2, "Vigor")
		"intensity":
			next_action = _add_stat_action_delta(next_action, "amount", int(stats.get("focus", 0)), "Focus")
		"illusion":
			next_action = _add_stat_action_delta(next_action, "health", int(stats.get("guard", 0)) * 2, "Guard")
			next_action = _add_stat_action_delta(next_action, "health", int(stats.get("earth_magick", 0)) * 2, "Earth Magick")
	next_action = _apply_progression_stats_to_intensity_bonus(next_action, stats, has_health_cost)
	return next_action

static func _apply_progression_stats_to_intensity_bonus(action: Dictionary, stats: Dictionary, has_health_cost: bool) -> Dictionary:
	if typeof(action.get("intensity_bonus", {})) != TYPE_DICTIONARY:
		return action
	var next_action: Dictionary = action.duplicate(true)
	var action_type: String = str(next_action.get("type", ""))
	var bonus: Dictionary = (next_action.get("intensity_bonus", {}) as Dictionary).duplicate(true)
	var focus_delta: int = int(stats.get("focus", 0)) * 2
	for field: String in ["damage", "burn", "poison", "health", "amount"]:
		if not bonus.has(field) or focus_delta <= 0:
			continue
		if not action_field_uses_fixed_point(action_type, field):
			continue
		bonus[field] = int(bonus.get(field, 0)) + focus_delta
	var fire_delta: int = int(stats.get("fire_magick", 0)) * 2
	if bonus.has("burn") and fire_delta > 0:
		bonus["burn"] = int(bonus.get("burn", 0)) + fire_delta
	if bonus.has("damage") and has_health_cost and fire_delta > 0:
		bonus["damage"] = int(bonus.get("damage", 0)) + fire_delta
	var earth_delta: int = int(stats.get("earth_magick", 0)) * 2
	if bonus.has("poison") and earth_delta > 0:
		bonus["poison"] = int(bonus.get("poison", 0)) + earth_delta
	var lightning_delta: int = int(stats.get("lightning_magick", 0)) * 2
	if bonus.has("damage") and lightning_delta > 0 and (int(action.get("shock", 0)) > 0 or int(action.get("chain", 0)) > 0 or int(bonus.get("shock", 0)) > 0 or int(bonus.get("chain", 0)) > 0):
		bonus["damage"] = int(bonus.get("damage", 0)) + lightning_delta
	var air_delta: int = int(stats.get("air_magick", 0)) * 2
	if bonus.has("damage") and air_delta > 0 and action_type in ["push", "pull"]:
		bonus["damage"] = int(bonus.get("damage", 0)) + air_delta
	next_action["intensity_bonus"] = bonus
	return next_action

static func _add_stat_action_delta(action: Dictionary, field: String, amount: int, source: String) -> Dictionary:
	if amount <= 0:
		return action
	var next_action: Dictionary = action.duplicate(true)
	var before_value: Variant = next_action.get(field, 0)
	next_action[field] = int(next_action.get(field, 0)) + amount
	return _record_stat_action_modifier(next_action, source, field, before_value, next_action.get(field, null), "%+d %s" % [amount, field.replace("_", " ")])

static func _stat_appended_action(action: Dictionary, source: String, label: String) -> Dictionary:
	var next_action: Dictionary = action.duplicate(true)
	return _record_stat_action_modifier(next_action, source, "_action", null, str(action.get("type", "")), label)

static func _apply_relic_action_mod(card: Dictionary, effect: Dictionary) -> Dictionary:
	if not _relic_effect_matches_card(card, effect):
		return card
	var actions: Array = (card.get("actions", []) as Array).duplicate(true)
	for index: int in range(actions.size()):
		if typeof(actions[index]) != TYPE_DICTIONARY:
			continue
		var action: Dictionary = (actions[index] as Dictionary).duplicate(true)
		if not _relic_effect_matches_action(action, effect):
			continue
		var field: String = str(effect.get("field", ""))
		if field.is_empty():
			continue
		var before_value: Variant = action.get(field, null)
		if typeof(effect.get("value", null)) == TYPE_BOOL:
			action[field] = bool(effect.get("value", false))
		elif field == "pierce":
			action[field] = true
		else:
			action[field] = int(action.get(field, 0)) + scaled_action_field_delta(
				str(action.get("type", "")),
				field,
				int(effect.get("amount", effect.get("value", 0)))
			)
		action = _record_relic_action_modifier(action, effect, field, before_value, action.get(field, null))
		actions[index] = action
	var next_card: Dictionary = card.duplicate(true)
	next_card["actions"] = actions
	return next_card

static func _apply_relic_append_action(card: Dictionary, effect: Dictionary) -> Dictionary:
	if not _relic_effect_matches_card(card, effect):
		return card
	if not _relic_effect_matches_card_action_requirement(card, effect):
		return card
	var appended_action: Variant = effect.get("action", {})
	if typeof(appended_action) != TYPE_DICTIONARY:
		return card
	var actions: Array = (card.get("actions", []) as Array).duplicate(true)
	var action: Dictionary = (appended_action as Dictionary).duplicate(true)
	action = _scale_action_fixed_point(action)
	action = _record_relic_action_modifier(action, effect, "_action", null, action.get("type", ""))
	actions.append(action)
	var next_card: Dictionary = card.duplicate(true)
	next_card["actions"] = actions
	return next_card

static func _record_relic_action_modifier(action: Dictionary, effect: Dictionary, field: String, before_value: Variant, after_value: Variant) -> Dictionary:
	var next_action: Dictionary = action.duplicate(true)
	var modifiers_by_field: Dictionary = {}
	if typeof(next_action.get("_modifiers", {})) == TYPE_DICTIONARY:
		modifiers_by_field = (next_action.get("_modifiers", {}) as Dictionary).duplicate(true)
	var field_modifiers: Array = []
	if typeof(modifiers_by_field.get(field, [])) == TYPE_ARRAY:
		field_modifiers = (modifiers_by_field.get(field, []) as Array).duplicate(true)
	field_modifiers.append({
		"source": _relic_effect_source_name(effect),
		"amount": _relic_modifier_amount(effect, before_value, after_value),
		"label": _relic_modifier_label(effect, field, before_value, after_value),
		"field": field,
		"before": _duplicate_variant(before_value),
		"after": _duplicate_variant(after_value)
	})
	modifiers_by_field[field] = field_modifiers
	next_action["_modifiers"] = modifiers_by_field
	return next_action

static func _record_stat_action_modifier(action: Dictionary, source: String, field: String, before_value: Variant, after_value: Variant, label: String) -> Dictionary:
	var next_action: Dictionary = action.duplicate(true)
	var modifiers_by_field: Dictionary = {}
	if typeof(next_action.get("_modifiers", {})) == TYPE_DICTIONARY:
		modifiers_by_field = (next_action.get("_modifiers", {}) as Dictionary).duplicate(true)
	var field_modifiers: Array = []
	if typeof(modifiers_by_field.get(field, [])) == TYPE_ARRAY:
		field_modifiers = (modifiers_by_field.get(field, []) as Array).duplicate(true)
	field_modifiers.append({
		"source": source,
		"amount": int(after_value) - int(before_value) if typeof(before_value) in [TYPE_INT, TYPE_FLOAT] and typeof(after_value) in [TYPE_INT, TYPE_FLOAT] else 0,
		"label": label,
		"field": field,
		"before": _duplicate_variant(before_value),
		"after": _duplicate_variant(after_value)
	})
	modifiers_by_field[field] = field_modifiers
	next_action["_modifiers"] = modifiers_by_field
	return next_action

static func _relic_modifier_amount(effect: Dictionary, before_value: Variant, after_value: Variant) -> int:
	if typeof(before_value) in [TYPE_INT, TYPE_FLOAT] and typeof(after_value) in [TYPE_INT, TYPE_FLOAT]:
		return int(after_value) - int(before_value)
	if typeof(effect.get("amount", null)) in [TYPE_INT, TYPE_FLOAT]:
		return int(effect.get("amount", 0))
	if typeof(effect.get("value", null)) in [TYPE_INT, TYPE_FLOAT]:
		return int(effect.get("value", 0))
	return 0

static func _relic_modifier_label(effect: Dictionary, field: String, before_value: Variant, after_value: Variant) -> String:
	var label: String = str(effect.get("modifier_label", ""))
	if not label.is_empty():
		return label
	if field == "_action":
		return "added action"
	if typeof(after_value) == TYPE_BOOL:
		return "adds %s" % field.capitalize()
	var amount: int = _relic_modifier_amount(effect, before_value, after_value)
	return "%+d %s" % [amount, field.replace("_", " ")]

static func _relic_effect_source_name(effect: Dictionary) -> String:
	var relic_id: String = str(effect.get("relic_id", ""))
	var relic: Dictionary = relic_def(relic_id)
	return str(relic.get("name", relic_id))

static func _relic_effect_matches_card(card: Dictionary, effect: Dictionary) -> bool:
	var element: String = str(effect.get("element", ""))
	return element.is_empty() or element == card_element_from_def(card)

static func _relic_effect_matches_action(action: Dictionary, effect: Dictionary) -> bool:
	var action_types: Array = effect.get("action_types", [])
	if not action_types.is_empty() and not action_types.has(str(action.get("type", ""))):
		return false
	var required_field: String = str(effect.get("requires_field", ""))
	if not required_field.is_empty() and not _action_has_field_or_intensity_bonus(action, required_field):
		return false
	return true

static func _relic_effect_matches_card_action_requirement(card: Dictionary, effect: Dictionary) -> bool:
	var required_field: String = str(effect.get("requires_field", ""))
	var required_type: String = str(effect.get("requires_action_type", ""))
	if required_field.is_empty() and required_type.is_empty():
		return true
	for action_var: Variant in card.get("actions", []):
		if typeof(action_var) != TYPE_DICTIONARY:
			continue
		var action: Dictionary = action_var
		if not required_type.is_empty() and str(action.get("type", "")) != required_type:
			continue
		if not required_field.is_empty() and not _action_has_field_or_intensity_bonus(action, required_field):
			continue
		return true
	return false

static func _action_has_field_or_intensity_bonus(action: Dictionary, field: String) -> bool:
	if int(action.get(field, 0)) > 0:
		return true
	var raw_bonus: Variant = action.get("intensity_bonus", {})
	if typeof(raw_bonus) != TYPE_DICTIONARY:
		return false
	return int((raw_bonus as Dictionary).get(field, 0)) > 0

static func _tag_card_actions_for_combat(card: Dictionary) -> Dictionary:
	var next_card: Dictionary = card.duplicate(true)
	var element_id: String = card_element_from_def(card)
	var actions: Array = (next_card.get("actions", []) as Array).duplicate(true)
	for index: int in range(actions.size()):
		if typeof(actions[index]) != TYPE_DICTIONARY:
			continue
		var action: Dictionary = (actions[index] as Dictionary).duplicate(true)
		action["_card_element"] = element_id
		actions[index] = action
	next_card["actions"] = actions
	return next_card

static func _apply_card_mod(card: Dictionary, mod: Dictionary) -> Dictionary:
	var next_card: Dictionary = card.duplicate(true)
	var actions: Array = (next_card.get("actions", []) as Array).duplicate(true)
	var action_index: int = int(mod.get("action_index", -1))
	if str(mod.get("kind", "")) == "action_add":
		var added_action: Variant = mod.get("action", {})
		if typeof(added_action) == TYPE_DICTIONARY:
			actions.append((added_action as Dictionary).duplicate(true))
			next_card["actions"] = actions
		return next_card
	if action_index < 0 or action_index >= actions.size() or typeof(actions[action_index]) != TYPE_DICTIONARY:
		return next_card
	var action: Dictionary = (actions[action_index] as Dictionary).duplicate(true)
	match str(mod.get("kind", "")):
		"pattern_add":
			action["pattern"] = _pattern_with_added_offsets((action.get("pattern", []) as Array), mod.get("offsets", []) as Array)
		_:
			var field: String = str(mod.get("field", ""))
			if not field.is_empty():
				action[field] = int(action.get(field, 0)) + int(mod.get("amount", 0))
	actions[action_index] = action
	next_card["actions"] = actions
	return next_card

static func _pattern_with_added_offsets(pattern: Array, offsets: Array) -> Array:
	var result: Array = pattern.duplicate(true)
	var seen: Dictionary = {}
	for existing_var: Variant in result:
		var offset: Vector2i = _offset_to_vector(existing_var)
		seen[offset] = true
	for offset_var: Variant in offsets:
		var offset: Vector2i = _offset_to_vector(offset_var)
		if seen.has(offset):
			continue
		seen[offset] = true
		result.append([offset.x, offset.y])
	return result

static func _missing_offsets(pattern: Array, offsets: Array) -> Array:
	var seen: Dictionary = {}
	for existing_var: Variant in pattern:
		seen[_offset_to_vector(existing_var)] = true
	var missing: Array = []
	for offset_var: Variant in offsets:
		var offset: Vector2i = _offset_to_vector(offset_var)
		if not seen.has(offset):
			missing.append([offset.x, offset.y])
	return missing

static func _offset_to_vector(value: Variant) -> Vector2i:
	match typeof(value):
		TYPE_VECTOR2I:
			return value
		TYPE_ARRAY:
			var pair: Array = value
			if pair.size() >= 2:
				return Vector2i(int(pair[0]), int(pair[1]))
		TYPE_DICTIONARY:
			var dict: Dictionary = value
			return Vector2i(int(dict.get("x", 0)), int(dict.get("y", 0)))
	return Vector2i.ZERO

static func _card_value(card: Dictionary) -> float:
	var total: float = 0.0
	for action_var: Variant in card.get("actions", []):
		if typeof(action_var) != TYPE_DICTIONARY:
			continue
		total += _action_value(action_var as Dictionary)
	total -= float(int(card.get("health_cost", 0))) * 1.6
	if bool(card.get("burn", false)):
		total -= 1.2
	return total

static func _action_value(action: Dictionary) -> float:
	var action_type: String = str(action.get("type", ""))
	var value: float = 0.0
	match action_type:
		"melee":
			value += float(int(action.get("damage", 0))) * 1.05
			value += float(maxi(0, int(action.get("range", 1)) - 1)) * 0.5
		"ranged":
			value += float(int(action.get("damage", 0))) * 1.0
			value += float(int(action.get("range", 0))) * 0.22
		"aoe":
			value += float(int(action.get("damage", 0))) * 1.35
			value += float(int(action.get("range", 0))) * 0.25
			value += float((action.get("pattern", []) as Array).size()) * 0.15
		"push":
			value += float(int(action.get("damage", 0))) * 0.9
			value += float(int(action.get("push", 0))) * 0.9
			value += float(int(action.get("range", 0))) * 0.18
		"pull":
			value += float(int(action.get("damage", 0))) * 0.9
			value += float(int(action.get("pull", 0))) * 0.65
			value += float(int(action.get("range", 0))) * 0.18
		"move":
			value += float(int(action.get("range", 0))) * 0.75
		"blink":
			value += float(int(action.get("range", 0))) * 0.95
		"block":
			value += float(int(action.get("amount", 0))) * 0.62
		"stoneskin":
			value += float(int(action.get("amount", 0))) * 0.88
		"heal":
			value += float(int(action.get("amount", 0))) * 1.35
		"draw":
			value += float(int(action.get("amount", 0))) * 2.4
		"card_play":
			value += float(int(action.get("amount", 0))) * 2.0
		"intensity":
			value += float(int(action.get("amount", 0))) * 1.4
		"illusion":
			value += float(int(action.get("health", action.get("amount", 0)))) * 0.95
			value += float(int(action.get("range", 0))) * 0.28
	value += float(int(action.get("burn", 0))) * 1.15
	value += float(int(action.get("bleed", 0))) * 1.05
	value += float(int(action.get("expose", 0))) * 0.95
	value += float(int(action.get("sunder", 0))) * 0.70
	value += float(int(action.get("poison", 0))) * 0.95
	value += float(int(action.get("freeze", 0))) * 3.2
	value += float(int(action.get("shock", 0))) * 2.4
	if bool(action.get("immobilize", false)):
		value += 1.7
	value += float(int(action.get("chain", 0))) * 1.5
	if bool(action.get("pierce", false)) and action_type in ATTACK_ACTION_TYPES:
		value += 1.1
	value += _intensity_bonus_value(action, action_type)
	return value * _intensity_requirement_value_scale(action)

static func _intensity_bonus_value(action: Dictionary, action_type: String) -> float:
	var raw: Variant = action.get("intensity_bonus", {})
	if typeof(raw) != TYPE_DICTIONARY:
		return 0.0
	var bonus: Dictionary = raw as Dictionary
	var threshold: int = int(bonus.get("threshold", bonus.get("amount", bonus.get("requires", 0))))
	if threshold <= 0:
		return 0.0
	var value: float = 0.0
	if action_type in ATTACK_ACTION_TYPES:
		var damage_multiplier: float = 1.0
		match action_type:
			"melee":
				damage_multiplier = 1.05
			"aoe":
				damage_multiplier = 1.35
			"push", "pull":
				damage_multiplier = 0.9
		value += float(int(bonus.get("damage", 0))) * damage_multiplier
	value += float(int(bonus.get("burn", 0))) * 1.15
	value += float(int(bonus.get("bleed", 0))) * 1.05
	value += float(int(bonus.get("expose", 0))) * 0.95
	value += float(int(bonus.get("sunder", 0))) * 0.70
	value += float(int(bonus.get("poison", 0))) * 0.95
	value += float(int(bonus.get("freeze", 0))) * 3.2
	value += float(int(bonus.get("shock", 0))) * 2.4
	if bool(bonus.get("immobilize", false)):
		value += 1.7
	value += float(int(bonus.get("chain", 0))) * 1.5
	value += float(int(bonus.get("push", 0))) * 0.9
	value += float(int(bonus.get("pull", 0))) * 0.65
	if action_type == "push":
		value += float(int(bonus.get("amount", 0))) * 0.9
	elif action_type == "pull":
		value += float(int(bonus.get("amount", 0))) * 0.65
	if bool(bonus.get("pierce", false)) and action_type in ATTACK_ACTION_TYPES:
		value += 1.1
	return value * clampf(1.0 - float(threshold - 1) * 0.18, 0.34, 0.82)

static func _intensity_requirement_value_scale(action: Dictionary) -> float:
	var raw: Variant = action.get("requires_intensity", {})
	if typeof(raw) != TYPE_DICTIONARY:
		return 1.0
	var requirement: Dictionary = raw as Dictionary
	var threshold: int = int(requirement.get("amount", requirement.get("threshold", 0)))
	if threshold <= 0:
		return 1.0
	return clampf(1.0 - float(threshold - 1) * 0.18, 0.34, 0.82)
