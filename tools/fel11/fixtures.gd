extends RefCounted
## Keep the state setup identical for baseline and branch. The room, combat
## creation, initiative, damage, movement, and travel use production code.

const SnareFixture = preload("res://tools/snare_inspection.gd")
const Objectives = preload("res://scripts/combat_objective_rules.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const Paths = preload("res://scripts/path_utils.gd")
const Rooms = preload("res://scripts/room_generator.gd")
const Run = preload("res://scripts/run_engine.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Store = preload("res://scripts/progression_store.gd")

const SNARE_SEED: int = SnareFixture.FIXTURE_SEED
const LEGACY_OBJECTIVE_REVISION: int = Objectives.STANDARD_KILL_ALL_REVISION - 1
const LEGACY_SEED_SEARCH_LIMIT: int = 128
const SNARE_EXIT_COUNT: int = 2
const PROOF_VISION: int = Combat.UMBRA_UNLIMITED_RADIUS

var engine := Run.new()
var combat := Combat.new()

func pre_battle() -> Dictionary:
	var state: Dictionary = SnareFixture.pre_battle(engine, combat, engine.create_new_run(SNARE_SEED, Store.default_data()))
	var room: Dictionary = Graph.room(state, state["current_room"])
	for link: Dictionary in room["connections"]:
		Graph.room(state, link["coord"])["revealed"] = true
	return state

func snare(source: Dictionary) -> Dictionary:
	var state: Dictionary = source.duplicate(true)
	var room: Dictionary = Graph.room(state, state["current_room"])
	room["connections"].resize(SNARE_EXIT_COUNT)
	state = engine.begin_pre_battle_combat(state)
	# Proof camera only. Hold full sight in both versions to show the same
	# boundaries even after pressure moves the hero.
	state["combat_state"]["umbra"]["vision_bonus"] = PROOF_VISION
	return state

func after_deadline(source: Dictionary, keep_open: bool) -> Dictionary:
	var battle: Dictionary = source["combat_state"].duplicate(true)
	var timed: Dictionary = battle["objective"]["exits"][1]
	if keep_open:
		var binder: int = battle["enemies"].find_custom(func(enemy: Dictionary) -> bool: return enemy["id"] == timed["sealbinder_id"])
		battle = combat._damage_enemy(battle, binder, int(battle["enemies"][binder]["hp"]), true, true, false, false)
	for turn: int in range(int(timed["seal_after_player_turns"])):
		battle = combat.advance_to_next_player_turn_with_steps(combat.finish_player_activation(battle))["state"]
	return engine.set_combat_state(source, battle)

func before_exit_step(source: Dictionary) -> Dictionary:
	var battle: Dictionary = source["combat_state"].duplicate(true)
	var selected: Dictionary = battle["objective"]["exits"][0]
	var path: Array[Vector2i] = Paths.find_path(battle["grid"], battle["player"]["pos"], selected["target_tile"])
	# Start one legal step from the threshold, leaving rules and costs active.
	battle["player"]["pos"] = path[path.size() - 2]
	for enemy: Dictionary in battle["enemies"]:
		if enemy["pos"] == battle["player"]["pos"]:
			enemy["pos"] = battle["snare_entry"]
	return engine.set_combat_state(source, battle)

func ordinary_states(source: Dictionary) -> Dictionary:
	var state: Dictionary = source.duplicate(true)
	var room: Dictionary = Graph.room(state, state["current_room"])
	room["type"] = "combat"
	room.erase("special_type")
	room.erase("special_variant")
	room["section_map_layout_revision"] = LEGACY_OBJECTIVE_REVISION
	room["encounter_biome"] = room["element"]
	var travel: Vector2i = state["pre_battle_travel_dir"]
	for seed: int in range(LEGACY_SEED_SEARCH_LIMIT):
		if Objectives.build_for_room(seed, room, travel)["type"] != Objectives.REACH_EXIT: continue
		state["seed"] = seed
		var layout: Dictionary = Rooms.new().generate_room(seed, room, travel)
		var ordinary_room: Dictionary = state.duplicate(true)
		Graph.room(ordinary_room, ordinary_room["current_room"])["cleared"] = true
		ordinary_room["current_room_layout"] = layout
		ordinary_room["mode"] = "room"
		state["current_room_layout"] = layout
		state["combat_state"] = combat.create_combat(seed, layout, engine._player_snapshot(state))
		state["mode"] = "combat"
		return {"fight": state, "room": ordinary_room}
	return {}
