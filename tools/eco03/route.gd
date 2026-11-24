extends RefCounted

const Graph = preload("res://scripts/section_map_graph.gd")
const Game = preload("res://scripts/game_data.gd")

static func kind(room: Dictionary) -> String:
	return str(room["mystery_type"]) if room["type"] == "mystery" else str(room["type"])

static func fight(room: Dictionary) -> bool:
	return kind(room) in ["combat", "guardian"]

static func section_routes(state: Dictionary, index: int) -> Dictionary:
	var info: Dictionary = Graph.section(state, index)
	var rooms: Array[Dictionary]
	for room: Dictionary in state["rooms"].values():
		if room["section_index"] == index: rooms.append(room)
	rooms.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return [a["map_step"], a["map_lane"]] < [b["map_step"], b["map_lane"]])
	var paths: Dictionary = {info["entry"]: {"fights": 0, "path": []}}
	var shops: Array[Dictionary]
	for room: Dictionary in rooms:
		var coord: Vector2i = room["coord"]
		if not paths.has(coord): continue
		var prefix: Dictionary = paths[coord]
		if kind(room) == "scavenger": shops.append(prefix)
		var count: int = int(prefix["fights"]) + int(fight(room))
		for link: Dictionary in room["connections"]:
			var target: Vector2i = link["coord"]
			if Graph.active_section({"rooms": state["rooms"], "current_room": target}) != index: continue
			if not paths.has(target) or count < int(paths[target]["fights"]):
				paths[target] = {"fights": count, "path": prefix["path"] + [target]}
	var first: Dictionary = {}
	var early: int = 0
	for shop: Dictionary in shops:
		if int(shop["fights"]) < 2: early += 1
		if first.is_empty() or int(shop["fights"]) < int(first["fights"]): first = shop
	return {"count": shops.size(), "early": early, "first": first}

static func enter_path(engine: RefCounted, state: Dictionary, path: Array) -> Dictionary:
	var embers: int = engine.held_embers(state)
	for coord: Vector2i in path:
		var target: Dictionary = Graph.room(state, coord)
		var counts_for_embers: bool = fight(target)
		# Structural proof bypasses non-fight services and choices from previous
		# rooms. Production movement still builds the seed's actual encounter.
		target["revealed"] = true
		state["mode"] = "room"
		state = engine.move_to_room(state, coord)
		assert(state["current_room"] == coord)
		if state["mode"] == "pre_battle": state = engine.begin_pre_battle_combat(state)
		if counts_for_embers:
			var roster: Array = state["combat_state"]["enemies"]
			for enemy: Dictionary in roster:
				if not bool(enemy.get("guardian_helper", false)):
					embers += int(Game.enemy_property(str(enemy["type"]), "reward_embers", 0))
		if state["mode"] == "combat":
			var room: Dictionary = Graph.room(state, coord)
			room["cleared"] = true
			state["combat_state"] = {}
	return engine.set_held_embers(state, embers)
