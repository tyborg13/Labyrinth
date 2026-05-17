extends RefCounted
class_name RunEngine

const CombatEngineScript = preload("res://scripts/combat_engine.gd")
const RoomGeneratorScript = preload("res://scripts/room_generator.gd")
const ElementData = preload("res://scripts/element_data.gd")
const GameData = preload("res://scripts/game_data.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")

const PLANNED_DEPTH_SEQUENCES: int = 4
const ACTIVE_DEPTH_SEQUENCES: int = 2
const DEPTHS_PER_SEQUENCE: int = 4
const MAX_DEPTH: int = ACTIVE_DEPTH_SEQUENCES * DEPTHS_PER_SEQUENCE
const BASE_MAX_HP: int = 360
const BASE_HAND_SIZE: int = 5
const BASE_CARDS_PER_TURN: int = 2
const BASE_DRAW_PER_TURN: int = 2
const REWARD_HEAL: int = 60
const BOSS_VICTORY_EMBERS: int = 30
const DEBUG_BOSS_SEED: int = 90429
const DEBUG_BOSS_COORD: Vector2i = Vector2i(4, 0)
const RELIC_ROOM_CANDIDATE_PERCENT: int = 47

var _combat_engine = CombatEngineScript.new()
var _room_generator = RoomGeneratorScript.new()

func create_new_run(seed: int, progression: Dictionary) -> Dictionary:
	var max_hp: int = BASE_MAX_HP + GameData.vigor_max_hp_bonus(progression) + GameData.stat_bonus_from_upgrades(progression, "max_hp")
	var hand_size: int = BASE_HAND_SIZE + GameData.stat_bonus_from_upgrades(progression, "hand_size")
	var heal_bonus: int = GameData.stat_bonus_from_upgrades(progression, "heal_bonus")
	var starting_embers: int = maxi(0, int(progression.get("embers", 0)))
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
		"held_embers": starting_embers,
		"unbanked_embers": starting_embers,
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
	_stage_recovery_marker(run_state)
	return run_state

func create_debug_boss_run(progression: Dictionary) -> Dictionary:
	var max_hp: int = 420
	var current_hp: int = 340
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
		"held_embers": 44,
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
	if not next_state.has("held_embers"):
		next_state["held_embers"] = int(next_state.get("unbanked_embers", 0))
	next_state["unbanked_embers"] = int(next_state.get("held_embers", 0))
	_stage_recovery_marker(next_state)
	var current_coord: Vector2i = next_state.get("current_room", Vector2i.ZERO)
	var current_room: Dictionary = room_metadata(next_state, current_coord)
	if str(next_state.get("mode", "room")) != "combat" or not _room_blocks_exit_reveal(current_room):
		_reveal_neighbors(next_state, current_coord)
		_ensure_loop_escape_connection(next_state, current_coord)
		_sync_current_layout_doors(next_state, current_coord)
	return next_state

func available_moves(run_state: Dictionary) -> Array[Vector2i]:
	var current: Vector2i = run_state.get("current_room", Vector2i.ZERO)
	var current_room: Dictionary = room_metadata(run_state, current)
	var current_depth: int = int(current_room.get("depth", 0))
	var cleared_intermediate_boss: bool = (
		str(current_room.get("type", "")) == "boss"
		and bool(current_room.get("cleared", false))
		and not _is_final_boss_depth(current_depth)
	)
	var neighbors: Array[Vector2i] = []
	var seen: Dictionary = {}
	for connection_var: Variant in current_room.get("connections", []):
		if typeof(connection_var) != TYPE_DICTIONARY:
			continue
		var connection: Dictionary = connection_var
		if cleared_intermediate_boss and str(connection.get("kind", "")) != "outward":
			continue
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
	var current_room_before_move: Dictionary = room_metadata(run_state, current)
	var connection: Dictionary = _connection_to_room(current_room_before_move, destination)
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
	var reveal_exits_on_entry: bool = not _room_blocks_exit_reveal(room)
	if reveal_exits_on_entry:
		_reveal_neighbors(next_state, destination)
		_ensure_loop_escape_connection(next_state, destination)
	rooms = next_state.get("rooms", {}).duplicate(true)
	room = _merge_room_metadata(int(next_state.get("seed", 0)), destination, rooms.get(destination_key, {}) as Dictionary)
	var travel_dir: Vector2i = connection.get("door_dir", Vector2i.ZERO)
	next_state["current_room_layout"] = _display_layout_for_room(int(next_state.get("seed", 0)), room, travel_dir)
	_stage_recovery_marker(next_state)
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
	return _apply_recovered_embers_from_combat(next_state, combat_state)

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
	_reveal_neighbors(next_state, current_room)
	_ensure_loop_escape_connection(next_state, current_room)
	_sync_current_layout_doors(next_state, current_room)
	var ember_bonus: int = GameData.stat_bonus_from_relics(next_state.get("relics", []), "combat_ember_bonus")
	var total_embers: int = int(combat_state.get("room_embers", 0)) + ember_bonus
	next_state = add_held_embers(next_state, total_embers)
	if str(room.get("type", "")) == "boss":
		next_state["player_hp"] = int(next_state.get("player_max_hp", next_state.get("player_hp", 1)))
		next_state = add_held_embers(next_state, BOSS_VICTORY_EMBERS)
		next_state["pending_reward"] = {}
		if _is_final_boss_depth(int(room.get("depth", _room_depth(current_room)))) or bool(next_state.get("debug_boss_run", false)):
			next_state["victory"] = true
			next_state["mode"] = "victory"
		else:
			next_state["victory"] = false
			next_state["mode"] = "room"
			next_state["notice"] = "The labyrinth opens outward."
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
	var bonus: int = GameData.stat_bonus_from_relics([relic_id], "max_hp")
	if bonus != 0:
		next_state["player_max_hp"] = int(next_state.get("player_max_hp", 1)) + bonus
		next_state["player_hp"] = int(next_state.get("player_hp", 1)) + bonus
	next_state["pending_relics"] = []
	next_state["mode"] = "room"
	return next_state

func leave_campfire(run_state: Dictionary, heal_amount: int = 0) -> Dictionary:
	var next_state: Dictionary = run_state.duplicate(true)
	if heal_amount > 0:
		var max_hp: int = maxi(1, int(next_state.get("player_max_hp", 1)))
		var current_hp: int = int(next_state.get("player_hp", max_hp))
		next_state["player_hp"] = mini(max_hp, current_hp + heal_amount)
	next_state["mode"] = "room"
	return next_state

func held_embers(run_state: Dictionary) -> int:
	return maxi(0, int(run_state.get("held_embers", run_state.get("unbanked_embers", 0))))

func set_held_embers(run_state: Dictionary, amount: int) -> Dictionary:
	var next_state: Dictionary = run_state.duplicate(true)
	next_state["held_embers"] = maxi(0, amount)
	next_state["unbanked_embers"] = maxi(0, amount)
	return next_state

func add_held_embers(run_state: Dictionary, amount: int) -> Dictionary:
	return set_held_embers(run_state, held_embers(run_state) + amount)

func spend_held_embers(run_state: Dictionary, amount: int) -> Dictionary:
	return set_held_embers(run_state, held_embers(run_state) - amount)

func clear_held_embers(run_state: Dictionary) -> Dictionary:
	return set_held_embers(run_state, 0)

func apply_progression_update(run_state: Dictionary, progression: Dictionary) -> Dictionary:
	var next_state: Dictionary = run_state.duplicate(true)
	var previous_progression: Dictionary = (next_state.get("progression", {}) as Dictionary).duplicate(true)
	var old_vigor_bonus: int = GameData.vigor_max_hp_bonus(previous_progression)
	var new_vigor_bonus: int = GameData.vigor_max_hp_bonus(progression)
	var hp_delta: int = new_vigor_bonus - old_vigor_bonus
	if hp_delta != 0:
		next_state["player_max_hp"] = maxi(1, int(next_state.get("player_max_hp", 1)) + hp_delta)
		next_state["player_hp"] = clampi(int(next_state.get("player_hp", 1)) + hp_delta, 1, int(next_state.get("player_max_hp", 1)))
	next_state["progression"] = progression.duplicate(true)
	next_state = set_held_embers(next_state, int(progression.get("embers", held_embers(next_state))))
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
		"stats": ((run_state.get("progression", {}) as Dictionary).get("stats", {}) as Dictionary).duplicate(true),
		"level": int((run_state.get("progression", {}) as Dictionary).get("level", 1)),
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
		"revealed": depth == 0,
		"visited": false,
		"cleared": room_type == "start",
		"sealed": false
	}

func _display_layout_for_room(seed: int, room: Dictionary, travel_dir: Vector2i) -> Dictionary:
	var layout: Dictionary = _room_generator.generate_room(seed, room, travel_dir)
	if layout.is_empty():
		return {}
	layout["enemies"] = []
	return layout

func _combat_layout_for_room(room: Dictionary, travel_dir: Vector2i, run_state: Dictionary) -> Dictionary:
	var layout_room: Dictionary = room.duplicate(true)
	if _room_has_recovery_marker(room):
		layout_room["type"] = "combat"
		if not ElementData.is_elemental(str(layout_room.get("element", ElementData.NONE))):
			layout_room["element"] = _room_element_for_coord(int(run_state.get("seed", 0)), layout_room.get("coord", Vector2i.ZERO), "combat")
	var layout: Dictionary = _room_generator.generate_room(int(run_state.get("seed", 0)), layout_room, travel_dir)
	return _layout_with_recovery_loot(layout, room, run_state)

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
		"loot": combat_state.get("loot", []).duplicate(true),
		"terrain": combat_state.get("terrain", []).duplicate(true)
	}

func _room_type_for_coord(seed: int, coord: Vector2i) -> String:
	var depth: int = _room_depth(coord)
	if depth == 0:
		return "start"
	if depth > MAX_DEPTH:
		return "boss"
	if _is_sequence_boss_depth(depth):
		return "boss"
	if _is_campfire_coord(coord):
		return "campfire"
	if _is_relic_room_coord(seed, coord):
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

func _depth_step_in_sequence(depth: int) -> int:
	return posmod(maxi(1, depth) - 1, DEPTHS_PER_SEQUENCE) + 1

func _is_sequence_boss_depth(depth: int) -> bool:
	return depth > 0 and depth <= MAX_DEPTH and _depth_step_in_sequence(depth) == DEPTHS_PER_SEQUENCE

func _is_final_boss_depth(depth: int) -> bool:
	return depth >= MAX_DEPTH and _is_sequence_boss_depth(depth)

func _is_campfire_coord(coord: Vector2i) -> bool:
	var depth: int = _room_depth(coord)
	return _depth_step_in_sequence(depth) == 2 and (coord.x == 0 or coord.y == 0)

func _is_relic_room_coord(seed: int, coord: Vector2i) -> bool:
	return _is_relic_room_coord_with_memo(seed, coord, {})

func _is_relic_room_coord_with_memo(seed: int, coord: Vector2i, memo: Dictionary) -> bool:
	var key: String = _room_key(coord)
	if memo.has(key):
		return bool(memo[key])
	if not _is_relic_room_candidate(seed, coord):
		memo[key] = false
		return false
	var priority: int = _relic_room_priority(seed, coord)
	for dir: Vector2i in PathUtils.DIRS_4:
		var neighbor: Vector2i = coord + dir
		if not _is_relic_room_candidate(seed, neighbor):
			continue
		var neighbor_priority: int = _relic_room_priority(seed, neighbor)
		var neighbor_has_priority: bool = neighbor_priority < priority or (neighbor_priority == priority and _room_key(neighbor) < key)
		if not neighbor_has_priority:
			continue
		if _is_relic_room_coord_with_memo(seed, neighbor, memo):
			memo[key] = false
			return false
	memo[key] = true
	return true

func _is_relic_room_candidate(seed: int, coord: Vector2i) -> bool:
	if not _is_relic_room_eligible(coord):
		return false
	return (_coord_hash(seed, coord, 77) % 1000) < RELIC_ROOM_CANDIDATE_PERCENT * 10

func _is_relic_room_eligible(coord: Vector2i) -> bool:
	var depth: int = _room_depth(coord)
	if depth <= 0 or depth > MAX_DEPTH:
		return false
	if _is_sequence_boss_depth(depth):
		return false
	if _is_campfire_coord(coord):
		return false
	if coord in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
		return false
	return true

func _relic_room_priority(seed: int, coord: Vector2i) -> int:
	return _coord_hash(seed, coord, 733)

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
	available.sort()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = _coord_hash(int(run_state.get("seed", 0)), coord, 543)
	var choices: Array[String] = []
	while choices.size() < 3 and not available.is_empty():
		var total_weight: int = 0
		for relic_id: String in available:
			total_weight += maxi(1, GameData.relic_offer_weight(relic_id))
		var roll: int = rng.randi_range(1, total_weight)
		var cursor: int = 0
		var picked_index: int = 0
		for index: int in range(available.size()):
			cursor += maxi(1, GameData.relic_offer_weight(available[index]))
			if roll <= cursor:
				picked_index = index
				break
		choices.append(available[picked_index])
		available.remove_at(picked_index)
	return choices

func _reveal_neighbors(run_state: Dictionary, center: Vector2i) -> void:
	var rooms: Dictionary = run_state.get("rooms", {}).duplicate(true)
	var center_room: Dictionary = room_metadata(run_state, center)
	for connection_var: Variant in center_room.get("connections", []):
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

func _room_blocks_exit_reveal(room: Dictionary) -> bool:
	var room_type: String = str(room.get("type", "combat"))
	if room_type not in ["combat", "boss"]:
		return false
	if bool(room.get("cleared", false)):
		return false
	if _room_has_npcs(room):
		return false
	return true

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
	if _room_can_link_outward(depth, index):
		var outward_coord: Vector2i = _outward_coord_for_room(coord)
		connections.append({"door_dir": outward_coord - coord, "coord": outward_coord, "kind": "outward"})
	return connections

func _connection_to(from_coord: Vector2i, destination: Vector2i) -> Dictionary:
	return _connection_to_room({"connections": _room_connections(from_coord)}, destination)

func _connection_to_room(room: Dictionary, destination: Vector2i) -> Dictionary:
	for connection_var: Variant in room.get("connections", []):
		if typeof(connection_var) != TYPE_DICTIONARY:
			continue
		var connection: Dictionary = connection_var
		if connection.get("coord", Vector2i(999, 999)) == destination:
			return connection.duplicate(true)
	return {}

func _ensure_loop_escape_connection(run_state: Dictionary, coord: Vector2i) -> void:
	var room: Dictionary = room_metadata(run_state, coord)
	if not _room_can_gain_loop_escape(room):
		return
	if _room_has_progressive_available_move(run_state, room):
		return
	var outward_coord: Vector2i = _outward_coord_for_room(coord)
	if _room_depth(outward_coord) != int(room.get("depth", 0)) + 1:
		return
	var outward_connection: Dictionary = {
		"door_dir": outward_coord - coord,
		"coord": outward_coord,
		"kind": "outward",
		"loop_escape": true
	}
	var connections: Array = (room.get("connections", []) as Array).duplicate(true)
	for connection_var: Variant in connections:
		if typeof(connection_var) != TYPE_DICTIONARY:
			continue
		var connection: Dictionary = connection_var
		if connection.get("coord", Vector2i(999, 999)) == outward_coord:
			return
	connections.append(outward_connection)
	room["connections"] = connections
	var rooms: Dictionary = run_state.get("rooms", {}).duplicate(true)
	rooms[_room_key(coord)] = room
	var outward_key: String = _room_key(outward_coord)
	var outward_room: Dictionary = _merge_room_metadata(int(run_state.get("seed", 0)), outward_coord, rooms.get(outward_key, {}) as Dictionary)
	outward_room["revealed"] = true
	rooms[outward_key] = outward_room
	run_state["rooms"] = rooms

func _room_can_gain_loop_escape(room: Dictionary) -> bool:
	var depth: int = int(room.get("depth", 0))
	if depth <= 0 or depth >= MAX_DEPTH:
		return false
	if str(room.get("type", "combat")) == "boss":
		return false
	return true

func _room_has_progressive_available_move(run_state: Dictionary, room: Dictionary) -> bool:
	var current_depth: int = int(room.get("depth", 0))
	for connection_var: Variant in room.get("connections", []):
		if typeof(connection_var) != TYPE_DICTIONARY:
			continue
		var connection: Dictionary = connection_var
		var candidate: Vector2i = connection.get("coord", Vector2i(999, 999))
		var candidate_room: Dictionary = room_metadata(run_state, candidate)
		if not bool(candidate_room.get("revealed", false)):
			continue
		if int(candidate_room.get("depth", 0)) < current_depth:
			continue
		if bool(candidate_room.get("sealed", false)):
			continue
		return true
	return false

func _sync_current_layout_doors(run_state: Dictionary, coord: Vector2i) -> void:
	if run_state.get("current_room", Vector2i.ZERO) != coord:
		return
	var layout: Dictionary = (run_state.get("current_room_layout", {}) as Dictionary).duplicate(true)
	if layout.is_empty():
		return
	var grid: Array = layout.get("grid", []).duplicate(true)
	if grid.is_empty():
		return
	var room: Dictionary = room_metadata(run_state, coord)
	for connection_var: Variant in room.get("connections", []):
		if typeof(connection_var) != TYPE_DICTIONARY:
			continue
		var connection: Dictionary = connection_var
		var door_tile: Vector2i = RoomGeneratorScript.door_tile_for_direction(connection.get("door_dir", Vector2i.ZERO))
		if door_tile.x < 0 or door_tile.y < 0 or door_tile.y >= grid.size():
			continue
		var row: Array = (grid[door_tile.y] as Array).duplicate()
		if door_tile.x >= row.size():
			continue
		row[door_tile.x] = RoomGeneratorScript.TILE_DOOR
		grid[door_tile.y] = row
	layout["grid"] = grid
	run_state["current_room_layout"] = layout

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

func _room_can_link_outward(depth: int, ring_index: int) -> bool:
	if depth <= 0 or depth >= MAX_DEPTH:
		return false
	if _is_sequence_boss_depth(depth):
		return true
	return _room_has_outward_link(depth, ring_index)

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
		if previous_index < 0 or not _room_can_link_outward(depth - 1, previous_index):
			continue
		if _outward_coord_for_room(candidate) == coord:
			return candidate
	return Vector2i(999, 999)

func _coord_hash(seed: int, coord: Vector2i, salt: int) -> int:
	var value: int = seed
	value = int((value * 1664525 + 1013904223 + salt) & 0x7fffffff)
	value = int((value + coord.x * 73856093 + coord.y * 19349663) & 0x7fffffff)
	return value

func _stage_recovery_marker(run_state: Dictionary) -> void:
	var progression: Dictionary = (run_state.get("progression", {}) as Dictionary).duplicate(true)
	var marker: Dictionary = ProgressionStore.recovery_marker(progression)
	if marker.is_empty():
		return
	if int(run_state.get("run_index", 0)) != int(marker.get("available_run", -1)):
		return
	var coord: Vector2i = ProgressionStore.recovery_coord(progression)
	var amount: int = int(marker.get("amount", 0))
	if amount <= 0:
		return
	var rooms: Dictionary = run_state.get("rooms", {}).duplicate(true)
	var key: String = _room_key(coord)
	var room: Dictionary = _merge_room_metadata(int(run_state.get("seed", 0)), coord, rooms.get(key, {}) as Dictionary)
	if coord != Vector2i.ZERO and str(room.get("type", "")) != "boss":
		room["type"] = "combat"
		room["element"] = _room_element_for_coord(int(run_state.get("seed", 0)), coord, "combat")
		room["npcs"] = []
		room["cleared"] = false
	room["recovery_marker"] = true
	room["recovery_amount"] = amount
	room["recovery_available_run"] = int(marker.get("available_run", 0))
	rooms[key] = room
	run_state["rooms"] = rooms

func _room_has_recovery_marker(room: Dictionary) -> bool:
	return bool(room.get("recovery_marker", false)) and int(room.get("recovery_amount", 0)) > 0

func _layout_with_recovery_loot(layout: Dictionary, room: Dictionary, run_state: Dictionary) -> Dictionary:
	if layout.is_empty() or not _room_has_recovery_marker(room):
		return layout
	var progression: Dictionary = (run_state.get("progression", {}) as Dictionary).duplicate(true)
	var marker: Dictionary = ProgressionStore.recovery_marker(progression)
	if marker.is_empty() or int(marker.get("available_run", -1)) != int(run_state.get("run_index", 0)):
		return layout
	if ProgressionStore.recovery_coord(progression) != layout.get("coord", Vector2i.ZERO):
		return layout
	var loot: Array = layout.get("loot", []).duplicate(true)
	for loot_var: Variant in loot:
		if typeof(loot_var) != TYPE_DICTIONARY:
			continue
		if str((loot_var as Dictionary).get("kind", "")) == "dropped_embers":
			layout["loot"] = loot
			return layout
	var tile: Vector2i = _recovery_loot_tile(layout)
	if tile.x < 0:
		return layout
	loot.append({
		"id": "lost_embers_%d_%d" % [tile.x, tile.y],
		"kind": "dropped_embers",
		"amount": int(marker.get("amount", 0)),
		"pos": tile,
		"recovery_marker": true
	})
	layout["loot"] = loot
	return layout

func _recovery_loot_tile(layout: Dictionary) -> Vector2i:
	var grid: Array = layout.get("grid", [])
	var occupied: Dictionary = _layout_occupied_tiles(layout)
	var best_tile: Vector2i = Vector2i(-1, -1)
	var best_score: float = -INF
	var center := Vector2(4.0, 4.0)
	for y: int in range(grid.size()):
		var row: Array = grid[y]
		for x: int in range(row.size()):
			var tile := Vector2i(x, y)
			if occupied.has(tile):
				continue
			if not PathUtils.is_passable(grid, tile):
				continue
			var score: float = -tile.distance_to(center)
			score += float(_coord_hash(int(layout.get("depth", 0)), tile, 1307) % 1000) / 10000.0
			if score > best_score:
				best_score = score
				best_tile = tile
	return best_tile

func _layout_occupied_tiles(layout: Dictionary) -> Dictionary:
	var occupied: Dictionary = {}
	occupied[layout.get("player_start", Vector2i.ZERO)] = true
	for enemy_var: Variant in layout.get("enemies", []):
		if typeof(enemy_var) != TYPE_DICTIONARY:
			continue
		for tile: Vector2i in _enemy_footprint_tiles(enemy_var as Dictionary):
			occupied[tile] = true
	for npc_var: Variant in layout.get("npcs", []):
		if typeof(npc_var) == TYPE_DICTIONARY:
			occupied[(npc_var as Dictionary).get("pos", Vector2i(-1, -1))] = true
	for trap_var: Variant in layout.get("traps", []):
		if typeof(trap_var) == TYPE_DICTIONARY:
			occupied[(trap_var as Dictionary).get("pos", Vector2i(-1, -1))] = true
	for loot_var: Variant in layout.get("loot", []):
		if typeof(loot_var) == TYPE_DICTIONARY:
			occupied[(loot_var as Dictionary).get("pos", Vector2i(-1, -1))] = true
	for terrain_var: Variant in layout.get("terrain", []):
		if typeof(terrain_var) == TYPE_DICTIONARY:
			occupied[(terrain_var as Dictionary).get("pos", Vector2i(-1, -1))] = true
	return occupied

func _enemy_footprint_tiles(enemy: Dictionary) -> Array[Vector2i]:
	var origin: Vector2i = enemy.get("pos", Vector2i(-1, -1))
	var footprint: Vector2i = enemy.get("footprint", Vector2i.ONE)
	var tiles: Array[Vector2i] = []
	for y: int in range(maxi(1, footprint.y)):
		for x: int in range(maxi(1, footprint.x)):
			tiles.append(origin + Vector2i(x, y))
	return tiles

func _apply_recovered_embers_from_combat(run_state: Dictionary, combat_state: Dictionary) -> Dictionary:
	var recovered_total: int = int(combat_state.get("recovered_embers_total", 0))
	var previous_total: int = int(run_state.get("recovered_embers_total", 0))
	if recovered_total <= previous_total:
		return run_state
	var delta: int = recovered_total - previous_total
	var next_state: Dictionary = add_held_embers(run_state, delta)
	next_state["recovered_embers_total"] = recovered_total
	var progression: Dictionary = (next_state.get("progression", {}) as Dictionary).duplicate(true)
	next_state["progression"] = ProgressionStore.clear_recovery_marker(progression)
	next_state["notice"] = "Recovered %d embers." % delta
	_clear_recovery_marker_on_current_room(next_state)
	return next_state

func _clear_recovery_marker_on_current_room(run_state: Dictionary) -> void:
	var coord: Vector2i = run_state.get("current_room", Vector2i.ZERO)
	var rooms: Dictionary = run_state.get("rooms", {}).duplicate(true)
	var key: String = _room_key(coord)
	if not rooms.has(key):
		return
	var room: Dictionary = (rooms.get(key, {}) as Dictionary).duplicate(true)
	room.erase("recovery_marker")
	room.erase("recovery_amount")
	room.erase("recovery_available_run")
	rooms[key] = room
	run_state["rooms"] = rooms
