extends RefCounted
class_name GameData

const ElementData = preload("res://scripts/element_data.gd")

const CARDS_PATH: String = "res://data/cards.json"
const ENEMIES_PATH: String = "res://data/enemies.json"
const NPCS_PATH: String = "res://data/npcs.json"
const RELICS_PATH: String = "res://data/relics.json"
const UPGRADES_PATH: String = "res://data/upgrades.json"
const ATTACK_ACTION_TYPES: Array[String] = ["melee", "ranged", "aoe", "push", "pull"]
const STATUS_UPGRADE_FIELDS: Array[String] = ["burn", "poison", "freeze", "shock"]

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
	var entry: Variant = card_upgrades.get(card_id, "")
	if typeof(entry) == TYPE_ARRAY:
		return card_def_with_card_mods(card_id, {card_id: entry})
	var upgrade_id: String = str(entry)
	if not upgrade_id.is_empty():
		var upgraded: Dictionary = upgraded_card_def(upgrade_id)
		return upgraded if not upgraded.is_empty() else card_def(card_id)
	return card_def(card_id)

static func card_def_with_card_mods(card_id: String, card_mods: Dictionary) -> Dictionary:
	var card: Dictionary = card_def(card_id)
	if card.is_empty():
		return {}
	var mods: Array = (card_mods.get(card_id, []) as Array).duplicate(true)
	card = _apply_card_mods(card, mods)
	if not mods.is_empty():
		card["base_card_id"] = card_id
		card["upgraded"] = true
		card["upgrade_count"] = mods.size()
		card["name"] = "%s+%d" % [str(card.get("name", card_id)), mods.size()]
	return card

static func card_def_for_progression(card_id: String, progression: Dictionary) -> Dictionary:
	var card: Dictionary = card_def_with_upgrades(card_id, progression.get("card_upgrades", {}) as Dictionary)
	var mods: Array = ((progression.get("card_mods", {}) as Dictionary).get(card_id, []) as Array).duplicate(true)
	card = _apply_card_mods(card, mods)
	var total_count: int = card_upgrade_count(progression, card_id)
	if total_count > 0:
		card["base_card_id"] = card_id
		card["upgraded"] = true
		card["upgrade_count"] = total_count
		card["name"] = "%s+%d" % [str(card_def(card_id).get("name", card_id)), total_count]
	return card

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

static func upgradeable_card_ids() -> Array:
	var result: Array = cards().keys()
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
			var range_label: String = "Move Range" if action_type == "move" else "Blink Range" if action_type == "blink" else "Attack Range"
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
	preview["name"] = "%s+%d" % [str(card_def(card_id).get("name", card_id)), card_upgrade_count(progression, card_id) + 1]
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
			if action_type in ["move", "blink"]:
				var base_cost: int = 150 if action_type == "move" else 190
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
	value += float(int(action.get("burn", 0))) * 1.15
	value += float(int(action.get("poison", 0))) * 0.95
	value += float(int(action.get("freeze", 0))) * 3.2
	value += float(int(action.get("shock", 0))) * 2.4
	value += float(int(action.get("stun", 0))) * 3.0
	value += float(int(action.get("chain", 0))) * 1.5
	return value
