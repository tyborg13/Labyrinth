extends RefCounted

# Geometry for a declared direction, measured from the whole actor's front
# edge. Odd-width anchor-centered shapes are insufficient for a 2x2 body.
const Paths = preload("res://scripts/path_utils.gd")

static func footprint_shape(engine: RefCounted, state: Dictionary, origin: Vector2i, direction: Vector2i, action: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i]
	if direction == Vector2i.ZERO: return result
	var size_data: Array = action.get("pattern_footprint", [1, 1])
	var size := Vector2i(maxi(1, int(size_data[0])), maxi(1, int(size_data[1])))
	var side := Vector2i(-direction.y, direction.x)
	var body: Array[Vector2i] = []
	var front: int = -9999
	var back: int = 9999
	var left: int = 9999
	var right: int = -9999
	for y: int in range(size.y):
		for x: int in range(size.x):
			var tile := origin + Vector2i(x, y)
			body.append(tile)
			var forward: int = tile.x * direction.x + tile.y * direction.y
			var lateral: int = tile.x * side.x + tile.y * side.y
			front = maxi(front, forward)
			back = mini(back, forward)
			left = mini(left, lateral)
			right = maxi(right, lateral)
	var shape: String = str(action.get("committed_shape", action.get("guardian_shape", "line")))
	var reach: int = int(action.get("guardian_length", action.get("range", 1)))
	var candidates: Array[Vector2i] = []
	for distance: int in range(1, reach + 1):
		# Authored shoulders let a wide-body breath reach adjacent diagonal cells.
		# Default zero preserves existing and saved fans.
		var flank: int = maxi(distance - 1, int(action.get("pattern_min_flank", 0))) if shape == "fan" else 1 if shape == "crescent" else int(action.get("pattern_flank", 0))
		for lane: int in range(left - flank, right + flank + 1):
			candidates.append(direction * (front + distance) + side * lane)
	if shape == "crescent":
		for row: int in range(back, front + 1):
			candidates.append(direction * row + side * (left - 1))
			candidates.append(direction * row + side * (right + 1))
	for tile: Vector2i in candidates:
		if not Paths.is_passable(state["grid"], tile) or result.has(tile): continue
		# Cover is evaluated from the nearest edge, never through the dragon.
		var nearest: Vector2i = body[0]
		for source: Vector2i in body:
			if Paths.manhattan(source, tile) < Paths.manhattan(nearest, tile): nearest = source
		if engine.combat_line_of_sight(state, nearest, tile): result.append(tile)
	return result

# Radial patterns use distance from the whole body, preserving a close safe eye.
# A swept pattern uses only the movement path that actually survives obstacles,
# traps and surfaces; preview and resolution pass the same resolved route.
static func radial_shape(engine: RefCounted, state: Dictionary, origin: Vector2i, action: Dictionary) -> Array[Vector2i]:
	var size: Array = action.get("pattern_footprint",[1,1])
	var body_actor := {"pos":origin,"footprint":Vector2i(int(size[0]),int(size[1]))}
	var body: Array[Vector2i] = engine._enemy_footprint_tiles(body_actor)
	var result: Array[Vector2i]
	var minimum: int = maxi(1,int(action.get("minimum_range",1)))
	var maximum: int = int(action.get("range",1))
	for tile: Vector2i in engine._all_passable_tiles(state):
		var nearest: Vector2i = body[0]
		for source: Vector2i in body:
			if Paths.manhattan(source,tile)<Paths.manhattan(nearest,tile): nearest=source
		var distance: int = Paths.manhattan(nearest,tile)
		if distance>=minimum and distance<=maximum and engine.combat_line_of_sight(state,nearest,tile): result.append(tile)
	return result

static func swept_shape(engine: RefCounted, state: Dictionary, origin: Vector2i, action: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i]
	var route: Array[Vector2i]
	route.assign(action.get("_resolved_path",[origin]))
	for anchor: Vector2i in route:
		for tile: Vector2i in radial_shape(engine,state,anchor,action):
			if not result.has(tile): result.append(tile)
	return result
