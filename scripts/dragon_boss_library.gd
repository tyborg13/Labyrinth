extends RefCounted
class_name DragonBossLibrary

const ElementData = preload("res://scripts/element_data.gd")

const DEPTHS_PER_SEQUENCE: int = 4
const ELEMENTAL_BOSS_COUNT: int = 5
const FINAL_BOSS_SEQUENCE_INDEX: int = ELEMENTAL_BOSS_COUNT

const EARTH_BOSS_ID: String = "tharokh"
const FIRE_BOSS_ID: String = "vyraketh"
const AIR_BOSS_ID: String = "vaeloryx"
const ICE_BOSS_ID: String = "iskaldra"
const LIGHTNING_BOSS_ID: String = "zekarion"
const SHADOW_BOSS_ID: String = "noctyrax"
const SHADOW_ELEMENT_ID: String = "shadow"

const ELEMENTAL_BOSS_IDS: Array[String] = [
	EARTH_BOSS_ID,
	FIRE_BOSS_ID,
	AIR_BOSS_ID,
	ICE_BOSS_ID,
	LIGHTNING_BOSS_ID
]

const BOSS_ELEMENTS := {
	EARTH_BOSS_ID: ElementData.EARTH,
	FIRE_BOSS_ID: ElementData.FIRE,
	AIR_BOSS_ID: ElementData.AIR,
	ICE_BOSS_ID: ElementData.ICE,
	LIGHTNING_BOSS_ID: ElementData.LIGHTNING,
	SHADOW_BOSS_ID: SHADOW_ELEMENT_ID
}

const BOSS_ROOM_NAMES := {
	EARTH_BOSS_ID: "The Worldspine Vault",
	FIRE_BOSS_ID: "The Cinder Crown",
	AIR_BOSS_ID: "The Hollow Gale",
	ICE_BOSS_ID: "The Rime Tyrant's Court",
	LIGHTNING_BOSS_ID: "Tempest God's Perch",
	SHADOW_BOSS_ID: "The Last Eclipse"
}

const OPENING_INTENT_IDS := {
	EARTH_BOSS_ID: "stonewake",
	FIRE_BOSS_ID: "kindle_ground",
	AIR_BOSS_ID: "hollow_gale",
	ICE_BOSS_ID: "crystal_mantle",
	SHADOW_BOSS_ID: "last_eclipse"
}

static func elemental_boss_order(run_seed: int) -> Array[String]:
	var result: Array[String] = ELEMENTAL_BOSS_IDS.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = _boss_order_seed(run_seed)
	for index: int in range(result.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, index)
		var held: String = result[index]
		result[index] = result[swap_index]
		result[swap_index] = held
	return result

static func boss_id_for_depth(run_seed: int, depth: int) -> String:
	if depth <= 0 or posmod(depth - 1, DEPTHS_PER_SEQUENCE) + 1 != DEPTHS_PER_SEQUENCE:
		return ""
	var sequence_index: int = int((depth - 1) / DEPTHS_PER_SEQUENCE)
	if sequence_index >= FINAL_BOSS_SEQUENCE_INDEX:
		return SHADOW_BOSS_ID
	var order: Array[String] = elemental_boss_order(run_seed)
	return order[clampi(sequence_index, 0, order.size() - 1)]

static func element_for_boss(boss_id: String) -> String:
	return str(BOSS_ELEMENTS.get(boss_id, ElementData.NONE))

static func room_name_for_boss(boss_id: String) -> String:
	return str(BOSS_ROOM_NAMES.get(boss_id, "Dragon's Perch"))

static func opening_intent_id(boss_id: String) -> String:
	return str(OPENING_INTENT_IDS.get(boss_id, ""))

static func is_dragon_boss_id(enemy_type: String) -> bool:
	return enemy_type == SHADOW_BOSS_ID or ELEMENTAL_BOSS_IDS.has(enemy_type)

static func _boss_order_seed(run_seed: int) -> int:
	var value: int = int((run_seed * 1664525 + 1013904223 + 2405) & 0x7fffffff)
	value = int((value ^ (value >> 13)) & 0x7fffffff)
	return maxi(1, value)
