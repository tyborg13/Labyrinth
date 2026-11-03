extends RefCounted

# Original RunScene HUD identity lookup, including the unnecessary plan query.
var _combat_engine := preload("res://scripts/combat_engine.gd").new()

func _enemy_threat_at_tile(display_state: Dictionary, tile: Vector2i) -> Dictionary:
	for enemy_index: int in range((display_state.get("enemies", []) as Array).size()):
		var enemy: Dictionary = (display_state.get("enemies", []) as Array)[enemy_index]
		if int(enemy.get("hp", 0)) <= 0:
			continue
		if not _combat_engine.is_enemy_visible_to_player(display_state, enemy):
			continue
		if not _enemy_footprint_tiles(enemy).has(tile):
			continue
		var threat: Dictionary = _combat_engine.enemy_threat_tiles(display_state, enemy_index)
		threat["enemy_key"] = _enemy_key(enemy)
		return threat
	return {}


func _enemy_footprint_tiles(enemy: Dictionary) -> Array[Vector2i]:
	var origin: Vector2i = enemy.get("pos", Vector2i.ZERO)
	var footprint: Vector2i = enemy.get("footprint", Vector2i.ONE)
	var tiles: Array[Vector2i]
	for y: int in range(maxi(1, footprint.y)):
		for x: int in range(maxi(1, footprint.x)):
			tiles.append(origin + Vector2i(x, y))
	return tiles


func _enemy_key(enemy: Dictionary) -> String:
	return "enemy_%d" % int(enemy.get("id", -1))

