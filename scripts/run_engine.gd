extends RefCounted
class_name RunEngine

const CombatEngineScript = preload("res://scripts/combat_engine.gd")
const RoomGeneratorScript = preload("res://scripts/room_generator.gd")
const ElementData = preload("res://scripts/element_data.gd")
const GameData = preload("res://scripts/game_data.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")

const MAX_DEPTH: int = 4
const BASE_MAX_HP: int = 36
const BASE_HAND_SIZE: int = 5
const BASE_CARDS_PER_TURN: int = 2
const BASE_DRAW_PER_TURN: int = 2
const REWARD_HEAL: int = 6
const BOSS_VICTORY_EMBERS: int = 30
const DEBUG_BOSS_SEED: int = 90429
const DEBUG_BOSS_COORD: Vector2i = Vector2i(4, 0)

var _combat_engine = CombatEngineScript.new()
var _room_generator = RoomGeneratorScript.new()

func create_new_run(seed: int, progression: Dictionary) -> Dictionary:
	var max_hp: int = BASE_MAX_HP + GameData.stat_bonus_from_upgrades(progression, "max_hp")
	var hand_size: int = BASE_HAND_SIZE + GameData.stat_bonus_from_upgrades(progression, "hand_size")
	var heal_bonus: int = GameData.stat_bonus_from_upgrades(progression, "heal_bonus")
	var rooms: Dictionary = {}
	var start_room: Dictionary = _build_room_metadata(seed, Vector2i.ZERO)
	start_room["revealed"] = true
	start_room["visited"] = true
	start_room["cleared"] = true
	rooms[_room_key(Vector2i.ZERO)] = start_room
	var start_layout: Dictionary = _display_layout_for_room(seed, start_room, Vector2i.ZERO)
	var run_state: Dictionary = {
		"seed": seed,
		"run_index": int(progression.get("run_counter", 0)),
		"mode": "room",
		"current_room": Vector2i.ZERO,
		"current_room_layout": start_layout,
		"rooms": rooms,
		"deck_cards": GameData.starting_deck(),
		"relics": [],
		"player_hp": max_hp,
		"player_max_hp": max_hp,
		"hand_size": hand_size,
		"heal_bonus": heal_bonus,
		"unbanked_embers": 0,
		"combat_state": {},
		"pending_reward": {},
		"pending_relics": [],
		"game_over": false,
		"victory": false,
		"turns_spent": 0,
		"notice": "",
		"progression": progression.duplicate(true)
	}
	_reveal_neighbors(run_state, Vector2i.ZERO)
	_try_recover_lost_embers(run_state)
	return run_state

func create_debug_boss_run(progression: Dictionary) -> Dictionary:
	var max_hp: int = 42
	var current_hp: int = 34
	var deck_cards: Array[String] = []
	for card_id: String in [
		"quick_stab",
		"guarded_step",
		"shadow_step",
		"bone_dart",
		"sidestep_slash",
		"whirlwind_slash",
		"patch_up",
		"bloody_lunge",
		"brace",
		"lantern_shot",
		"iron_wheel",
		"ricochet_knife",
		"warded_advance",
		"cinderburst",
		"chain_bolt",
		"static_lash",
		"volt_surge",
		"frostbolt"
	]:
		deck_cards.append(card_id)
	var relics: Array[String] = []
	for relic_id: String in ["iron_lung", "ember_lens", "pilgrim_boots"]:
		relics.append(relic_id)
	var boss_room: Dictionary = _build_room_metadata(DEBUG_BOSS_SEED, DEBUG_BOSS_COORD)
	boss_room["revealed"] = true
	boss_room["visited"] = true
	boss_room["cleared"] = false
	boss_room["sealed"] = false
	var layout: Dictionary = _combat_layout_for_room(boss_room, Vector2i(1, 0), {"seed": DEBUG_BOSS_SEED})
	var player_snapshot: Dictionary = {
		"hp": current_hp,
		"max_hp": max_hp,
		"deck_cards": deck_cards,
		"relics": relics,
		"hand_size": BASE_HAND_SIZE,
		"cards_per_turn": BASE_CARDS_PER_TURN,
		"draw_per_turn": BASE_DRAW_PER_TURN,
		"heal_bonus": 2,
		"card_upgrades": {},
		"card_mods": {}
	}
	var combat_state: Dictionary = _combat_engine.create_combat(DEBUG_BOSS_SEED, layout, player_snapshot)
	var rooms: Dictionary = {}
	rooms[_room_key(DEBUG_BOSS_COORD)] = boss_room
	return {
		"seed": DEBUG_BOSS_SEED,
		"run_index": -1,
		"mode": "combat",
		"current_room": DEBUG_BOSS_COORD,
		"current_room_layout": layout,
		"rooms": rooms,
		"deck_cards": deck_cards,
		"relics": relics,
		"player_hp": current_hp,
		"player_max_hp": max_hp,
		"hand_size": BASE_HAND_SIZE,
		"cards_per_turn": BASE_CARDS_PER_TURN,
		"draw_per_turn": BASE_DRAW_PER_TURN,
		"heal_bonus": 2,
		"unbanked_embers": 44,
		"combat_state": combat_state,
		"pending_reward": {},
		"pending_relics": [],
		"game_over": false,
		"victory": false,
		"turns_spent": 11,
		"notice": "Debug boss fixture",
		"progression": progression.duplicate(true),
		"debug_boss_run": true
	}

func repair_loaded_run_state(run_state: Dictionary) -> Dictionary:
	var next_state: Dictionary = run_state.duplicate(true)
	if next_state.is_empty():
		return next_state
	_reveal_neighbors(next_state, next_state.get("current_room", Vector2i.ZERO))
	return next_state

func available_moves(run_state: Dictionary) -> Array[Vector2i]:
	var current: Vector2i = run_state.get("current_room", Vector2i.ZERO)
	var current_room: Dictionary = room_metadata(run_state, current)
	var current_depth: int = int(current_room.get("depth", 0))
	var neighbors: Array[Vector2i] = []
	var seen: Dictionary = {}
	for connection_var: Variant in current_room.get("connections", []):
		if typeof(connection_var) != TYPE_DICTIONARY:
			continue
		var connection: Dictionary = connection_var
		var candidate: Vector2i = connection.get("coord", Vector2i(999, 999))
		if seen.has(candidate):
			continue
		var candidate_room: Dictionary = room_metadata(run_state, candidate)
		if not bool(candidate_room.get("revealed", false)):
			continue
		if int(candidate_room.get("depth", 0)) < current_depth:
			continue
		if bool(candidate_room.get("sealed", false)):
			continue
		seen[candidate] = true
		neighbors.append(candidate)
	return neighbors

func room_metadata(run_state: Dictionary, coord: Vector2i) -> Dictionary:
	var rooms: Dictionary = run_state.get("rooms", {})
	var key: String = _room_key(coord)
	if rooms.has(key):
		return _merge_room_metadata(int(run_state.get("seed", 0)), coord, rooms[key] as Dictionary)
	return _build_room_metadata(int(run_state.get("seed", 0)), coord)

func move_to_room(run_state: Dictionary, destination: Vector2i) -> Dictionary:
	var current: Vector2i = run_state.get("current_room", Vector2i.ZERO)
	if destination == current:
		return run_state.duplicate(true)
	if not available_moves(run_state).has(destination):
		return run_state.duplicate(true)
	var connection: Dictionary = _connection_to(current, destination)
	if connection.is_empty():
		return run_state.duplicate(true)
	var next_state: Dictionary = run_state.duplicate(true)
	var rooms: Dictionary = next_state.get("rooms", {}).duplicate(true)
	var destination_key: String = _room_key(destination)
	var current_key: String = _room_key(current)
	var current_room: Dictionary = _merge_room_metadata(int(next_state.get("seed", 0)), current, rooms.get(current_key, {}) as Dictionary)
	current_room["sealed"] = true
	rooms[current_key] = current_room
	var room: Dictionary = _merge_room_metadata(int(next_state.get("seed", 0)), destination, rooms.get(destination_key, {}) as Dictionary)
	room["revealed"] = true
	room["visited"] = true
	room["sealed"] = false
	rooms[destination_key] = room
	next_state["current_room"] = destination
	next_state["turns_spent"] = int(next_state.get("turns_spent", 0)) + 1
	next_state["notice"] = ""
	next_state["rooms"] = rooms
	_reveal_neighbors(next_state, destination)
	rooms = next_state.get("rooms", {}).duplicate(true)
	room = _merge_room_metadata(int(next_state.get("seed", 0)), destination, rooms.get(destination_key, {}) as Dictionary)
	var travel_dir: Vector2i = connection.get("door_dir", Vector2i.ZERO)
	next_state["current_room_layout"] = _display_layout_for_room(int(next_state.get("seed", 0)), room, travel_dir)
	_try_recover_lost_embers(next_state)
	match str(room.get("type", "combat")):
		"start":
			next_state["mode"] = "room"
			next_state["combat_state"] = {}
		"campfire":
			room["cleared"] = true
			rooms[destination_key] = room
			next_state["rooms"] = rooms
			next_state["mode"] = "campfire"
			next_state["combat_state"] = {}
		"treasure":
			if bool(room.get("cleared", false)):
				next_state["pending_relics"] = []
				next_state["mode"] = "room"
			else:
				room["cleared"] = true
				rooms[destination_key] = room
				next_state["rooms"] = rooms
				var relic_choices: Array[String] = _generate_relic_choices(next_state, destination)
				next_state["pending_relics"] = relic_choices
				next_state["mode"] = "treasure" if not relic_choices.is_empty() else "room"
			next_state["combat_state"] = {}
		_:
			if _room_has_npcs(room):
				room["cleared"] = true
				rooms[destination_key] = room
				next_state["rooms"] = rooms
				next_state["mode"] = "room"
				next_state["combat_state"] = {}
				return next_state
			if bool(room.get("cleared", false)):
				next_state["mode"] = "room"
				next_state["combat_state"] = {}
				return next_state
			var layout: Dictionary = _combat_layout_for_room(room, travel_dir, next_state)
			var combat_state: Dictionary = _combat_engine.create_combat(int(next_state.get("seed", 0)), layout, _player_snapshot(next_state))
			next_state["combat_state"] = combat_state
			next_state["mode"] = "combat"
	return next_state

func set_combat_state(run_state: Dictionary, combat_state: Dictionary) -> Dictionary:
	var next_state: Dictionary = run_state.duplicate(true)
	next_state["combat_state"] = combat_state.duplicate(true)
	next_state["player_hp"] = int((combat_state.get("player", {}) as Dictionary).get("hp", next_state.get("player_hp", 1)))
	return next_state

func finish_combat(run_state: Dictionary, combat_state: Dictionary) -> Dictionary:
	var next_state: Dictionary = set_combat_state(run_state, combat_state)
	next_state["current_room_layout"] = _room_layout_from_combat_state(combat_state)
	next_state["combat_state"] = {}
	next_state["player_hp"] = int((combat_state.get("player", {}) as Dictionary).get("hp", next_state.get("player_hp", 1)))
	var outcome: String = _combat_engine.combat_outcome(combat_state)
	if outcome == "defeat":
		next_state["mode"] = "defeat"
		next_state["game_over"] = true
		return next_state
	if outcome != "victory":
		next_state["mode"] = "combat"
		next_state["combat_state"] = combat_state.duplicate(true)
		return next_state
	var rooms: Dictionary = next_state.get("rooms", {}).duplicate(true)
	var current_room: Vector2i = next_state.get("current_room", Vector2i.ZERO)
	var room_key: String = _room_key(current_room)
	var room: Dictionary = (rooms.get(room_key, {}) as Dictionary).duplicate(true)
	room["cleared"] = true
	rooms[room_key] = room
	next_state["rooms"] = rooms
	var ember_bonus: int = GameData.stat_bonus_from_relics(next_state.get("relics", []), "combat_ember_bonus")
	var total_embers: int = int(combat_state.get("room_embers", 0)) + ember_bonus
	next_state["unbanked_embers"] = int(next_state.get("unbanked_embers", 0)) + total_embers
	if str(room.get("type", "")) == "boss":
		next_state["player_hp"] = int(next_state.get("player_max_hp", next_state.get("player_hp", 1)))
		next_state["victory"] = true
		next_state["mode"] = "victory"
		next_state["unbanked_embers"] = int(next_state.get("unbanked_embers", 0)) + BOSS_VICTORY_EMBERS
		return next_state
	next_state["pending_reward"] = {
		"cards": _generate_card_rewards(next_state, current_room),
		"heal_amount": REWARD_HEAL + int(next_state.get("heal_bonus", 0)),
		"ember_amount": total_embers
	}
	next_state["mode"] = "reward"
	return next_state

func claim_card_reward(run_state: Dictionary, card_id: String) -> Dictionary:
	var next_state: Dictionary = run_state.duplicate(true)
	if not card_id.is_empty():
		var deck_cards: Array = next_state.get("deck_cards", []).duplicate()
		deck_cards.append(card_id)
		next_state["deck_cards"] = deck_cards
	next_state["pending_reward"] = {}
	next_state["mode"] = "room"
	return next_state

func skip_reward_for_heal(run_state: Dictionary) -> Dictionary:
	var next_state: Dictionary = run_state.duplicate(true)
	var heal_amount: int = int((next_state.get("pending_reward", {}) as Dictionary).get("heal_amount", 0))
	next_state["player_hp"] = mini(int(next_state.get("player_max_hp", 1)), int(next_state.get("player_hp", 0)) + heal_amount)
	next_state["pending_reward"] = {}
	next_state["mode"] = "room"
	return next_state

func claim_relic(run_state: Dictionary, relic_id: String) -> Dictionary:
	var next_state: Dictionary = run_state.duplicate(true)
	if relic_id.is_empty():
		next_state["pending_relics"] = []
		next_state["mode"] = "room"
		return next_state
	var relics: Array = next_state.get("relics", []).duplicate()
	if not relics.has(relic_id):
		relics.append(relic_id)
	next_state["relics"] = relics
	var relic: Dictionary = GameData.relic_def(relic_id)
	if str(relic.get("effect", "")) == "max_hp":
		var bonus: int = int(relic.get("value", 0))
		next_state["player_max_hp"] = int(next_state.get("player_max_hp", 1)) + bonus
		next_state["player_hp"] = int(next_state.get("player_hp", 1)) + bonus
	next_state["pending_relics"] = []
	next_state["mode"] = "room"
	return next_state

func leave_campfire(run_state: Dictionary) -> Dictionary:
	var next_state: Dictionary = run_state.duplicate(true)
	next_state["mode"] = "room"
	return next_state

func bankable_embers(run_state: Dictionary) -> int:
	return int(run_state.get("unbanked_embers", 0))

func consume_banked_embers(run_state: Dictionary) -> Dictionary:
	var next_state: Dictionary = run_state.duplicate(true)
	next_state["unbanked_embers"] = 0
	return next_state

func room_neighbors_with_metadata(run_state: Dictionary) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for coord: Vector2i in available_moves(run_state):
		results.append(room_metadata(run_state, coord))
	return results

func exit_options(run_state: Dictionary) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var current_room: Dictionary = room_metadata(run_state, run_state.get("current_room", Vector2i.ZERO))
	var available_lookup: Dictionary = {}
	for coord: Vector2i in available_moves(run_state):
		available_lookup[coord] = true
	for connection_var: Variant in current_room.get("connections", []):
		if typeof(connection_var) != TYPE_DICTIONARY:
			continue
		var connection: Dictionary = connection_var
		var destination: Vector2i = connection.get("coord", Vector2i(999, 999))
		if not available_lookup.has(destination):
			continue
		var door_dir: Vector2i = connection.get("door_dir", Vector2i.ZERO)
		var room: Dictionary = room_metadata(run_state, destination)
		results.append({
			"dir": door_dir,
			"door_dir": door_dir,
			"coord": destination,
			"door_tile": RoomGeneratorScript.door_tile_for_direction(door_dir),
			"room": room
		})
	return results

func _player_snapshot(run_state: Dictionary) -> Dictionary:
	return {
		"hp": int(run_state.get("player_hp", 1)),
		"max_hp": int(run_state.get("player_max_hp", 1)),
		"deck_cards": run_state.get("deck_cards", []).duplicate(),
		"card_upgrades": ((run_state.get("progression", {}) as Dictionary).get("card_upgrades", {}) as Dictionary).duplicate(true),
		"card_mods": ((run_state.get("progression", {}) as Dictionary).get("card_mods", {}) as Dictionary).duplicate(true),
		"relics": run_state.get("relics", []).duplicate(),
		"hand_size": int(run_state.get("hand_size", BASE_HAND_SIZE)),
		"heal_bonus": int(run_state.get("heal_bonus", 0)),
		"cards_per_turn": BASE_CARDS_PER_TURN,
		"draw_per_turn": BASE_DRAW_PER_TURN
	}

func _build_room_metadata(seed: int, coord: Vector2i) -> Dictionary:
	var depth: int = _room_depth(coord)
	var room_type: String = _room_type_for_coord(seed, coord)
	var element_id: String = _room_element_for_coord(seed, coord, room_type)
	var npcs: Array[Dictionary] = _room_npcs_for_coord(seed, coord)
	return {
		"coord": coord,
		"depth": depth,
		"type": room_type,
		"element": element_id,
		"connections": _room_connections(coord),
		"npcs": npcs,
		"revealed": depth <= 1,
		"visited": false,
		"cleared": room_type == "start",
		"sealed": false
	}

func _display_layout_for_room(seed: int, room: Dictionary, travel_dir: Vector2i) -> Dictionary:
	var layout: Dictionary = _room_generator.generate_room(seed, room, travel_dir)
	if layout.is_empty():
		return {}
	layout["enemies"] = []
	if _room_has_npcs(room) or (str(room.get("type", "")) != "combat" and str(room.get("type", "")) != "boss"):
		layout["loot"] = []
	return layout

func _combat_layout_for_room(room: Dictionary, travel_dir: Vector2i, run_state: Dictionary) -> Dictionary:
	return _room_generator.generate_room(int(run_state.get("seed", 0)), room, travel_dir)

func _room_layout_from_combat_state(combat_state: Dictionary) -> Dictionary:
	return {
		"name": combat_state.get("room_name", "Room"),
		"coord": combat_state.get("room_coord", Vector2i.ZERO),
		"type": combat_state.get("room_type", "combat"),
		"element": combat_state.get("room_element", ElementData.NONE),
		"grid": combat_state.get("grid", []).duplicate(true),
		"moss": combat_state.get("moss", {}).duplicate(true),
		"player_start": (combat_state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO),
		"npcs": [],
		"enemies": [],
		"traps": combat_state.get("traps", []).duplicate(true),
		"loot": combat_state.get("loot", []).duplicate(true)
	}

func _room_type_for_coord(seed: int, coord: Vector2i) -> String:
	var depth: int = _room_depth(coord)
	if depth == 0:
		return "start"
	if depth >= MAX_DEPTH:
		return "boss"
	if depth == 2 and (coord.x == 0 or coord.y == 0):
		return "campfire"
	var roll: int = _coord_hash(seed, coord, 77) % 100
	if roll < 18:
		return "treasure"
	return "combat"

func _room_element_for_coord(seed: int, coord: Vector2i, room_type: String) -> String:
	if room_type == "boss":
		return ElementData.LIGHTNING
	if room_type != "combat":
		return ElementData.NONE
	var roll: int = _coord_hash(seed, coord, 151) % ElementData.all_elements().size()
	return ElementData.all_elements()[roll]

func _room_depth(coord: Vector2i) -> int:
	return maxi(absi(coord.x), absi(coord.y))

func _generate_card_rewards(run_state: Dictionary, coord: Vector2i) -> Array[String]:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = _coord_hash(int(run_state.get("seed", 0)), coord, 991)
	var choices: Array[String] = []
	var room: Dictionary = room_metadata(run_state, coord)
	var room_element: String = str(room.get("element", ElementData.NONE))
	if ElementData.is_elemental(room_element):
		choices.append_array(_draw_reward_cards_for_element(rng, room_element, 2, choices))
	choices.append_array(_draw_reward_cards_for_element(rng, ElementData.NONE, 1, choices))
	if choices.size() < 3:
		choices.append_array(_draw_reward_cards_for_element(rng, "", 3 - choices.size(), choices))
	return choices

func _draw_reward_cards_for_element(rng: RandomNumberGenerator, element_filter: String, count: int, existing_choices: Array[String]) -> Array[String]:
	var pool_by_rarity: Dictionary = GameData.reward_card_pool_by_rarity(element_filter)
	var choices: Array[String] = []
	var attempts: int = 0
	while choices.size() < count and attempts < 72:
		attempts += 1
		var rarity_roll: int = rng.randi_range(1, 100)
		var rarity: String = "common"
		if rarity_roll > 86:
			rarity = "rare"
		elif rarity_roll > 56:
			rarity = "uncommon"
		var pool: Array = (pool_by_rarity.get(rarity, []) as Array).duplicate()
		if pool.is_empty():
			continue
		var weighted_pool: Array[String] = []
		for card_id_var: Variant in pool:
			var card_id: String = str(card_id_var)
			if existing_choices.has(card_id) or choices.has(card_id):
				continue
			for _weight_index: int in range(GameData.reward_offer_weight(card_id)):
				weighted_pool.append(card_id)
		if weighted_pool.is_empty():
			continue
		choices.append(str(weighted_pool[rng.randi_range(0, weighted_pool.size() - 1)]))
	return choices

func _generate_relic_choices(run_state: Dictionary, coord: Vector2i) -> Array[String]:
	var owned: Array = run_state.get("relics", []).duplicate()
	var available: Array[String] = []
	for relic_id: String in GameData.relic_ids():
		if not owned.has(relic_id):
			available.append(relic_id)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = _coord_hash(int(run_state.get("seed", 0)), coord, 543)
	var shuffled: Array[String] = GameData.shuffle_cards(available, rng)
	return shuffled.slice(0, mini(3, shuffled.size()))

func _reveal_neighbors(run_state: Dictionary, center: Vector2i) -> void:
	var rooms: Dictionary = run_state.get("rooms", {}).duplicate(true)
	for connection_var: Variant in _room_connections(center):
		if typeof(connection_var) != TYPE_DICTIONARY:
			continue
		var connection: Dictionary = connection_var
		var coord: Vector2i = connection.get("coord", Vector2i(999, 999))
		var key: String = _room_key(coord)
		var room: Dictionary = _merge_room_metadata(int(run_state.get("seed", 0)), coord, rooms.get(key, {}) as Dictionary)
		room["revealed"] = true
		rooms[key] = room
	run_state["rooms"] = rooms

func _room_key(coord: Vector2i) -> String:
	return "%d,%d" % [coord.x, coord.y]

func _room_npcs_for_coord(_seed: int, coord: Vector2i) -> Array[Dictionary]:
	if coord == Vector2i.ZERO:
		return [
			{
				"id": "emaciated_man",
				"pos": Vector2i(4, 3)
			}
		]
	return []

func _room_has_npcs(room: Dictionary) -> bool:
	return (room.get("npcs", []) as Array).size() > 0

func _merge_room_metadata(seed: int, coord: Vector2i, stored_room: Dictionary) -> Dictionary:
	var room: Dictionary = _build_room_metadata(seed, coord)
	for key_var: Variant in stored_room.keys():
		var key: String = str(key_var)
		room[key] = stored_room[key_var]
	if not room.has("sealed"):
		room["sealed"] = false
	return room

# Each non-center depth is a square ring with literal cardinal adjacency.
func _room_connections(coord: Vector2i) -> Array[Dictionary]:
	if coord == Vector2i.ZERO:
		return [
			{"door_dir": Vector2i(0, -1), "coord": Vector2i(0, -1), "kind": "outward"},
			{"door_dir": Vector2i(1, 0), "coord": Vector2i(1, 0), "kind": "outward"},
			{"door_dir": Vector2i(0, 1), "coord": Vector2i(0, 1), "kind": "outward"},
			{"door_dir": Vector2i(-1, 0), "coord": Vector2i(-1, 0), "kind": "outward"}
		]
	var depth: int = _room_depth(coord)
	if depth <= 0 or depth > MAX_DEPTH:
		return []
	var ring: Array[Vector2i] = _ring_coords(depth)
	var index: int = _ring_index_for_coord(ring, coord)
	if index < 0:
		return []
	var previous_coord: Vector2i = ring[(index - 1 + ring.size()) % ring.size()]
	var next_coord: Vector2i = ring[(index + 1) % ring.size()]
	var connections: Array[Dictionary] = [
		{"door_dir": previous_coord - coord, "coord": previous_coord, "kind": "lateral"},
		{"door_dir": next_coord - coord, "coord": next_coord, "kind": "lateral"}
	]
	var inward_coord: Vector2i = _inward_source_for_room(coord)
	if inward_coord.x < 900:
		connections.append({"door_dir": inward_coord - coord, "coord": inward_coord, "kind": "inward"})
	if depth < MAX_DEPTH and _room_has_outward_link(depth, index):
		var outward_coord: Vector2i = _outward_coord_for_room(coord)
		connections.append({"door_dir": outward_coord - coord, "coord": outward_coord, "kind": "outward"})
	return connections

func _connection_to(from_coord: Vector2i, destination: Vector2i) -> Dictionary:
	for connection_var: Variant in _room_connections(from_coord):
		if typeof(connection_var) != TYPE_DICTIONARY:
			continue
		var connection: Dictionary = connection_var
		if connection.get("coord", Vector2i(999, 999)) == destination:
			return connection.duplicate(true)
	return {}

func _ring_coords(depth: int) -> Array[Vector2i]:
	var coords: Array[Vector2i] = []
	if depth <= 0:
		return coords
	for y: int in range(-depth, depth + 1):
		coords.append(Vector2i(depth, y))
	for x: int in range(depth - 1, -depth - 1, -1):
		coords.append(Vector2i(x, depth))
	for y: int in range(depth - 1, -depth - 1, -1):
		coords.append(Vector2i(-depth, y))
	for x: int in range(-depth + 1, depth):
		coords.append(Vector2i(x, -depth))
	return coords

func _ring_index_for_coord(ring: Array[Vector2i], coord: Vector2i) -> int:
	for index: int in range(ring.size()):
		if ring[index] == coord:
			return index
	return -1

func _room_has_outward_link(depth: int, ring_index: int) -> bool:
	return depth > 0 and ring_index % 4 == 0

func _outward_coord_for_room(coord: Vector2i) -> Vector2i:
	return coord + _outward_dir_for_room(coord)

func _outward_dir_for_room(coord: Vector2i) -> Vector2i:
	var depth: int = _room_depth(coord)
	if coord == Vector2i(depth, -depth):
		return Vector2i(1, 0)
	if coord == Vector2i(depth, depth):
		return Vector2i(0, 1)
	if coord == Vector2i(-depth, depth):
		return Vector2i(-1, 0)
	if coord == Vector2i(-depth, -depth):
		return Vector2i(0, -1)
	if coord.x == depth:
		return Vector2i(1, 0)
	if coord.y == depth:
		return Vector2i(0, 1)
	if coord.x == -depth:
		return Vector2i(-1, 0)
	return Vector2i(0, -1)

func _inward_source_for_room(coord: Vector2i) -> Vector2i:
	var depth: int = _room_depth(coord)
	if depth <= 0:
		return Vector2i(999, 999)
	for dir: Vector2i in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
		var candidate: Vector2i = coord + dir
		if _room_depth(candidate) != depth - 1:
			continue
		if candidate == Vector2i.ZERO:
			if coord in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
				return candidate
			continue
		var previous_ring: Array[Vector2i] = _ring_coords(depth - 1)
		var previous_index: int = _ring_index_for_coord(previous_ring, candidate)
		if previous_index < 0 or not _room_has_outward_link(depth - 1, previous_index):
			continue
		if _outward_coord_for_room(candidate) == coord:
			return candidate
	return Vector2i(999, 999)

func _coord_hash(seed: int, coord: Vector2i, salt: int) -> int:
	var value: int = seed
	value = int((value * 1664525 + 1013904223 + salt) & 0x7fffffff)
	value = int((value + coord.x * 73856093 + coord.y * 19349663) & 0x7fffffff)
	return value

func _try_recover_lost_embers(run_state: Dictionary) -> void:
	var progression: Dictionary = (run_state.get("progression", {}) as Dictionary).duplicate(true)
	var marker: Dictionary = ProgressionStore.recovery_marker(progression)
	if marker.is_empty():
		return
	if int(run_state.get("run_index", 0)) != int(marker.get("available_run", -1)):
		return
	var coord: Vector2i = ProgressionStore.recovery_coord(progression)
	if coord != run_state.get("current_room", Vector2i.ZERO):
		return
	var amount: int = int(marker.get("amount", 0))
	if amount <= 0:
		return
	run_state["unbanked_embers"] = int(run_state.get("unbanked_embers", 0)) + amount
	run_state["notice"] = "Recovered %d embers." % amount
	run_state["progression"] = ProgressionStore.clear_recovery_marker(progression)
