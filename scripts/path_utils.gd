extends RefCounted
class_name PathUtils

const DIRS_4: Array[Vector2i] = [
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 0)
]

const BLOCKING_TILES: Array[String] = ["wall", "pillar", "door"]

static func is_in_bounds(grid: Array, tile: Vector2i) -> bool:
	if tile.y < 0 or tile.y >= grid.size():
		return false
	var row: Array = grid[tile.y]
	return tile.x >= 0 and tile.x < row.size()

static func tile_id(grid: Array, tile: Vector2i) -> String:
	if not is_in_bounds(grid, tile):
		return "void"
	return str((grid[tile.y] as Array)[tile.x])

static func is_passable(grid: Array, tile: Vector2i) -> bool:
	if not is_in_bounds(grid, tile):
		return false
	var terrain: String = tile_id(grid, tile)
	return not BLOCKING_TILES.has(terrain)

static func manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

static func reachable_tiles(grid: Array, start: Vector2i, max_distance: int, occupied: Dictionary = {}) -> Array[Vector2i]:
	var results: Array[Vector2i] = []
	if max_distance < 0 or not is_passable(grid, start):
		return results
	var queue: Array[Vector2i] = [start]
	var distance_by_tile: Dictionary = {start: 0}
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		var current_distance: int = int(distance_by_tile.get(current, 0))
		if current_distance > 0:
			results.append(current)
		if current_distance >= max_distance:
			continue
		for dir: Vector2i in DIRS_4:
			var next_tile: Vector2i = current + dir
			if distance_by_tile.has(next_tile):
				continue
			if not is_passable(grid, next_tile):
				continue
			if occupied.has(next_tile):
				continue
			distance_by_tile[next_tile] = current_distance + 1
			queue.append(next_tile)
	return results

static func find_path(grid: Array, start: Vector2i, goal: Vector2i, occupied: Dictionary = {}, allow_goal_occupied: bool = false) -> Array[Vector2i]:
	var empty: Array[Vector2i] = []
	if start == goal:
		return [start]
	if not is_in_bounds(grid, start) or not is_in_bounds(grid, goal):
		return empty
	var frontier: Array[Vector2i] = [start]
	var came_from: Dictionary = {start: start}
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		if current == goal:
			break
		for dir: Vector2i in DIRS_4:
			var next_tile: Vector2i = current + dir
			if came_from.has(next_tile):
				continue
			if not is_passable(grid, next_tile):
				continue
			var blocked: bool = occupied.has(next_tile) and (next_tile != goal or not allow_goal_occupied)
			if blocked:
				continue
			came_from[next_tile] = current
			frontier.append(next_tile)
	if not came_from.has(goal):
		return empty
	var path: Array[Vector2i] = [goal]
	var cursor: Vector2i = goal
	while cursor != start:
		cursor = came_from[cursor]
		path.push_front(cursor)
	return path

static func has_line_of_sight(grid: Array, start: Vector2i, goal: Vector2i) -> bool:
	if start == goal:
		return true
	for point: Vector2i in _supercover_line(start, goal):
		if point == start or point == goal:
			continue
		if not is_passable(grid, point):
			return false
	return true

static func diamond_tiles(center: Vector2i, radius: int, grid: Array = []) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for dy: int in range(-radius, radius + 1):
		for dx: int in range(-radius, radius + 1):
			var candidate: Vector2i = center + Vector2i(dx, dy)
			if absi(dx) + absi(dy) > radius:
				continue
			if not grid.is_empty() and not is_in_bounds(grid, candidate):
				continue
			result.append(candidate)
	return result

static func _supercover_line(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var x0: int = start.x
	var y0: int = start.y
	var x1: int = goal.x
	var y1: int = goal.y
	var dx: int = absi(x1 - x0)
	var dy: int = absi(y1 - y0)
	var sx: int = 1 if x0 < x1 else -1
	var sy: int = 1 if y0 < y1 else -1
	var err: int = dx - dy
	result.append(Vector2i(x0, y0))
	while x0 != x1 or y0 != y1:
		var e2: int = err * 2
		if e2 > -dy:
			err -= dy
			x0 += sx
		if e2 < dx:
			err += dx
			y0 += sy
		var point: Vector2i = Vector2i(x0, y0)
		if not result.has(point):
			result.append(point)
	return result
