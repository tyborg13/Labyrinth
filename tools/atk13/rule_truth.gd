extends RefCounted
## Independent sentence checks for the rules with live movement. Shared engine
## primitives supply legal landing, ground arrival and terrain placement.
const Surface = preload("res://scripts/board_surface_rules.gd")
const PathUtils = preload("res://scripts/path_utils.gd")
const Throw = preload("res://scripts/enemy_mechanics/burrow.gd")
const Blink = preload("res://scripts/enemy_mechanics/stalker.gd")
const Terrain = preload("res://scripts/combat_terrain_rules.gd")

static func rise(engine: RefCounted, before: Dictionary, instance: Dictionary) -> Array[Dictionary]:
	var state: Dictionary = before.duplicate(true)
	var source: Dictionary = instance["source"]
	var origin: Vector2i = state.get("snare_entry", state["player"]["pos"])
	if str(source["kind"]) == "enemy": origin = engine._surface_actor(state, "enemy", int(source["id"]))["pos"]
	var outcomes: Array[Dictionary]
	for tile: Vector2i in instance.get("marks", []):
		var category: String = _site_category(engine, state, tile)
		if category.is_empty():
			var trial: Dictionary = state.duplicate(true)
			for actor: Dictionary in engine._surface_actor_records(state):
				if not Surface.footprint_tiles(actor["unit"]).has(tile): continue
				var kind: String = actor["kind"]
				var id: int = actor["id"]
				var destination: Vector2i = Throw.adjacent_free(engine, trial, tile, origin, -1, actor["unit"])
				if engine._force_actor_anchored(trial, kind, id) or bool(actor["unit"].get("burrowed", false)) or Vector2i(actor["unit"].get("footprint", Vector2i.ONE)) != Vector2i.ONE or destination == engine.INVALID_TILE:
					category = "occupied_raise"
					break
				trial = engine._force_place_actor(trial, kind, id, destination)
				trial = engine.surface_actor_arrival(trial, kind, id, tile)
			if category.is_empty():
				category = "raised"
				# A failed primitive on a legal site still expects a raise.
				# Treat any missing actual lift as a mismatch.
				Terrain.raise_outcrop(engine, trial, tile, int(instance["dials"]["health"]), {"actor_kind": source["kind"], "actor_id": int(source.get("id", -1))})
				state = trial
		outcomes.append({"tile": tile, "category": category})
	return outcomes

static func _site_category(engine: RefCounted, state: Dictionary, tile: Vector2i) -> String:
	if not PathUtils.is_passable(state["grid"], tile) or engine._terrain_index_at_tile(state, tile) >= 0 or engine._impassable_tiles(state).has(tile): return "impassable"
	if engine._trap_index_at_tile(state, tile) >= 0: return "trap"
	for brazier: Dictionary in state.get("guardian_braziers", []):
		if brazier.get("pos") == tile: return "brazier"
	return ""

static func shadowstep(engine: RefCounted, before: Dictionary, instance: Dictionary) -> Array[Vector2i]:
	var state: Dictionary = before.duplicate(true)
	var visibility: Dictionary = engine.umbra_visible_tile_lookup(state)
	var hero: Vector2i = state["player"]["pos"]
	var dials: Dictionary = instance["dials"]
	var who: Variant = dials.get("who", "all_hidden")
	var targets: Array[Dictionary]
	for enemy: Dictionary in before["enemies"]:
		if int(enemy.get("hp", 0)) <= 0 or engine.is_enemy_visible_to_player(before, enemy, visibility): continue
		if not Throw.targetable(enemy, {"type": "blink"}) or engine._force_actor_anchored(before, "enemy", int(enemy["id"])): continue
		if who is Array and not who.has(enemy["type"]): continue
		targets.append(enemy)
	targets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var distance_a: int = PathUtils.manhattan(a["pos"], hero)
		var distance_b: int = PathUtils.manhattan(b["pos"], hero)
		return distance_a < distance_b if distance_a != distance_b else before["enemies"].find(a) < before["enemies"].find(b))
	var landings: Array[Vector2i]
	for enemy: Dictionary in targets:
		var id: int = int(enemy["id"])
		var occupied: Dictionary = engine._enemy_blocking_tiles(state, id)
		var legal: Array[Vector2i]
		for tile: Vector2i in PathUtils.diamond_tiles(enemy["pos"], int(dials["blink"]), state["grid"]):
			if engine.is_tile_visible_to_player(state, tile, visibility) and engine._enemy_can_occupy_anchor(state, enemy, tile, occupied):
				legal.append(tile)
		var best: Vector2i = engine.INVALID_TILE
		for tile: Vector2i in legal:
			if best == engine.INVALID_TILE or PathUtils.manhattan(tile, hero) < PathUtils.manhattan(best, hero): best = tile
		if best == engine.INVALID_TILE: continue
		state = Blink.blink(engine, state, engine._enemy_index_for_id(state, id), best)
		var final: Vector2i = engine._surface_actor(state, "enemy", id).get("pos", enemy["pos"])
		if final != enemy["pos"]: landings.append(final)
	return landings
