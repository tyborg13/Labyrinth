extends SceneTree
## Offline measurements only. Never changes the generation inputs or runtime rules.
const Graph = preload("res://scripts/section_map_graph.gd")
const Bosses = preload("res://scripts/dragon_boss_library.gd")
const Rooms = preload("res://scripts/room_generator.gd")
const Run = preload("res://scripts/run_engine.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Game = preload("res://scripts/game_data.gd")
const Paths = preload("res://scripts/path_utils.gd")
const Store = preload("res://scripts/analytics_store.gd")
const BIOMES: PackedStringArray = ["fire", "earth", "ice", "air", "lightning", "shadow"]
const DEFAULT_FIRST_SEED: int = 1
const DEFAULT_SEEDS: int = 2000
const FREE_TILES_PER_TURN: int = 2
const GOLDEN_SEEDS: PackedInt32Array = [1, 19, 421]

static func option(args: PackedStringArray, name: String, fallback: String) -> String:
	var index: int = args.find(name)
	return args[index + 1] if index >= 0 and index + 1 < args.size() else fallback

static func map_for_seed(seed_value: int) -> Dictionary:
	var state: Dictionary = {"seed": seed_value, "current_room": Vector2i.ZERO, "mode": "room"}
	Graph.initialize(state)
	return state

static func samples(state: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary]
	for section: Dictionary in state["map_sections"]:
		var biome: String = Bosses.element_for_boss(str(section["boss_id"]))
		for tier: int in range(1, 4):
			var candidates: Array[Dictionary]
			for room: Dictionary in state["rooms"].values():
				if room["type"] == "combat" and int(room["section_index"]) == int(section["index"]) and posmod(int(room["depth"]) - 1, 4) + 1 == tier:
					candidates.append(room)
			if candidates.is_empty(): continue
			var room: Dictionary = candidates[posmod(int(state["seed"]), candidates.size())]
			# Use the first actual incoming map edge, including its physical door.
			var travel: Vector2i = Vector2i.ZERO
			for parent: Dictionary in state["rooms"].values():
				for edge: Dictionary in parent.get("connections", []):
					if edge.get("coord") == room["coord"] and int(parent.get("map_step", -1)) < int(room["map_step"]) and parent["section_index"] == room["section_index"]:
						travel = edge["door_dir"]
						break
				if travel != Vector2i.ZERO: break
			assert(travel != Vector2i.ZERO, "Sample must have a real incoming map edge")
			result.append({"seed": int(state["seed"]), "tier": tier, "biome": biome, "section_index": int(section["index"]), "room": room.duplicate(true), "travel_dir": travel})
	return result

static func layout(sample: Dictionary, map_state: Dictionary = {}) -> Dictionary:
	# RunEngine owns encounter biome/history, equipment drops and objective setup.
	# Mark an earlier combat completed so this is not the guided first fight.
	var state: Dictionary = (map_state if not map_state.is_empty() else map_for_seed(int(sample["seed"]))).duplicate(true)
	state["current_room"] = sample["room"]["coord"]
	state["encounter_history"] = []
	# _run_has_completed_combat uses the persisted cleared-room metadata.
	for room: Dictionary in state["rooms"].values():
		if room["type"] == "combat" and room["coord"] != sample["room"]["coord"]:
			room["cleared"] = true
			break
	return Run.new()._combat_layout_for_room(sample["room"], sample["travel_dir"], state)

static func unblocked_distance(grid: Array, start: Vector2i, goals: Array) -> int:
	var nearest: int = -1
	for goal: Vector2i in goals:
		var path: Array[Vector2i] = Paths.find_path(grid, start, goal)
		if not path.is_empty() and (nearest < 0 or path.size() - 1 < nearest): nearest = path.size() - 1
	return nearest

static func composition(sample: Dictionary, room: Dictionary) -> Dictionary:
	var objective: Dictionary = room["objective"]
	var result: Dictionary = {"seed": sample["seed"], "tier": sample["tier"], "biome": sample["biome"], "section_index": sample["section_index"], "coord": sample["room"]["coord"], "travel_dir": sample["travel_dir"], "objective": objective["type"], "encounter_id": room.get("encounter_id", ""), "unit_count": room["enemies"].size(), "base_hp": 0, "spawn_hp": 0, "roles": {}, "leader_type": "", "leader_distance": null, "leader_closest": null, "exit_path_length": null, "exit_free_turns": null}
	var closest: int = 1000000
	for enemy: Dictionary in room["enemies"]:
		var definition: Dictionary = Game.enemy_def(enemy["type"])
		result["base_hp"] += int(definition.get("max_hp", 0))
		result["spawn_hp"] += int(enemy["max_hp"])
		var role: String = str((definition.get("ai_profile", {}) as Dictionary).get("role", "unspecified"))
		result["roles"][role] = int(result["roles"].get(role, 0)) + 1
		var distance: int = Paths.manhattan(room["player_start"], enemy["pos"])
		closest = mini(closest, distance)
		if int(enemy["id"]) == int(objective.get("leader_id", -1)):
			result["leader_type"] = enemy["type"]
			result["leader_distance"] = distance
	if result["leader_distance"] != null: result["leader_closest"] = result["leader_distance"] == closest
	if objective["type"] == "reach_exit":
		var goals: Array = preload("res://scripts/combat_objective_rules.gd").exit_target_tiles(objective)
		var distance: int = unblocked_distance(room["grid"], room["player_start"], goals)
		result["exit_path_length"] = distance
		result["exit_free_turns"] = ceili(float(distance) / FREE_TILES_PER_TURN) if distance >= 0 else null
	return result

static func golden() -> Dictionary:
	var result: Dictionary = {}
	for seed_value: int in GOLDEN_SEEDS:
		var state: Dictionary = map_for_seed(seed_value)
		var rooms: Array = []
		var combat: Array = []
		for sample: Dictionary in samples(state):
			var generated: Dictionary = layout(sample, state)
			rooms.append(generated)
			var engine := Combat.new()
			var initial: Dictionary = engine.create_combat(seed_value, generated, {"hp": 24, "max_hp": 24, "deck_cards": Game.starting_deck(), "equipped_equipment": Game.starting_equipped_equipment()})
			combat.append(initial)
			combat.append(engine.advance_to_next_player_turn_with_steps(engine.finish_player_activation(initial))["state"])
		result[str(seed_value)] = {"map": digest(state), "rooms": digest(rooms), "combat": digest(combat), "save_roundtrip": digest(bytes_to_var(var_to_bytes([state, rooms, combat])))}
	return result

static func digest(value: Variant) -> String:
	return JSON.stringify(Store._sanitize_variant(value)).sha256_text()

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var output: String = option(args, "--output", "user://encounter_sweep.jsonl")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	var file := FileAccess.open(output, FileAccess.WRITE)
	assert(file != null, "Cannot open sweep output")
	if args.has("--golden"):
		file.store_string(JSON.stringify(golden(), "\t"))
		print("ENCOUNTER GOLDEN: recorded " + output)
		quit()
		return
	var count: int = int(option(args, "--seeds", str(DEFAULT_SEEDS)))
	var first: int = int(option(args, "--first-seed", str(DEFAULT_FIRST_SEED)))
	assert(count > 0 and first >= 0)
	var counts: Dictionary = {}
	var generated: int = 0
	var seed_value: int = first
	while counts.size() < 18 or counts.values().min() < count:
		var state: Dictionary = map_for_seed(seed_value)
		for sample: Dictionary in samples(state):
			var key: String = "%s/%s" % [sample["biome"], sample["tier"]]
			if int(counts.get(key, 0)) >= count: continue
			var room: Dictionary = layout(sample, state)
			file.store_line(JSON.stringify(Store._sanitize_variant(composition(sample, room))))
			counts[key] = int(counts.get(key, 0)) + 1
			generated += 1
		seed_value += 1
		if seed_value % 100 == 0: print("ENCOUNTER SWEEP: seed %d, %d rooms" % [seed_value, generated])
	file.close()
	print("ENCOUNTER SWEEP: PASS (%d rooms; %d seeds per tier/biome; seeds %d..%d)" % [generated, count, first, seed_value - 1])
	quit()
