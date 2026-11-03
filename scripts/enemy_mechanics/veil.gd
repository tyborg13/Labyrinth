extends RefCounted

static func prior_follower(state: Dictionary, enemy: Dictionary) -> bool:
	if bool(enemy.get("is_leader", false)) or int(enemy.get("hp", 0)) <= 0: return false
	var leader: Dictionary = preload("res://scripts/warband_combat_rules.gd").captain(state)
	return preload("res://scripts/warband_combat_rules.gd").order(state, leader, "prior_veil")

# A real captain death reveals followers before the break even in dark rooms.
# Missing captains in information-limited forecasts never count as a death.
static func prior_revealed(state: Dictionary, enemy: Dictionary) -> bool:
	if bool(enemy.get("is_leader", false)): return false
	var rules: Script = preload("res://scripts/warband_combat_rules.gd")
	return str(rules.order_for_objective(state.get("objective", {})).get("id", "")) == "prior_veil" and rules.broken(state)

static func prior_hidden(engine: RefCounted, state: Dictionary, enemy: Dictionary) -> bool:
	if not prior_follower(state, enemy) or engine._enemy_distance_to_tile(enemy, state["player"]["pos"]) <= 2 or engine.player_has_truesight(state): return false
	for tile: Vector2i in engine._enemy_footprint_tiles(enemy):
		if engine._light_source_covers_tile(state, tile): return false
	return true
