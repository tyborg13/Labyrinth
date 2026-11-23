extends RefCounted

const Groups = preload("res://scripts/board_hud_group_placement.gd")

# Keep the base seat and any existing enemy pairs unless a local move clears
# the hero. Each accepted move preserves the current count for every peer.
static func offsets(hero: Array[Rect2], enemies: Dictionary, half_tile: float, chip_height: float, other: Array[Rect2], bounds: Rect2, reserved: Array[Rect2]) -> Dictionary:
	var result: Dictionary = {}
	var occupied: Dictionary = enemies.duplicate()
	for key: String in enemies:
		var pieces: Array[Rect2] = occupied[key]
		if _overlaps(pieces, Vector2.ZERO, hero) == 0: continue
		occupied.erase(key)
		var limits := Vector2(half_tile, pieces[0].size.y + chip_height)
		var offset: Vector2 = nearest(pieces, hero, occupied, other, bounds, reserved, limits)
		if offset != Vector2.ZERO: result[key] = offset
		occupied[key] = Groups.translate_rects(pieces, offset)
	return result

static func nearest(pieces: Array[Rect2], hero: Array[Rect2], peers: Dictionary, other: Array[Rect2], bounds: Rect2, reserved: Array[Rect2], limits: Vector2) -> Vector2:
	if _overlaps(pieces, Vector2.ZERO, hero) == 0: return Vector2.ZERO
	var direction: float = signf(pieces[0].get_center().x - Groups.pieces_bounds(hero).get_center().x)
	var x_min: float = -limits.x if direction <= 0.0 else 0.0
	var x_max: float = limits.x if direction >= 0.0 else 0.0
	var reach: Rect2 = Groups.pieces_bounds(pieces).grow_individual(-x_min, limits.y, x_max, 0.0)
	var hard: Array[Rect2] = reserved.duplicate()
	hard.append_array(other)
	var obstacles: Array[Rect2] = hero.duplicate()
	obstacles.append_array(hard)
	var before: Dictionary = {}
	for key: String in peers:
		before[key] = _overlaps(pieces, Vector2.ZERO, peers[key])
		obstacles.append_array(peers[key])

	var xs: Array[float]
	var ys: Array[float]
	_add_axis(xs, x_min, x_min, x_max)
	_add_axis(xs, x_max, x_min, x_max)
	_add_axis(ys, -limits.y, -limits.y, 0.0)
	if bounds.has_area():
		var group: Rect2 = Groups.pieces_bounds(pieces)
		_add_axis(xs, bounds.position.x - group.position.x, x_min, x_max)
		_add_axis(xs, bounds.end.x - group.end.x, x_min, x_max)
		_add_axis(ys, bounds.position.y - group.position.y, -limits.y, 0.0)
		_add_axis(ys, bounds.end.y - group.end.y, -limits.y, 0.0)
	for obstacle: Rect2 in obstacles:
		if not reach.intersects(obstacle, true): continue
		for piece: Rect2 in pieces:
			if not piece.grow_individual(-x_min, limits.y, x_max, 0.0).intersects(obstacle, true): continue
			# Keep translated edges clear through float32 position and end rounding.
			var rounding: Vector2 = piece.position.abs().max(piece.end.abs()).max(obstacle.position.abs()).max(obstacle.end.abs()) * (2.0 * Groups.FLOAT32_EPSILON)
			_add_axis(xs, obstacle.position.x - piece.end.x - rounding.x, x_min, x_max)
			_add_axis(xs, obstacle.end.x - piece.position.x + rounding.x, x_min, x_max)
			_add_axis(ys, obstacle.position.y - piece.end.y - rounding.y, -limits.y, 0.0)
			_add_axis(ys, obstacle.end.y - piece.position.y + rounding.y, -limits.y, 0.0)
	xs.sort_custom(func(a: float, b: float) -> bool: return a > b if absf(a) == absf(b) else absf(a) < absf(b))
	ys.sort()
	ys.reverse()

	for x: float in xs:
		var offset := Vector2(x, 0.0)
		if _is_free(pieces, offset, hero, peers, before, bounds, hard): return offset
	for y: float in ys:
		var offset := Vector2(0.0, y)
		if _is_free(pieces, offset, hero, peers, before, bounds, hard): return offset

	var best := Vector2.ZERO
	var distance: float = INF
	for x: float in xs:
		for y: float in ys:
			var offset := Vector2(x, y)
			var cost: float = offset.length_squared()
			if cost >= distance: break
			if not _is_free(pieces, offset, hero, peers, before, bounds, hard): continue
			best = offset
			distance = cost
			break
	return best

static func _add_axis(axis: Array[float], value: float, lower: float, upper: float) -> void:
	if value != 0.0 and value >= lower and value <= upper and not axis.has(value):
		axis.append(value)

static func _is_free(pieces: Array[Rect2], offset: Vector2, hero: Array[Rect2], peers: Dictionary, before: Dictionary, bounds: Rect2, hard: Array[Rect2]) -> bool:
	if not Groups.allowed(pieces, offset, bounds, hard) or _overlaps(pieces, offset, hero) != 0: return false
	for key: String in peers:
		if _overlaps(pieces, offset, peers[key]) > int(before[key]): return false
	return true

static func _overlaps(pieces: Array[Rect2], offset: Vector2, obstacles: Array[Rect2]) -> int:
	var count: int = 0
	for piece: Rect2 in pieces:
		var shifted := Rect2(piece.position + offset, piece.size)
		for obstacle: Rect2 in obstacles:
			if shifted.intersects(obstacle, false): count += 1
	return count
