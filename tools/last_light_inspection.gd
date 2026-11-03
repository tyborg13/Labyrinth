extends RefCounted
## Playtest-packet fixture for Last Light (spx-08), shaped like the Snare's and
## the Warband's: a natural combat node of the requested biome and tier becomes
## the Last Light room, entered through its production layout.
const Rooms = preload("res://scripts/room_generator.gd")
const Library = preload("res://scripts/special_encounter_library.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const Dragons = preload("res://scripts/dragon_boss_library.gd")
const FIXTURE_SEED: int = 83
const DEFAULT_BIOME: String = "shadow"
const DEFAULT_TIER: int = 2
const FIXTURE_TRAVEL: Vector2i = Vector2i.UP
static var CASES: Array[String] = _string_array(["pre_battle", "encounter"])

static func _string_array(values: Array) -> Array[String]:
	var result: Array[String]
	for value: String in values: result.append(value)
	return result

static func validate(options: Dictionary) -> String:
	if not Library.definition("last_light")["variants"].has(str(options.get("last_light_biome", DEFAULT_BIOME))): return "Unknown Last Light biome"
	if int(options.get("last_light_tier", DEFAULT_TIER)) not in [1, 2, 3]: return "Last Light tier must be 1, 2 or 3"
	if not CASES.has(str(options.get("last_light_case", "encounter"))): return "Unknown Last Light case"
	return ""

static func room_spec(biome: String, tier: int, coord: Vector2i = Vector2i.ZERO) -> Dictionary:
	return {"type": "special", "special_type": "last_light", "special_variant": biome, "element": biome, "depth": tier, "coord": coord,
		"section_map_layout_revision": Graph.LAYOUT_REVISION, "section_index": 0, "connections": [{"door_dir": Vector2i.UP, "coord": coord + Vector2i.UP, "kind": "outward"}],
		"revealed": true, "visited": true, "cleared": false, "sealed": false}

static func build(engine: RefCounted, combat: RefCounted, source: Dictionary, options: Dictionary) -> Dictionary:
	assert(validate(options).is_empty())
	var state: Dictionary = source.duplicate(true)
	var biome: String = str(options.get("last_light_biome", DEFAULT_BIOME))
	var tier: int = int(options.get("last_light_tier", DEFAULT_TIER))
	var room: Dictionary = {}
	for candidate: Dictionary in state["rooms"].values():
		if str(candidate.get("type", "")) not in ["combat", "special"] or posmod(int(candidate["depth"]) - 1, 4) + 1 != tier: continue
		var section: Dictionary = Graph.section(state, int(candidate["section_index"]))
		if Dragons.element_for_boss(str(section["boss_id"])) == biome:
			room = candidate.duplicate(true)
			break
	assert(not room.is_empty(), "No natural room for Last Light fixture biome/tier")
	var coord: Vector2i = room["coord"]
	room["type"] = "special"
	room["special_type"] = "last_light"
	room["special_variant"] = biome
	room["element"] = biome
	room["revealed"] = true
	room["visited"] = true
	room["cleared"] = false
	room["sealed"] = false
	state["rooms"][Graph.key(coord)] = room
	state["current_room"] = coord
	state["current_room_layout"] = Rooms.new().generate_room(int(state["seed"]), room, FIXTURE_TRAVEL)
	room["special_starting_reward_embers"] = Library.starting_embers(state["current_room_layout"])
	var study: String = str(options.get("last_light_case", "encounter"))
	state["last_light_inspection"] = {"biome": biome, "tier": tier, "case": study}
	state["notice"] = ""
	if study == "pre_battle":
		state["mode"] = "pre_battle"
		state["pre_battle_pending"] = true
		state["pre_battle_travel_dir"] = FIXTURE_TRAVEL
		state["combat_state"] = {}
		return state
	state["combat_state"] = combat.create_combat(int(state["seed"]), state["current_room_layout"], engine._player_snapshot(state))
	state["mode"] = "combat"
	return engine.repair_loaded_run_state(state)

# The native probe opens production pre-battle UI through the factory contract,
# as the Warband probe does.
static func prepared(engine: RefCounted, combat: RefCounted, state: Dictionary) -> Dictionary:
	var layout: Dictionary = state["current_room_layout"]
	return {"input": state.duplicate(true), "definitions": engine._pre_battle_definitions().duplicate(true), "layout": layout.duplicate(true),
		"combat_state": combat.create_combat(int(state["seed"]), layout, engine._player_snapshot(state)), "authored_tutorial": false}
