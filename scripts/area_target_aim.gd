extends RefCounted

const BoardSurfaceRules = preload("res://scripts/board_surface_rules.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")
const PathUtils = preload("res://scripts/path_utils.gd")
const TypedArrays = preload("res://scripts/typed_arrays.gd")

const INVALID_CENTER := Vector2i(-1, -1)
const NO_HIT_DISTANCE: int = 0x7fffffff

# Score the prospective footprint against enemies targetable at decision time.
static func placement(engine: CombatEngine, state: Dictionary, information: Dictionary, action: Dictionary, centers: Array[Vector2i], fallback: Vector2i) -> Dictionary:
	var best: Dictionary = {"direction": fallback, "center": INVALID_CENTER}
	if str(action.get("aim", "")) == "facing" or str(action.get("type", "")) == "outcrop":
		# A facing attack follows the chosen tile. Outcrops only rise on empty floor.
		return best
	var visible: Dictionary = engine.umbra_visible_tile_lookup(information)
	var targetable: Dictionary = {}
	for enemy: Dictionary in information.get("enemies", []):
		if engine.is_enemy_targetable_by_player(information, enemy, action, visible):
			targetable[enemy["id"]] = true
	if targetable.is_empty(): return best
	var directions: Array[Vector2i] = TypedArrays.vector2i([Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP])
	directions.erase(fallback)
	directions.push_front(fallback)
	# Only an attack line uses proximity to break a hit-count tie. Other
	# areas and surfaces keep the authored direction when hits are equal.
	var prefer_near: bool = str(action.get("type", "")) in ["aoe", "meteor_marks"] and is_line(engine._aoe_pattern_offsets(action))
	var hero: Vector2i = state.get("player", {}).get("pos", Vector2i.ZERO)
	var best_score := Vector2i(0, NO_HIT_DISTANCE)
	var aimed: Dictionary = action.duplicate(false)
	for candidate: Vector2i in directions:
		aimed["orientation"] = candidate
		for center: Vector2i in centers:
			var score: Vector2i = _score(engine, state, aimed, center, targetable, prefer_near, hero)
			if score.x > best_score.x or (score.x == best_score.x and score.y < best_score.y):
				best_score = score
				best = {"direction": candidate, "center": center}
	return best


static func is_line(offsets: Array[Vector2i]) -> bool:
	if offsets.size() < 2: return false
	var horizontal: bool = true
	var vertical: bool = true
	for offset: Vector2i in offsets:
		horizontal = horizontal and offset.y == offsets[0].y
		vertical = vertical and offset.x == offsets[0].x
	return horizontal or vertical


static func _score(engine: CombatEngine, state: Dictionary, action: Dictionary, center: Vector2i, targetable: Dictionary, prefer_near: bool, hero: Vector2i) -> Vector2i:
	var action_type: String = str(action.get("type", ""))
	var tiles: Array[Vector2i]
	match action_type:
		"aoe", "meteor_marks":
			tiles = engine.aoe_tiles_for_player_action(state, action, center)
		"surface":
			for tile: Vector2i in engine._surface_action_tiles(state, action, center):
				if BoardSurfaceRules.can_place(state, tile):
					tiles.append(tile)
		_:
			return Vector2i(0, NO_HIT_DISTANCE)
	var hits: int = 0
	var nearest: int = NO_HIT_DISTANCE
	for index: int in engine._enemy_indices_in_tiles(state, tiles):
		var enemy: Dictionary = state["enemies"][index]
		if not targetable.has(enemy["id"]): continue
		hits += 1
		if prefer_near:
			for tile: Vector2i in engine._enemy_footprint_tiles(enemy):
				if tiles.has(tile): nearest = mini(nearest, PathUtils.manhattan(hero, tile))
	return Vector2i(hits, nearest)
