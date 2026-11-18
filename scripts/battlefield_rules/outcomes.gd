extends RefCounted
## Resolver snapshots stay private. Only this filtered projection reaches views.
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const SurfaceVisibility = preload("res://scripts/board_surface_visibility.gd")
const STATUS_FIELDS: Array = ["freeze", "shock", "chilled", "bleed", "expose", "immobilize"]

static func project(engine: RefCounted, before: Dictionary, after: Dictionary, player_visible: bool = true, board_sight: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {"moves": [], "tiles": {"catch": [], "freeze": [], "strike": [], "rise": []}, "hits": [], "collision_markers": [], "emergences": []}
	var visible: Dictionary = engine.umbra_visible_tile_lookup(before)
	var surface_tiles: Variant = board_sight.get("umbra_visible_tiles", visible.keys())
	var enemy_ids: Variant = board_sight.get("visible_enemy_ids")
	var rule: String = str(before.get("battlefield_rule", {}).get("rule", ""))
	var events: Array = engine._surface_events_since(before, after)
	var gust_contacts: Dictionary = {}
	if player_visible and rule == "gust":
		result["tiles"]["gust"] = []
		for event: Dictionary in events:
			if event.get("kind") == "force_collision": gust_contacts[event["actor_key"]] = true
	var allowed: Dictionary = {}
	for actor: Dictionary in engine._surface_actor_records(before):
		var kind: String = str(actor["kind"])
		var id: int = int(actor["id"])
		var old: Dictionary = actor["unit"]
		var unit: Dictionary = engine._surface_actor(after, kind, id)
		var start: Vector2i = old["pos"]
		var finish: Vector2i = unit.get("pos", start)
		if player_visible and rule == "gust" and (start != finish or gust_contacts.has(actor["key"])):
			var unit_is_drawn: bool = kind != "enemy"
			if kind == "enemy":
				if board_sight.is_empty(): unit_is_drawn = engine.is_enemy_visible_to_player(before, old, visible)
				else: unit_is_drawn = not (enemy_ids is Array) or enemy_ids.has(id)
			if unit_is_drawn and SurfaceVisibility.tile_is_drawn(before, start, surface_tiles) and not result["tiles"]["gust"].has(start):
				result["tiles"]["gust"].append(start)
		if player_visible and kind == "enemy" and not engine.is_enemy_visible_to_player(before, old, visible):
			# A hidden mover stays anonymous: only a landing the player will see is kept, without its actor (el-05).
			var landing: Vector2i = unit.get("pos", old["pos"])
			if landing != old["pos"] and engine.is_tile_visible_to_player(before, landing, visible): result["emergences"].append(landing)
			continue
		var key: String = str(actor["key"])
		allowed[key] = true
		if start != finish and (not player_visible or engine.is_tile_visible_to_player(before, finish, visible)):
			result["moves"].append({"actor_key": key, "from": start, "to": finish})
		var statuses: Dictionary = {}
		for field: String in STATUS_FIELDS:
			if int(unit.get(field, 0)) > int(old.get(field, 0)): statuses[field] = unit[field]
		var damage: int = maxi(0, int(old.get("hp", 0)) - int(unit.get("hp", 0)))
		if damage > 0 or not statuses.is_empty(): result["hits"].append({"actor_key": key, "damage": damage, "statuses": statuses})
	for event: Dictionary in events:
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
			if (not player_visible or SurfaceVisibility.tile_is_drawn(before, tile, surface_tiles)) and not result["tiles"][bucket].has(tile): result["tiles"][bucket].append(tile)
	var instance: Dictionary = before.get("battlefield_rule", {})
	var bucket: String = {"lightning_storm": "strike", "frostbite": "freeze", "wildfire": "catch"}.get(str(instance.get("rule", "")), "")
	if not bucket.is_empty():
		# Geometry is an announcement, including empty tiles and consumed fuel.
		result["tiles"][bucket] = []
		for tile: Vector2i in preload("res://scripts/battlefield_rules/geometry.gd").affected_tiles(engine, before, instance):
			if not player_visible or SurfaceVisibility.tile_is_drawn(before, tile, surface_tiles): result["tiles"][bucket].append(tile)
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
