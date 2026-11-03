extends RefCounted
## Resolver snapshots stay private. Only this filtered projection reaches views.
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const STATUS_FIELDS: Array = ["freeze", "shock", "chilled", "bleed", "expose", "immobilize"]

static func project(engine: RefCounted, before: Dictionary, after: Dictionary, player_visible: bool = true) -> Dictionary:
	var result: Dictionary = {"moves": [], "tiles": {"catch": [], "freeze": [], "strike": [], "rise": []}, "hits": [], "collision_markers": [], "emergences": []}
	var visible: Dictionary = engine.umbra_visible_tile_lookup(before)
	var allowed: Dictionary = {}
	for actor: Dictionary in engine._surface_actor_records(before):
		var kind: String = str(actor["kind"])
		var id: int = int(actor["id"])
		var old: Dictionary = actor["unit"]
		var unit: Dictionary = engine._surface_actor(after, kind, id)
		if player_visible and kind == "enemy" and not engine.is_enemy_visible_to_player(before, old, visible):
			# A hidden mover stays anonymous: only a landing the player will see is kept, without its actor (el-05).
			var landing: Vector2i = unit.get("pos", old["pos"])
			if landing != old["pos"] and engine.is_tile_visible_to_player(before, landing, visible): result["emergences"].append(landing)
			continue
		var key: String = str(actor["key"])
		allowed[key] = true
		var start: Vector2i = old["pos"]
		var finish: Vector2i = unit.get("pos", start)
		if start != finish and (not player_visible or engine.is_tile_visible_to_player(before, finish, visible)):
			result["moves"].append({"actor_key": key, "from": start, "to": finish})
		var statuses: Dictionary = {}
		for field: String in STATUS_FIELDS:
			if int(unit.get(field, 0)) > int(old.get(field, 0)): statuses[field] = unit[field]
		var damage: int = maxi(0, int(old.get("hp", 0)) - int(unit.get("hp", 0)))
		if damage > 0 or not statuses.is_empty(): result["hits"].append({"actor_key": key, "damage": damage, "statuses": statuses})
	for event: Dictionary in engine._surface_events_since(before, after):
		var bucket: String = ""
		match str(event.get("kind", "")):
			"surface_created", "surface_replaced":
				if str(event.get("surface", "")) == "fire": bucket = "catch"
			"surface_removed":
				if str(event.get("surface", "")) == "ice" and str(event.get("reason", "")) == "freeze": bucket = "freeze"
			"terrain_created": bucket = "rise"
			"force_collision":
				if not player_visible or (allowed.has(str(event.get("actor_key", ""))) and engine.is_tile_visible_to_player(before, event["blocked_tile"], visible) and not _hidden_blocker(engine, before, event, visible)):
					var marker: Dictionary = event.duplicate(true)
					# Commit-only switch events can change sequence numbers, never geometry.
					marker.erase("sequence")
					# A collision's private damage context can name a hidden source.
					if player_visible: marker.erase("source")
					result["collision_markers"].append(marker)
		if not bucket.is_empty() and event.has("tile"):
			var tile: Vector2i = event["tile"]
			if (not player_visible or engine.is_tile_visible_to_player(before, tile, visible)) and not result["tiles"][bucket].has(tile): result["tiles"][bucket].append(tile)
	if str(before.get("battlefield_rule", {}).get("rule", "")) == "lightning_storm":
		for tile: Vector2i in Surfaces.fuel_tiles(before, "electrified"):
			if not player_visible or engine.is_tile_visible_to_player(before, tile, visible): result["tiles"]["strike"].append(tile)
	return result

static func _hidden_blocker(engine: RefCounted, state: Dictionary, event: Dictionary, visible: Dictionary) -> bool:
	var index: int = engine._enemy_index_at_tile(state, event["blocked_tile"])
	return index >= 0 and not engine.is_enemy_visible_to_player(state, state["enemies"][index], visible)

static func analytics(engine: RefCounted, before: Dictionary, after: Dictionary, projection: Dictionary = {}) -> Dictionary:
	var affected: Dictionary = {}
	var damage_to_player: int = 0
	var damage_to_enemies: int = 0
	var outcomes: Dictionary = project(engine, before, after, false) if projection.is_empty() else projection
	for move: Dictionary in outcomes["moves"]: affected[move["actor_key"]] = true
	for hit: Dictionary in outcomes["hits"]:
		affected[hit["actor_key"]] = true
		if hit["actor_key"] == "player": damage_to_player += int(hit["damage"])
		elif str(hit["actor_key"]).begins_with("enemy_"): damage_to_enemies += int(hit["damage"])
	# Include defense-only hits/collisions as affected units too.
	for actor: Dictionary in engine._surface_actor_records(before):
		var unit: Dictionary = engine._surface_actor(after, actor["kind"], actor["id"])
		for field: String in ["block", "stoneskin"]:
			if int(unit.get(field, 0)) != int(actor["unit"].get(field, 0)): affected[actor["key"]] = true
	var tiles: Dictionary = {}
	for event: Dictionary in engine._surface_events_since(before, after):
		if str(event.get("kind", "")) in ["surface_created", "surface_replaced", "surface_removed", "terrain_created", "terrain_destroyed"] and event.has("tile"): tiles[event["tile"]] = true
	return {"affected_units": affected.size(), "tiles_changed": tiles.size(), "damage_to_player": damage_to_player, "damage_to_enemies": damage_to_enemies}
