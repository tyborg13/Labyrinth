extends RefCounted
class_name RunEngine

const CombatEngineScript = preload("res://scripts/combat_engine.gd")
const RoomGeneratorScript = preload("res://scripts/room_generator.gd")
const ElementData = preload("res://scripts/element_data.gd")
const GameData = preload("res://scripts/game_data.gd")
const PathUtils = preload("res://scripts/path_utils.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")

const MAX_DEPTH: int = 4
const BASE_MAX_HP: int = 36
const BASE_HAND_SIZE: int = 5
const BASE_CARDS_PER_TURN: int = 2
const BASE_DRAW_PER_TURN: int = 2
const REWARD_HEAL: int = 6
const BOSS_VICTORY_EMBERS: int = 30

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

func available_moves(run_state: Dictionary) -> Array[Vector2i]:
	var current: Vector2i = run_state.get("current_room", Vector2i.ZERO)
	var neighbors: Array[Vector2i] = []
	for dir: Vector2i in PathUtils.DIRS_4:
		var candidate: Vector2i = current + dir
		if _room_depth(candidate) > MAX_DEPTH:
			continue
		neighbors.append(candidate)
	return neighbors

func room_metadata(run_state: Dictionary, coord: Vector2i) -> Dictionary:
	var rooms: Dictionary = run_state.get("rooms", {})
	var key: String = _room_key(coord)
	if rooms.has(key):
		return (rooms[key] as Dictionary).duplicate(true)
	return _build_room_metadata(int(run_state.get("seed", 0)), coord)

func move_to_room(run_state: Dictionary, destination: Vector2i) -> Dictionary:
	var current: Vector2i = run_state.get("current_room", Vector2i.ZERO)
	if destination == current:
		return run_state.duplicate(true)
	if not available_moves(run_state).has(destination):
		return run_state.duplicate(true)
	var next_state: Dictionary = run_state.duplicate(true)
	var rooms: Dictionary = next_state.get("rooms", {}).duplicate(true)
	var destination_key: String = _room_key(destination)
	if not rooms.has(destination_key):
		rooms[destination_key] = _build_room_metadata(int(next_state.get("seed", 0)), destination)
	next_state["rooms"] = rooms
	next_state["current_room"] = destination
	next_state["turns_spent"] = int(next_state.get("turns_spent", 0)) + 1
	next_state["notice"] = ""
	var room: Dictionary = (rooms[destination_key] as Dictionary).duplicate(true)
	room["revealed"] = true
	room["visited"] = true
	rooms[destination_key] = room
	next_state["rooms"] = rooms
	_reveal_neighbors(next_state, destination)
	var travel_dir: Vector2i = destination - current
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
				next_state["mode"] = "room"
			else:
				room["cleared"] = true
				rooms[destination_key] = room
				next_state["rooms"] = rooms
				next_state["pending_relics"] = _generate_relic_choices(next_state, destination)
				next_state["mode"] = "treasure"
			next_state["combat_state"] = {}
		_:
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
	for dir: Vector2i in PathUtils.DIRS_4:
		var destination: Vector2i = run_state.get("current_room", Vector2i.ZERO) + dir
		if _room_depth(destination) > MAX_DEPTH:
			continue
		var room: Dictionary = room_metadata(run_state, destination)
		if not bool(room.get("revealed", false)):
			continue
		results.append({
			"dir": dir,
			"coord": destination,
			"door_tile": RoomGeneratorScript.door_tile_for_direction(dir),
			"room": room
		})
	return results

func _player_snapshot(run_state: Dictionary) -> Dictionary:
	return {
		"hp": int(run_state.get("player_hp", 1)),
		"max_hp": int(run_state.get("player_max_hp", 1)),
		"deck_cards": run_state.get("deck_cards", []).duplicate(),
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
	return {
		"coord": coord,
		"depth": depth,
		"type": room_type,
		"element": element_id,
		"revealed": depth <= 1,
		"visited": false,
		"cleared": room_type == "start"
	}

func _display_layout_for_room(seed: int, room: Dictionary, travel_dir: Vector2i) -> Dictionary:
	var layout: Dictionary = _room_generator.generate_room(seed, room, travel_dir)
	if layout.is_empty():
		return {}
	layout["enemies"] = []
	if str(room.get("type", "")) != "combat" and str(room.get("type", "")) != "boss":
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
		"player_start": (combat_state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO),
		"enemies": [],
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
	if room_type != "combat":
		return ElementData.NONE
	var roll: int = _coord_hash(seed, coord, 151) % ElementData.all_elements().size()
	return ElementData.all_elements()[roll]

func _room_depth(coord: Vector2i) -> int:
	return absi(coord.x) + absi(coord.y)

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
	for coord: Vector2i in available_moves({"current_room": center}):
		var key: String = _room_key(coord)
		if not rooms.has(key):
			rooms[key] = _build_room_metadata(int(run_state.get("seed", 0)), coord)
		var room: Dictionary = (rooms[key] as Dictionary).duplicate(true)
		room["revealed"] = true
		rooms[key] = room
	run_state["rooms"] = rooms

func _room_key(coord: Vector2i) -> String:
	return "%d,%d" % [coord.x, coord.y]

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
