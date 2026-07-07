extends RefCounted
class_name GrimoireLibrary

const GameData = preload("res://scripts/game_data.gd")

const GRIMOIRE_PATH: String = "res://data/grimoire.json"
const UNLOCKED_KEY: String = "grimoire_unlocked"
const UNREAD_KEY: String = "grimoire_unread"
const NOTICE_KEY: String = "grimoire_notice"
const MERCHANT_STOCK_KEY: String = "merchant_stock"

const SECTION_MAGICKS: String = "magicks"
const SECTION_EQUIPMENT: String = "equipment"
const SECTION_ITEMS: String = "items"
const SECTION_CHARACTERS: String = "characters"

const ELEMENT_TITLES := {
	"fire": "Fire",
	"ice": "Ice",
	"lightning": "Lightning",
	"air": "Air",
	"earth": "Earth",
	"none": "Unaligned"
}

const EQUIPMENT_SLOT_TITLES := {
	"weapon": "Weapons",
	"offhand": "Offhands",
	"armor": "Armor",
	"boots": "Boots",
	"trinket": "Trinkets"
}

const CHARACTER_BODIES := {
	"arcanist": [
		"NPC merchant associated with learned magicks.",
		"Arcanist rooms offer magic cards. Purchased magic enters reserve and can be attuned from the character sheet."
	],
	"blacksmith": [
		"NPC merchant associated with weapons, armor, trinkets, and other equipment.",
		"Blacksmith rooms offer equipment. Equipment changes the deck by adding its granted cards while equipped."
	],
	"scavenger": [
		"NPC merchant associated with single-use item cards.",
		"Scavenger rooms offer item cards. Items can be equipped into item slots and are consumed when played."
	],
	"emaciated_man": [
		"NPC encountered in the starting chamber.",
		"The Emaciated Man appears before the first door selection and provides the run's opening dialogue."
	]
}

const ACTION_TYPE_ENTRY_IDS := {
	"melee": "keyword:melee",
	"ranged": "keyword:ranged",
	"aoe": "keyword:aoe",
	"move": "keyword:move",
	"move_toward": "keyword:move",
	"move_away": "keyword:move",
	"blink": "keyword:blink",
	"block": "keyword:block",
	"guard_ally": "keyword:block",
	"stoneskin": "keyword:stoneskin",
	"heal": "keyword:heal",
	"heal_self": "keyword:heal",
	"heal_ally": "keyword:heal",
	"draw": "keyword:draw",
	"card_play": "keyword:card_play",
	"illusion": "keyword:illusion",
	"push": "keyword:push",
	"pull": "keyword:pull",
	"intensity": "combat:intensity",
	"lightning_strikes": "combat:lightning_strikes",
	"summon_minions": "combat:summons"
}

const ACTION_FIELD_ENTRY_IDS := {
	"bleed": "keyword:bleed",
	"burn": "keyword:burn",
	"poison": "keyword:poison",
	"freeze": "keyword:freeze",
	"shock": "keyword:shock",
	"immobilize": "keyword:immobilize",
	"expose": "keyword:expose",
	"sunder": "keyword:sunder",
	"chain": "keyword:chain",
	"pierce": "keyword:pierce",
	"push": "keyword:push",
	"pull": "keyword:pull"
}

static var _cache: Dictionary = {}

static func data() -> Dictionary:
	if not _cache.is_empty():
		return _cache
	var file: FileAccess = FileAccess.open(GRIMOIRE_PATH, FileAccess.READ)
	if file == null:
		push_error("Unable to load grimoire data: %s" % GRIMOIRE_PATH)
		_cache = {"sections": [], "entries": []}
		return _cache
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid grimoire data: %s" % GRIMOIRE_PATH)
		_cache = {"sections": [], "entries": []}
		return _cache
	_cache = (parsed as Dictionary).duplicate(true)
	return _cache

static func sections() -> Array:
	return (data().get("sections", []) as Array).duplicate(true)

static func entries() -> Array:
	var result: Array = (data().get("entries", []) as Array).duplicate(true)
	result.append_array(magick_entries())
	result.append_array(equipment_entries())
	result.append_array(item_entries())
	result.append_array(character_entries())
	return result

static func magick_entries() -> Array:
	var result: Array = []
	for card_id: String in GameData.cards().keys():
		var card: Dictionary = GameData.card_def(card_id)
		if card.is_empty() or not is_magick_card_id(card_id):
			continue
		result.append({
			"id": magick_entry_id(card_id),
			"section": SECTION_MAGICKS,
			"title": str(card.get("name", card_id)),
			"card_id": card_id,
			"group": _card_element_group(card),
			"group_title": _card_element_group_title(card),
			"body": _card_entry_body(card)
		})
	return result

static func equipment_entries() -> Array:
	var result: Array = []
	for equipment_id_var: Variant in GameData.equipment_ids():
		var equipment_id: String = str(equipment_id_var)
		var item: Dictionary = GameData.equipment_def(equipment_id)
		if item.is_empty() or GameData.equipment_slot(equipment_id).is_empty():
			continue
		result.append({
			"id": equipment_entry_id(equipment_id),
			"section": SECTION_EQUIPMENT,
			"title": str(item.get("name", equipment_id)),
			"equipment_id": equipment_id,
			"group": GameData.equipment_slot(equipment_id),
			"group_title": str(EQUIPMENT_SLOT_TITLES.get(GameData.equipment_slot(equipment_id), GameData.equipment_slot(equipment_id).capitalize())),
			"body": _equipment_entry_body(equipment_id, item)
		})
	return result

static func item_entries() -> Array:
	var result: Array = []
	for card_id_var: Variant in GameData.item_card_ids():
		var card_id: String = str(card_id_var)
		var card: Dictionary = GameData.card_def(card_id)
		if card.is_empty():
			continue
		result.append({
			"id": item_entry_id(card_id),
			"section": SECTION_ITEMS,
			"title": str(card.get("name", card_id)),
			"card_id": card_id,
			"body": _card_entry_body(card)
		})
	return result

static func character_entries() -> Array:
	var result: Array = []
	for npc_id: String in GameData.npcs().keys():
		var npc: Dictionary = GameData.npc_def(npc_id)
		if npc.is_empty():
			continue
		result.append({
			"id": character_entry_id(npc_id),
			"section": SECTION_CHARACTERS,
			"title": str(npc.get("name", npc_id)),
			"npc_id": npc_id,
			"body": _character_entry_body(npc_id, npc)
		})
	return result

static func magick_entry_id(card_id: String) -> String:
	return "magick:%s" % card_id

static func item_entry_id(card_id: String) -> String:
	return "item:%s" % card_id

static func equipment_entry_id(equipment_id: String) -> String:
	return "equipment:%s" % equipment_id

static func character_entry_id(npc_id: String) -> String:
	return "character:%s" % npc_id

static func entry_map() -> Dictionary:
	var result: Dictionary = {}
	for entry_var: Variant in entries():
		if typeof(entry_var) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_var as Dictionary
		var entry_id: String = str(entry.get("id", ""))
		if not entry_id.is_empty():
			result[entry_id] = entry
	return result

static func entry_def(entry_id: String) -> Dictionary:
	return (entry_map().get(entry_id, {}) as Dictionary).duplicate(true)

static func section_def(section_id: String) -> Dictionary:
	for section_var: Variant in sections():
		if typeof(section_var) != TYPE_DICTIONARY:
			continue
		var section: Dictionary = section_var as Dictionary
		if str(section.get("id", "")) == section_id:
			return section.duplicate(true)
	return {}

static func default_entry_ids() -> Array[String]:
	var result: Array[String] = []
	for entry_var: Variant in entries():
		if typeof(entry_var) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_var as Dictionary
		if bool(entry.get("default", false)):
			result.append(str(entry.get("id", "")))
	return ordered_entry_ids(result)

static func ensure_progression_state(progression: Dictionary) -> Dictionary:
	if progression.is_empty():
		return {}
	var next_progression: Dictionary = progression.duplicate(true)
	var unlocked: Array[String] = normalize_entry_ids(next_progression.get(UNLOCKED_KEY, []))
	for entry_id: String in default_entry_ids():
		if not unlocked.has(entry_id):
			unlocked.append(entry_id)
	unlocked = ordered_entry_ids(unlocked)
	next_progression[UNLOCKED_KEY] = unlocked
	var unread: Array[String] = normalize_entry_ids(next_progression.get(UNREAD_KEY, []))
	var filtered_unread: Array[String] = []
	for entry_id: String in ordered_entry_ids(unread):
		if unlocked.has(entry_id):
			filtered_unread.append(entry_id)
	next_progression[UNREAD_KEY] = filtered_unread
	return next_progression

static func ensure_run_state(run_state: Dictionary) -> Dictionary:
	var next_state: Dictionary = run_state.duplicate(true)
	var unlocked: Array[String] = normalize_entry_ids(next_state.get(UNLOCKED_KEY, []))
	var progression: Dictionary = {}
	if typeof(next_state.get("progression", {})) == TYPE_DICTIONARY:
		progression = ensure_progression_state(next_state.get("progression", {}) as Dictionary)
		if not progression.is_empty():
			next_state["progression"] = progression
			for entry_id: String in normalize_entry_ids(progression.get(UNLOCKED_KEY, [])):
				if not unlocked.has(entry_id):
					unlocked.append(entry_id)
	var has_unlocked_key: bool = next_state.has(UNLOCKED_KEY)
	for entry_id: String in default_entry_ids():
		if not unlocked.has(entry_id):
			unlocked.append(entry_id)
	if not has_unlocked_key:
		unlocked.append_array(entry_ids_for_run_state(next_state))
	unlocked = ordered_entry_ids(unlocked)
	next_state[UNLOCKED_KEY] = unlocked
	var unread: Array[String] = normalize_entry_ids(next_state.get(UNREAD_KEY, []))
	if not progression.is_empty():
		for entry_id: String in normalize_entry_ids(progression.get(UNREAD_KEY, [])):
			if not unread.has(entry_id):
				unread.append(entry_id)
	var filtered_unread: Array[String] = []
	for entry_id: String in ordered_entry_ids(unread):
		if unlocked.has(entry_id):
			filtered_unread.append(entry_id)
	next_state[UNREAD_KEY] = filtered_unread
	if not next_state.has(NOTICE_KEY):
		next_state[NOTICE_KEY] = ""
	return next_state

static func unlock_entries(run_state: Dictionary, candidate_ids: Array) -> Dictionary:
	var next_state: Dictionary = ensure_run_state(run_state)
	var unlocked: Array[String] = normalize_entry_ids(next_state.get(UNLOCKED_KEY, []))
	var unread: Array[String] = normalize_entry_ids(next_state.get(UNREAD_KEY, []))
	var progression: Dictionary = {}
	var progression_unlocked: Array[String] = []
	var progression_unread: Array[String] = []
	if typeof(next_state.get("progression", {})) == TYPE_DICTIONARY:
		progression = ensure_progression_state(next_state.get("progression", {}) as Dictionary)
		if not progression.is_empty():
			progression_unlocked = normalize_entry_ids(progression.get(UNLOCKED_KEY, []))
			progression_unread = normalize_entry_ids(progression.get(UNREAD_KEY, []))
	var added: Array[String] = []
	var progression_changed: bool = false
	for entry_id: String in ordered_entry_ids(candidate_ids):
		var run_already_unlocked: bool = unlocked.has(entry_id)
		if not run_already_unlocked:
			unlocked.append(entry_id)
			if not unread.has(entry_id):
				unread.append(entry_id)
			added.append(entry_id)
		if not progression.is_empty() and not progression_unlocked.has(entry_id):
			progression_unlocked.append(entry_id)
			progression_changed = true
			if not run_already_unlocked and not progression_unread.has(entry_id):
				progression_unread.append(entry_id)
	next_state[UNLOCKED_KEY] = ordered_entry_ids(unlocked)
	next_state[UNREAD_KEY] = ordered_entry_ids(unread)
	if not progression.is_empty():
		progression[UNLOCKED_KEY] = ordered_entry_ids(progression_unlocked)
		progression[UNREAD_KEY] = ordered_entry_ids(progression_unread)
		next_state["progression"] = progression
	if not added.is_empty():
		next_state[NOTICE_KEY] = notice_for_added_entries(added)
	return {
		"state": next_state,
		"added": added,
		"progression_changed": progression_changed
	}

static func clear_unread(run_state: Dictionary) -> Dictionary:
	var next_state: Dictionary = ensure_run_state(run_state)
	next_state[UNREAD_KEY] = []
	next_state[NOTICE_KEY] = ""
	if typeof(next_state.get("progression", {})) == TYPE_DICTIONARY:
		var progression: Dictionary = ensure_progression_state(next_state.get("progression", {}) as Dictionary)
		if not progression.is_empty():
			progression[UNREAD_KEY] = []
			next_state["progression"] = progression
	return next_state

static func notice_for_added_entries(entry_ids: Array) -> String:
	var ordered: Array[String] = ordered_entry_ids(entry_ids)
	if ordered.is_empty():
		return ""
	if ordered.size() == 1:
		var entry: Dictionary = entry_def(ordered[0])
		return "Added %s entry to the Grimoire." % str(entry.get("title", "new"))
	return "Added %d entries to the Grimoire." % ordered.size()

static func entries_for_section(section_id: String, unlocked_ids: Array) -> Array[Dictionary]:
	var unlocked: Array[String] = normalize_entry_ids(unlocked_ids)
	var result: Array[Dictionary] = []
	for entry_var: Variant in entries():
		if typeof(entry_var) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_var as Dictionary
		var entry_id: String = str(entry.get("id", ""))
		if unlocked.has(entry_id) and str(entry.get("section", "")) == section_id:
			result.append(entry.duplicate(true))
	return result

static func first_unlocked_entry_id_for_section(section_id: String, unlocked_ids: Array) -> String:
	for entry: Dictionary in entries_for_section(section_id, unlocked_ids):
		return str(entry.get("id", ""))
	return ""

static func section_has_unlocked_entries(section_id: String, unlocked_ids: Array) -> bool:
	return not first_unlocked_entry_id_for_section(section_id, unlocked_ids).is_empty()

static func normalize_entry_ids(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if typeof(value) != TYPE_ARRAY:
		return result
	var known: Dictionary = entry_map()
	for id_var: Variant in value:
		var entry_id: String = str(id_var)
		if entry_id.is_empty() or not known.has(entry_id) or result.has(entry_id):
			continue
		result.append(entry_id)
	return ordered_entry_ids(result)

static func ordered_entry_ids(value: Variant) -> Array[String]:
	var wanted: Dictionary = {}
	if typeof(value) == TYPE_ARRAY:
		for id_var: Variant in value:
			var entry_id: String = str(id_var)
			if not entry_id.is_empty():
				wanted[entry_id] = true
	elif typeof(value) == TYPE_DICTIONARY:
		for id_var: Variant in (value as Dictionary).keys():
			var entry_id: String = str(id_var)
			if not entry_id.is_empty():
				wanted[entry_id] = true
	var result: Array[String] = []
	for entry_var: Variant in entries():
		if typeof(entry_var) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_var as Dictionary
		var entry_id: String = str(entry.get("id", ""))
		if bool(wanted.get(entry_id, false)):
			result.append(entry_id)
	return result

static func entry_ids_for_card_ids(card_ids: Variant) -> Array[String]:
	var result: Array[String] = []
	if typeof(card_ids) != TYPE_ARRAY:
		return result
	for card_id_var: Variant in card_ids:
		for entry_id: String in entry_ids_for_card_id(str(card_id_var)):
			if not result.has(entry_id):
				result.append(entry_id)
	return ordered_entry_ids(result)

static func entry_ids_for_card_id(card_id: String) -> Array[String]:
	var card: Dictionary = GameData.card_def(card_id)
	if card.is_empty():
		return []
	var result: Array[String] = []
	if GameData.card_is_item(card_id):
		result.append(item_entry_id(card_id))
	elif is_magick_card_id(card_id):
		result.append(magick_entry_id(card_id))
	for entry_id: String in entry_ids_for_card_def(card):
		if not result.has(entry_id):
			result.append(entry_id)
	return ordered_entry_ids(result)

static func entry_ids_for_equipment_ids(equipment_ids: Variant) -> Array[String]:
	var result: Array[String] = []
	if typeof(equipment_ids) != TYPE_ARRAY:
		return result
	for equipment_id_var: Variant in equipment_ids:
		for entry_id: String in entry_ids_for_equipment_id(str(equipment_id_var)):
			if not result.has(entry_id):
				result.append(entry_id)
	return ordered_entry_ids(result)

static func entry_ids_for_equipment_id(equipment_id: String) -> Array[String]:
	if GameData.equipment_def(equipment_id).is_empty() or GameData.equipment_slot(equipment_id).is_empty():
		return []
	var result: Array[String] = []
	result.append(equipment_entry_id(equipment_id))
	for card_id_var: Variant in GameData.equipment_cards(equipment_id):
		for entry_id: String in entry_ids_for_card_id(str(card_id_var)):
			if entry_id.begins_with("magick:") or entry_id.begins_with("item:"):
				continue
			if not result.has(entry_id):
				result.append(entry_id)
	return ordered_entry_ids(result)

static func entry_ids_for_npc_ids(npc_ids: Variant) -> Array[String]:
	var result: Array[String] = []
	if typeof(npc_ids) != TYPE_ARRAY:
		return result
	for npc_id_var: Variant in npc_ids:
		var npc_id: String = str(npc_id_var)
		if GameData.npc_def(npc_id).is_empty():
			continue
		var entry_id: String = character_entry_id(npc_id)
		if not result.has(entry_id):
			result.append(entry_id)
	return ordered_entry_ids(result)

static func entry_ids_for_card_def(card: Dictionary) -> Array[String]:
	var result: Array[String] = []
	if bool(card.get("burn", false)):
		result.append("keyword:exhaust")
	if bool(card.get("consume_on_play", false)):
		result.append("keyword:consume")
	if int(card.get("health_cost", 0)) > 0:
		result.append("keyword:health_cost")
	if card.has("requires_intensity") or card.has("intensity_bonus"):
		result.append("combat:intensity")
	for entry_id: String in entry_ids_for_actions(card.get("actions", [])):
		if not result.has(entry_id):
			result.append(entry_id)
	return ordered_entry_ids(result)

static func entry_ids_for_enemy_types(enemy_types: Variant) -> Array[String]:
	var result: Array[String] = []
	if typeof(enemy_types) != TYPE_ARRAY:
		return result
	for enemy_type_var: Variant in enemy_types:
		var enemy_type: String = str(enemy_type_var)
		var enemy_entry_id: String = "enemy:%s" % enemy_type
		if not result.has(enemy_entry_id):
			result.append(enemy_entry_id)
		var enemy_def: Dictionary = GameData.enemy_def(enemy_type)
		for entry_id: String in entry_ids_for_enemy_def(enemy_def):
			if not result.has(entry_id):
				result.append(entry_id)
	return ordered_entry_ids(result)

static func entry_ids_for_enemy_def(enemy: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for intent_var: Variant in enemy.get("intents", []):
		if typeof(intent_var) != TYPE_DICTIONARY:
			continue
		var intent: Dictionary = intent_var as Dictionary
		for entry_id: String in entry_ids_for_actions(intent.get("actions", [])):
			if not result.has(entry_id):
				result.append(entry_id)
	return ordered_entry_ids(result)

static func entry_ids_for_combat_state(combat_state: Dictionary) -> Array[String]:
	var result: Array[String] = []
	if not (combat_state.get("traps", []) as Array).is_empty():
		result.append("combat:traps")
	var enemy_types: Array[String] = []
	for enemy_var: Variant in combat_state.get("enemies", []):
		if typeof(enemy_var) != TYPE_DICTIONARY:
			continue
		var enemy: Dictionary = enemy_var as Dictionary
		var enemy_type: String = str(enemy.get("type", ""))
		if not enemy_type.is_empty() and not enemy_types.has(enemy_type):
			enemy_types.append(enemy_type)
	for entry_id: String in entry_ids_for_enemy_types(enemy_types):
		if not result.has(entry_id):
			result.append(entry_id)
	var equipment_ids: Array = []
	for loot_var: Variant in combat_state.get("loot", []):
		if typeof(loot_var) != TYPE_DICTIONARY:
			continue
		var loot: Dictionary = loot_var as Dictionary
		if str(loot.get("kind", "")) != "equipment":
			continue
		var loot_equipment_id: String = str(loot.get("equipment_id", ""))
		if not loot_equipment_id.is_empty():
			equipment_ids.append(loot_equipment_id)
	equipment_ids.append_array(combat_state.get("collected_equipment", []))
	for entry_id: String in entry_ids_for_equipment_ids(equipment_ids):
		if not result.has(entry_id):
			result.append(entry_id)
	var deck: Dictionary = combat_state.get("deck", {}) as Dictionary
	for pile_name: String in ["hand", "draw", "discard", "burned", "consumed"]:
		for entry_id: String in entry_ids_for_card_ids(deck.get(pile_name, [])):
			if not result.has(entry_id):
				result.append(entry_id)
	return ordered_entry_ids(result)

static func entry_ids_for_run_state(run_state: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for card_list_key: String in ["deck_cards", "reward_cards", "attuned_magic_cards", "magic_inventory", "item_inventory", "equipped_items"]:
		for entry_id: String in entry_ids_for_card_ids(run_state.get(card_list_key, [])):
			if not result.has(entry_id):
				result.append(entry_id)
	var equipment_ids: Array = []
	equipment_ids.append_array(run_state.get("collected_equipment", []))
	equipment_ids.append_array(run_state.get("equipment_inventory", []))
	for equipment_id_var: Variant in (run_state.get("equipped_equipment", {}) as Dictionary).values():
		equipment_ids.append(equipment_id_var)
	for entry_id: String in entry_ids_for_equipment_ids(equipment_ids):
		if not result.has(entry_id):
			result.append(entry_id)
	var current_room: Dictionary = _current_room_metadata(run_state)
	var npc_ids: Array = []
	for npc_var: Variant in current_room.get("npcs", []):
		if typeof(npc_var) != TYPE_DICTIONARY:
			continue
		var npc_id: String = str((npc_var as Dictionary).get("id", ""))
		if not npc_id.is_empty():
			npc_ids.append(npc_id)
	for entry_id: String in entry_ids_for_npc_ids(npc_ids):
		if not result.has(entry_id):
			result.append(entry_id)
	var pending_reward: Dictionary = run_state.get("pending_reward", {}) as Dictionary
	for entry_id: String in entry_ids_for_card_ids(pending_reward.get("cards", [])):
		if not result.has(entry_id):
			result.append(entry_id)
	for offer_id_var: Variant in _current_merchant_offer_ids(run_state):
		var offer_id: String = str(offer_id_var)
		var offer_entries: Array[String] = entry_ids_for_equipment_id(offer_id) if not GameData.equipment_def(offer_id).is_empty() else entry_ids_for_card_id(offer_id)
		for entry_id: String in offer_entries:
			if not result.has(entry_id):
				result.append(entry_id)
	var combat_state: Dictionary = run_state.get("combat_state", {}) as Dictionary
	for entry_id: String in entry_ids_for_combat_state(combat_state):
		if not result.has(entry_id):
			result.append(entry_id)
	return ordered_entry_ids(result)

static func entry_ids_for_actions(actions: Variant) -> Array[String]:
	var result: Array[String] = []
	if typeof(actions) != TYPE_ARRAY:
		return result
	for action_var: Variant in actions:
		if typeof(action_var) != TYPE_DICTIONARY:
			continue
		var action: Dictionary = action_var as Dictionary
		var action_type: String = str(action.get("type", ""))
		var type_entry: String = str(ACTION_TYPE_ENTRY_IDS.get(action_type, ""))
		if not type_entry.is_empty() and not result.has(type_entry):
			result.append(type_entry)
		if action_type == "summon_minions":
			var minion_type: String = str(action.get("minion_type", ""))
			var minion_entry: String = "enemy:%s" % minion_type
			if not minion_type.is_empty() and not result.has(minion_entry):
				result.append(minion_entry)
		for field_name: String in ACTION_FIELD_ENTRY_IDS.keys():
			if not action.has(field_name) or not _truthy_value(action.get(field_name)):
				continue
			var field_entry: String = str(ACTION_FIELD_ENTRY_IDS.get(field_name, ""))
			if not field_entry.is_empty() and not result.has(field_entry):
				result.append(field_entry)
		if action.has("requires_intensity") or action.has("intensity_bonus"):
			if not result.has("combat:intensity"):
				result.append("combat:intensity")
		for entry_id: String in _entry_ids_for_nested_action_values(action):
			if not result.has(entry_id):
				result.append(entry_id)
	return ordered_entry_ids(result)

static func _entry_ids_for_nested_action_values(value: Variant) -> Array[String]:
	var result: Array[String] = []
	match typeof(value):
		TYPE_DICTIONARY:
			for key_var: Variant in (value as Dictionary).keys():
				var key: String = str(key_var)
				var nested_value: Variant = (value as Dictionary).get(key_var)
				var field_entry: String = str(ACTION_FIELD_ENTRY_IDS.get(key, ""))
				if not field_entry.is_empty() and _truthy_value(nested_value) and not result.has(field_entry):
					result.append(field_entry)
				for nested_entry: String in _entry_ids_for_nested_action_values(nested_value):
					if not result.has(nested_entry):
						result.append(nested_entry)
		TYPE_ARRAY:
			for item_var: Variant in value:
				for nested_entry: String in _entry_ids_for_nested_action_values(item_var):
					if not result.has(nested_entry):
						result.append(nested_entry)
	return ordered_entry_ids(result)

static func _current_merchant_offer_ids(run_state: Dictionary) -> Array:
	var room: Dictionary = _current_room_metadata(run_state)
	var result: Array = []
	for item_var: Variant in room.get(MERCHANT_STOCK_KEY, []):
		var item_id: String = str(item_var)
		if item_id.is_empty() or result.has(item_id):
			continue
		if not GameData.card_def(item_id).is_empty() or not GameData.equipment_def(item_id).is_empty():
			result.append(item_id)
	return result

static func _current_room_metadata(run_state: Dictionary) -> Dictionary:
	var rooms: Dictionary = run_state.get("rooms", {}) as Dictionary
	var coord: Vector2i = run_state.get("current_room", Vector2i.ZERO)
	var key: String = "%d,%d" % [coord.x, coord.y]
	return (rooms.get(key, {}) as Dictionary).duplicate(true)

static func _card_entry_body(card: Dictionary) -> Array:
	var body: Array = []
	var description: String = str(card.get("description", "")).strip_edges()
	if not description.is_empty():
		body.append(description)
	var facts: Array = []
	var rarity: String = str(GameData.card_rarity_from_def(card)).capitalize()
	if not rarity.is_empty():
		facts.append("Rarity: %s" % rarity)
	var element: String = str(GameData.card_element_from_def(card))
	if not element.is_empty() and element != "none":
		facts.append("Element: %s" % element.capitalize())
	if card.has("time"):
		facts.append("Time: %d" % int(card.get("time", 0)))
	if int(card.get("health_cost", 0)) > 0:
		facts.append("Health cost: %d" % int(card.get("health_cost", 0)))
	if not facts.is_empty():
		body.append(". ".join(facts) + ".")
	var notes: Array = []
	if bool(card.get("burn", false)):
		notes.append("Exhausts for the rest of combat after use")
	if bool(card.get("consume_on_play", false)):
		notes.append("Consumed after use")
	if bool(card.get("starter", false)):
		notes.append("Starter card")
	elif bool(card.get("reward_pool", true)):
		notes.append("Can appear as a card reward")
	if not notes.is_empty():
		body.append(". ".join(notes) + ".")
	return body

static func _equipment_entry_body(equipment_id: String, item: Dictionary) -> Array:
	var body: Array = []
	var description: String = str(item.get("description", "")).strip_edges()
	if not description.is_empty():
		body.append(description)
	var slot_label: String = _equipment_slot_singular(GameData.equipment_slot(equipment_id))
	var rarity: String = GameData.equipment_rarity(equipment_id).capitalize()
	var card_count: int = GameData.equipment_cards(equipment_id).size()
	body.append("%s %s equipment. Adds %d card%s to the deck while equipped." % [
		rarity,
		slot_label,
		card_count,
		"" if card_count == 1 else "s"
	])
	return body

static func _character_entry_body(npc_id: String, npc: Dictionary) -> Array:
	var predefined: Array = (CHARACTER_BODIES.get(npc_id, []) as Array).duplicate(true)
	if not predefined.is_empty():
		return predefined
	var dialogue: Array = npc.get("default_dialogue", [])
	if not dialogue.is_empty():
		return ["NPC encountered in the labyrinth.", "Default dialogue lines: %d." % dialogue.size()]
	return ["NPC encountered in the labyrinth."]

static func _card_element_group(card: Dictionary) -> String:
	var element: String = str(GameData.card_element_from_def(card))
	return element if ELEMENT_TITLES.has(element) else "none"

static func _card_element_group_title(card: Dictionary) -> String:
	var group: String = _card_element_group(card)
	return str(ELEMENT_TITLES.get(group, group.capitalize()))

static func _equipment_slot_singular(slot: String) -> String:
	match slot:
		"weapon":
			return "weapon"
		"offhand":
			return "offhand"
		"armor":
			return "armor"
		"boots":
			return "boots"
		"trinket":
			return "trinket"
	return "gear"

static func is_magick_card_id(card_id: String) -> bool:
	if card_id.is_empty() or GameData.card_is_item(card_id):
		return false
	var card: Dictionary = GameData.card_def(card_id)
	if card.is_empty():
		return false
	if GameData.starting_magic_cards().has(card_id):
		return true
	return bool(card.get("reward_pool", true))

static func _truthy_value(value: Variant) -> bool:
	match typeof(value):
		TYPE_BOOL:
			return bool(value)
		TYPE_INT:
			return int(value) != 0
		TYPE_FLOAT:
			return not is_zero_approx(float(value))
		TYPE_STRING:
			return not str(value).is_empty()
		TYPE_NIL:
			return false
	return true
