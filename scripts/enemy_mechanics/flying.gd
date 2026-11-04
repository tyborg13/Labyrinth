extends RefCounted

const TypedArrays = preload("res://scripts/typed_arrays.gd")
const Data = preload("res://scripts/game_data.gd")
const Paths = preload("res://scripts/path_utils.gd")

static func flying(unit: Dictionary) -> bool:
	return bool(Data.enemies().get(str(unit.get("type", "")), {}).get("flying", false))

static func navigation(engine: RefCounted, state: Dictionary, unit: Dictionary, budget: int, occupied: Dictionary) -> Dictionary:
	var paths: Dictionary = {unit["pos"]: engine._vector2i_values([unit["pos"]])}
	var queue: Array[Vector2i] = engine._vector2i_values([unit["pos"]])
	var cursor: int = 0
	while cursor < queue.size():
		var from: Vector2i = queue[cursor]; cursor += 1
		var path: Array[Vector2i] = engine._vector2i_values(paths[from])
		if path.size() > budget: continue
		for direction: Vector2i in Paths.DIRS_4:
			var to: Vector2i = from + direction
			if paths.has(to) or not Paths.is_passable(state.get("grid", []), to): continue
			if occupied.has(to): continue
			var next: Array[Vector2i] = TypedArrays.vector2i(path.duplicate()); next.append(to)
			paths[to] = next; queue.append(to)
	var costs: Dictionary = {}; var hazards: Dictionary = {}
	for tile: Vector2i in paths.keys():
		if engine._terrain_index_at_tile(state, tile) >= 0: paths.erase(tile); continue
		costs[tile] = paths[tile].size() - 1; hazards[tile] = 0
	return {"paths": paths, "costs": costs, "hazards": hazards}
