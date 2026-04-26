extends RefCounted
class_name RoomGenerator

const ElementData = preload("res://scripts/element_data.gd")
const GameData = preload("res://scripts/game_data.gd")
const PathUtils = preload("res://scripts/path_utils.gd")

const ROOM_WIDTH: int = 9
const ROOM_HEIGHT: int = 9
const ENEMY_SPAWN_SAFE_RADIUS: int = 2
const ENEMY_SPAWN_PICK_WINDOW: int = 6

const TILE_ASH: String = "ash"
const TILE_EMBER: String = "ember"
const TILE_WALL: String = "wall"
const TILE_PILLAR: String = "pillar"
const TILE_DOOR: String = "door"

const ENTRANCE_BY_TRAVEL_DIR := {
	Vector2i(0, -1): Vector2i(4, 7),
	Vector2i(1, 0): Vector2i(1, 4),
	Vector2i(0, 1): Vector2i(4, 1),
	Vector2i(-1, 0): Vector2i(7, 4),
	Vector2i.ZERO: Vector2i(4, 7)
}

const DOOR_BY_DIRECTION := {
	Vector2i(0, -1): Vector2i(4, 0),
	Vector2i(1, 0): Vector2i(8, 4),
	Vector2i(0, 1): Vector2i(4, 8),
	Vector2i(-1, 0): Vector2i(0, 4)
}

const TEMPLATE_LIBRARY: Array = [
	[
		{"tile": TILE_PILLAR, "cells": [Vector2i(2, 2), Vector2i(6, 2), Vector2i(2, 6), Vector2i(6, 6)]}
	],
	[
		{"tile": TILE_WALL, "cells": [Vector2i(3, 2), Vector2i(3, 3), Vector2i(5, 5), Vector2i(5, 6)]},
		{"tile": TILE_PILLAR, "cells": [Vector2i(6, 3), Vector2i(2, 5)]}
	],
	[
		{"tile": TILE_WALL, "cells": [Vector2i(2, 4), Vector2i(3, 4), Vector2i(5, 4), Vector2i(6, 4)]}
	],
	[
		{"tile": TILE_PILLAR, "cells": [Vector2i(4, 2), Vector2i(2, 4), Vector2i(6, 4), Vector2i(4, 6)]}
	],
	[
		{"tile": TILE_WALL, "cells": [Vector2i(2, 3), Vector2i(3, 3), Vector2i(5, 5), Vector2i(6, 5)]},
		{"tile": TILE_PILLAR, "cells": [Vector2i(5, 2), Vector2i(3, 6)]}
	],
	[
		{"tile": TILE_WALL, "cells": [Vector2i(4, 2), Vector2i(4, 3), Vector2i(4, 5), Vector2i(4, 6)]},
		{"tile": TILE_PILLAR, "cells": [Vector2i(2, 4), Vector2i(6, 4)]}
	]
]

const ROOM_NAME_PREFIXES: Array[String] = [
	"Quiet",
	"Bleak",
	"Shuttered",
	"Fevered",
	"Crooked",
	"Hollow",
	"Sooted",
	"Sealed"
]

const ROOM_NAME_SUFFIXES: Array[String] = [
	"Vault",
	"Gallery",
	"Antechamber",
	"Spine",
	"Passage",
	"Sanctum",
	"Hall",
	"Grotto"
]

func generate_room(run_seed: int, room: Dictionary, travel_dir: Vector2i) -> Dictionary:
	var depth: int = int(room.get("depth", 1))
	var room_type: String = str(room.get("type", "combat"))
	var room_element: String = str(room.get("element", "none"))
	var coord: Vector2i = room.get("coord", Vector2i.ZERO)
	var npc_specs: Array = room.get("npcs", [])
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = _room_seed(run_seed, coord, 101)

	var grid: Array = _base_grid(rng)
	var entrance_tile: Vector2i = ENTRANCE_BY_TRAVEL_DIR.get(travel_dir, ENTRANCE_BY_TRAVEL_DIR[Vector2i.ZERO])
	_apply_available_doors(grid, room)
	_apply_template(grid, rng)
	var moss: Dictionary = _generate_moss_overlays(grid, run_seed, coord)

	var player_start: Vector2i = entrance_tile
	var enemy_types: Array = [] if not npc_specs.is_empty() else _encounter_enemy_types(room_type, depth, rng)
	var enemy_positions: Array[Vector2i] = _pick_enemy_positions(grid, player_start, enemy_types.size(), rng)
	var enemies: Array[Dictionary] = []
	for index: int in range(enemy_types.size()):
		enemies.append({
			"id": index + 1,
			"type": enemy_types[index],
			"element": room_element,
			"pos": enemy_positions[index],
			"hp": int(GameData.enemy_def(enemy_types[index]).get("max_hp", 1)),
			"max_hp": int(GameData.enemy_def(enemy_types[index]).get("max_hp", 1)),
			"block": 0,
			"stoneskin": 0
		})

	var occupied: Dictionary = {player_start: true}
	for enemy: Dictionary in enemies:
		occupied[enemy.get("pos", Vector2i(-1, -1))] = true
	var npcs: Array[Dictionary] = _build_room_npcs(grid, player_start, npc_specs, rng, occupied)
	for npc: Dictionary in npcs:
		occupied[npc.get("pos", Vector2i(-1, -1))] = true
	var traps: Array[Dictionary] = _generate_traps(grid, room_type, room_element, depth, player_start, rng, occupied)
	for trap: Dictionary in traps:
		occupied[trap.get("pos", Vector2i(-1, -1))] = true
	var loot: Array = []
	if npcs.is_empty():
		loot = _generate_loot(grid, room_type, depth, rng, occupied)

	return {
		"name": _room_name(coord, room_type, rng),
		"coord": coord,
		"depth": depth,
		"type": room_type,
		"element": room_element,
		"grid": grid,
		"moss": moss,
		"player_start": player_start,
		"npcs": npcs,
		"enemies": enemies,
		"traps": traps,
		"loot": loot,
		"theme": TILE_ASH
	}

func _base_grid(rng: RandomNumberGenerator) -> Array:
	# Preserve the old theme roll so later room RNG stays aligned.
	rng.randf()
	var grid: Array = []
	for y: int in range(ROOM_HEIGHT):
		var row: Array[String] = []
		for x: int in range(ROOM_WIDTH):
			var tile_id: String = TILE_ASH
			if x == 0 or y == 0 or x == ROOM_WIDTH - 1 or y == ROOM_HEIGHT - 1:
				tile_id = TILE_WALL
			row.append(tile_id)
		grid.append(row)
	return grid

func _apply_available_doors(grid: Array, room: Dictionary) -> void:
	for connection_var: Variant in room.get("connections", []):
		if typeof(connection_var) != TYPE_DICTIONARY:
			continue
		var connection: Dictionary = connection_var
		var door_dir: Vector2i = connection.get("door_dir", Vector2i.ZERO)
		var door_tile: Vector2i = DOOR_BY_DIRECTION.get(door_dir, Vector2i(-1, -1))
		if door_tile.x < 0:
			continue
		grid[door_tile.y][door_tile.x] = TILE_DOOR

func _apply_template(grid: Array, rng: RandomNumberGenerator) -> void:
	var protected_tiles: Dictionary = {}
	for entry_tile: Vector2i in ENTRANCE_BY_TRAVEL_DIR.values():
		protected_tiles[entry_tile] = true
	var template_index: int = rng.randi_range(0, TEMPLATE_LIBRARY.size() - 1)
	var rotation_steps: int = rng.randi_range(0, 3)
	var mirrored: bool = rng.randf() < 0.5
	var template: Array = TEMPLATE_LIBRARY[template_index]
	for element: Dictionary in template:
		var tile_id: String = str(element.get("tile", TILE_PILLAR))
		if tile_id == TILE_WALL:
			tile_id = TILE_PILLAR
		for cell_var: Variant in element.get("cells", []):
			if typeof(cell_var) != TYPE_VECTOR2I:
				continue
			var transformed: Vector2i = _transform_cell(cell_var, rotation_steps, mirrored)
			if protected_tiles.has(transformed):
				continue
			if transformed.x <= 0 or transformed.y <= 0 or transformed.x >= ROOM_WIDTH - 1 or transformed.y >= ROOM_HEIGHT - 1:
				continue
			grid[transformed.y][transformed.x] = tile_id
	if _reachable_floor_count(grid, Vector2i(4, 7)) < 18:
		for y: int in range(ROOM_HEIGHT):
			for x: int in range(ROOM_WIDTH):
				if str(grid[y][x]) == TILE_WALL or str(grid[y][x]) == TILE_PILLAR:
					if x == 0 or y == 0 or x == ROOM_WIDTH - 1 or y == ROOM_HEIGHT - 1:
						continue
					grid[y][x] = TILE_ASH

func _generate_moss_overlays(grid: Array, run_seed: int, coord: Vector2i) -> Dictionary:
	return {
		"floor": _select_floor_moss_tiles(grid, run_seed, coord),
		"wall": _select_wall_moss_tiles(grid, run_seed, coord),
		"pillar": _select_pillar_moss_tiles(grid, run_seed, coord)
	}

func _select_floor_moss_tiles(grid: Array, run_seed: int, coord: Vector2i) -> Array[Vector2i]:
	var protected_tiles: Dictionary = {}
	for entry_tile: Vector2i in ENTRANCE_BY_TRAVEL_DIR.values():
		protected_tiles[entry_tile] = true
	var candidates: Array[Vector2i] = []
	for y: int in range(1, ROOM_HEIGHT - 1):
		for x: int in range(1, ROOM_WIDTH - 1):
			var tile := Vector2i(x, y)
			if protected_tiles.has(tile):
				continue
			if str(grid[y][x]) != TILE_ASH:
				continue
			candidates.append(tile)
	if candidates.is_empty():
		return []
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return _floor_accent_score(run_seed, coord, a) < _floor_accent_score(run_seed, coord, b)
	)
	var target_count: int = clampi(int(round(float(candidates.size()) * 0.24)), 4, 9)
	target_count = mini(target_count + (_floor_accent_score(run_seed, coord, Vector2i(4, 4), 37) % 3), candidates.size())
	var chosen: Dictionary = {}
	for tile: Vector2i in candidates:
		if chosen.size() >= target_count:
			break
		if _selected_moss_neighbor_count(chosen, tile) > 0:
			continue
		chosen[tile] = true
	if chosen.size() < target_count:
		for tile: Vector2i in candidates:
			if chosen.has(tile):
				continue
			if _selected_moss_neighbor_count(chosen, tile) > 1:
				continue
			chosen[tile] = true
			if chosen.size() >= target_count:
				break
	return _vector2i_keys(chosen)

func _select_wall_moss_tiles(grid: Array, run_seed: int, coord: Vector2i) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []
	for y: int in range(ROOM_HEIGHT):
		for x: int in range(ROOM_WIDTH):
			var tile := Vector2i(x, y)
			if str(grid[y][x]) != TILE_WALL:
				continue
			if _is_corner_boundary_tile(tile):
				continue
			if _tile_touches_door(grid, tile):
				continue
			candidates.append(tile)
	if candidates.is_empty():
		return []
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return _floor_accent_score(run_seed, coord, a, 101) < _floor_accent_score(run_seed, coord, b, 101)
	)
	var target_count: int = clampi(int(round(float(candidates.size()) * 0.26)), 1, 3)
	var chosen: Dictionary = {}
	for tile: Vector2i in candidates:
		if chosen.size() >= target_count:
			break
		if _selected_moss_neighbor_count(chosen, tile) > 0:
			continue
		chosen[tile] = true
	return _vector2i_keys(chosen)

func _select_pillar_moss_tiles(grid: Array, run_seed: int, coord: Vector2i) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []
	for y: int in range(1, ROOM_HEIGHT - 1):
		for x: int in range(1, ROOM_WIDTH - 1):
			var tile := Vector2i(x, y)
			if str(grid[y][x]) != TILE_PILLAR:
				continue
			candidates.append(tile)
	if candidates.is_empty():
		return []
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return _floor_accent_score(run_seed, coord, a, 211) < _floor_accent_score(run_seed, coord, b, 211)
	)
	var target_count: int = clampi(int(round(float(candidates.size()) * 0.5)), 1, 3)
	var chosen: Dictionary = {}
	for tile: Vector2i in candidates:
		if chosen.size() >= target_count:
			break
		if _selected_moss_neighbor_count(chosen, tile) > 0:
			continue
		chosen[tile] = true
	return _vector2i_keys(chosen)

func _floor_accent_score(run_seed: int, coord: Vector2i, tile: Vector2i, salt: int = 0) -> int:
	var mixed: int = _room_seed(run_seed, coord, 701 + salt)
	mixed = int((mixed + tile.x * 92821 + tile.y * 68917 + tile.x * tile.y * 137 + (tile.x - tile.y) * 59) & 0x7fffffff)
	return mixed

func _selected_moss_neighbor_count(chosen: Dictionary, tile: Vector2i) -> int:
	var neighbors: int = 0
	for offset_y: int in range(-1, 2):
		for offset_x: int in range(-1, 2):
			if offset_x == 0 and offset_y == 0:
				continue
			if chosen.has(tile + Vector2i(offset_x, offset_y)):
				neighbors += 1
	return neighbors

func _vector2i_keys(source: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for tile_var: Variant in source.keys():
		if typeof(tile_var) == TYPE_VECTOR2I:
			result.append(tile_var)
	result.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.y == b.y:
			return a.x < b.x
		return a.y < b.y
	)
	return result

func _is_corner_boundary_tile(tile: Vector2i) -> bool:
	return (tile.x == 0 or tile.x == ROOM_WIDTH - 1) and (tile.y == 0 or tile.y == ROOM_HEIGHT - 1)

func _tile_touches_door(grid: Array, tile: Vector2i) -> bool:
	for dir: Vector2i in PathUtils.DIRS_4:
		var neighbor: Vector2i = tile + dir
		if not PathUtils.is_in_bounds(grid, neighbor):
			continue
		if str((grid[neighbor.y] as Array)[neighbor.x]) == TILE_DOOR:
			return true
	return false

func _transform_cell(cell: Vector2i, rotation_steps: int, mirrored: bool) -> Vector2i:
	var centered: Vector2i = cell - Vector2i(4, 4)
	if mirrored:
		centered.x = -centered.x
	for _i: int in range(rotation_steps):
		centered = Vector2i(-centered.y, centered.x)
	return centered + Vector2i(4, 4)

func _reachable_floor_count(grid: Array, start: Vector2i) -> int:
	var queue: Array[Vector2i] = []
	queue.append(start)
	var visited: Dictionary = {start: true}
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		for dir: Vector2i in PathUtils.DIRS_4:
			var next_tile: Vector2i = current + dir
			if visited.has(next_tile):
				continue
			if not PathUtils.is_passable(grid, next_tile):
				continue
			visited[next_tile] = true
			queue.append(next_tile)
	return visited.size()

func _encounter_enemy_types(room_type: String, depth: int, rng: RandomNumberGenerator) -> Array:
	if room_type == "start" or room_type == "campfire" or room_type == "treasure":
		return []
	if room_type == "boss":
		return ["heart_warden", "warden", "crawler"]
	var pool: Array = []
	match depth:
		1:
			pool = [
				["crawler", "crawler", "harrier"],
				["crawler", "harrier", "acolyte"],
				["crawler", "crawler", "acolyte"]
			]
		2:
			pool = [
				["warden", "crawler", "crawler", "harrier"],
				["acolyte", "harrier", "crawler", "crawler"],
				["warden", "acolyte", "harrier", "crawler"]
			]
		_:
			pool = [
				["warden", "harrier", "acolyte", "crawler", "crawler"],
				["warden", "warden", "crawler", "crawler", "harrier"],
				["warden", "acolyte", "harrier", "crawler", "crawler"]
			]
	return pool[rng.randi_range(0, pool.size() - 1)].duplicate()

func _pick_enemy_positions(grid: Array, player_start: Vector2i, count: int, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var floor_tiles: Array[Vector2i] = _floor_tiles(grid)
	var candidates: Array[Vector2i] = []
	for tile: Vector2i in floor_tiles:
		if tile == player_start:
			continue
		if PathUtils.manhattan(tile, player_start) <= ENEMY_SPAWN_SAFE_RADIUS:
			continue
		candidates.append(tile)
	for index: int in range(candidates.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, index)
		var tmp: Vector2i = candidates[index]
		candidates[index] = candidates[swap_index]
		candidates[swap_index] = tmp
	var chosen: Array[Vector2i] = []
	while chosen.size() < count and not candidates.is_empty():
		var scored: Array[Dictionary] = []
		for index: int in range(candidates.size()):
			var tile: Vector2i = candidates[index]
			scored.append({
				"index": index,
				"score": _enemy_spawn_score(tile, player_start, chosen, rng)
			})
		scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return float(a.get("score", 0.0)) > float(b.get("score", 0.0))
		)
		var pick_window: int = mini(ENEMY_SPAWN_PICK_WINDOW, scored.size())
		var best_score: float = float(scored[0].get("score", 0.0))
		var worst_score: float = float(scored[pick_window - 1].get("score", 0.0))
		var total_weight: float = 0.0
		for rank: int in range(pick_window):
			total_weight += maxf(0.05, float(scored[rank].get("score", 0.0)) - worst_score + 0.05)
		var roll: float = rng.randf() * total_weight
		var picked_rank: int = 0
		for rank: int in range(pick_window):
			var weight: float = maxf(0.05, float(scored[rank].get("score", 0.0)) - worst_score + 0.05)
			roll -= weight
			if roll <= 0.0:
				picked_rank = rank
				break
		if best_score - worst_score < 0.001:
			picked_rank = rng.randi_range(0, pick_window - 1)
		var picked_index: int = int(scored[picked_rank].get("index", 0))
		var tile: Vector2i = candidates[picked_index]
		candidates.remove_at(picked_index)
		chosen.append(tile)
		if chosen.size() >= count:
			break
	if chosen.size() < count:
		for tile: Vector2i in floor_tiles:
			if tile == player_start or chosen.has(tile):
				continue
			if PathUtils.manhattan(tile, player_start) <= ENEMY_SPAWN_SAFE_RADIUS:
				continue
			chosen.append(tile)
			if chosen.size() >= count:
				break
	return chosen

func _enemy_spawn_score(tile: Vector2i, player_start: Vector2i, chosen: Array[Vector2i], rng: RandomNumberGenerator) -> float:
	var score: float = rng.randf() * 1.4
	var player_distance: int = PathUtils.manhattan(tile, player_start)
	score -= absf(float(player_distance - 4)) * 0.08
	score -= float(_room_edge_count(tile)) * 0.12
	if chosen.is_empty():
		return score
	var nearest_distance: int = 99
	var same_corner_count: int = 0
	var same_wall_band_count: int = 0
	var tile_corner: Vector2i = _room_corner_band(tile)
	for existing: Vector2i in chosen:
		var distance: int = PathUtils.manhattan(tile, existing)
		nearest_distance = mini(nearest_distance, distance)
		if tile_corner != Vector2i.ZERO and tile_corner == _room_corner_band(existing):
			same_corner_count += 1
		if _shares_wall_band(tile, existing):
			same_wall_band_count += 1
	if nearest_distance <= 1:
		score -= 3.0
	elif nearest_distance == 2:
		score -= 1.0
	elif nearest_distance == 3:
		score += 0.2
	else:
		score += 0.35
	score -= float(same_corner_count) * 0.9
	score -= float(same_wall_band_count) * 0.22
	return score

func _room_edge_count(tile: Vector2i) -> int:
	var edges: int = 0
	if tile.x == 1 or tile.x == ROOM_WIDTH - 2:
		edges += 1
	if tile.y == 1 or tile.y == ROOM_HEIGHT - 2:
		edges += 1
	return edges

func _room_corner_band(tile: Vector2i) -> Vector2i:
	var band_x: int = 0
	if tile.x <= 2:
		band_x = -1
	elif tile.x >= ROOM_WIDTH - 3:
		band_x = 1
	var band_y: int = 0
	if tile.y <= 2:
		band_y = -1
	elif tile.y >= ROOM_HEIGHT - 3:
		band_y = 1
	if band_x == 0 or band_y == 0:
		return Vector2i.ZERO
	return Vector2i(band_x, band_y)

func _shares_wall_band(a: Vector2i, b: Vector2i) -> bool:
	return (
		(a.x <= 2 and b.x <= 2)
		or (a.x >= ROOM_WIDTH - 3 and b.x >= ROOM_WIDTH - 3)
		or (a.y <= 2 and b.y <= 2)
		or (a.y >= ROOM_HEIGHT - 3 and b.y >= ROOM_HEIGHT - 3)
	)

func _build_room_npcs(grid: Array, player_start: Vector2i, npc_specs: Array, rng: RandomNumberGenerator, occupied: Dictionary) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var occupied_tiles: Dictionary = occupied.duplicate(true)
	for index: int in range(npc_specs.size()):
		if typeof(npc_specs[index]) != TYPE_DICTIONARY:
			continue
		var spec: Dictionary = npc_specs[index]
		var npc_id: String = str(spec.get("id", ""))
		if npc_id.is_empty():
			continue
		var pos: Vector2i = spec.get("pos", Vector2i(-1, -1))
		if not _can_place_room_actor(grid, pos, occupied_tiles) or pos == player_start:
			pos = _fallback_npc_position(grid, player_start, occupied_tiles, rng)
		if not _can_place_room_actor(grid, pos, occupied_tiles):
			continue
		occupied_tiles[pos] = true
		var npc_def: Dictionary = GameData.npc_def(npc_id)
		results.append({
			"id": npc_id,
			"name": str(npc_def.get("name", npc_id)),
			"pos": pos,
			"accent": str(npc_def.get("accent", "#d2c2a7"))
		})
	return results

func _can_place_room_actor(grid: Array, tile: Vector2i, occupied: Dictionary) -> bool:
	return tile.x >= 0 and tile.y >= 0 and PathUtils.is_passable(grid, tile) and not occupied.has(tile)

func _fallback_npc_position(grid: Array, player_start: Vector2i, occupied: Dictionary, rng: RandomNumberGenerator) -> Vector2i:
	var best_tile: Vector2i = Vector2i(-1, -1)
	var best_score: float = -INF
	var room_center: Vector2 = Vector2((ROOM_WIDTH - 1) * 0.5, (ROOM_HEIGHT - 1) * 0.5)
	for tile: Vector2i in _floor_tiles(grid):
		if occupied.has(tile) or tile == player_start:
			continue
		var score: float = -tile.distance_to(room_center)
		score += float(PathUtils.manhattan(tile, player_start)) * 0.8
		score += rng.randf() * 0.15
		if score > best_score:
			best_score = score
			best_tile = tile
	return best_tile

func _generate_loot(grid: Array, room_type: String, depth: int, rng: RandomNumberGenerator, occupied: Dictionary) -> Array[Dictionary]:
	var loot: Array[Dictionary] = []
	if room_type == "boss":
		return loot
	if room_type == "treasure" or room_type == "campfire":
		return loot
	if rng.randf() > 0.55:
		return loot
	var candidates: Array[Vector2i] = []
	for tile: Vector2i in _floor_tiles(grid):
		if occupied.has(tile):
			continue
		if PathUtils.manhattan(tile, Vector2i(4, 4)) > 4:
			continue
		candidates.append(tile)
	if candidates.is_empty():
		return loot
	var loot_tile: Vector2i = candidates[rng.randi_range(0, candidates.size() - 1)]
	var heal_amount: int = 4 + depth
	var ember_amount: int = 5 + depth * 2
	var loot_kind: String = "healing_vial" if rng.randf() < 0.5 else "ember_cache"
	loot.append({
		"id": "loot_%d_%d" % [loot_tile.x, loot_tile.y],
		"kind": loot_kind,
		"amount": heal_amount if loot_kind == "healing_vial" else ember_amount,
		"pos": loot_tile
	})
	return loot

func _generate_traps(grid: Array, room_type: String, room_element: String, depth: int, player_start: Vector2i, rng: RandomNumberGenerator, occupied: Dictionary) -> Array[Dictionary]:
	var traps: Array[Dictionary] = []
	if room_type not in ["combat", "boss"]:
		return traps
	if not ElementData.is_elemental(room_element):
		return traps
	var candidates: Array[Vector2i] = []
	for tile: Vector2i in _floor_tiles(grid):
		if occupied.has(tile):
			continue
		if PathUtils.manhattan(tile, player_start) < 2:
			continue
		candidates.append(tile)
	if candidates.is_empty():
		return traps
	var trap_count: int = rng.randi_range(2, 3)
	var chosen: Array[Vector2i] = []
	while chosen.size() < trap_count and not candidates.is_empty():
		var best_index: int = 0
		var best_score: float = -INF
		for index: int in range(candidates.size()):
			var tile: Vector2i = candidates[index]
			var score: float = _trap_spawn_score(tile, player_start, chosen, rng)
			if score > best_score:
				best_score = score
				best_index = index
		var trap_tile: Vector2i = candidates[best_index]
		candidates.remove_at(best_index)
		chosen.append(trap_tile)
		traps.append(_trap_for_tile(trap_tile, room_element, depth))
	return traps

func _trap_spawn_score(tile: Vector2i, player_start: Vector2i, chosen: Array[Vector2i], rng: RandomNumberGenerator) -> float:
	var room_center: Vector2 = Vector2((ROOM_WIDTH - 1) * 0.5, (ROOM_HEIGHT - 1) * 0.5)
	var player_distance: int = PathUtils.manhattan(tile, player_start)
	var score: float = -tile.distance_to(room_center) * 1.1
	score -= absf(float(player_distance - 4)) * 0.18
	score -= float(_room_edge_count(tile)) * 0.45
	if _room_corner_band(tile) != Vector2i.ZERO:
		score -= 0.65
	if not chosen.is_empty():
		var nearest_distance: int = 99
		for existing: Vector2i in chosen:
			nearest_distance = mini(nearest_distance, PathUtils.manhattan(tile, existing))
		if nearest_distance <= 1:
			score -= 4.0
		else:
			score -= absf(float(nearest_distance - 3)) * 0.28
	score += rng.randf() * 0.35
	return score

func _trap_for_tile(tile: Vector2i, room_element: String, depth: int) -> Dictionary:
	var trap: Dictionary = {
		"id": "trap_%d_%d" % [tile.x, tile.y],
		"pos": tile,
		"element": room_element,
		"damage": clampi(1 + depth, 2, 4)
	}
	match room_element:
		ElementData.FIRE:
			trap["burn"] = 1 if depth <= 1 else 2 if depth == 2 else 3
		ElementData.ICE:
			trap["freeze"] = 1
		ElementData.LIGHTNING:
			trap["shock"] = 1
		ElementData.AIR:
			trap["stun"] = 1
		ElementData.EARTH:
			trap["poison"] = 2 if depth <= 2 else 3
	return trap

func _floor_tiles(grid: Array) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for y: int in range(grid.size()):
		var row: Array = grid[y]
		for x: int in range(row.size()):
			var tile: Vector2i = Vector2i(x, y)
			if PathUtils.is_passable(grid, tile):
				tiles.append(tile)
	return tiles

func _room_name(coord: Vector2i, room_type: String, rng: RandomNumberGenerator) -> String:
	if room_type == "boss":
		return "The Heart Sanctum"
	if room_type == "campfire":
		return "Ashen Campfire"
	if room_type == "treasure":
		return "Relic Cache"
	return "%s %s" % [
		ROOM_NAME_PREFIXES[(absi(coord.x) + rng.randi_range(0, ROOM_NAME_PREFIXES.size() - 1)) % ROOM_NAME_PREFIXES.size()],
		ROOM_NAME_SUFFIXES[(absi(coord.y) + rng.randi_range(0, ROOM_NAME_SUFFIXES.size() - 1)) % ROOM_NAME_SUFFIXES.size()]
	]

func _room_seed(run_seed: int, coord: Vector2i, salt: int) -> int:
	var value: int = run_seed
	value = int((value * 1103515245 + 12345 + salt) & 0x7fffffff)
	value = int((value + coord.x * 92821 + coord.y * 68917) & 0x7fffffff)
	return value

static func door_tile_for_direction(dir: Vector2i) -> Vector2i:
	return DOOR_BY_DIRECTION.get(dir, Vector2i(-1, -1))

static func entry_tile_for_direction(dir: Vector2i) -> Vector2i:
	return ENTRANCE_BY_TRAVEL_DIR.get(dir, ENTRANCE_BY_TRAVEL_DIR[Vector2i.ZERO])
