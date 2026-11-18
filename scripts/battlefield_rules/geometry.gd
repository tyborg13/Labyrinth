extends RefCounted
## Tiles affected by the rule if it fires on this board.
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const Paths = preload("res://scripts/path_utils.gd")
const Gust = preload("res://scripts/battlefield_rules/gust.gd")
static func toward_player(engine: RefCounted, state: Dictionary, instance: Dictionary) -> Vector2i:
	var source: Dictionary = engine._surface_actor(state, "enemy", int(instance["source"]["id"]))
	return engine._cardinal_direction(Vector2i(state["player"]["pos"]) - Vector2i(source["pos"]))

static func affected_tiles(engine: RefCounted, state: Dictionary, instance: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i]
	for tile: Vector2i in candidate_tiles(engine, state, instance):
		if Surfaces.can_place(state, tile): result.append(tile)
	return result

static func candidate_tiles(engine: RefCounted, state: Dictionary, instance: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i]
	match str(instance["rule"]):
		"lightning_storm": result.assign(Surfaces.tiles(state, "electrified"))
		"frostbite": result.assign(Surfaces.tiles(state, "ice"))
		"wildfire":
			var directions: Array[Vector2i]
			match str(instance["dials"]["spread"]):
				"all": directions.assign(Paths.DIRS_4)
				"toward_player": directions.append(toward_player(engine, state, instance))
				"away_from_entry": directions.append(-Gust.entry_direction(state))
			for tile: Vector2i in Surfaces.tiles(state, "fire"):
				for axis: Vector2i in directions:
					var destination: Vector2i = tile + axis
					if Surfaces.can_place(state, destination) and Surfaces.element_at(state, destination) != "fire" and not result.has(destination): result.append(destination)
	return result
