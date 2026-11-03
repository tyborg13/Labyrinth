extends RefCounted

# Permanent production-combat fixture; no captured baseline or absolute paths.
const Data = preload("res://scripts/game_data.gd")
const FIXTURE_SEED: int = 611
const BOARD_SIZE: int = 11
const FIXTURE_HP: int = 100

static func fixture(engine: RefCounted, type: String, seed_value: int) -> Dictionary:
	var grid: Array
	for y: int in range(BOARD_SIZE):
		var row: Array[String]
		for x: int in range(BOARD_SIZE): row.append("wall" if x == 0 or y == 0 or x == BOARD_SIZE - 1 or y == BOARD_SIZE - 1 else "stone")
		grid.append(row)
	var room: Dictionary = {"coord": Vector2i(1, 0), "depth": 2, "type": "combat", "grid": grid, "player_start": Vector2i(5, 5), "enemies": [{"id": 1, "type": type, "pos": Vector2i(5, 2), "hp": FIXTURE_HP, "max_hp": FIXTURE_HP}], "terrain": [], "traps": [], "loot": []}
	var state: Dictionary = engine.create_combat(seed_value, room, {"hp": FIXTURE_HP, "max_hp": FIXTURE_HP, "deck_cards": ["quick_stab", "brace"], "skill_ids": [], "relics": [], "hand_size": 1})
	state.erase("umbra")
	return state

static func intent(type: String, id: String) -> Dictionary:
	for entry: Dictionary in Data.enemy_def(type)["intents"]:
		if str(entry["id"]) == id: return entry.duplicate(true)
	return {}

static func save_comparable(value: Variant) -> Variant:
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value:
			if key == "tile_filter": continue
			# Ice's surface was implicit before mrk-01; it is now a data dial.
			if key == "surface" and str(value.get("type", "")) == "icefall_land": continue
			if key == "ignore_line_of_sight" and str(value.get("type", "")) == "icefall_mark": continue
			result[key] = save_comparable(value[key])
		return result
	if value is Array:
		var result: Array
		for entry: Variant in value: result.append(save_comparable(entry))
		return result
	return value
