extends RefCounted

const Library = preload("res://scripts/special_encounter_library.gd")
const Paths = preload("res://scripts/path_utils.gd")
const MAX_PLACEMENT_ATTEMPTS: int = 20
const ESCORT_RADIUS: int = 3

static func roster(room: Dictionary, tier: int) -> Array:
	var variant: Dictionary = Library.definition("warband")["variants"][room["special_variant"]]
	return [variant["captain"]] + (variant["escort"] as Array).slice(0, tier + 2)

static func objective(room: Dictionary, tier: int) -> Dictionary:
	var rules: Dictionary = Library.definition("warband")
	var variant: Dictionary = rules["variants"][room["special_variant"]]
	return {"special_type": "warband", "special_variant": room["special_variant"], "leader_display_name": variant["title"],
		"leader_health_multiplier": rules["captain"]["hp_multiplier"], "leader_stoneskin": rules["captain"]["stoneskin_by_tier"][tier - 1],
		"command": rules["captain"]["command"].duplicate(true), "keep_distance": rules["captain"]["keep_distance"].duplicate(true), "break_line": rules["break_line"]}

# The range metric is Manhattan, as for all combat ranges. Reachability and
# shortest paths additionally respect the generated grid. No units are trimmed.
static func positions(grid: Array, entry: Vector2i, count: int, rng: RandomNumberGenerator, dynamo: bool, deterministic: bool = false) -> Array[Vector2i]:
	var rules: Dictionary = Library.definition("warband")["captain"]
	var reachable: Array[Vector2i] = Paths.reachable_tiles(grid, entry, grid.size() * grid.size())
	var captains: Array[Vector2i]
	for tile: Vector2i in reachable:
		var distance: int = Paths.manhattan(tile, entry)
		if distance >= int(rules["start_distance"][0]) and distance <= int(rules["start_distance"][1]): captains.append(tile)
	# Dynamo must use the globally farthest legal anchor, not just the farthest
	# of a random sample. Stable order resolves otherwise identical candidates.
	captains.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return Paths.manhattan(a, entry) > Paths.manhattan(b, entry) if Paths.manhattan(a, entry) != Paths.manhattan(b, entry) else a.y * grid.size() + a.x < b.y * grid.size() + b.x)
	if not deterministic and not dynamo: _shuffle(captains, rng)
	for captain: Vector2i in captains:
		var path: Array[Vector2i] = Paths.find_path(grid, entry, captain)
		var screens: Array[Vector2i]
		for tile: Vector2i in reachable:
			if tile == captain or Paths.manhattan(tile, entry) >= Paths.manhattan(captain, entry): continue
			var to_screen: Array[Vector2i] = Paths.find_path(grid, entry, tile)
			var to_captain: Array[Vector2i] = Paths.find_path(grid, tile, captain)
			if to_screen.size() + to_captain.size() == path.size() + 1: screens.append(tile)
		if not deterministic: _shuffle(screens, rng)
		for screen: Vector2i in screens:
			var rest: Array[Vector2i]
			for tile: Vector2i in reachable:
				if tile != captain and tile != screen and Paths.manhattan(tile, captain) <= ESCORT_RADIUS: rest.append(tile)
			if rest.size() < count - 2: continue
			if not deterministic: _shuffle(rest, rng)
			var result: Array[Vector2i]
			result.append(captain)
			result.append(screen)
			result.append_array(rest.slice(0, count - 2))
			return result
	var empty: Array[Vector2i]
	return empty

static func _shuffle(tiles: Array[Vector2i], rng: RandomNumberGenerator) -> void:
	for index: int in range(tiles.size() - 1, 0, -1):
		var other: int = rng.randi_range(0, index)
		var value: Vector2i = tiles[index]
		tiles[index] = tiles[other]
		tiles[other] = value

static func validate(layout: Dictionary) -> bool:
	var enemies: Array = layout["enemies"]
	var captain: Vector2i = enemies[0]["pos"]
	var entry: Vector2i = layout["player_start"]
	var grid: Array = layout["grid"]
	var distance: int = Paths.manhattan(captain, entry)
	var rules: Dictionary = Library.definition("warband")["captain"]
	if distance < int(rules["start_distance"][0]) or distance > int(rules["start_distance"][1]): return false
	var occupied: Dictionary = {entry: true}
	var closest: int = distance
	for index: int in range(enemies.size()):
		var tile: Vector2i = enemies[index]["pos"]
		if occupied.has(tile) or not Paths.is_passable(grid, tile) or Paths.find_path(grid, entry, tile).is_empty(): return false
		occupied[tile] = true
		closest = mini(closest, Paths.manhattan(entry, tile))
		if index > 1 and Paths.manhattan(captain, tile) > ESCORT_RADIUS: return false
	var screen: Vector2i = enemies[1]["pos"]
	if Paths.find_path(grid, entry, screen).size() + Paths.find_path(grid, screen, captain).size() != Paths.find_path(grid, entry, captain).size() + 1: return false
	if closest >= distance: return false
	if str(enemies[0]["type"]) == "storm_capacitor":
		var unused_rng := RandomNumberGenerator.new()
		var deepest: Array[Vector2i] = positions(grid, entry, enemies.size(), unused_rng, true, true)
		if deepest.is_empty() or Paths.manhattan(deepest[0], entry) != distance: return false
	return true
