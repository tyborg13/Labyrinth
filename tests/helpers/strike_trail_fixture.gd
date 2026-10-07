extends RefCounted
const Combat = preload("res://scripts/combat_engine.gd")
const LOADOUTS: Dictionary = {"sword": "iron_cleaver", "heavy": "war_maul", "stab": "duelist_rapier",
	"thrust": "hunting_spear", "lash": "galewhip", "bow": "stormstring_bow", "repeater": "windlass_repeater"}

static func state(direction: Vector2i = Vector2i(0, 1)) -> Dictionary:
	var grid: Array = []
	for y: int in range(7):
		var row: Array = []
		for x: int in range(7):
			row.append("wall" if x == 0 or y == 0 or x == 6 or y == 6 else "stone")
		grid.append(row)
	var layout: Dictionary = {"name": "Strike Trail Trial", "coord": Vector2i(4, 3), "type": "combat", "grid": grid,
		"player_start": Vector2i(3, 3), "enemies": [{"id": 1, "type": "crawler", "pos": Vector2i(3, 3) + direction, "hp": 80, "max_hp": 80, "block": 0}],
		"traps": [], "terrain": [], "element": "none"}
	return Combat.new().create_combat(173, layout, {"hp": 24, "max_hp": 24, "deck_cards": ["quick_stab", "brace"], "relics": [], "hand_size": 5, "heal_bonus": 0})
