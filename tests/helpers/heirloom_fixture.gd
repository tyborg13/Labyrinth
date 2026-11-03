extends RefCounted

const Fixture = preload("res://tests/helpers/opening_boon_fixture.gd")
const Data = preload("res://scripts/game_data.gd")
# Debug/proof equipment only. Four-piece case matches the approved mockup.
static var PROOF_ITEMS: Array[String] = _strings(["duelist_rapier", "glacial_bulwark", "ironshod_sabatons", "stormglass_orb"])
const PROOF_ARMOR: String = "glassbone_cuirass"
const BURN_CLOCK_SECONDS: float = 0.30
const MID_CLOCK_SECONDS: float = 0.70
const CROSSFADE_PROOF_SECONDS: float = 0.125

static func equip(state: Dictionary, count: int = 4) -> Dictionary:
	var result: Dictionary = state.duplicate(true)
	result["equipped_equipment"] = Data.starting_equipped_equipment()
	var pieces: Array[String] = PROOF_ITEMS.duplicate()
	if count == 5: pieces.insert(2, PROOF_ARMOR)
	for id: String in pieces.slice(0, count):
		result["equipped_equipment"][Data.equipment_slot(id)] = id
		if not result["collected_equipment"].has(id): result["collected_equipment"].append(id)
	result["deck_cards"] = Data.compile_deck_cards(result["equipped_equipment"], result["attuned_magic_cards"], result.get("equipped_items", []), result)
	return result

static func terminal(count: int = 4) -> Dictionary:
	var result: Dictionary = equip(Fixture.state(true), count)
	result["mode"] = "defeat"
	result["game_over"] = true
	result["player_hp"] = 0
	return result

static func _strings(values: Array) -> Array[String]:
	var result: Array[String]
	for value: Variant in values: result.append(str(value))
	return result
