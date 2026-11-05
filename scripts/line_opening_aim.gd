extends RefCounted

const TypedArrays = preload("res://scripts/typed_arrays.gd")
const SurfaceCards = preload("res://scripts/surface_card_rules.gd")

# Selection only: compare legal line placements using the real damage resolver.
# The caller supplies known information, so opening aim cannot reveal hidden foes.
# Preserve the authored/default direction on ties, including no damaging hits.
static func direction(engine: RefCounted, state: Dictionary, action: Dictionary, fallback: Vector2i) -> Vector2i:
	if not engine.player_action_needs_orientation(action) or str(action.get("aim", "")) == "facing": return fallback
	var offsets: Array[Vector2i] = engine._aoe_pattern_offsets(action)
	if not _is_line(offsets): return fallback
	var directions: Array[Vector2i] = TypedArrays.vector2i([Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP])
	directions.erase(fallback)
	directions.push_front(fallback)
	var best: Vector2i = fallback
	var best_hits: int = 0
	for candidate: Vector2i in directions:
		var aimed: Dictionary = action.duplicate(true)
		aimed["orientation"] = candidate
		for target: Vector2i in engine.valid_targets_for_player_action(state, aimed):
			var tiles: Array[Vector2i] = engine.aoe_tiles_for_player_action(state, aimed, target)
			var indices: Array[int] = engine._enemy_indices_in_tiles(state, tiles)
			if indices.size() <= best_hits: continue
			var after: Dictionary = engine.surface_preview_for_player_action(state, aimed, target, true)["state"]
			if str(action.get("type", "")) == "meteor_marks":
				# Compare this delayed line's impact on current occupants alone.
				after[SurfaceCards.METEOR_STATE_KEY] = [SurfaceCards.meteor_marks(after).back()]
				after = SurfaceCards.resolve_meteor_marks(engine, after)
			var hits: int = _damaged_enemies(state, after, indices)
			if hits > best_hits:
				best_hits = hits
				best = candidate
	return best

static func _is_line(offsets: Array[Vector2i]) -> bool:
	if offsets.size() < 2: return false
	var horizontal: bool = true
	var vertical: bool = true
	for offset: Vector2i in offsets:
		horizontal = horizontal and offset.y == offsets[0].y
		vertical = vertical and offset.x == offsets[0].x
	return horizontal or vertical

static func _damaged_enemies(before: Dictionary, after: Dictionary, indices: Array[int]) -> int:
	var remaining_hp: Dictionary = {}
	for enemy: Dictionary in after.get("enemies", []): remaining_hp[enemy["id"]] = int(enemy.get("hp", 0))
	var hits: int = 0
	for index: int in indices:
		var enemy: Dictionary = before["enemies"][index]
		if int(remaining_hp.get(enemy["id"], 0)) < int(enemy.get("hp", 0)): hits += 1
	return hits
