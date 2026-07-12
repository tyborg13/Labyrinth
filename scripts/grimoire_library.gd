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
# Catalog data is generated from immutable resource definitions. Public accessors
# still return isolated copies; hot internal derivation paths share these refs.
static var _entries_cache: Array = []
static var _entry_map_cache: Dictionary = {}
static var _entry_ids_cache: Array[String] = []
static var _section_map_cache: Dictionary = {}
static var _default_entry_ids_cache: Array[String] = []
static var _card_entry_ids_cache: Dictionary = {}
static var _equipment_entry_ids_cache: Dictionary = {}
static var _enemy_type_entry_ids_cache: Dictionary = {}

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
	return _entries_ref().duplicate(true)

static func _entries_ref() -> Array:
	if not _entries_cache.is_empty():
		return _entries_cache
	var result: Array = (data().get("entries", []) as Array).duplicate(true)
	result.append_array(magick_entries())
	result.append_array(equipment_entries())
	result.append_array(item_entries())
	result.append_array(character_entries())
	_entries_cache = result
	return _entries_cache

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
	return _entry_map_ref().duplicate(true)

static func _entry_map_ref() -> Dictionary:
	if not _entry_map_cache.is_empty():
		return _entry_map_cache
	var result: Dictionary = {}
	for entry_var: Variant in _entries_ref():
		if typeof(entry_var) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_var as Dictionary
		var entry_id: String = str(entry.get("id", ""))
		if not entry_id.is_empty():
			result[entry_id] = entry
	_entry_map_cache = result
	return _entry_map_cache

static func _entry_ids_ref() -> Array[String]:
	if not _entry_ids_cache.is_empty():
		return _entry_ids_cache
	for entry_var: Variant in _entries_ref():
		if typeof(entry_var) != TYPE_DICTIONARY:
			continue
		var entry_id: String = str((entry_var as Dictionary).get("id", ""))
		if not entry_id.is_empty():
			_entry_ids_cache.append(entry_id)
	return _entry_ids_cache

static func entry_def(entry_id: String) -> Dictionary:
	return (_entry_map_ref().get(entry_id, {}) as Dictionary).duplicate(true)

static func section_def(section_id: String) -> Dictionary:
	if _section_map_cache.is_empty():
		for section_var: Variant in data().get("sections", []):
			if typeof(section_var) != TYPE_DICTIONARY:
				continue
			var section: Dictionary = section_var as Dictionary
			var cached_section_id: String = str(section.get("id", ""))
			if not cached_section_id.is_empty():
				_section_map_cache[cached_section_id] = section
	return (_section_map_cache.get(section_id, {}) as Dictionary).duplicate(true)

static func default_entry_ids() -> Array[String]:
	return _copy_string_array(_default_entry_ids_ref())

static func _default_entry_ids_ref() -> Array[String]:
	if not _default_entry_ids_cache.is_empty():
		return _default_entry_ids_cache
	for entry_var: Variant in _entries_ref():
		if typeof(entry_var) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_var as Dictionary
		if bool(entry.get("default", false)):
			var entry_id: String = str(entry.get("id", ""))
			if not entry_id.is_empty():
				_default_entry_ids_cache.append(entry_id)
	return _default_entry_ids_cache

static func ensure_progression_state(progression: Dictionary) -> Dictionary:
	if progression.is_empty():
		return {}
	var next_progression: Dictionary = progression.duplicate(true)
	_ensure_progression_state_in_place(next_progression)
	return next_progression

static func ensure_run_state(run_state: Dictionary) -> Dictionary:
	var next_state: Dictionary = run_state.duplicate(true)
	_ensure_run_state_in_place(next_state)
	return next_state

static func _ensure_progression_state_in_place(progression: Dictionary) -> void:
	var unlocked_wanted: Dictionary = _entry_id_set(progression.get(UNLOCKED_KEY, []))
	_add_entry_ids_to_set(unlocked_wanted, _default_entry_ids_ref())
	var unlocked: Array[String] = _ordered_entry_ids_from_set(unlocked_wanted)
	progression[UNLOCKED_KEY] = unlocked
	var unlocked_set: Dictionary = _entry_id_set(unlocked)
	var unread_set: Dictionary = _entry_id_set(progression.get(UNREAD_KEY, []))
	var filtered_unread: Array[String] = []
	for entry_id: String in _entry_ids_ref():
		if unread_set.has(entry_id) and unlocked_set.has(entry_id):
			filtered_unread.append(entry_id)
	progression[UNREAD_KEY] = filtered_unread

static func _ensure_run_state_in_place(next_state: Dictionary) -> void:
	var unlocked: Array[String] = normalize_entry_ids(next_state.get(UNLOCKED_KEY, []))
	var progression: Dictionary = {}
	if typeof(next_state.get("progression", {})) == TYPE_DICTIONARY:
		progression = next_state.get("progression", {}) as Dictionary
		if not progression.is_empty():
			_ensure_progression_state_in_place(progression)
			next_state["progression"] = progression
			for entry_id: String in progression.get(UNLOCKED_KEY, []):
				if not unlocked.has(entry_id):
					unlocked.append(entry_id)
	var has_unlocked_key: bool = next_state.has(UNLOCKED_KEY)
	for entry_id: String in _default_entry_ids_ref():
		if not unlocked.has(entry_id):
			unlocked.append(entry_id)
	if not has_unlocked_key:
		unlocked.append_array(entry_ids_for_run_state(next_state))
	unlocked = ordered_entry_ids(unlocked)
	next_state[UNLOCKED_KEY] = unlocked
	var unread: Array[String] = normalize_entry_ids(next_state.get(UNREAD_KEY, []))
	if not progression.is_empty():
		for entry_id: String in progression.get(UNREAD_KEY, []):
			if not unread.has(entry_id):
				unread.append(entry_id)
	var filtered_unread: Array[String] = []
	var unlocked_set: Dictionary = _entry_id_set(unlocked)
	for entry_id: String in ordered_entry_ids(unread):
		if unlocked_set.has(entry_id):
			filtered_unread.append(entry_id)
	next_state[UNREAD_KEY] = filtered_unread
	if not next_state.has(NOTICE_KEY):
		next_state[NOTICE_KEY] = ""

static func unlock_entries(run_state: Dictionary, candidate_ids: Array) -> Dictionary:
	var next_state: Dictionary = run_state.duplicate(true)
	_ensure_run_state_in_place(next_state)
	var unlocked: Array[String] = normalize_entry_ids(next_state.get(UNLOCKED_KEY, []))
	var unread: Array[String] = normalize_entry_ids(next_state.get(UNREAD_KEY, []))
	var unlocked_set: Dictionary = _entry_id_set(unlocked)
	var unread_set: Dictionary = _entry_id_set(unread)
	var progression: Dictionary = {}
	var progression_unlocked: Array[String] = []
	var progression_unread: Array[String] = []
	var progression_unlocked_set: Dictionary = {}
	var progression_unread_set: Dictionary = {}
	if typeof(next_state.get("progression", {})) == TYPE_DICTIONARY:
		progression = next_state.get("progression", {}) as Dictionary
		if not progression.is_empty():
			progression_unlocked = _copy_string_values(progression.get(UNLOCKED_KEY, []))
			progression_unread = _copy_string_values(progression.get(UNREAD_KEY, []))
			progression_unlocked_set = _entry_id_set(progression_unlocked)
			progression_unread_set = _entry_id_set(progression_unread)
	var added: Array[String] = []
	var progression_changed: bool = false
	for entry_id: String in ordered_entry_ids(candidate_ids):
		var run_already_unlocked: bool = unlocked_set.has(entry_id)
		if not run_already_unlocked:
			unlocked.append(entry_id)
			unlocked_set[entry_id] = true
			if not unread_set.has(entry_id):
				unread.append(entry_id)
				unread_set[entry_id] = true
			added.append(entry_id)
		if not progression.is_empty() and not progression_unlocked_set.has(entry_id):
			progression_unlocked.append(entry_id)
			progression_unlocked_set[entry_id] = true
			progression_changed = true
			if not run_already_unlocked and not progression_unread_set.has(entry_id):
				progression_unread.append(entry_id)
				progression_unread_set[entry_id] = true
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
	var next_state: Dictionary = run_state.duplicate(true)
	_ensure_run_state_in_place(next_state)
	next_state[UNREAD_KEY] = []
	next_state[NOTICE_KEY] = ""
	if typeof(next_state.get("progression", {})) == TYPE_DICTIONARY:
		var progression: Dictionary = next_state.get("progression", {}) as Dictionary
		if not progression.is_empty():
			progression[UNREAD_KEY] = []
			next_state["progression"] = progression
	return next_state

static func notice_for_added_entries(entry_ids: Array) -> String:
	var ordered: Array[String] = ordered_entry_ids(entry_ids)
	if ordered.is_empty():
		return ""
	if ordered.size() == 1:
		var entry: Dictionary = _entry_map_ref().get(ordered[0], {}) as Dictionary
		return "Added %s entry to the Grimoire." % str(entry.get("title", "new"))
	return "Added %d entries to the Grimoire." % ordered.size()

static func entries_for_section(section_id: String, unlocked_ids: Array) -> Array[Dictionary]:
	var unlocked: Array[String] = normalize_entry_ids(unlocked_ids)
	var unlocked_set: Dictionary = _entry_id_set(unlocked)
	var result: Array[Dictionary] = []
	for entry_var: Variant in _entries_ref():
		if typeof(entry_var) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_var as Dictionary
		var entry_id: String = str(entry.get("id", ""))
		if unlocked_set.has(entry_id) and str(entry.get("section", "")) == section_id:
			result.append(entry.duplicate(true))
	return result

static func first_unlocked_entry_id_for_section(section_id: String, unlocked_ids: Array) -> String:
	var unlocked_set: Dictionary = _entry_id_set(normalize_entry_ids(unlocked_ids))
	for entry_var: Variant in _entries_ref():
		if typeof(entry_var) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_var as Dictionary
		var entry_id: String = str(entry.get("id", ""))
		if unlocked_set.has(entry_id) and str(entry.get("section", "")) == section_id:
			return entry_id
	return ""

static func section_has_unlocked_entries(section_id: String, unlocked_ids: Array) -> bool:
	return not first_unlocked_entry_id_for_section(section_id, unlocked_ids).is_empty()

static func normalize_entry_ids(value: Variant) -> Array[String]:
	if typeof(value) != TYPE_ARRAY:
		return _empty_string_array()
	return _ordered_entry_ids_from_set(_entry_id_set(value))

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
	return _ordered_entry_ids_from_set(wanted)

static func _entry_id_set(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if typeof(value) != TYPE_ARRAY:
		return result
	for id_var: Variant in value:
		var entry_id: String = str(id_var)
		if not entry_id.is_empty():
			result[entry_id] = true
	return result

static func _add_entry_ids_to_set(target: Dictionary, values: Variant) -> void:
	if typeof(values) != TYPE_ARRAY:
		return
	for id_var: Variant in values:
		var entry_id: String = str(id_var)
		if not entry_id.is_empty():
			target[entry_id] = true

static func _ordered_entry_ids_from_set(wanted: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for entry_id: String in _entry_ids_ref():
		if wanted.has(entry_id):
			result.append(entry_id)
	return result

static func _copy_string_array(source: Array[String]) -> Array[String]:
	var result: Array[String] = []
	result.append_array(source)
	return result

static func _empty_string_array() -> Array[String]:
	var result: Array[String] = []
	return result

static func _copy_string_values(source: Variant) -> Array[String]:
	var result: Array[String] = []
	if typeof(source) != TYPE_ARRAY:
		return result
	for value: Variant in source:
		result.append(str(value))
	return result

static func entry_ids_for_card_ids(card_ids: Variant) -> Array[String]:
	if typeof(card_ids) != TYPE_ARRAY:
		return _empty_string_array()
	var wanted: Dictionary = {}
	_collect_entry_ids_for_card_ids(card_ids, wanted)
	return _ordered_entry_ids_from_set(wanted)

static func entry_ids_for_card_id(card_id: String) -> Array[String]:
	return _copy_string_values(_entry_ids_for_card_id_ref(card_id))

static func _entry_ids_for_card_id_ref(card_id: String) -> Array:
	if _card_entry_ids_cache.has(card_id):
		return _card_entry_ids_cache.get(card_id, []) as Array
	var card: Dictionary = GameData.card_def(card_id)
	if card.is_empty():
		_card_entry_ids_cache[card_id] = []
		return []
	var wanted: Dictionary = {}
	if GameData.card_is_item(card_id):
		wanted[item_entry_id(card_id)] = true
	elif is_magick_card_id(card_id):
		wanted[magick_entry_id(card_id)] = true
	_collect_entry_ids_for_card_def(card, wanted)
	var result: Array[String] = _ordered_entry_ids_from_set(wanted)
	_card_entry_ids_cache[card_id] = result
	return result

static func _collect_entry_ids_for_card_ids(card_ids: Variant, wanted: Dictionary) -> void:
	if typeof(card_ids) != TYPE_ARRAY:
		return
	for card_id_var: Variant in card_ids:
		_add_entry_ids_to_set(wanted, _entry_ids_for_card_id_ref(str(card_id_var)))

static func entry_ids_for_equipment_ids(equipment_ids: Variant) -> Array[String]:
	if typeof(equipment_ids) != TYPE_ARRAY:
		return _empty_string_array()
	var wanted: Dictionary = {}
	_collect_entry_ids_for_equipment_ids(equipment_ids, wanted)
	return _ordered_entry_ids_from_set(wanted)

static func entry_ids_for_equipment_id(equipment_id: String) -> Array[String]:
	return _copy_string_values(_entry_ids_for_equipment_id_ref(equipment_id))

static func _entry_ids_for_equipment_id_ref(equipment_id: String) -> Array:
	if _equipment_entry_ids_cache.has(equipment_id):
		return _equipment_entry_ids_cache.get(equipment_id, []) as Array
	if GameData.equipment_def(equipment_id).is_empty() or GameData.equipment_slot(equipment_id).is_empty():
		_equipment_entry_ids_cache[equipment_id] = []
		return []
	var wanted: Dictionary = {}
	wanted[equipment_entry_id(equipment_id)] = true
	for card_id_var: Variant in GameData.equipment_cards(equipment_id):
		for entry_id_var: Variant in _entry_ids_for_card_id_ref(str(card_id_var)):
			var entry_id: String = str(entry_id_var)
			if entry_id.begins_with("magick:") or entry_id.begins_with("item:"):
				continue
			wanted[entry_id] = true
	var result: Array[String] = _ordered_entry_ids_from_set(wanted)
	_equipment_entry_ids_cache[equipment_id] = result
	return result

static func _collect_entry_ids_for_equipment_ids(equipment_ids: Variant, wanted: Dictionary) -> void:
	if typeof(equipment_ids) != TYPE_ARRAY:
		return
	for equipment_id_var: Variant in equipment_ids:
		_add_entry_ids_to_set(wanted, _entry_ids_for_equipment_id_ref(str(equipment_id_var)))

static func entry_ids_for_npc_ids(npc_ids: Variant) -> Array[String]:
	if typeof(npc_ids) != TYPE_ARRAY:
		return _empty_string_array()
	var wanted: Dictionary = {}
	for npc_id_var: Variant in npc_ids:
		var npc_id: String = str(npc_id_var)
		if GameData.npc_def(npc_id).is_empty():
			continue
		var entry_id: String = character_entry_id(npc_id)
		wanted[entry_id] = true
	return _ordered_entry_ids_from_set(wanted)

static func entry_ids_for_card_def(card: Dictionary) -> Array[String]:
	var wanted: Dictionary = {}
	_collect_entry_ids_for_card_def(card, wanted)
	return _ordered_entry_ids_from_set(wanted)

static func _collect_entry_ids_for_card_def(card: Dictionary, wanted: Dictionary) -> void:
	if bool(card.get("burn", false)):
		wanted["keyword:exhaust"] = true
	if bool(card.get("consume_on_play", false)):
		wanted["keyword:consume"] = true
	if bool(card.get("flurry", false)):
		wanted["keyword:flurry"] = true
	if int(card.get("health_cost", 0)) > 0:
		wanted["keyword:health_cost"] = true
	if card.has("requires_intensity") or card.has("intensity_bonus"):
		wanted["combat:intensity"] = true
	_collect_entry_ids_for_actions(card.get("actions", []), wanted)

static func entry_ids_for_enemy_types(enemy_types: Variant) -> Array[String]:
	if typeof(enemy_types) != TYPE_ARRAY:
		return _empty_string_array()
	var wanted: Dictionary = {}
	for enemy_type_var: Variant in enemy_types:
		_add_entry_ids_to_set(wanted, _entry_ids_for_enemy_type_ref(str(enemy_type_var)))
	return _ordered_entry_ids_from_set(wanted)

static func _entry_ids_for_enemy_type_ref(enemy_type: String) -> Array:
	if _enemy_type_entry_ids_cache.has(enemy_type):
		return _enemy_type_entry_ids_cache.get(enemy_type, []) as Array
	var wanted: Dictionary = {}
	wanted["enemy:%s" % enemy_type] = true
	_collect_entry_ids_for_enemy_def(GameData.enemy_def(enemy_type), wanted)
	var result: Array[String] = _ordered_entry_ids_from_set(wanted)
	_enemy_type_entry_ids_cache[enemy_type] = result
	return result

static func entry_ids_for_enemy_def(enemy: Dictionary) -> Array[String]:
	var wanted: Dictionary = {}
	_collect_entry_ids_for_enemy_def(enemy, wanted)
	return _ordered_entry_ids_from_set(wanted)

static func _collect_entry_ids_for_enemy_def(enemy: Dictionary, wanted: Dictionary) -> void:
	for intent_var: Variant in enemy.get("intents", []):
		if typeof(intent_var) != TYPE_DICTIONARY:
			continue
		var intent: Dictionary = intent_var as Dictionary
		_collect_entry_ids_for_actions(intent.get("actions", []), wanted)

static func entry_ids_for_combat_state(combat_state: Dictionary) -> Array[String]:
	var wanted: Dictionary = {}
	if not (combat_state.get("traps", []) as Array).is_empty():
		wanted["combat:traps"] = true
	var enemy_types_seen: Dictionary = {}
	for enemy_var: Variant in combat_state.get("enemies", []):
		if typeof(enemy_var) != TYPE_DICTIONARY:
			continue
		var enemy: Dictionary = enemy_var as Dictionary
		var enemy_type: String = str(enemy.get("type", ""))
		if enemy_type.is_empty() or enemy_types_seen.has(enemy_type):
			continue
		enemy_types_seen[enemy_type] = true
		_add_entry_ids_to_set(wanted, _entry_ids_for_enemy_type_ref(enemy_type))
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
	_collect_entry_ids_for_equipment_ids(equipment_ids, wanted)
	var deck: Dictionary = combat_state.get("deck", {}) as Dictionary
	for pile_name: String in ["hand", "draw", "discard", "burned", "consumed"]:
		_collect_entry_ids_for_card_ids(deck.get(pile_name, []), wanted)
	return _ordered_entry_ids_from_set(wanted)

static func entry_ids_for_run_state(run_state: Dictionary) -> Array[String]:
	var wanted: Dictionary = {}
	for card_list_key: String in ["deck_cards", "reward_cards", "attuned_magic_cards", "magic_inventory", "item_inventory", "equipped_items"]:
		_collect_entry_ids_for_card_ids(run_state.get(card_list_key, []), wanted)
	var equipment_ids: Array = []
	equipment_ids.append_array(run_state.get("collected_equipment", []))
	equipment_ids.append_array(run_state.get("equipment_inventory", []))
	for equipment_id_var: Variant in (run_state.get("equipped_equipment", {}) as Dictionary).values():
		equipment_ids.append(equipment_id_var)
	_collect_entry_ids_for_equipment_ids(equipment_ids, wanted)
	var current_room: Dictionary = _current_room_metadata(run_state)
	var npc_ids: Array = []
	for npc_var: Variant in current_room.get("npcs", []):
		if typeof(npc_var) != TYPE_DICTIONARY:
			continue
		var npc_id: String = str((npc_var as Dictionary).get("id", ""))
		if not npc_id.is_empty():
			npc_ids.append(npc_id)
	_add_entry_ids_to_set(wanted, entry_ids_for_npc_ids(npc_ids))
	var pending_reward: Dictionary = run_state.get("pending_reward", {}) as Dictionary
	_collect_entry_ids_for_card_ids(pending_reward.get("cards", []), wanted)
	for offer_id_var: Variant in _current_merchant_offer_ids(run_state):
		var offer_id: String = str(offer_id_var)
		var offer_entries: Array = _entry_ids_for_equipment_id_ref(offer_id) if not GameData.equipment_def(offer_id).is_empty() else _entry_ids_for_card_id_ref(offer_id)
		_add_entry_ids_to_set(wanted, offer_entries)
	var combat_state: Dictionary = run_state.get("combat_state", {}) as Dictionary
	_add_entry_ids_to_set(wanted, entry_ids_for_combat_state(combat_state))
	return _ordered_entry_ids_from_set(wanted)

static func entry_ids_for_actions(actions: Variant) -> Array[String]:
	var wanted: Dictionary = {}
	_collect_entry_ids_for_actions(actions, wanted)
	return _ordered_entry_ids_from_set(wanted)

static func _collect_entry_ids_for_actions(actions: Variant, wanted: Dictionary) -> void:
	if typeof(actions) != TYPE_ARRAY:
		return
	for action_var: Variant in actions:
		if typeof(action_var) != TYPE_DICTIONARY:
			continue
		var action: Dictionary = action_var as Dictionary
		var action_type: String = str(action.get("type", ""))
		var type_entry: String = str(ACTION_TYPE_ENTRY_IDS.get(action_type, ""))
		if not type_entry.is_empty():
			wanted[type_entry] = true
		if action_type == "summon_minions":
			var minion_type: String = str(action.get("minion_type", ""))
			var minion_entry: String = "enemy:%s" % minion_type
			if not minion_type.is_empty():
				wanted[minion_entry] = true
		for field_name: String in ACTION_FIELD_ENTRY_IDS.keys():
			if not action.has(field_name) or not _truthy_value(action.get(field_name)):
				continue
			var field_entry: String = str(ACTION_FIELD_ENTRY_IDS.get(field_name, ""))
			if not field_entry.is_empty():
				wanted[field_entry] = true
		if action.has("requires_intensity") or action.has("intensity_bonus"):
			wanted["combat:intensity"] = true
		_collect_nested_action_entry_ids(action, wanted)

static func _entry_ids_for_nested_action_values(value: Variant) -> Array[String]:
	var wanted: Dictionary = {}
	_collect_nested_action_entry_ids(value, wanted)
	return _ordered_entry_ids_from_set(wanted)

static func _collect_nested_action_entry_ids(value: Variant, wanted: Dictionary) -> void:
	match typeof(value):
		TYPE_DICTIONARY:
			for key_var: Variant in (value as Dictionary).keys():
				var key: String = str(key_var)
				var nested_value: Variant = (value as Dictionary).get(key_var)
				var field_entry: String = str(ACTION_FIELD_ENTRY_IDS.get(key, ""))
				if not field_entry.is_empty() and _truthy_value(nested_value):
					wanted[field_entry] = true
				_collect_nested_action_entry_ids(nested_value, wanted)
		TYPE_ARRAY:
			for item_var: Variant in value:
				_collect_nested_action_entry_ids(item_var, wanted)

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
	return rooms.get(key, {}) as Dictionary

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
	if bool(card.get("flurry", false)):
		notes.append("Spends every current card play and repeats once per play spent")
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
