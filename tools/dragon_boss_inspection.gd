extends RefCounted

## Playable dragon fixtures use the production map, encounter, shuffle and save
## paths. No debug-boss flag, inflated health, extra plays, or staged winning hand.
const Bosses = preload("res://scripts/dragon_boss_library.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const Data = preload("res://scripts/game_data.gd")
const CASES: Array[String] = ["encounter", "pre_battle", "reward"]
const BUILDS: Array[String] = ["balanced", "skirmisher"]

static func default_level(depth: int) -> int:
	# Fresh-profile budget: cumulative level spend 0 / 180 / 430 / 430 / 770 / 770.
	return int({4:1, 8:2, 12:3, 16:3, 20:4, 24:4}.get(depth, 1))

static func default_skills(depth: int) -> Array[String]:
	var skills: Array[String] = []
	if depth >= 8: skills.append("quick_wits")
	if depth >= 12: skills.append("measured_breath")
	if depth >= 20: skills.append("ghost_stride")
	return skills

static func validate(options: Dictionary) -> String:
	var id: String = str(options.get("dragon_id", "vyraketh"))
	var depth: int = int(options.get("dragon_depth", 4))
	if not Bosses.is_dragon_boss_id(id): return "Unknown --dragon-id: %s" % id
	if depth not in [4, 8, 12, 16, 20, 24]: return "--dragon-depth must be 4, 8, 12, 16, 20 or 24."
	if (id == "noctyrax") != (depth == 24): return "Noctyrax belongs at depth 24; elemental dragons belong at depths 4–20."
	if not CASES.has(str(options.get("dragon_case", "encounter"))): return "Unknown --dragon-case."
	if not BUILDS.has(str(options.get("dragon_build", "balanced"))): return "Unknown --dragon-build."
	return ""

static func seed_for_options(options: Dictionary) -> int:
	var seed: int = int(options.get("seed", 7262026))
	for candidate: int in range(seed, seed + 10000):
		if Bosses.boss_id_for_depth(candidate, int(options.get("dragon_depth", 4))) == str(options.get("dragon_id", "vyraketh")):
			return candidate
	assert(false, "No seed found for dragon inspection")
	return seed

static func build(engine: RefCounted, combat: RefCounted, source: Dictionary, options: Dictionary) -> Dictionary:
	var state: Dictionary = source.duplicate(true)
	var depth: int = int(options.get("dragon_depth", 4))
	var id: String = str(options.get("dragon_id", "vyraketh"))
	var study: String = str(options.get("dragon_case", "encounter"))
	var coord := Vector2i(depth, 0)
	var room: Dictionary = Graph.room(state, coord)
	assert(str(room.get("boss_id", "")) == id)
	_loadout(state, options, depth)
	# Route history and acquired trophies represent the preceding gates. Currency
	# is not fabricated; the acquisition budget is documented in the playtest log.
	preload("res://tools/guardian_inspection.gd")._mark_route(state, Vector2i.ZERO, coord)
	room["cleared"] = false
	room["revealed"] = true
	room["visited"] = true
	room["sealed"] = false
	state["current_room"] = coord
	state["notice"] = ""
	state["mode"] = "pre_battle"
	state["pre_battle_pending"] = true
	state["pre_battle_travel_dir"] = Vector2i.RIGHT
	state["current_room_layout"] = engine._display_layout_for_room(int(state["seed"]), room, Vector2i.RIGHT)
	state["combat_state"] = {}
	state["dragon_inspection"] = {"id": id, "depth": depth, "case": study, "build": options.get("dragon_build", "balanced")}
	Graph.refresh_knowledge(state)
	if study == "pre_battle": return state
	state = engine.begin_pre_battle_combat(state)
	if study == "reward":
		var battle: Dictionary = state["combat_state"]
		for index: int in range(battle["enemies"].size()):
			if str(battle["enemies"][index]["type"]) == id:
				battle = combat._damage_enemy(battle, index, int(battle["enemies"][index]["hp"]) + 999, true, true)
				break
		return engine.finish_combat(state, battle)
	return state

static func _loadout(state: Dictionary, options: Dictionary, depth: int) -> void:
	var skirmisher: bool = str(options.get("dragon_build", "balanced")) == "skirmisher"
	# First gate: two common equipment replacements, one rare spell, one common
	# relic, one expendable item. Retain three starter slots; no upgraded cards.
	if str(options.get("equip", "")).is_empty():
		state["equipped_equipment"]["weapon"] = "sawtooth_knife" if skirmisher else "iron_cleaver"
		state["equipped_equipment"]["offhand"] = "buckler_of_nails" if skirmisher else "ward_kite"
		if depth >= 8: state["equipped_equipment"]["armor"] = "boiled_leather"
		if depth >= 12: state["equipped_equipment"]["weapon"] = "duelist_rapier"
		if depth >= 16: state["equipped_equipment"]["boots"] = "trapdoor_spurs"
		if depth >= 20: state["equipped_equipment"]["trinket"] = "clockwork_arrowhead"
		state["collected_equipment"] = state["equipped_equipment"].values()
	if str(options.get("attuned_magic", "")).is_empty():
		state["attuned_magic_cards"] = ["chain_bolt", "stone_plate", "frostbolt", "cinderburst", "root_snare", "gust_step"]
		if skirmisher: state["attuned_magic_cards"] = ["chain_bolt", "stone_plate", "frostbolt", "cinderburst", "dawnstep", "gust_step"]
		if depth >= 12: state["attuned_magic_cards"][4] = "reprise"
		if depth >= 20: state["attuned_magic_cards"][0] = "storm_beacon"
	if str(options.get("relics", "")).is_empty():
		state["relics"] = ["iron_buckler"]
		if depth >= 8: state["relics"].append("duelist_whetstone" if skirmisher else "pilgrim_boots")
		if depth >= 16: state["relics"].append("reinforced_shield")
		for gate: int in range(4, depth, 4):
			state["relics"].append(Bosses.relic_for_boss(Bosses.boss_id_for_depth(int(state["seed"]), gate)))
	if depth > 4:
		state["skill_state"]["moltshard_awarded"] = true
		# The first-gate shard was retained, not spent on a reset or another run.
		state["progression"] = preload("res://scripts/progression_store.gd").add_moltshard_for_award(state["progression"], "%s:first_boss_moltshard" % preload("res://scripts/run_engine.gd").run_result_id(state))
	if str(options.get("equipped_items", "")).is_empty(): state["equipped_items"] = ["crimson_draught"]
	state["deck_cards"] = Data.compile_deck_cards(state["equipped_equipment"], state["attuned_magic_cards"], state["equipped_items"])
	state["magic_inventory"] = state["attuned_magic_cards"].duplicate()
	state["card_upgrades"] = {}
	# A player may have healed at the preceding campfire; 20/24 is the default
	# first-gate baseline. Explicit HP/gear options remain available for studies.
	if int(options.get("player_hp", -1)) < 0: state["player_hp"] = maxi(1, int(state["player_max_hp"]) - 4)
