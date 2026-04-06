extends RefCounted
class_name RoomGenerator

const GameData = preload("res://scripts/game_data.gd")
const PathUtils = preload("res://scripts/path_utils.gd")

const ROOM_WIDTH: int = 9
const ROOM_HEIGHT: int = 9

const TILE_ASH: String = "ash"
const TILE_MOSS: String = "moss"
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
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = _room_seed(run_seed, coord, 101)

	var grid: Array = _base_grid(rng)
	var entrance_tile: Vector2i = ENTRANCE_BY_TRAVEL_DIR.get(travel_dir, ENTRANCE_BY_TRAVEL_DIR[Vector2i.ZERO])
	_apply_available_doors(grid, coord)
	_apply_template(grid, rng)

	var player_start: Vector2i = entrance_tile
	var enemy_types: Array = _encounter_enemy_types(room_type, depth, rng)
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
	var loot: Array[Dictionary] = _generate_loot(grid, room_type, depth, rng, occupied)

	return {
		"name": _room_name(coord, room_type, rng),
		"coord": coord,
		"depth": depth,
		"type": room_type,
		"element": room_element,
		"grid": grid,
		"player_start": player_start,
		"enemies": enemies,
		"loot": loot,
		"theme": _theme_id(rng)
	}

func _base_grid(rng: RandomNumberGenerator) -> Array:
	var floor_tile: String = _theme_id(rng)
	var grid: Array = []
	for y: int in range(ROOM_HEIGHT):
		var row: Array[String] = []
		for x: int in range(ROOM_WIDTH):
			var tile_id: String = floor_tile
			if x == 0 or y == 0 or x == ROOM_WIDTH - 1 or y == ROOM_HEIGHT - 1:
				tile_id = TILE_WALL
			row.append(tile_id)
		grid.append(row)
	return grid

func _apply_available_doors(grid: Array, coord: Vector2i) -> void:
	for dir: Vector2i in PathUtils.DIRS_4:
		var neighbor: Vector2i = coord + dir
		var depth: int = absi(neighbor.x) + absi(neighbor.y)
		if depth > 4:
			continue
		var door_tile: Vector2i = DOOR_BY_DIRECTION.get(dir, Vector2i(-1, -1))
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

func _transform_cell(cell: Vector2i, rotation_steps: int, mirrored: bool) -> Vector2i:
	var centered: Vector2i = cell - Vector2i(4, 4)
	if mirrored:
		centered.x = -centered.x
	for _i: int in range(rotation_steps):
		centered = Vector2i(-centered.y, centered.x)
	return centered + Vector2i(4, 4)

func _reachable_floor_count(grid: Array, start: Vector2i) -> int:
	var queue: Array[Vector2i] = [start]
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
		if PathUtils.manhattan(tile, player_start) < 3:
			continue
		candidates.append(tile)
	for index: int in range(candidates.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, index)
		var tmp: Vector2i = candidates[index]
		candidates[index] = candidates[swap_index]
		candidates[swap_index] = tmp
	var chosen: Array[Vector2i] = []
	while chosen.size() < count and not candidates.is_empty():
		var best_index: int = 0
		var best_score: float = -INF
		for index: int in range(candidates.size()):
			var tile: Vector2i = candidates[index]
			var score: float = float(PathUtils.manhattan(tile, player_start)) * 0.9
			for existing: Vector2i in chosen:
				score += float(PathUtils.manhattan(existing, tile)) * 0.18
			score += rng.randf() * 0.25
			if score > best_score:
				best_score = score
				best_index = index
		var tile: Vector2i = candidates[best_index]
		candidates.remove_at(best_index)
		chosen.append(tile)
		if chosen.size() >= count:
			break
	if chosen.size() < count:
		for tile: Vector2i in floor_tiles:
			if tile == player_start or chosen.has(tile):
				continue
			chosen.append(tile)
			if chosen.size() >= count:
				break
	return chosen

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

func _theme_id(rng: RandomNumberGenerator) -> String:
	var roll: float = rng.randf()
	if roll < 0.34:
		return TILE_ASH
	if roll < 0.67:
		return TILE_MOSS
	return TILE_EMBER

func _room_seed(run_seed: int, coord: Vector2i, salt: int) -> int:
	var value: int = run_seed
	value = int((value * 1103515245 + 12345 + salt) & 0x7fffffff)
	value = int((value + coord.x * 92821 + coord.y * 68917) & 0x7fffffff)
	return value

static func door_tile_for_direction(dir: Vector2i) -> Vector2i:
	return DOOR_BY_DIRECTION.get(dir, Vector2i(-1, -1))

static func entry_tile_for_direction(dir: Vector2i) -> Vector2i:
	return ENTRANCE_BY_TRAVEL_DIR.get(dir, ENTRANCE_BY_TRAVEL_DIR[Vector2i.ZERO])
