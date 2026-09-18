extends "res://scripts/combat_engine.gd"

# Frozen algorithms from 365dc25: independent route and footprint oracle.

func _enemy_distance_to_tile(enemy: Dictionary, tile: Vector2i) -> int:
	var best_distance: int = 9999
	for enemy_tile: Vector2i in _enemy_footprint_tiles(enemy):
		best_distance = mini(best_distance, PathUtils.manhattan(enemy_tile, tile))
	return best_distance

func _closest_enemy_tile_to(enemy: Dictionary, tile: Vector2i) -> Vector2i:
	var best_tile: Vector2i = enemy.get("pos", Vector2i.ZERO)
	var best_distance: int = 9999
	for enemy_tile: Vector2i in _enemy_footprint_tiles(enemy):
		var distance: int = PathUtils.manhattan(enemy_tile, tile)
		if distance < best_distance:
			best_distance = distance
			best_tile = enemy_tile
	return best_tile

func _enemy_future_route_to_attack(state: Dictionary, enemy: Dictionary, attack_action: Dictionary, target: Dictionary, move_range: int, planning_context: Dictionary) -> Dictionary:
	var start: Vector2i = enemy.get("pos", Vector2i.ZERO)
	var start_path: Array[Vector2i] = _vector2i_values([start])
	var open: Array[Dictionary]
	open.append({"tile": start, "cost": 0, "steps": 0, "route": start_path, "open_prefix_steps": 0, "prefix_blocked": false, "regression_cost": 0, "prefix_distance_cost": 0})
	var best_by_tile: Dictionary = {start: open[0]}
	var closed: Dictionary = {}
	while not open.is_empty():
		var best_open_index: int = _enemy_best_open_route_index(open)
		var current: Dictionary = open[best_open_index]
		open.remove_at(best_open_index)
		var current_tile: Vector2i = current.get("tile", start)
		if closed.has(current_tile):
			continue
		closed[current_tile] = true
		var candidate_enemy: Dictionary = enemy.duplicate(true)
		candidate_enemy["pos"] = current_tile
		var anchor_details: Dictionary = _enemy_future_anchor_details(state, enemy, current_tile, planning_context)
		if bool(anchor_details.get("dynamically_open", false)) and _enemy_action_reaches_target(state, candidate_enemy, attack_action, target):
			return current
		for direction: Vector2i in PathUtils.DIRS_4:
			var next_tile: Vector2i = current_tile + direction
			if closed.has(next_tile):
				continue
			var next_anchor_details: Dictionary = _enemy_future_anchor_details(state, enemy, next_tile, planning_context)
			if not bool(next_anchor_details.get("in_grid", false)):
				continue
			var step_cost: int = _enemy_future_anchor_step_cost(state, next_anchor_details, attack_action, move_range, BoardSurfaceRules.movement_step_cost(state, enemy, current_tile, next_tile))
			if step_cost < 0:
				continue
			var route: Array[Vector2i] = _vector2i_values(current.get("route", []))
			if route.has(next_tile):
				continue
			var next_route: Array[Vector2i] = route.duplicate()
			next_route.append(next_tile)
			var current_enemy: Dictionary = enemy.duplicate(true)
			current_enemy["pos"] = current_tile
			var next_enemy: Dictionary = enemy.duplicate(true)
			next_enemy["pos"] = next_tile
			var current_target_distance: int = _enemy_distance_to_tile(current_enemy, target.get("pos", Vector2i.ZERO))
			var next_target_distance: int = _enemy_distance_to_tile(next_enemy, target.get("pos", Vector2i.ZERO))
			var regression_cost: int = int(current.get("regression_cost", 0)) + maxi(0, next_target_distance - current_target_distance)
			var next_steps: int = int(current.get("steps", 0)) + 1
			var prefix_distance_cost: int = int(current.get("prefix_distance_cost", 0))
			if next_steps <= move_range:
				# Weight earlier steps more heavily so equal-cost routes postpone a
				# necessary detour until the obstacle is actually near. Previously a
				# distant blocker could make the first activation move away, sideways,
				# and back even though direct progress remained open for several tiles.
				prefix_distance_cost += next_target_distance * (move_range - next_steps + 1)
			var prefix_blocked: bool = bool(current.get("prefix_blocked", false))
			var open_prefix_steps: int = int(current.get("open_prefix_steps", 0))
			if not prefix_blocked and open_prefix_steps < move_range:
				if bool(next_anchor_details.get("dynamically_open", false)):
					open_prefix_steps += 1
				else:
					prefix_blocked = true
			var next_record: Dictionary = {
				"tile": next_tile,
				"cost": int(current.get("cost", 0)) + step_cost,
				"steps": next_steps,
				"route": next_route,
				"open_prefix_steps": open_prefix_steps,
				"prefix_blocked": prefix_blocked,
				"regression_cost": regression_cost,
				"prefix_distance_cost": prefix_distance_cost
			}
			if best_by_tile.has(next_tile) and not _enemy_route_record_precedes(next_record, best_by_tile[next_tile] as Dictionary):
				continue
			best_by_tile[next_tile] = next_record
			open.append(next_record)
	return {}
