extends RefCounted
const Combat = preload("res://scripts/combat_engine.gd")
const Data = preload("res://scripts/game_data.gd")
const SEED: int = 41027
const HERO_HP: int = 30
const GRID_SIZE: int = 9
const HERO := Vector2i(6, 4)
const ACTOR := Vector2i(1, 4)

static func enemy(type: String, id: int, tile: Vector2i, intent_id: String = "") -> Dictionary:
	var definition: Dictionary = Data.enemy_def(type)
	var intent: Dictionary = {}
	for entry: Dictionary in definition["intents"]:
		if entry["id"] == intent_id: intent = entry.duplicate(true)
	return {"id": id, "type": type, "pos": tile, "hp": definition["max_hp"], "max_hp": definition["max_hp"], "block": 0, "stoneskin": 0, "intent": intent}

static func state(units: Array, hero: Vector2i = HERO) -> Dictionary:
	var grid: Array
	for y: int in range(GRID_SIZE):
		var row: Array[String]
		for x: int in range(GRID_SIZE): row.append("wall" if x == 0 or y == 0 or x == GRID_SIZE - 1 or y == GRID_SIZE - 1 else "stone")
		grid.append(row)
	var layout: Dictionary = {"name": "thr-01 proof", "coord": Vector2i(1, 0), "type": "combat", "depth": 1, "umbra_stage": "clear", "element": "lightning", "grid": grid, "player_start": hero, "enemies": units, "terrain": [], "traps": [], "loot": []}
	var engine := Combat.new()
	var result: Dictionary = engine.create_combat(SEED, layout, {"hp": HERO_HP, "max_hp": HERO_HP, "deck_cards": ["quick_stab"], "relics": [], "hand_size": 1})
	for index: int in range(units.size()):
		if not units[index]["intent"].is_empty(): result["enemies"][index]["intent"] = units[index]["intent"].duplicate(true)
	return engine._initialize_initiative_queue(result)

static func bolt() -> Dictionary:
	return state([enemy("arc_thrall", 1, ACTOR, "arc_bolt")])
