extends RefCounted

const Rooms = preload("res://scripts/room_generator.gd")
const Library = preload("res://scripts/special_encounter_library.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const Dragons = preload("res://scripts/dragon_boss_library.gd")
const CombatRules = preload("res://scripts/warband_combat_rules.gd")
const Paths = preload("res://scripts/path_utils.gd")
const FIXTURE_SEED: int = 83
const DEFAULT_BIOME: String = "air"
const DEFAULT_TIER: int = 2
const CASES: Array[String] = ["encounter", "pre_battle", "keep_distance", "break"]

static func validate(options: Dictionary) -> String:
	if not Library.definition("warband")["variants"].has(str(options.get("warband_biome", DEFAULT_BIOME))): return "Unknown Warband biome"
	if int(options.get("warband_tier", DEFAULT_TIER)) not in [1, 2, 3]: return "Warband tier must be 1, 2 or 3"
	if not CASES.has(str(options.get("warband_case", "encounter"))): return "Unknown Warband case"
	return ""

static func room_spec(biome: String, tier: int, coord: Vector2i = Vector2i.ZERO) -> Dictionary:
	return {"type": "special", "special_type": "warband", "special_variant": biome, "element": biome, "depth": tier, "coord": coord,
		"section_map_layout_revision": 6, "section_index": 0, "connections": [{"door_dir": Vector2i.UP, "coord": coord + Vector2i.UP, "kind": "outward"}], "revealed": true, "visited": true, "cleared": false, "sealed": false}

static func build(engine: RefCounted, combat: RefCounted, source: Dictionary, options: Dictionary) -> Dictionary:
	assert(validate(options).is_empty())
	var state: Dictionary = source.duplicate(true)
	var biome: String = str(options.get("warband_biome", DEFAULT_BIOME))
	var tier: int = int(options.get("warband_tier", DEFAULT_TIER))
	var room: Dictionary = {}
	for candidate: Dictionary in state["rooms"].values():
		if str(candidate.get("type", "")) != "combat" or posmod(int(candidate["depth"]) - 1, 4) + 1 != tier: continue
		var section: Dictionary = Graph.section(state, int(candidate["section_index"]))
		if Dragons.element_for_boss(str(section["boss_id"])) == biome:
			room = candidate.duplicate(true)
			break
	assert(not room.is_empty(), "No natural room for Warband fixture biome/tier")
	var coord: Vector2i = room["coord"]
	room["type"] = "special"
	room["special_type"] = "warband"
	room["special_variant"] = biome
	room["element"] = biome
	room["section_map_layout_revision"] = 6
	room["revealed"] = true
	room["visited"] = true
	room["cleared"] = false
	room["sealed"] = false
	state["rooms"]["%d,%d" % [coord.x, coord.y]] = room
	state["current_room"] = coord
	state["current_room_layout"] = Rooms.new().generate_room(int(state["seed"]), room, Vector2i.UP)
	state["combat_state"] = combat.create_combat(int(state["seed"]), state["current_room_layout"], engine._player_snapshot(state))
	state["mode"] = "combat"
	state["notice"] = ""
	state["warband_inspection"] = {"biome": room["special_variant"], "tier": tier, "case": str(options.get("warband_case", "encounter"))}
	var study: String = str(options.get("warband_case", "encounter"))
	if study == "pre_battle":
		state["mode"] = "pre_battle"
		state["pre_battle_pending"] = true
		state["pre_battle_travel_dir"] = Vector2i.UP
		state["combat_state"] = {}
	elif study == "keep_distance": stage_keep_distance(state["combat_state"])
	elif study == "break":
		state["combat_state"]["enemies"][0]["hp"] = 1
		state["combat_state"]["enemies"][0]["stoneskin"] = 0
	return state

# Allows the native probe to inspect production pre-battle UI before spx-02
# supplies special-room entry. No map or production entry behavior is changed.
static func prepared(engine: RefCounted, combat: RefCounted, state: Dictionary) -> Dictionary:
	var layout: Dictionary = state["current_room_layout"]
	return {"input": state.duplicate(true), "definitions": engine._pre_battle_definitions().duplicate(true), "layout": layout.duplicate(true),
		"combat_state": combat.create_combat(int(state["seed"]), layout, engine._player_snapshot(state)), "authored_tutorial": false}

static func stage_keep_distance(battle: Dictionary) -> bool:
	var captain: Dictionary = battle["enemies"][0]
	var occupied: Dictionary = {}
	for enemy: Dictionary in battle["enemies"]: occupied[enemy["pos"]] = true
	var engine := preload("res://scripts/combat_engine.gd").new()
	var original: Vector2i = battle["player"]["pos"]
	for tile: Vector2i in Paths.reachable_tiles(battle["grid"], captain["pos"], 2, occupied):
		battle["player"]["pos"] = tile
		if bool(preload("res://scripts/game_data.gd").enemy_def(str(captain["type"])).get("immobile", false)) or not CombatRules.retreat_path(engine, battle, captain).is_empty(): return true
	battle["player"]["pos"] = original
	return false
