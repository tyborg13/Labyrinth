extends RefCounted
## Skybreak's held field. Only this local hash orders candidates; no RNG calls.
const Paths = preload("res://scripts/path_utils.gd")
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const NEAR_COUNT: int = 4
const SAFE_COUNT: int = 3

static func tiles(engine: RefCounted, state: Dictionary, enemy: Dictionary, count: int) -> Array[Vector2i]:
	var hero: Vector2i = state["player"]["pos"]
	var seed: int = int(state.get("fight_seed", state.get("rng_state", 0)))
	var cycle: int = int(enemy.get("dragon_cycle", 0))
	var candidates: Array[Vector2i]
	for tile: Vector2i in engine._all_passable_tiles(state):
		if Surfaces.can_place(state, tile) and engine._enemy_index_at_tile(state, tile) < 0: candidates.append(tile)
	var refuge: Array[Vector2i] = _reachable(candidates, hero)
	var result: Array[Vector2i]
	if count <= 0: return result
	if candidates.has(hero) and _accept(hero, result, refuge): result.append(hero)
	var near: Array[Vector2i]
	for tile: Vector2i in candidates:
		var distance: int = Paths.manhattan(hero, tile)
		if distance >= 2 and distance <= 3: near.append(tile)
	near.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return _before(a, b, seed, cycle))
	var near_target: int = mini(count, 1 + NEAR_COUNT)
	var selected_near: Array[Vector2i] = _near_selection(near, 0, result, refuge, near_target)
	if not selected_near.is_empty(): result = selected_near
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var a_close: bool = Paths.manhattan(hero, a) <= 5
		var b_close: bool = Paths.manhattan(hero, b) <= 5
		return a_close if a_close != b_close else _before(a, b, seed, cycle))
	for tile: Vector2i in candidates:
		if result.size() >= count: break
		if _accept(tile, result, refuge): result.append(tile)
	# Exhausted/obstructed boards yield fewer marks rather than violate safety.
	return result

static func _near_selection(candidates: Array[Vector2i], start: int, marked: Array[Vector2i], refuge: Array[Vector2i], target: int) -> Array[Vector2i]:
	if marked.size() >= target: return marked
	for i: int in range(start, candidates.size()):
		if not _accept(candidates[i], marked, refuge): continue
		var branch: Array[Vector2i] = marked.duplicate()
		branch.append(candidates[i])
		var found: Array[Vector2i] = _near_selection(candidates, i + 1, branch, refuge, target)
		if not found.is_empty(): return found
	var empty: Array[Vector2i]
	return empty

static func _accept(tile: Vector2i, marked: Array[Vector2i], refuge: Array[Vector2i]) -> bool:
	for other: Vector2i in marked:
		if Paths.manhattan(tile, other) < 2: return false
	var safe: int = 0
	for other: Vector2i in refuge:
		if other != tile and not marked.has(other): safe += 1
	return safe >= SAFE_COUNT

static func _reachable(floor_tiles: Array[Vector2i], hero: Vector2i) -> Array[Vector2i]:
	var reached: Array[Vector2i]
	var frontier: Array[Vector2i]
	frontier.append(hero)
	for _step: int in range(2):
		var next: Array[Vector2i]
		for tile: Vector2i in frontier:
			for direction: Vector2i in Paths.DIRS_4:
				var adjacent: Vector2i = tile + direction
				if adjacent == hero or reached.has(adjacent) or not floor_tiles.has(adjacent): continue
				reached.append(adjacent)
				next.append(adjacent)
		frontier = next
	return reached

static func _hash(tile: Vector2i, seed: int, cycle: int) -> int:
	var value: int = (seed ^ ((cycle + 1) * 92821)) & 0x7fffffff
	value = (value * 1103515245 + tile.x * 68917 + tile.y * 28307 + 12345) & 0x7fffffff
	value = ((value ^ (value >> 16)) * 1103515245 + 12345) & 0x7fffffff
	return value ^ (value >> 15)

static func _before(a: Vector2i, b: Vector2i, seed: int, cycle: int) -> bool:
	var ha: int = _hash(a, seed, cycle)
	var hb: int = _hash(b, seed, cycle)
	if ha != hb: return ha < hb
	return a.y < b.y if a.y != b.y else a.x < b.x
