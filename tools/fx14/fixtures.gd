extends RefCounted
## Director-only stage. Cards and intents are read from the production data.

const Combat = preload("res://scripts/combat_engine.gd")
const Ranged = preload("res://scripts/protagonist_cutout/ranged_action.gd")
const HERO := Vector2i(3, 4)
const TARGET := Vector2i(5, 4)
const HIDDEN := Vector2i(7, 4)
const ROOM := Vector2i(1, 0)
const SEED: int = 97131
const CARD_CASES := [
	"pinning_quarrel", "dull_bolt", "hurl_spear", "ricochet_knife", "chain_lock",
	"throwing_net", "jaw_trap", "snake_eyes", "headsmans_toll", "lantern_shot",
	"sunlance", "icicle_lance", "frostbolt", "rockburst", "razor_gale",
	"vacuum_line", "updraft",
]
const ENEMY_CASES := [
	["acolyte", "dust_bolt"], ["harrier", "pelt"], ["frostglass_lancer", "spear_cast"],
	["rime_spitter", "needle"], ["hollow_mimic", "shade_bolt"], ["veilbound_acolyte", "veil_needle"],
]
const BOW: String = "stormstring_bow"

static var _cards: Dictionary
static var _enemies: Dictionary

static func cards() -> Dictionary:
	if _cards.is_empty():
		_cards = JSON.parse_string(FileAccess.get_file_as_string("res://data/cards.json"))
	return _cards

static func enemies() -> Dictionary:
	if _enemies.is_empty():
		_enemies = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies.json"))
	return _enemies

static func single_candidate(action: Dictionary) -> bool:
	var kind: String = action["type"]
	return kind == "ranged" or (kind in ["pull", "push"] and int(action.get("range", 0)) > 1)

static func card_effect(id: String, action: Dictionary) -> Dictionary:
	var kind: String = action["type"]
	return {
		"kind": "ranged",
		"action_type": kind,
		"base_card_id": id,
		"protagonist_ranged": Ranged.clip_for_action(action),
		"protagonist_origin": HERO,
		"from": HERO,
		"to": TARGET,
		"range": int(action.get("range", 2)),
		"element": action.get("element", cards()[id].get("element", "none")),
	}

static func enemy_effect(enemy: String, intent: Dictionary, action: Dictionary) -> Dictionary:
	return {
		"kind": action["type"],
		"action_type": action["type"],
		"actor_key": "enemy_1",
		"enemy_type": enemy,
		"intent_id": intent["id"],
		"from": TARGET,
		"to": HERO,
		"target_key": "player",
		"range": int(action.get("range", 2)),
		"element": action.get("element", enemies()[enemy].get("element", "none")),
	}

static func card_action(id: String) -> Dictionary:
	for action: Dictionary in cards()[id]["actions"]:
		if single_candidate(action):
			return action
	return {}

static func named_card(id: String) -> Dictionary:
	var action: Dictionary = card_action(id)
	return {} if action.is_empty() else card_effect(id, action)

static func named_enemy(enemy: String, id: String) -> Dictionary:
	for intent: Dictionary in enemies()[enemy]["intents"]:
		if intent["id"] != id:
			continue
		for action: Dictionary in intent["actions"]:
			if single_candidate(action):
				return enemy_effect(enemy, intent, action)
	return {}

static func cases() -> Dictionary:
	var result: Dictionary = {}
	for id: String in CARD_CASES:
		result["dull_bolt_no_bow" if id == "dull_bolt" else id] = named_card(id)
		if id == "dull_bolt":
			var bow: Dictionary = named_card(id)
			bow["protagonist_ranged_motion"] = "bow"
			bow["protagonist_weapon_motion"] = "bow"
			result["dull_bolt_bow"] = bow
	for row: Array in ENEMY_CASES:
		result[row[0] + "_" + row[1]] = named_enemy(row[0], row[1])
	var hidden: Dictionary = named_enemy("frostglass_lancer", "spear_cast")
	hidden["from"] = HIDDEN
	hidden["hidden_by_umbra"] = true
	result["umbra_half_hidden"] = hidden
	return result

static func layout_for(effect: Dictionary) -> Dictionary:
	var grid: Array = []
	for y: int in range(9):
		var row: Array[String]
		for x: int in range(9):
			row.append("wall" if x in [0, 8] or y in [0, 8] else "stone")
		grid.append(row)
	var enemy: String = effect.get("enemy_type", "crawler")
	var source: Vector2i = effect.get("from", TARGET) if effect.has("enemy_type") else TARGET
	return {
		"name": "FX-14 proof", "coord": ROOM, "type": "combat", "depth": 2, "grid": grid,
		"player_start": HERO, "enemies": [{"id": 1, "type": enemy, "pos": source}],
		"terrain": [], "traps": [], "loot": [],
	}

static func state_for(effect: Dictionary) -> Dictionary:
	var state: Dictionary = Combat.new().create_combat(SEED, layout_for(effect), {
		"hp": 24, "max_hp": 24, "deck_cards": ["dull_bolt", "hurl_spear", "icicle_lance"],
		"relics": [], "hand_size": 3,
	})
	var enemies_in_room: Array = state["enemies"]
	var foe: Dictionary = enemies_in_room[0]
	foe["id"] = 1
	foe["hp"] = 24
	foe["max_hp"] = 24
	for intent: Dictionary in enemies().get(effect.get("enemy_type", "crawler"), {}).get("intents", []):
		if intent["id"] == effect.get("intent_id"):
			foe["intent"] = intent.duplicate(true)
			break
	if bool(effect.get("hidden_by_umbra", false)):
		state["umbra"] = {"stage": "heart", "stage_reduction": 0, "light_sources": []}
	else:
		state.erase("umbra")
	return state
