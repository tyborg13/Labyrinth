extends RefCounted

## Index only tiles that can contribute to the overlay plan. The caller still
## visits them in the board's depth order and emits the original operations.
static func candidates(board: Control, sources: Dictionary) -> Dictionary:
	var shown: Dictionary = board.presentation
	var result: Dictionary = {}
	for lookup: Dictionary in [
		board._rest_threat_tile_alphas, sources["lob_marks"], sources["icefall_marks"],
		board._objective_exit_tiles_lookup_cache, board.exit_tiles, board._confirmation_target_tiles_lookup_cache,
		board._focus_tiles_lookup_cache, board._move_tiles_lookup_cache, board._ability_tiles_lookup_cache,
		board._attack_tiles_lookup_cache, board._projected_attack_tiles_lookup_cache, board._summon_tiles_lookup_cache,
		board._projected_destination_tiles_lookup_cache, sources["meteor_tiles"],
	]:
		result.merge(lookup)
	for tile: Variant in shown.get("attack_reach_tiles", []):
		if tile is Vector2i: result[tile] = true
	for tag: Dictionary in sources["zone_tags"]: result[tag["tile"]] = true
	for tile: Vector2i in [board.selected_tile, board._hover_tile, board._controller_focus_tile, board._threat_lift_tile, shown.get("objective_leader_tile", Vector2i(-1, -1))]:
		result[tile] = true
	if board.SnareRules.active(board.combat_state):
		for exit: Dictionary in board.combat_state["objective"]["exits"]:
			result[exit["target_tile"]] = true
	return result

static func meteor_tiles(state: Dictionary, shown: Dictionary, burrow_marks: Array, burst_tiles: Array) -> Dictionary:
	var result: Dictionary = {}
	for tile: Vector2i in burst_tiles: result[tile] = true
	for mark: Dictionary in burrow_marks: result[mark["tile"]] = true
	for group: Array in [state.get("meteor_marks", []), shown.get("burst_effects", [])]:
		for mark: Variant in group:
			if mark is Dictionary:
				for tile: Variant in mark.get("tiles", []):
					if tile is Vector2i: result[tile] = true
	return result
