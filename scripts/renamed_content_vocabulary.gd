extends RefCounted
## Catalog sources and the historical rewrite shared by migration and Chronicle.

const GameData = preload("res://scripts/game_data.gd")
const Grimoire = preload("res://scripts/grimoire_library.gd")
const Skills = preload("res://scripts/skill_tree_library.gd")
const Specials = preload("res://scripts/special_encounter_library.gd")
const Biomes = preload("res://scripts/biome_library.gd")
const Boons = preload("res://scripts/opening_boon_rules.gd")
const Elements = preload("res://scripts/element_data.gd")
const BattlefieldRules = preload("res://scripts/battlefield_rules/dispatcher.gd")
const Glossary = preload("res://scripts/glossary.gd")

const LEGACY_PREFIX: String = "ash"
const NEUTRAL_WORD: String = "cinder"

static func neutralizer() -> RegEx:
	return RegEx.create_from_string("(?i)(?<![[:alnum:]])%s[[:alnum:]_-]*" % LEGACY_PREFIX)

# Read-only catalog sources. Grimoire entries also cover generated discoveries
# and mechanics that don't have an entry in GameData.
static func catalogs() -> Array[Dictionary]:
	var result: Array[Dictionary] = [
		GameData.cards(), GameData.relics(), GameData.enemies(), GameData.events(),
		GameData.omens(), GameData.equipment(), GameData.npcs(), GameData.upgrades(),
		Skills.definitions(), Grimoire._entry_map_ref(), Boons.definitions()["boons"],
		Biomes.data()["biomes"], Specials.catalog()["types"], Elements.ELEMENTS,
		BattlefieldRules.data()["instances"]
	]
	return result

static func nested_definitions() -> Array[Dictionary]:
	var result: Array[Dictionary]
	for enemy: Dictionary in GameData.enemies().values():
		result.append_array(enemy.get("intents", []))
	for event: Dictionary in GameData.events().values():
		result.append_array(event.get("choices", []))
	result.append_array(BattlefieldRules.data()["rules"])
	result.append_array(Glossary.all_entries())
	return result

static func catalog_ids() -> Dictionary:
	var ids: Dictionary = {}
	for catalog: Dictionary in catalogs():
		for id: String in catalog:
			ids[id] = true
	for row: Dictionary in nested_definitions():
		if not str(row.get("id", "")).is_empty():
			ids[str(row["id"])] = true
	return ids
