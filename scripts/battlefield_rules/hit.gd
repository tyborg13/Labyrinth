extends RefCounted
## Team-neutral targeting uses the shared attack resolver, never a second hit loop.
static func resolve(engine: RefCounted, state: Dictionary, instance: Dictionary, action: Dictionary, tiles: Array[Vector2i], trace: Dictionary = {}) -> Dictionary:
	if tiles.is_empty(): return state
	action = action.duplicate(true)
	action["_battlefield_all_units"] = true
	action["_battlefield_rule_fuel"] = true
	var source: Dictionary = instance["source"]
	# Primitive: full board attack resolution (Expose, statuses, traps, terrain,
	# death batching and on-hit reactions); non-player actors get no card bonuses.
	return engine._resolve_board_attack(state, action, engine.INVALID_TILE, str(source["kind"]), int(source.get("id", -1)), trace, tiles)
