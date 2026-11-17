extends SceneTree
## Supplement diff-01's seeded native census with every authored legacy pool,
## objective-addition and Hunted path, plus all special/Guardian/dragon rosters.
const Rooms = preload("res://scripts/room_generator.gd")
const Tables = preload("res://scripts/encounter_tables.gd")
const Guardians = preload("res://scripts/guardian_library.gd")
const Bosses = preload("res://scripts/dragon_boss_library.gd")
const Data = preload("res://scripts/game_data.gd")
const Specials = preload("res://scripts/special_encounter_library.gd")
const Rules = preload("res://scripts/difficulty_tier_rules.gd")
const SEED: int = 1001
const TRAVEL: Vector2i = Vector2i.RIGHT
class PoolGenerator extends "res://scripts/room_generator.gd":
	var units: Array = []
	func _encounter_enemy_types(_kind: String, _depth: int, _rng: RandomNumberGenerator, _element: String = "none", _boss: String = "") -> Array:
		return units.duplicate()
class EntryGenerator extends "res://scripts/room_generator.gd":
	var entry: Dictionary = {}
	func _section_encounter(room: Dictionary, _tier: int, rng: RandomNumberGenerator) -> Dictionary:
		return preload("res://scripts/encounter_tables.gd").expand_entry(entry, room["element"], room["encounter_biome"], rng)
var file: FileAccess
var cases: int = 0
var oversized: int = 0
func record(generator: RefCounted, room: Dictionary, path: String) -> void:
	var seed_input: int = SEED
	if room.has("objective_type"):
		for candidate_seed: int in range(SEED, SEED + 100):
			if preload("res://scripts/combat_objective_rules.gd").build_for_room(candidate_seed, room, TRAVEL)["type"] == room["objective_type"]:
				seed_input = candidate_seed
				break
	var layout: Dictionary = generator.generate_room(seed_input, room, TRAVEL)
	assert(not room.has("objective_type") or layout["objective"]["type"] == room["objective_type"], "Census uses the requested real legacy objective")
	var count: int = Rules.starter_count(layout)
	if count > 5: oversized += 1
	cases += 1
	file.store_line(JSON.stringify({"path": path, "section": int((int(room["depth"]) - 1) / 4), "room_type": room["type"], "objective": layout["objective"]["type"], "seed": seed_input, "hunted": room.get("omen_extra_enemies", 0), "umbra_depth": room.get("umbra_depth", 0), "start_non_summoned": count, "start_count": layout["enemies"].size()}))
func base_room(depth: int, element: String) -> Dictionary:
	return {"type": "combat", "depth": depth, "coord": Vector2i(4,4), "element": element, "connections": [{"coord": Vector2i(5,4), "door_dir": Vector2i.RIGHT}, {"coord": Vector2i(4,3), "door_dir": Vector2i.UP}, {"coord": Vector2i(3,4), "door_dir": Vector2i.LEFT}]}
func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	file = FileAccess.open(preload("res://tools/encounter_sweep.gd").option(OS.get_cmdline_user_args(), "--output", ""), FileAccess.WRITE)
	var generator := Rooms.new()
	var pools := PoolGenerator.new()
	var entries := EntryGenerator.new()
	for section: int in range(6):
		for tier: int in range(1,4):
			for biome: String in Tables.BIOMES:
				var room: Dictionary = base_room(section * 4 + tier, biome)
				var groups: Array = generator._base_encounter_enemy_type_pool(tier)
				generator._add_element_locked_enemy_type_pools(groups, tier, biome)
				for index: int in range(groups.size()):
					pools.units = groups[index]
					for objective: String in ["kill_all", "kill_leader", "reach_exit"]:
						for hunted: int in [0,1]:
							room["objective_type"] = objective
							room["omen_extra_enemies"] = hunted
							record(pools, room, "legacy_pool/%s/%d" % [biome,index])
				room["section_map_layout_revision"] = 4
				room["section_index"] = section
				room["encounter_biome"] = biome
				for entry: Dictionary in Tables.load()["tiers"][str(tier)]:
					if not Tables.supports_element(entry, biome): continue
					entries.entry = entry
					for objective: String in ["kill_all", "kill_leader", "reach_exit"]:
						for hunted: int in [0,1]:
							room["objective_type"] = objective
							room["omen_extra_enemies"] = hunted
							record(entries, room, "legacy_table/%s/%s" % [biome,entry["id"]])
		for kind: String in ["warband", "umbral_snare", "last_light", "ember_hoarder"]:
			for biome: String in Tables.BIOMES:
				for tier: int in range(1,4):
					var room: Dictionary = base_room(section * 4 + tier, biome)
					room.merge({"type":"special", "special_type":kind, "special_variant":biome})
					for umbra_depth: int in [0,20]:
						room["umbra_depth"] = umbra_depth
						record(generator, room, kind + "/" + biome)
		for boss: String in Guardians.DEFINITIONS:
			for room_kind: String in ["guardian", "boss"]:
				var room: Dictionary = base_room(section * 4 + (4 if room_kind == "boss" else 3), Bosses.element_for_boss(boss))
				room.merge({"type":room_kind, "boss_id":boss})
				for umbra_depth: int in [0,20]:
					room["umbra_depth"] = umbra_depth
					record(generator, room, room_kind + "/" + boss)
	file.close()
	print("TUNE01_LEGACY_CENSUS: cases=%d over_5_non_summoned=%d" % [cases, oversized])
	quit(0 if oversized == 0 else 1)
