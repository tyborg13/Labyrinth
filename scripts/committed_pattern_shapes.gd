extends RefCounted

# Geometry for a declared direction, measured from the whole actor's front
# edge. Odd-width anchor-centered shapes are insufficient for a 2x2 body.
const Paths = preload("res://scripts/path_utils.gd")
const PROJECTION_LIMIT: int = 9999

static func footprint_size(action: Dictionary) -> Vector2i:
	var size: Array = action.get("pattern_footprint", [1, 1])
	return Vector2i(maxi(1, int(size[0])), maxi(1, int(size[1])))

# For any cardinal direction, every projection must fit both at the world
# anchor and at zero for translation to preserve the legacy extrema.
static func can_translate_footprint(origin: Vector2i, size: Vector2i) -> bool:
	return (
		maxi(size.x, size.y) - 1 <= PROJECTION_LIMIT
		and mini(origin.x, origin.y) >= -PROJECTION_LIMIT
		and maxi(origin.x + size.x - 1, origin.y + size.y - 1) <= PROJECTION_LIMIT
	)

static func footprint_offsets(direction: Vector2i, action: Dictionary, size: Vector2i, origin: Vector2i = Vector2i.ZERO) -> Array[Vector2i]:
	var offsets: Array[Vector2i]
	if direction == Vector2i.ZERO: return offsets
	var side := Vector2i(-direction.y, direction.x)
	var forward: int = origin.x * direction.x + origin.y * direction.y
	var lateral: int = origin.x * side.x + origin.y * side.y
	var forward_x: int = direction.x * (size.x - 1)
	var forward_y: int = direction.y * (size.y - 1)
	var lateral_x: int = side.x * (size.x - 1)
	var lateral_y: int = side.y * (size.y - 1)
	var front: int = maxi(-PROJECTION_LIMIT, forward + maxi(0, forward_x) + maxi(0, forward_y))
	var back: int = mini(PROJECTION_LIMIT, forward + mini(0, forward_x) + mini(0, forward_y))
	var left: int = mini(PROJECTION_LIMIT, lateral + mini(0, lateral_x) + mini(0, lateral_y))
	var right: int = maxi(-PROJECTION_LIMIT, lateral + maxi(0, lateral_x) + maxi(0, lateral_y))
	var shape: String = str(action.get("committed_shape", action.get("guardian_shape", "line")))
	var reach: int = int(action.get("guardian_length", action.get("range", 1)))
	for distance: int in range(1, reach + 1):
		# Authored shoulders let a wide-body breath reach adjacent diagonal cells.
		var flank: int = maxi(distance - 1, int(action.get("pattern_min_flank", 0))) if shape == "fan" else 1 if shape == "crescent" else int(action.get("pattern_flank", 0))
		for lane: int in range(left - flank, right + flank + 1):
			offsets.append(direction * (front + distance) + side * lane)
	if shape == "crescent":
		for row: int in range(back, front + 1):
			offsets.append(direction * row + side * (left - 1))
			offsets.append(direction * row + side * (right + 1))
	return offsets

static func footprint_shape(engine: RefCounted, state: Dictionary, origin: Vector2i, direction: Vector2i, action: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i]
	if direction == Vector2i.ZERO: return result
	var size: Vector2i = footprint_size(action)
	var candidates: Array[Vector2i] = footprint_offsets(direction, action, size, origin)
	# Tharokh's retained lanes crossed its old spires. Keep that geometry when
	# Upheaval uses ordinary sight-blocking Outcrops; only the source's stone
	# is transparent to this flagged attack. Movement still uses the real board.
	var sight_state: Dictionary = state
	if bool(action.get("preserve_owned_terrain", false)):
		var stone: Array[Dictionary] = engine._dragon_spires(state)
		if not stone.is_empty():
			sight_state = state.duplicate(false)
			sight_state["terrain"] = state.get("terrain", []).filter(func(entry: Dictionary) -> bool: return not stone.has(entry))
	for tile: Vector2i in candidates:
		if not Paths.is_passable(state["grid"], tile) or result.has(tile): continue
		# Cover is evaluated from the nearest edge, never through the dragon.
		var nearest: Vector2i = closest_footprint_tile(origin, size, tile)
		if engine.combat_line_of_sight(sight_state, nearest, tile): result.append(tile)
	return result

static func closest_footprint_tile(origin: Vector2i, size: Vector2i, tile: Vector2i) -> Vector2i:
	return Vector2i(clampi(tile.x, origin.x, origin.x + size.x - 1), clampi(tile.y, origin.y, origin.y + size.y - 1))

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

static func swept_shape(engine: RefCounted, state: Dictionary, origin: Vector2i, action: Dictionary, radial_cache: Variant = null) -> Array[Vector2i]:
	# A planner may share this private cache across its candidate paths. Ordinary
	# calls own a fresh cache; nothing survives a board/action/status change.
	var footprints: Dictionary = radial_cache if radial_cache is Dictionary else {}
	var result: Array[Vector2i]
	var route: Array[Vector2i]
	route.assign(action.get("_resolved_path",[origin]))
	for anchor: Vector2i in route:
		if not footprints.has(anchor): footprints[anchor] = radial_shape(engine,state,anchor,action)
		for tile: Vector2i in footprints[anchor]:
			if not result.has(tile): result.append(tile)
	return result
