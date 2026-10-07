extends "res://scripts/run_engine.gd"

# Frozen pre-optimization move entry, captured for complete state equivalence.
# Original source SHA-256: 82608243f722c22a264fb3601055df375c8719c2157f03fbe30f6742e31492bf
func move_to_pre_battle(run_state: Dictionary, destination: Vector2i) -> Dictionary:
	if SectionMapGraph.enabled(run_state) and str(run_state.get("mode", "")) != "room":
		return run_state.duplicate(true)
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
	SectionMapGraph.record_choice(next_state, destination)
	next_state["pending_escape"] = {}
	var move_skill_state: Dictionary = _normalized_skill_state(next_state.get(SKILL_STATE_KEY, {}))
	move_skill_state["previous_room"] = current
	next_state[SKILL_STATE_KEY] = move_skill_state
	_clear_pre_battle_state(next_state)
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
	SectionMapGraph.refresh_knowledge(next_state)
	var reveal_exits_on_entry: bool = not _room_blocks_exit_reveal(room)
	if reveal_exits_on_entry:
		_reveal_neighbors(next_state, destination)
		_ensure_loop_escape_connection(next_state, destination)
	rooms = next_state.get("rooms", {}).duplicate(true)
	room = _merge_room_metadata(int(next_state.get("seed", 0)), destination, rooms.get(destination_key, {}) as Dictionary)
	var merchant_kind: String = merchant_kind_for_room(room)
	if not merchant_kind.is_empty():
		room = _merchant_room_with_stock(next_state, room, merchant_kind)
		rooms[destination_key] = room
		next_state["rooms"] = rooms
	var travel_dir: Vector2i = connection.get("door_dir", Vector2i.ZERO)
	next_state["current_room_layout"] = _display_layout_for_room(int(next_state.get("seed", 0)), room, travel_dir)
	_stage_recovery_marker(next_state)
	if str(room.get("type", "combat")) not in ["combat", "boss", "guardian"] or bool(room.get("cleared", false)) or _room_has_npcs(room):
		return move_to_room(run_state, destination)
	next_state["mode"] = MODE_PRE_BATTLE
	next_state["combat_state"] = {}
	next_state["pre_battle_pending"] = true
	next_state["pre_battle_travel_dir"] = travel_dir
	return next_state

