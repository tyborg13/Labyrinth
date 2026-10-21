extends RefCounted

const Library = preload("res://scripts/special_encounter_library.gd")
const Paths = preload("res://scripts/path_utils.gd")
const MAX_PLACEMENT_ATTEMPTS: int = 20
# Director feedback 1 supersedes the protected data's original 4–6 opening.
# Keep that supplied file untouched until its owner updates it in spx-02.
const CAPTAIN_START_DISTANCE_MIN: int = 5
const CAPTAIN_START_DISTANCE_MAX: int = 7
const ESCORT_ENTRY_DISTANCE_MIN: int = 3

static func roster(room: Dictionary, tier: int) -> Array:
	var variant: Dictionary = Library.definition("warband")["variants"][room["special_variant"]]
	return [variant["captain"]] + (variant["escort"] as Array).slice(0, tier + 2)

static func objective(room: Dictionary, tier: int) -> Dictionary:
	var rules: Dictionary = Library.definition("warband")
	var variant: Dictionary = rules["variants"][room["special_variant"]]
	return {"special_type": "warband", "special_variant": room["special_variant"], "leader_display_name": variant["title"],
		"leader_health_multiplier": rules["captain"]["hp_multiplier"], "leader_stoneskin": rules["captain"]["stoneskin_by_tier"][tier - 1],
		"command": rules["captain"]["command"].duplicate(true), "keep_distance": rules["captain"]["keep_distance"].duplicate(true), "break_line": rules["break_line"]}

# Ranges use Manhattan distance. A screen must also lie on a shortest walkable
# route; every complete formation has an approach avoiding its outer followers.
static func positions(grid: Array, entry: Vector2i, count: int, entry_safe_radius: int, rng: RandomNumberGenerator, dynamo: bool, deterministic: bool = false, _legacy_relax: bool = false) -> Array[Vector2i]:
	var rules: Dictionary = Library.definition("warband")["followers"]
	var reachable: Array[Vector2i] = Paths.reachable_tiles(grid, entry, grid.size() * grid.size())
	var captains: Array[Vector2i]
	for tile: Vector2i in reachable:
		var distance: int = Paths.manhattan(tile, entry)
		if distance >= CAPTAIN_START_DISTANCE_MIN and distance <= CAPTAIN_START_DISTANCE_MAX and distance > entry_safe_radius: captains.append(tile)
	captains.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return Paths.manhattan(a, entry) > Paths.manhattan(b, entry) if Paths.manhattan(a, entry) != Paths.manhattan(b, entry) else _row_major_precedes(a, b))
	if not deterministic and not dynamo: _shuffle(captains, rng)
	for captain: Vector2i in captains:
		var guards: Array[Vector2i]
		var screens: Array[Vector2i]
		var skirmishers: Array[Vector2i]
		var shortest: int = Paths.find_path(grid, entry, captain).size()
		for tile: Vector2i in reachable:
			if tile == captain or not _escort_entry_safe(tile, entry, entry_safe_radius): continue
			var captain_distance: int = Paths.manhattan(tile, captain)
			if captain_distance <= int(rules["guard_radius"]): guards.append(tile)
			if captain_distance >= int(rules["screen_distance"][0]) and captain_distance <= int(rules["screen_distance"][1]) and Paths.manhattan(entry, tile) + captain_distance == Paths.manhattan(entry, captain):
				if Paths.find_path(grid, entry, tile).size() + Paths.find_path(grid, tile, captain).size() == shortest + 1: screens.append(tile)
			var from_entry: int = Paths.manhattan(tile, entry)
			if from_entry >= int(rules["skirmisher_entry_distance"][0]) and from_entry <= int(rules["skirmisher_entry_distance"][1]) and captain_distance >= int(rules["min_gap"]): skirmishers.append(tile)
		if not deterministic:
			_shuffle(guards, rng)
			_shuffle(screens, rng)
			_shuffle(skirmishers, rng)
		# The seeded candidate order is the only priority within each side.
		for guard: Vector2i in guards:
			for screen: Vector2i in screens:
				if Paths.manhattan(guard, screen) <= 1: continue
				var result: Array[Vector2i]
				result.append(captain)
				result.append(guard)
				result.append(screen)
				if _place_skirmishers(grid, entry, result, skirmishers, count, int(rules["min_gap"])): return result
	var empty: Array[Vector2i]
	return empty

static func _row_major_precedes(a: Vector2i, b: Vector2i) -> bool:
	return a.y < b.y if a.y != b.y else a.x < b.x

static func side(entry: Vector2i, captain: Vector2i, tile: Vector2i) -> int:
	var line: Vector2i = captain - entry
	var offset: Vector2i = tile - entry
	# In grid/screen coordinates y grows down: negative cross is left.
	return line.x * offset.y - line.y * offset.x

static func _place_skirmishers(grid: Array, entry: Vector2i, result: Array[Vector2i], candidates: Array[Vector2i], count: int, min_gap: int) -> bool:
	if result.size() == count: return has_way_through(grid, entry, result)
	var left: bool = (result.size() - 3) % 2 == 0
	for tile: Vector2i in candidates:
		var offset: int = side(entry, result[0], tile)
		if offset == 0 or (offset < 0) != left: continue
		var legal: bool = true
		for placed: Vector2i in result:
			if Paths.manhattan(tile, placed) < min_gap:
				legal = false
				break
		if not legal: continue
		result.append(tile)
		# Once blocked, adding another follower can never restore the approach.
		if has_way_through(grid, entry, result) and _place_skirmishers(grid, entry, result, candidates, count, min_gap): return true
		result.pop_back()
	return false

static func has_way_through(grid: Array, entry: Vector2i, positions: Array[Vector2i]) -> bool:
	var blocked: Dictionary = {}
	for index: int in range(positions.size()):
		var tile: Vector2i = positions[index]
		blocked[tile] = true
		if index >= 2:
			for axis: Vector2i in Paths.DIRS_4: blocked[tile + axis] = true
	if blocked.has(entry): return false
	var queue: Array[Vector2i]
	queue.append(entry)
	var seen: Dictionary = {entry: true}
	var cursor: int = 0
	while cursor < queue.size():
		var tile: Vector2i = queue[cursor]
		cursor += 1
		if Paths.manhattan(tile, positions[0]) <= 2: return true
		for axis: Vector2i in Paths.DIRS_4:
			var next: Vector2i = tile + axis
			if seen.has(next) or blocked.has(next) or not Paths.is_passable(grid, next): continue
			seen[next] = true
			queue.append(next)
	return false

static func fallback_positions(grid: Array, entry: Vector2i, count: int, entry_safe_radius: int, dynamo: bool) -> Array[Vector2i]:
	var unused_rng := RandomNumberGenerator.new()
	return positions(grid, entry, count, entry_safe_radius, unused_rng, dynamo, true)

static func _escort_entry_safe(tile: Vector2i, entry: Vector2i, entry_safe_radius: int) -> bool:
	var distance: int = Paths.manhattan(tile, entry)
	return distance >= ESCORT_ENTRY_DISTANCE_MIN and distance > entry_safe_radius

static func _shuffle(tiles: Array[Vector2i], rng: RandomNumberGenerator) -> void:
	for index: int in range(tiles.size() - 1, 0, -1):
		var other: int = rng.randi_range(0, index)
		var value: Vector2i = tiles[index]
		tiles[index] = tiles[other]
		tiles[other] = value

static func validate(layout: Dictionary, entry_safe_radius: int) -> bool:
	var enemies: Array = layout["enemies"]
	if enemies.size() < 3: return false
	var rules: Dictionary = Library.definition("warband")["followers"]
	var captain: Vector2i = enemies[0]["pos"]
	var entry: Vector2i = layout["player_start"]
	var grid: Array = layout["grid"]
	var distance: int = Paths.manhattan(captain, entry)
	if distance < CAPTAIN_START_DISTANCE_MIN or distance > CAPTAIN_START_DISTANCE_MAX: return false
	var occupied: Dictionary = {entry: true}
	var placed: Array[Vector2i]
	for index: int in range(enemies.size()):
		var tile: Vector2i = enemies[index]["pos"]
		if occupied.has(tile) or not Paths.is_passable(grid, tile) or Paths.find_path(grid, entry, tile).is_empty(): return false
		if Paths.manhattan(entry, tile) <= entry_safe_radius: return false
		if index > 0 and not _escort_entry_safe(tile, entry, entry_safe_radius): return false
		if index == 1 and Paths.manhattan(tile, captain) > int(rules["guard_radius"]): return false
		if index >= 3:
			var from_entry: int = Paths.manhattan(tile, entry)
			if from_entry < int(rules["skirmisher_entry_distance"][0]) or from_entry > int(rules["skirmisher_entry_distance"][1]): return false
			var offset: int = side(entry, captain, tile)
			if offset == 0 or (offset < 0) != ((index - 3) % 2 == 0): return false
		for previous: int in range(placed.size()):
			if index > 0 and previous > 0 and Paths.manhattan(tile, placed[previous]) <= 1: return false
			if index >= 3 and Paths.manhattan(tile, placed[previous]) < int(rules["min_gap"]): return false
		placed.append(tile)
		occupied[tile] = true
	var screen: Vector2i = placed[2]
	var screen_distance: int = Paths.manhattan(screen, captain)
	if screen_distance < int(rules["screen_distance"][0]) or screen_distance > int(rules["screen_distance"][1]): return false
	if Paths.manhattan(entry, screen) + screen_distance != distance: return false
	if Paths.find_path(grid, entry, screen).size() + Paths.find_path(grid, screen, captain).size() != Paths.find_path(grid, entry, captain).size() + 1: return false
	if not has_way_through(grid, entry, placed): return false
	if str(enemies[0]["type"]) == "storm_capacitor":
		var unused_rng := RandomNumberGenerator.new()
		var deepest: Array[Vector2i] = positions(grid, entry, enemies.size(), entry_safe_radius, unused_rng, true, true)
		if deepest.is_empty() or Paths.manhattan(deepest[0], entry) != distance: return false
	return true
