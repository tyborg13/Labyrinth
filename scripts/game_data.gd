extends RefCounted
class_name GameData

const ElementData = preload("res://scripts/element_data.gd")

const CARDS_PATH: String = "res://data/cards.json"
const ENEMIES_PATH: String = "res://data/enemies.json"
const NPCS_PATH: String = "res://data/npcs.json"
const RELICS_PATH: String = "res://data/relics.json"
const UPGRADES_PATH: String = "res://data/upgrades.json"

static var _cache: Dictionary = {}

static func cards() -> Dictionary:
	return _load_json_dict(CARDS_PATH)

static func enemies() -> Dictionary:
	return _load_json_dict(ENEMIES_PATH)

static func npcs() -> Dictionary:
	return _load_json_dict(NPCS_PATH)

static func relics() -> Dictionary:
	return _load_json_dict(RELICS_PATH)

static func upgrades() -> Dictionary:
	return _load_json_dict(UPGRADES_PATH)

static func card_def(card_id: String) -> Dictionary:
	return _duplicate_dict(cards().get(card_id, {}))

static func card_def_with_upgrades(card_id: String, card_upgrades: Dictionary) -> Dictionary:
	var upgrade_id: String = str(card_upgrades.get(card_id, ""))
	if upgrade_id.is_empty():
		return card_def(card_id)
	var upgraded: Dictionary = upgraded_card_def(upgrade_id)
	return upgraded if not upgraded.is_empty() else card_def(card_id)

static func card_def_for_progression(card_id: String, progression: Dictionary) -> Dictionary:
	return card_def_with_upgrades(card_id, progression.get("card_upgrades", {}) as Dictionary)

static func enemy_def(enemy_type: String) -> Dictionary:
	return _duplicate_dict(enemies().get(enemy_type, {}))

static func npc_def(npc_id: String) -> Dictionary:
	return _duplicate_dict(npcs().get(npc_id, {}))

static func relic_def(relic_id: String) -> Dictionary:
	return _duplicate_dict(relics().get(relic_id, {}))

static func upgrade_def(upgrade_id: String) -> Dictionary:
	return _duplicate_dict(upgrades().get(upgrade_id, {}))

static func upgraded_card_def(upgrade_id: String) -> Dictionary:
	var upgrade: Dictionary = upgrade_def(upgrade_id)
	var card_id: String = str(upgrade.get("card_id", ""))
	var card: Dictionary = card_def(card_id)
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

static func starting_deck() -> Array[String]:
	return [
		"quick_stab",
		"guarded_step",
		"shadow_step",
		"whirlwind_slash",
		"bone_dart",
		"sidestep_slash",
		"patch_up",
		"bloody_lunge",
		"brace",
		"lantern_shot"
	]

static func reward_card_pool_by_rarity(element_filter: String = "") -> Dictionary:
	var result: Dictionary = {
		"common": [],
		"uncommon": [],
		"rare": []
	}
	for card_id: String in cards().keys():
		var card: Dictionary = cards()[card_id]
		var rarity: String = str(card.get("rarity", "common"))
		if rarity == "starter":
			continue
		var card_element: String = card_element_from_def(card)
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

static func relic_ids() -> Array:
	return relics().keys()

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
	for relic_id_var: Variant in relic_ids_list:
		var relic_id: String = str(relic_id_var)
		var relic: Dictionary = relics().get(relic_id, {})
		if str(relic.get("effect", "")) == effect_key:
			total += int(relic.get("value", 0))
	return total

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
	value += float(int(action.get("burn", 0))) * 1.15
	value += float(int(action.get("poison", 0))) * 0.95
	value += float(int(action.get("freeze", 0))) * 3.2
	value += float(int(action.get("shock", 0))) * 2.4
	value += float(int(action.get("stun", 0))) * 3.0
	value += float(int(action.get("chain", 0))) * 1.5
	return value
