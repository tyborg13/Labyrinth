extends RefCounted

## rr-04 replaces the historical whole-body idle/meshed anatomy contract.
## Keep the shared fixture API for existing probes; validate the maquette runtime.
static func run(tree: SceneTree, expect: Callable) -> void:
	await preload("res://tests/maquette_cutout/runtime_suite.gd").run(tree, expect, "bile_bloomer")

static func fixture_state() -> Dictionary:
	var grid: Array = []
	for y: int in range(8):
		var row: Array = []
		for x: int in range(8):
			row.append("wall" if x == 0 or y == 0 or x == 7 or y == 7 else "stone")
		grid.append(row)
	return {"grid": grid, "room_coord": Vector2i(4, 3), "terrain": [], "traps": [], "loot": [],
		"player": {"pos": Vector2i(4, 3), "hp": 40, "max_hp": 40},
		"enemies": [{"id": 1, "type": "bile_bloomer", "pos": Vector2i(3, 3), "hp": 14, "max_hp": 14},
			{"id": 2, "type": "bile_bloomer", "pos": Vector2i(5, 5), "hp": 14, "max_hp": 14},
			{"id": 3, "type": "warden", "pos": Vector2i(6, 6), "hp": 18, "max_hp": 18}]}
