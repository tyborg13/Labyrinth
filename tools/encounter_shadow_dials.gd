extends RefCounted
## meas-05: sweep-only copies. Never persist changes to a production catalog.
const Sweep = preload("res://tools/encounter_sweep.gd")
const Tables = preload("res://scripts/encounter_tables.gd")
const GROUPS: PackedStringArray = ["baseline", "A", "B", "C", "D", "E", "F", "G"]

static func replace_units(value: Variant, source: String, replacement: String) -> Variant:
	if value is String: return replacement if value == source else value
	if value is Array:
		var result: Array = []
		for item: Variant in value: result.append(replace_units(item, source, replacement))
		return result
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value: result[key] = replace_units(value[key], source, replacement) if key in ["units", "element_regulars", "biome_groups", "tiers"] or value[key] is Array or value[key] is Dictionary else value[key]
		return result
	return value

static func layout(sample: Dictionary, map_state: Dictionary, group: String, selection: Dictionary) -> Dictionary:
	assert(group in GROUPS)
	var natural: Dictionary
	if group == "F" and sample["biome"] == "shadow":
		assert(not selection.get("source", "").is_empty() and not selection.get("replacement", "").is_empty())
		var original: Dictionary = Tables.load()
		var substituted: Dictionary = replace_units(original, selection["source"], selection["replacement"])
		Tables.install_table_for_tests(substituted)
		natural = Sweep.layout(sample, map_state)
		Tables.install_table_for_tests(original)
	else:
		natural = Sweep.layout(sample, map_state)
	return prepare_room(natural, str(sample["biome"]), group)

static func prepare_room(room: Dictionary, biome: String, group: String) -> Dictionary:
	var result: Dictionary = room.duplicate(true)
	if biome != "shadow": return result
	if group in ["A", "E"] and result["enemies"].size() > 1:
		var removed: Dictionary = result["enemies"].pop_back()
		assert(int(result["objective"].get("leader_id", -1)) != int(removed["id"]), "TODO_DESIGN_removed_objective_leader")
		result["objective"]["initial_enemy_count"] = result["enemies"].size()
	if group == "B":
		result["_shadow_hp_override"] = true
		for enemy: Dictionary in result["enemies"]:
			enemy["max_hp"] = maxi(1, ceili(float(enemy["max_hp"]) * 0.75))
			enemy["hp"] = enemy["max_hp"]
	return result

static func damage_delta(group: String) -> int:
	return 2 if group == "D" else 1 if group in ["C", "E"] else 0
