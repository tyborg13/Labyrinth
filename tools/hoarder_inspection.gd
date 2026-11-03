extends RefCounted
## Inspection fixture for the Ember Hoarder (spx-09):
## --scenario ember_hoarder --hoarder-biome <section> --hoarder-tier <1-3>
## --hoarder-case pre_battle|encounter
const Rooms = preload("res://scripts/room_generator.gd")
const Library = preload("res://scripts/special_encounter_library.gd")
const Rules = preload("res://scripts/hoarder_room_rules.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const Dragons = preload("res://scripts/dragon_boss_library.gd")
const FIXTURE_SEED: int = 83
const DEFAULT_BIOME: String = "fire"
const DEFAULT_TIER: int = 2
const FIXTURE_TRAVEL: Vector2i = Vector2i.UP
static var CASES: Array[String] = _string_array(["encounter", "pre_battle"])

static func _string_array(values: Array) -> Array[String]:
	var result: Array[String]
	for value: String in values: result.append(value)
	return result

static func biomes() -> Array[String]:
	var result: Array[String]
	for biome: String in Dragons.BOSS_ELEMENTS.values(): result.append(biome)
	return result

static func validate(options: Dictionary) -> String:
	if not biomes().has(str(options.get("hoarder_biome", DEFAULT_BIOME))): return "Unknown Ember Hoarder biome"
	if int(options.get("hoarder_tier", DEFAULT_TIER)) not in [1, 2, 3]: return "Ember Hoarder tier must be 1, 2 or 3"
	if not CASES.has(str(options.get("hoarder_case", "encounter"))): return "Unknown Ember Hoarder case"
	return ""

static func room_spec(biome: String, tier: int, coord: Vector2i = Vector2i.ZERO) -> Dictionary:
	return {"type": "special", "special_type": Rules.TYPE, "special_variant": biome, "element": biome, "depth": tier, "coord": coord,
		"section_map_layout_revision": 7, "section_index": 0, "connections": [{"door_dir": Vector2i.UP, "coord": coord + Vector2i.UP, "kind": "outward"}],
		"revealed": true, "visited": true, "cleared": false, "sealed": false}

# Uses the run's own Hoarder node at that section and tier when the seeded map
# placed one there; otherwise converts that section's first standard combat.
static func build(engine: RefCounted, combat: RefCounted, source: Dictionary, options: Dictionary) -> Dictionary:
	assert(validate(options).is_empty())
	var state: Dictionary = source.duplicate(true)
	var biome: String = str(options.get("hoarder_biome", DEFAULT_BIOME))
	var tier: int = int(options.get("hoarder_tier", DEFAULT_TIER))
	var room: Dictionary = {}
	for wanted: String in ["special", "combat"]:
		for candidate: Dictionary in state["rooms"].values():
			if str(candidate.get("type", "")) != wanted or posmod(int(candidate["depth"]) - 1, 4) + 1 != tier: continue
			if wanted == "special" and str(candidate.get("special_type", "")) != Rules.TYPE: continue
			if Dragons.element_for_boss(str(Graph.section(state, int(candidate["section_index"]))["boss_id"])) != biome: continue
			room = candidate.duplicate(true)
			break
		if not room.is_empty(): break
	assert(not room.is_empty(), "No natural room for the Ember Hoarder fixture biome/tier")
	var coord: Vector2i = room["coord"]
	room["type"] = "special"
	room["special_type"] = Rules.TYPE
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
	state["combat_state"] = combat.create_combat(int(state["seed"]), state["current_room_layout"], engine._player_snapshot(state))
	state["mode"] = "combat"
	state["notice"] = ""
	var study: String = str(options.get("hoarder_case", "encounter"))
	state["hoarder_inspection"] = {"biome": biome, "tier": tier, "case": study}
	if study == "pre_battle":
		state["mode"] = "pre_battle"
		state["pre_battle_pending"] = true
		state["pre_battle_travel_dir"] = FIXTURE_TRAVEL
		state["combat_state"] = {}
	return state

# The production pre-battle factory input, for probes that capture that screen.
static func prepared(engine: RefCounted, combat: RefCounted, state: Dictionary) -> Dictionary:
	var layout: Dictionary = state["current_room_layout"]
	return {"input": state.duplicate(true), "definitions": engine._pre_battle_definitions().duplicate(true), "layout": layout.duplicate(true),
		"combat_state": combat.create_combat(int(state["seed"]), layout, engine._player_snapshot(state)), "authored_tutorial": false}
