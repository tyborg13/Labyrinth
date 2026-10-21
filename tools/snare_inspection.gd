extends RefCounted
const Rooms = preload("res://scripts/room_generator.gd")
const Rules = preload("res://scripts/snare_room_rules.gd")
const Library = preload("res://scripts/special_encounter_library.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const Dragons = preload("res://scripts/dragon_boss_library.gd")
const FIXTURE_SEED: int = 83
const DEFAULT_BIOME: String = "fire"
const DEFAULT_TIER: int = 2
# Debug-only endurance for unattended boundary captures; never production tuning.
const FIXTURE_PLAYER_HP: int = 100
const CASES: Array = ["encounter", "first_turn", "first_seal", "kept_open", "escape"]

static func validate(options: Dictionary) -> String:
	if not Library.definition("umbral_snare")["variants"].has(str(options.get("snare_biome", DEFAULT_BIOME))): return "Unknown Snare biome"
	if int(options.get("snare_tier", DEFAULT_TIER)) not in [1, 2, 3]: return "Snare tier must be 1, 2 or 3"
	if not CASES.has(str(options.get("snare_case", "encounter"))): return "Unknown Snare case"
	return ""

static func room_spec(biome: String, tier: int) -> Dictionary:
	return {"type": "special", "special_type": "umbral_snare", "special_variant": biome, "element": biome, "depth": tier, "coord": Vector2i.ZERO,
		"section_map_layout_revision": 6, "connections": [
			{"door_dir": Vector2i.UP, "coord": Vector2i(1, 0), "kind": "outward"},
			{"door_dir": Vector2i.RIGHT, "coord": Vector2i(1, 1), "kind": "outward"},
			{"door_dir": Vector2i.DOWN, "coord": Vector2i(1, 2), "kind": "outward"}]}

static func build(engine: RefCounted, combat: RefCounted, source: Dictionary, options: Dictionary) -> Dictionary:
	assert(validate(options).is_empty())
	var state: Dictionary = source.duplicate(true)
	var biome: String = str(options.get("snare_biome", DEFAULT_BIOME))
	var tier: int = int(options.get("snare_tier", DEFAULT_TIER))
	var room: Dictionary = {}
	for candidate: Dictionary in state["rooms"].values():
		if str(candidate.get("type", "")) not in ["combat", "special"] or posmod(int(candidate["depth"]) - 1, 4) + 1 != tier: continue
		var section: Dictionary = Graph.section(state, int(candidate["section_index"]))
		if Dragons.element_for_boss(str(section["boss_id"])) != biome: continue
		if room.is_empty() or candidate["connections"].size() > room["connections"].size(): room = candidate.duplicate(true)
	assert(not room.is_empty(), "No natural branching room for Snare biome/tier")
	# Fixture-only branches: some biome/tier/seed rows have no branching combat
	# node. Use three real next-row destinations so every requested reproduction
	# has both chips, without changing the production map solver.
	var destinations: Array[Vector2i]
	for link: Dictionary in room["connections"]: destinations.append(link["coord"])
	for candidate: Dictionary in state["rooms"].values():
		if destinations.size() >= 3: break
		if int(candidate["section_index"]) == int(room["section_index"]) and int(candidate["map_step"]) == int(room["map_step"]) + 1 and not destinations.has(candidate["coord"]): destinations.append(candidate["coord"])
	destinations.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return float(Graph.room(state, a)["map_lane"]) < float(Graph.room(state, b)["map_lane"]))
	room["connections"] = []
	var directions: Array[Vector2i]
	directions.assign([Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN])
	for index: int in range(mini(3, destinations.size())):
		room["connections"].append({"coord": destinations[index], "door_dir": directions[index], "kind": "outward"})
	room["type"] = "special"
	room["special_type"] = "umbral_snare"
	room["special_variant"] = biome
	room["element"] = biome
	room["section_map_layout_revision"] = 6
	room["revealed"] = true
	room["visited"] = true
	room["cleared"] = false
	room["sealed"] = false
	var travel: Vector2i = Vector2i.RIGHT
	for direction: Vector2i in preload("res://scripts/path_utils.gd").DIRS_4:
		if not room["connections"].any(func(link: Dictionary) -> bool: return link["door_dir"] == -direction):
			travel = direction
			break
	state["rooms"][Graph.key(room["coord"])] = room
	state["current_room"] = room["coord"]
	state["current_room_layout"] = Rooms.new().generate_room(int(state["seed"]), room, travel)
	room["special_starting_reward_embers"] = state["current_room_layout"]["special_starting_reward_embers"]
	state["player_hp"] = FIXTURE_PLAYER_HP
	state["player_max_hp"] = FIXTURE_PLAYER_HP
	state["combat_state"] = combat.create_combat(int(state["seed"]), state["current_room_layout"], engine._player_snapshot(state))
	state["mode"] = "combat"
	state["notice"] = ""
	var study: String = str(options.get("snare_case", "encounter"))
	state["snare_inspection"] = {"biome": biome, "tier": tier, "case": study, "travel": travel}
	# Normalize the same rules-version metadata that a resumed production run
	# receives, before comparing pending-round save/resume snapshots.
	state = engine.repair_loaded_run_state(state)
	stage(combat, state, study)
	return state

static func stage(combat: RefCounted, state: Dictionary, study: String) -> void:
	var battle: Dictionary = state["combat_state"]
	if study == "kept_open":
		battle = combat._damage_enemy(battle, 1, Rules.SEALBINDER_HP, true, true, false, false)
	if study in ["first_seal", "kept_open"]:
		var seal_turn: int = int(battle["objective"]["exits"][1]["seal_after_player_turns"])
		for turn: int in range(seal_turn):
			battle = combat.advance_to_next_player_turn_with_steps(combat.finish_player_activation(battle))["state"]
			assert(combat.combat_outcome(battle) == "", "Fixture must survive to its seal boundary")
	elif study == "escape":
		# Debug-only setup: the final legal walking step still resolves normally.
		var exit: Dictionary = battle["objective"]["exits"][0]
		var path: Array[Vector2i] = preload("res://scripts/path_utils.gd").find_path(battle["grid"], battle["player"]["pos"], exit["target_tile"])
		battle["player"]["pos"] = path[path.size() - 2]
		for enemy: Dictionary in battle["enemies"]:
			if enemy["pos"] == battle["player"]["pos"]: enemy["pos"] = state["current_room_layout"]["player_start"]
		battle = combat.apply_player_movement(battle, exit["target_tile"])
	state["combat_state"] = battle
