extends RefCounted

# Fixed fields are separate from a dragon's moving body. Store their anchors in
# the revealed action so a dodge, displacement or reload cannot retarget them.
const Paths = preload("res://scripts/path_utils.gd")
const Surfaces = preload("res://scripts/board_surface_rules.gd")

static func vectors(values: Array) -> Array[Vector2i]:
	var result: Array[Vector2i]
	result.assign(values)
	return result

static func band_tiles(engine: RefCounted, state: Dictionary, enemy: Dictionary, count: int) -> Array[Vector2i]:
	var target: Vector2i = state["player"]["pos"]
	var direction: Vector2i = engine._cardinal_direction(target - engine._closest_enemy_tile_to(enemy, target))
	if direction == Vector2i.ZERO: direction = Vector2i.LEFT
	var side := Vector2i(-direction.y, direction.x)
	var choices: Array[Vector2i] = vectors([target, target + side, target - side,
		target + side * 2, target - side * 2, target + side * 2 + direction, target - side * 2 - direction])
	var result: Array[Vector2i]
	for tile: Vector2i in choices:
		if result.size() >= count: break
		if _field_floor(engine, state, tile): result.append(tile)
	# At an edge, fold the band along available ground instead of losing half
	# its pressure. Prefer adjacent cells; never overwrite occupied terrain.
	while result.size() < count:
		var best := Vector2i(-1, -1)
		var best_score: int = -99999
		for tile: Vector2i in engine._all_passable_tiles(state):
			if result.has(tile) or not _field_floor(engine, state, tile): continue
			var nearest: int = 99
			for placed: Vector2i in result: nearest = mini(nearest, Paths.manhattan(placed, tile))
			var score: int = -nearest * 20 - Paths.manhattan(target, tile)
			if score > best_score:
				best_score = score
				best = tile
		if best.x < 0: break
		result.append(best)
	return result

static func _field_floor(engine: RefCounted, state: Dictionary, tile: Vector2i) -> bool:
	return Surfaces.can_place(state, tile) and engine._enemy_index_at_tile(state, tile) < 0

static func source_tiles(state: Dictionary, enemy: Dictionary, action: Dictionary) -> Array[Vector2i]:
	var kind: String = str(action.get("snapshot_surface", "electrified"))
	var key: String = str(action.get("snapshot_key", ""))
	var candidates: Array[Vector2i] = Surfaces.tiles(state, kind) if key.is_empty() else vectors(enemy.get(key, []))
	return vectors(candidates.filter(func(tile: Vector2i) -> bool: return Surfaces.has_surface(state, tile, kind)))

static func neighborhood(engine: RefCounted, state: Dictionary, centers: Array[Vector2i], radius: int) -> Array[Vector2i]:
	var result: Array[Vector2i]
	for center: Vector2i in centers:
		for tile: Vector2i in Paths.diamond_tiles(center, maxi(0, radius), state["grid"]):
			if not result.has(tile) and Paths.is_passable(state["grid"], tile) and engine.combat_line_of_sight(state, center, tile): result.append(tile)
	return result

static func refuge_tiles(engine: RefCounted, state: Dictionary, action: Dictionary) -> Array[Vector2i]:
	# Current warnings contest the player's declared position, including their
	# own Light. The area never follows later movement. Unflagged saved actions
	# retain the original nearest-brazier anchor.
	if str(action.get("field_anchor", "")) == "player":
		action["field_center"] = state["player"]["pos"]
		return neighborhood(engine, state, vectors([action["field_center"]]), int(action.get("field_radius", 2)))
	var choices: Array = state.get("guardian_braziers", []).duplicate()
	choices.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var da: int = Paths.manhattan(a["pos"], state["player"]["pos"])
		var db: int = Paths.manhattan(b["pos"], state["player"]["pos"])
		return da < db if da != db else int(a["id"]) < int(b["id"]))
	if choices.is_empty(): return vectors([])
	action["refuge_id"] = int(choices[0]["id"])
	action["field_center"] = choices[0]["pos"]
	return neighborhood(engine, state, vectors([choices[0]["pos"]]), int(action.get("field_radius", 2)))

static func retire_owned_surface(state: Dictionary, enemy: Dictionary, action: Dictionary) -> void:
	if not bool(action.get("replace_owned_field", false)): return
	var kind: String = str(action.get("surface", ""))
	var removed: Array[Vector2i]
	for tile: Vector2i in Surfaces.tiles(state, kind):
		var owner: Dictionary = Surfaces.surface_at(state, tile).get("elemental_source", {})
		if str(owner.get("actor_kind", "")) == "enemy" and int(owner.get("actor_id", -1)) == int(enemy["id"]):
			Surfaces.remove(state, tile, kind, "dragon_field_replaced")
			removed.append(tile)
	if not removed.is_empty():
		Surfaces.record_event(state, {"kind":"dragon_field_replaced", "surface":kind, "tiles":removed,
			"source":{"actor_kind":"enemy", "actor_id":enemy["id"]}})
