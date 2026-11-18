extends RefCounted
## Resolve held marks with live occupants. Connectivity belongs to marking time.
const Surface = preload("res://scripts/board_surface_rules.gd")
const Terrain = preload("res://scripts/combat_terrain_rules.gd")
const Burrow = preload("res://scripts/enemy_mechanics/burrow.gd")
const Typed = preload("res://scripts/typed_arrays.gd")

static func passable(state: Dictionary, tile: Vector2i) -> bool:
	# Use the existing state-aware movement rule: sealed Snare thresholds are
	# impassable even though their underlying renderer grid remains floor.
	return Surface.can_place(state, tile) and not load("res://scripts/snare_room_rules.gd").sealed_tiles(state).has(tile)

static func site_blocked(engine: RefCounted, state: Dictionary, tile: Vector2i) -> bool:
	return not block_category(engine, state, tile).is_empty()

static func block_category(engine: RefCounted, state: Dictionary, tile: Vector2i) -> String:
	if not passable(state, tile): return "impassable"
	if engine._trap_index_at_tile(state, tile) >= 0: return "trap"
	for object: Dictionary in state.get("guardian_braziers", []):
		if object.get("pos", engine.INVALID_TILE) == tile: return "brazier"
	return ""

static func attempt(engine: RefCounted, before: Dictionary, instance: Dictionary, marks: Array[Vector2i]) -> Dictionary:
	var state: Dictionary = before.duplicate(true)
	var outcomes: Array[Dictionary]
	var source: Dictionary = instance["source"]
	var origin: Vector2i = state.get("snare_entry", state["player"]["pos"])
	if str(source["kind"]) == "enemy": origin = engine._surface_actor(state, "enemy", int(source["id"]))["pos"]
	for tile: Vector2i in marks:
		var blocker: String = block_category(engine, state, tile)
		if not blocker.is_empty():
			outcomes.append({"tile": tile, "category": blocker})
			continue
		var trial: Dictionary = state.duplicate(true)
		var blocked: bool = false
		for actor: Dictionary in engine._surface_actor_records(trial):
			if not engine._surface_unit_intersects(actor["unit"], Typed.vector2i([tile])): continue
			if Vector2i(actor["unit"].get("footprint", Vector2i.ONE)) != Vector2i.ONE or not Burrow.targetable(actor["unit"], {"type": "push"}) or engine._force_actor_anchored(trial, str(actor["kind"]), int(actor["id"])):
				blocked = true
				break
			var destination: Vector2i = Burrow.adjacent_free(engine, trial, tile, origin, -1, actor["unit"])
			if destination == engine.INVALID_TILE:
				blocked = true
				break
			trial = engine._force_place_actor(trial, str(actor["kind"]), int(actor["id"]), destination)
			trial = engine.surface_actor_arrival(trial, str(actor["kind"]), int(actor["id"]), tile)
		if blocked:
			outcomes.append({"tile": tile, "category": "occupied_raise"})
			continue
		if Terrain.raise_outcrop(engine, trial, tile, int(instance["dials"]["health"]), {"actor_kind": source["kind"], "actor_id": int(source.get("id", -1))}):
			state = trial
			outcomes.append({"tile": tile, "category": "raised"})
		else: outcomes.append({"tile": tile, "category": "unexpected_blocker"})
	return {"state": state, "outcomes": outcomes}
