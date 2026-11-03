extends RefCounted
## No ground fuel: Shadowstep selects currently hidden units, not laid ground.
const Burrow = preload("res://scripts/enemy_mechanics/burrow.gd")
const Blink = preload("res://scripts/enemy_mechanics/stalker.gd")
const Paths = preload("res://scripts/path_utils.gd")
const WHO_MODES: Array = ["all_hidden", "enemy_types"]

static func dial_error(_state: Dictionary, instance: Dictionary) -> String:
	if int(instance.get("dials", {}).get("blink", 0)) <= 0: return "Shadowstep requires positive blink"
	var who: Variant = instance["dials"].get("who", "all_hidden")
	return "Shadowstep who must be all_hidden or an enemy-type list" if not (who is Array or who == "all_hidden") else ""

static func resolve_beat(engine: RefCounted, state: Dictionary, instance: Dictionary) -> Dictionary:
	var hero: Vector2i = state["player"]["pos"]
	var visible: Dictionary = engine.umbra_visible_tile_lookup(state)
	var who: Variant = instance["dials"].get("who", "all_hidden")
	var enemies: Array[Dictionary]
	for enemy: Dictionary in state.get("enemies", []):
		# Primitive: the existing Umbra/Truesight/Light visibility predicate.
		if int(enemy.get("hp", 0)) <= 0 or not Burrow.targetable(enemy, {"type": "blink"}) or engine.is_enemy_visible_to_player(state, enemy, visible): continue
		if engine._force_actor_anchored(state, "enemy", int(enemy["id"])): continue
		if who is Array and not who.has(str(enemy["type"])): continue
		enemies.append(enemy)
	# Stable sort preserves enemy-array order on equal distance.
	enemies.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var first: int = Paths.manhattan(a["pos"], hero)
		var second: int = Paths.manhattan(b["pos"], hero)
		return first < second if first != second else state["enemies"].find(a) < state["enemies"].find(b))
	for enemy: Dictionary in enemies:
		var old: Vector2i = enemy["pos"]
		var landing: Vector2i = engine.INVALID_TILE
		var nearest: int = 2147483647
		var occupied: Dictionary = engine._enemy_blocking_tiles(state, int(enemy["id"]))
		# Primitive: Blink's Manhattan tile range; deterministic row-major order.
		for tile: Vector2i in Paths.diamond_tiles(old, int(instance["dials"]["blink"]), state["grid"]):
			if not engine.is_tile_visible_to_player(state, tile, visible) or Paths.manhattan(tile, hero) >= nearest: continue
			if not engine._enemy_can_occupy_anchor(state, enemy, tile, occupied): continue
			nearest = Paths.manhattan(tile, hero)
			landing = tile
		if landing == engine.INVALID_TILE: continue
		# Primitive: Blink placement, then the shared ground-entry trigger.
		state = Blink.blink(engine, state, engine._enemy_index_for_id(state, int(enemy["id"])), landing)
	return state

static func forecast(engine: RefCounted, state: Dictionary) -> Dictionary:
	return load("res://scripts/battlefield_rules/dispatcher.gd").forecast(engine, state)
