extends RefCounted

const Data = preload("res://scripts/game_data.gd")
const Rooms = preload("res://scripts/room_generator.gd")
const Runs = preload("res://scripts/run_engine.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Progression = preload("res://scripts/progression_store.gd")

static func offset(value: Array) -> Vector2i:
	return Vector2i(int(value[0]), int(value[1]))

static func hand_for(clip: Dictionary) -> Array[String]:
	var hand: Array[String]
	for action: Array in clip["actions"]:
		if action[0] == "play": hand.append(action[1])
	return hand

static func build(clip: Dictionary, defaults: Dictionary) -> Dictionary:
	var seed_value: int = int(defaults["seed"])
	var runs := Runs.new()
	var run: Dictionary = runs.create_new_run(seed_value, Progression.default_data())
	var layout: Dictionary = run["current_room_layout"].duplicate(true)
	# Reuse the production depth-one biome and dimensions. +x is the brief's
	# enemy direction, so use the production entrance for eastward travel.
	var hero: Vector2i = Rooms.ENTRANCE_BY_TRAVEL_DIR[Vector2i.RIGHT]
	for row: Array in layout["grid"]:
		row.fill(Rooms.TILE_STONE)
	layout["player_start"] = hero
	layout["type"] = "combat"
	layout["depth"] = 1
	layout["enemies"] = []
	layout["traps"] = []
	layout["terrain"] = []
	layout["loot"] = []
	layout["npcs"] = []
	layout["surfaces"] = {}
	layout["moss"] = {}
	layout["objective"] = {}
	var rooms := Rooms.new()
	for entry: Array in clip["enemies"]:
		var hp: int = rooms._scaled_enemy_max_hp(entry[0], 1)
		layout["enemies"].append({"id": layout["enemies"].size() + 1, "type": entry[0], "pos": hero + offset(entry[1]), "hp": hp, "max_hp": hp, "element": layout.get("element", "none")})
	for entry: Array in clip.get("traps", []):
		layout["traps"].append(rooms._trap_for_tile(hero + offset(entry[1]), entry[0], 1))
	var hand: Array[String] = hand_for(clip)
	var snapshot: Dictionary = runs._player_snapshot(run)
	snapshot["hp"] = snapshot["max_hp"]
	var state: Dictionary = Combat.new().create_combat(seed_value, layout, snapshot)
	# Only the hand is director-authored. Keep the default draw pile, costs,
	# turn budget and progression; an invented empty deck would add fatigue.
	state["deck"]["hand"] = hand.duplicate()
	for enemy: Dictionary in state["enemies"]:
		var forced: String = clip.get("forced_intents", {}).get(enemy["type"], "")
		if forced.is_empty(): continue
		for intent: Dictionary in Data.enemy_def(enemy["type"])["intents"]:
			if intent["id"] == forced: enemy["intent"] = intent.duplicate(true)
	run["mode"] = "combat"
	run["current_room_layout"] = layout
	run["combat_state"] = state
	return {"run": run, "state": state, "hero": hero, "layout": layout}

static func validate(fixture: Dictionary, clip: Dictionary) -> Array[String]:
	var errors: Array[String]
	var state: Dictionary = fixture["state"]
	var hero: Vector2i = fixture["hero"]
	if state["player"]["pos"] != hero or state["player"]["hp"] != state["player"]["max_hp"]: errors.append("hero position/full HP")
	if state["deck"]["hand"] != hand_for(clip): errors.append("hand")
	if state["enemies"].size() != clip["enemies"].size(): errors.append("enemy count")
	for index: int in range(clip["enemies"].size()):
		var expected: Array = clip["enemies"][index]
		var enemy: Dictionary = state["enemies"][index]
		if enemy["type"] != expected[0] or enemy["pos"] != hero + offset(expected[1]): errors.append("enemy placement")
		var forced: String = clip.get("forced_intents", {}).get(expected[0], "")
		if not forced.is_empty() and enemy.get("intent", {}).get("id", "") != forced: errors.append("forced intent")
		if enemy.get("intent", {}).is_empty(): errors.append("empty intent")
		var tile: Vector2i = enemy["pos"]
		if tile.x < 0 or tile.y < 0 or tile.y >= state["grid"].size() or tile.x >= state["grid"][0].size(): errors.append("enemy out of bounds")
	if state["traps"].size() != clip.get("traps", []).size(): errors.append("trap count")
	for index: int in range(clip.get("traps", []).size()):
		if state["traps"][index]["pos"] != hero + offset(clip["traps"][index][1]) or state["traps"][index]["element"] != clip["traps"][index][0]: errors.append("trap placement")
	if not state["surfaces"].is_empty() or not state["terrain"].is_empty(): errors.append("unlisted surfaces/props")
	return errors
