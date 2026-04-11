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

static func enemy_def(enemy_type: String) -> Dictionary:
	return _duplicate_dict(enemies().get(enemy_type, {}))

static func npc_def(npc_id: String) -> Dictionary:
	return _duplicate_dict(npcs().get(npc_id, {}))

static func relic_def(relic_id: String) -> Dictionary:
	return _duplicate_dict(relics().get(relic_id, {}))

static func upgrade_def(upgrade_id: String) -> Dictionary:
	return _duplicate_dict(upgrades().get(upgrade_id, {}))

static func starting_deck() -> Array[String]:
	return [
		"quick_stab",
		"guarded_step",
		"shadow_step",
		"shadow_step",
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
