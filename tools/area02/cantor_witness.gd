extends RefCounted

const Bot = preload("res://tools/encounter_bot.gd")
const Commit = preload("res://scripts/battlefield_rules/committed.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")

static func real_health(player: Dictionary) -> bool:
	var hp: int = int(player.get("hp", 0))
	return int(player.get("max_hp", 0)) == Bot.MAX_HP and hp > 0 and hp <= Bot.MAX_HP

static func visible_electrified(engine: RefCounted, state: Dictionary) -> Array[Vector2i]:
	var visible: Dictionary = engine.umbra_visible_tile_lookup(state)
	var tiles: Array[Vector2i]
	for tile: Vector2i in Surface.tiles(state, "electrified"):
		if engine.is_tile_visible_to_player(state, tile, visible): tiles.append(tile)
	return tiles

static func resolve_pass(engine: RefCounted, before: Dictionary) -> Dictionary:
	var steps: Array[Dictionary]
	var scheduled: Dictionary = Commit.finish_player_activation_with_rule_steps(engine, before, steps)
	var result: Dictionary = Commit.advance_to_player(engine, scheduled)
	steps.append_array(result["steps"])
	return {"steps": steps, "state": result["state"]}

static func new_tender_tiles(engine: RefCounted, passed: Dictionary, state: Dictionary) -> Array[Vector2i]:
	var laid: Array[Vector2i]
	for tile: Vector2i in visible_electrified(engine, state):
		if Surface.element_at(passed, tile) == "electrified": continue
		var placement: Dictionary = Surface.surface_at(state, tile).get("elemental_source", {})
		if placement.get("actor_kind") != "enemy": continue
		var tender: Dictionary = engine._surface_actor(state, "enemy", int(placement.get("actor_id", -1)))
		if tender.get("type") == "bell_tender": laid.append(tile)
	return laid

static func peal(engine: RefCounted, passed: Dictionary, steps: Array) -> Dictionary:
	for step: Dictionary in steps:
		if not bool(step.get("battlefield_rule_step", false)) or step.get("rule") != "lightning_storm": continue
		var before: Dictionary = step["before"]
		var source: Dictionary = before["battlefield_rule"]["source"]
		var cantor: Dictionary = engine._surface_actor(before, "enemy", int(source["id"]))
		if cantor.get("type") != "storm_cantor": continue
		var field: Array[Vector2i] = Surface.tiles(before, "electrified")
		if step["tiles"] != field or not real_health(step["after"]["player"]): continue
		var laid: Array[Vector2i] = new_tender_tiles(engine, passed, before)
		if not laid.is_empty():
			var new_ground_sources: Dictionary = {}
			for tile: Vector2i in field:
				if Surface.element_at(passed, tile) == "electrified": continue
				var placement: Dictionary = Surface.surface_at(before, tile).get("elemental_source", {})
				var actor: Dictionary = engine._surface_actor(before, "enemy", int(placement.get("actor_id", -1)))
				new_ground_sources[str(tile)] = {"actor": actor.get("type", ""), "source": placement}
			return {"strike": field, "laid": laid, "new_ground_sources": new_ground_sources}
	return {}
