extends RefCounted

const RoomGeneratorScript = preload("res://scripts/room_generator.gd")
const RunEngineScript = preload("res://scripts/run_engine.gd")
const CombatObjectiveRulesScript = preload("res://scripts/combat_objective_rules.gd")
const DragonBossLibraryScript = preload("res://scripts/dragon_boss_library.gd")
const GameDataScript = preload("res://scripts/game_data.gd")


class RngRecordingGenerator:
	extends RoomGeneratorScript

	var final_rng_state: int = 0
	var flood_fill_calls: int = 0

	func _room_name(coord: Vector2i, room_type: String, rng: RandomNumberGenerator, boss_id: String = "") -> String:
		var result: String = super._room_name(coord, room_type, rng, boss_id)
		final_rng_state = rng.state
		return result

	func _terrain_layout_stays_connected(grid: Array, start: Vector2i, blocked: Dictionary) -> bool:
		flood_fill_calls += 1
		return super._terrain_layout_stays_connected(grid, start, blocked)


class OriginalTerrainGenerator:
	extends RngRecordingGenerator

	# Force the original per-candidate flood fill through the same public room
	# generator, including every score, selection, loot roll and final name roll.
	func _terrain_safe_candidate_lookup(grid: Array, start: Vector2i, blocked: Dictionary, candidates: Array[Vector2i]) -> Dictionary:
		var result: Dictionary = {}
		for candidate: Vector2i in candidates:
			var proposed_blocked: Dictionary = blocked.duplicate(true)
			proposed_blocked[candidate] = true
			if _terrain_layout_stays_connected(grid, start, proposed_blocked):
				result[candidate] = true
		return result


static func run(expect: Callable) -> void:
	_test_graph_edge_cases(expect)
	_test_all_small_floor_graphs(expect)
	_test_complete_room_and_rng_equivalence(expect)
	_test_pre_battle_gear_context_equivalence(expect)


static func _test_graph_edge_cases(expect: Callable) -> void:
	var cases: Array = [
		{"name": "corridor cut vertices", "rows": ["....."], "start": Vector2i(0, 0)},
		{"name": "cycle without cut vertices", "rows": ["...", ".#.", "..."], "start": Vector2i(0, 0)},
		{"name": "root with several branches", "rows": ["#.#", "...", "#.#"], "start": Vector2i(1, 1)},
		{"name": "disconnected singleton removable", "rows": ["..#."], "start": Vector2i(0, 0)},
		{"name": "disconnected multi-tile component", "rows": ["..#.."], "start": Vector2i(0, 0)},
		{"name": "start already blocked", "rows": ["..."], "start": Vector2i(0, 0), "blocked": [Vector2i(0, 0)]},
		{"name": "all floor tiles blocked", "rows": ["..."], "start": Vector2i(0, 0), "blocked": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]},
		{"name": "no open floor", "rows": ["###"], "start": Vector2i(0, 0)},
		{"name": "non-passable start retains old predicate", "rows": ["#..#."], "start": Vector2i(0, 0)},
		{"name": "only start remains", "rows": ["#.#"], "start": Vector2i(1, 0)},
		{"name": "blocked wall door pillar and out-of-bounds tile", "rows": ["...", ".#D", "..P"], "start": Vector2i(0, 0), "blocked": [Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 2), Vector2i(-4, 7)]},
		{"name": "prior terrain creates cut vertices", "rows": ["...", "...", "..."], "start": Vector2i(0, 0), "blocked": [Vector2i(1, 1), Vector2i(2, 1)]},
		{"name": "ragged floor graph", "rows": ["...", ".", ".."], "start": Vector2i(0, 0)},
	]
	for case_var: Variant in cases:
		var graph_case: Dictionary = case_var as Dictionary
		var grid: Array = _grid_from_rows(graph_case.get("rows", []) as Array)
		var blocked: Dictionary = _tile_lookup(graph_case.get("blocked", []) as Array)
		_assert_lookup_equivalence(grid, graph_case.get("start", Vector2i.ZERO), blocked, str(graph_case["name"]), expect)
	var generator := RngRecordingGenerator.new()
	var cycle: Array = _grid_from_rows(["...", ".#.", "..."])
	generator._terrain_safe_candidate_lookup(cycle, Vector2i.ZERO, {}, _all_candidates(cycle))
	expect.call(generator.flood_fill_calls == 0, "Connected terrain candidates should share graph analysis without per-candidate flood fills")
	var disconnected: Array = _grid_from_rows(["..#."])
	var accepted: Dictionary = generator._terrain_safe_candidate_lookup(disconnected, Vector2i.ZERO, {}, _all_candidates(disconnected))
	expect.call(accepted.has(Vector2i(3, 0)), "Removing a disconnected singleton must retain the original successful connectivity result")
	expect.call(generator.flood_fill_calls > 0, "Disconnected terrain graphs should retain the exact original flood-fill fallback")


static func _test_all_small_floor_graphs(expect: Callable) -> void:
	# Every 3x3 passability pattern exercises cut points, cycles and disconnected
	# components independently of the room templates. Include a blocked floor or
	# wall and a start that may itself be impassable, as the old predicate permits.
	for mask: int in range(512):
		var rows: Array = []
		for y: int in range(3):
			var row_text: String = ""
			for x: int in range(3):
				row_text += "." if (mask & (1 << (y * 3 + x))) != 0 else "#"
			rows.append(row_text)
		var grid: Array = _grid_from_rows(rows)
		_assert_lookup_equivalence(grid, Vector2i.ZERO, {}, "3x3 floor mask %d" % mask, expect)
		_assert_lookup_equivalence(grid, Vector2i(1, 1), {Vector2i(2, 1): true, Vector2i(-1, -1): true}, "3x3 blocked mask %d" % mask, expect)


static func _assert_lookup_equivalence(grid: Array, start: Vector2i, blocked: Dictionary, label: String, expect: Callable) -> void:
	var candidates: Array[Vector2i] = _all_candidates(grid)
	var original_grid: Array = grid.duplicate(true)
	var original_blocked: Dictionary = blocked.duplicate(true)
	var original_candidates: Array[Vector2i] = candidates.duplicate()
	var actual: Dictionary = RoomGeneratorScript.new()._terrain_safe_candidate_lookup(grid, start, blocked, candidates)
	var expected: Dictionary = {}
	for candidate: Vector2i in candidates:
		if _independent_candidate_connected(grid, start, blocked, candidate):
			expected[candidate] = true
	expect.call(actual == expected, "Terrain candidate connectivity should match independent reachability for %s (actual %s, expected %s)" % [label, actual, expected])
	expect.call(grid == original_grid and blocked == original_blocked and candidates == original_candidates, "Terrain connectivity analysis should preserve caller inputs for %s" % label)


static func _independent_candidate_connected(grid: Array, start: Vector2i, blocked: Dictionary, candidate: Vector2i) -> bool:
	if blocked.has(start) or candidate == start:
		return false
	var open: Dictionary = {}
	for y: int in range(grid.size()):
		var row: Array = grid[y]
		for x: int in range(row.size()):
			var tile := Vector2i(x, y)
			if str(row[x]) not in ["wall", "pillar", "door"] and not blocked.has(tile) and tile != candidate:
				open[tile] = true
	if open.is_empty():
		return false
	# The original predicate counts its start even if it is not passable. Keep
	# that behavior in this independent fixed-point reachability oracle too.
	var reached: Dictionary = {start: true}
	var changed: bool = true
	while changed:
		changed = false
		for tile: Vector2i in open:
			if reached.has(tile):
				continue
			if reached.has(tile + Vector2i.UP) or reached.has(tile + Vector2i.RIGHT) or reached.has(tile + Vector2i.DOWN) or reached.has(tile + Vector2i.LEFT):
				reached[tile] = true
				changed = true
	return reached.size() == open.size()


static func _test_complete_room_and_rng_equivalence(expect: Callable) -> void:
	var candidate := RngRecordingGenerator.new()
	var original := OriginalTerrainGenerator.new()
	var objectives_seen: Dictionary = {}
	var elements: Array = ["fire", "ice", "earth", "air", "lightning", "none"]
	var depths: Array = [1, 2, 3, 5, 7, 11, 19, 23]
	var equipment_ids: Array = GameDataScript.equipment_ids()
	expect.call(not equipment_ids.is_empty(), "Terrain equivalence should exercise real equipment-drop definitions")
	var drop_ids: Array = [""]
	if not equipment_ids.is_empty():
		drop_ids.append(str(equipment_ids[0]))
		drop_ids.append(str(equipment_ids[equipment_ids.size() - 1]))
	var directions: Array[Vector2i] = _travel_directions()
	for seed_index: int in range(24):
		var seed_value: int = 7103 + seed_index * 7919
		for direction_index: int in range(directions.size()):
			var depth: int = int(depths[(seed_index + direction_index) % depths.size()])
			var coord := Vector2i(depth if seed_index % 2 == 0 else -depth, posmod(seed_index * 3, depth * 2 + 1) - depth)
			for drop_var: Variant in drop_ids:
				var room: Dictionary = _room_metadata(coord, depth, "combat", str(elements[(seed_index + direction_index) % elements.size()]))
				room["equipment_drop"] = str(drop_var)
				room[CombatObjectiveRulesScript.ONBOARDING_ROOM_KEY] = seed_index % 7 == 0
				var result: Dictionary = _assert_room_equivalence(candidate, original, seed_value, room, directions[direction_index], expect)
				objectives_seen[str((result.get("objective", {}) as Dictionary).get("type", ""))] = true
	for objective_type: String in ["kill_all", "kill_leader", "survive", "reach_exit"]:
		expect.call(objectives_seen.has(objective_type), "Complete terrain parity matrix should exercise %s objectives" % objective_type)
	var boss_ids: Array = DragonBossLibraryScript.ELEMENTAL_BOSS_IDS.duplicate()
	boss_ids.append(DragonBossLibraryScript.SHADOW_BOSS_ID)
	for boss_var: Variant in boss_ids:
		var boss_id: String = str(boss_var)
		for depth: int in [4, 12, 24]:
			for direction: Vector2i in directions:
				var room: Dictionary = _room_metadata(Vector2i(-depth, depth), depth, "boss", DragonBossLibraryScript.element_for_boss(boss_id))
				room["boss_id"] = boss_id
				var result: Dictionary = _assert_room_equivalence(candidate, original, 91573 + depth, room, direction, expect)
				var enemies: Array = result.get("enemies", []) as Array
				expect.call(not enemies.is_empty() and (enemies[0] as Dictionary).get("footprint", Vector2i.ONE) == Vector2i(2, 2), "Terrain parity should include the large footprint for %s" % boss_id)
	for room_type: String in ["start", "campfire", "treasure", "scavenger"]:
		for direction: Vector2i in directions:
			_assert_room_equivalence(candidate, original, 92183, _room_metadata(Vector2i(2, -1), 2, room_type, "none"), direction, expect)
	expect.call(original.flood_fill_calls > candidate.flood_fill_calls, "Equivalent complete room generation should eliminate repeated connectivity flood fills")


static func _assert_room_equivalence(candidate: RngRecordingGenerator, original: OriginalTerrainGenerator, seed_value: int, room: Dictionary, direction: Vector2i, expect: Callable) -> Dictionary:
	var input_before: Dictionary = room.duplicate(true)
	var actual: Dictionary = candidate.generate_room(seed_value, room, direction)
	var expected: Dictionary = original.generate_room(seed_value, room, direction)
	var context: String = "seed %d, room %s, travel %s, drop %s" % [seed_value, room, direction, room.get("equipment_drop", "")]
	expect.call(actual == expected, "Complete generated room must match original terrain placement for %s" % context)
	expect.call(candidate.final_rng_state == original.final_rng_state, "Final generation RNG state must match original terrain placement for %s" % context)
	expect.call(room == input_before, "Room generation must preserve input metadata for %s" % context)
	return actual


static func _test_pre_battle_gear_context_equivalence(expect: Callable) -> void:
	var candidate_generator := RngRecordingGenerator.new()
	var original_generator := OriginalTerrainGenerator.new()
	var candidate_engine := RunEngineScript.new()
	var original_engine := RunEngineScript.new()
	candidate_engine.set("_room_generator", candidate_generator)
	original_engine.set("_room_generator", original_generator)
	var equipment_ids: Array = GameDataScript.equipment_ids()
	var directions: Array[Vector2i] = _travel_directions()
	for context_index: int in range(20):
		var depth: int = 1 + context_index % 3
		var coord := Vector2i(depth, -depth)
		var room: Dictionary = _room_metadata(coord, depth, "combat", "fire")
		var equipped: Dictionary = {}
		var inventory: Array = []
		if not equipment_ids.is_empty():
			var equipment_id: String = str(equipment_ids[context_index % equipment_ids.size()])
			inventory.append(equipment_id)
			if context_index % 2 == 0:
				equipped[GameDataScript.equipment_slot(equipment_id)] = equipment_id
		var run_state: Dictionary = {
			"mode": RunEngineScript.MODE_PRE_BATTLE,
			"seed": 18473 + context_index * 997,
			"current_room": coord,
			"rooms": {"%d,%d" % [coord.x, coord.y]: room},
			"pre_battle_travel_dir": directions[context_index % directions.size()],
			"player_hp": 35,
			"player_max_hp": 50,
			"deck_cards": ["quick_stab", "quick_stab"],
			"equipment_inventory": inventory,
			"equipped_equipment": equipped,
			"collected_equipment": equipment_ids.duplicate() if context_index % 5 == 0 else [],
			"equipment_drop_misses": 99 if context_index % 3 == 0 else 0,
			"progression": {"level": 1, "skill_ids": ["true_bearing"] if context_index % 2 == 0 else []},
		}
		if context_index % 2 == 0:
			var start_tiles: Array[Vector2i] = candidate_engine.pre_battle_start_tiles(run_state)
			if not start_tiles.is_empty():
				run_state["pre_battle_start"] = start_tiles[start_tiles.size() - 1]
		var before: Dictionary = run_state.duplicate(true)
		var actual: Dictionary = candidate_engine.pre_battle_preview_state(run_state)
		var expected: Dictionary = original_engine.pre_battle_preview_state(run_state)
		expect.call(not actual.is_empty(), "Pre-battle terrain parity fixture %d must produce combat" % context_index)
		expect.call(actual == expected, "Complete pre-battle state should match original terrain with gear/pity/start context %d" % context_index)
		expect.call(candidate_generator.final_rng_state == original_generator.final_rng_state, "Pre-battle layout RNG should match with gear/pity/start context %d" % context_index)
		expect.call(run_state == before, "Pre-battle terrain generation should not mutate source state for context %d" % context_index)


static func _grid_from_rows(rows: Array) -> Array:
	var grid: Array = []
	for row_var: Variant in rows:
		var row_text: String = str(row_var)
		var row: Array = []
		for index: int in range(row_text.length()):
			row.append("wall" if row_text[index] == "#" else "door" if row_text[index] == "D" else "pillar" if row_text[index] == "P" else "stone")
		grid.append(row)
	return grid


static func _all_candidates(grid: Array) -> Array[Vector2i]:
	var result: Array[Vector2i]
	for y: int in range(grid.size()):
		for x: int in range((grid[y] as Array).size()):
			result.append(Vector2i(x, y))
	result.append(Vector2i(-1, -1))
	result.append(Vector2i(99, 99))
	return result


static func _tile_lookup(tiles: Array) -> Dictionary:
	var result: Dictionary = {}
	for tile: Vector2i in tiles:
		result[tile] = true
	return result


static func _travel_directions() -> Array[Vector2i]:
	var result: Array[Vector2i]
	result.append(Vector2i.ZERO)
	result.append(Vector2i.UP)
	result.append(Vector2i.RIGHT)
	result.append(Vector2i.DOWN)
	result.append(Vector2i.LEFT)
	return result


static func _room_metadata(coord: Vector2i, depth: int, room_type: String, element: String) -> Dictionary:
	var connections: Array = []
	for direction: Vector2i in _travel_directions():
		if direction != Vector2i.ZERO:
			connections.append({"door_dir": direction, "coord": coord + direction, "kind": "outward"})
	return {"coord": coord, "depth": depth, "type": room_type, "element": element, "connections": connections, "npcs": []}
