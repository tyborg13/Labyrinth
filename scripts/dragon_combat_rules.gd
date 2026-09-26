extends RefCounted

const Paths = preload("res://scripts/path_utils.gd")
const Committed = preload("res://scripts/guardian_combat_rules.gd")
const Surfaces = preload("res://scripts/board_surface_rules.gd")

static func declare(engine: RefCounted, state: Dictionary, index: int, intents: Array) -> Dictionary:
	var enemy: Dictionary = state["enemies"][index]
	if bool((enemy.get("intent",{}) as Dictionary).get("restore_braziers",false)):
		for brazier: Dictionary in state.get("guardian_braziers",[]): brazier["lit"] = true
		Surfaces.record_event(state,{"kind":"dragon_light_restored","source":{"actor_kind":"enemy","actor_id":enemy["id"]}})
	var cycle: int = int(enemy.get("dragon_cycle", -1)) + 1
	enemy["dragon_cycle"] = cycle
	var intent: Dictionary = (intents[posmod(cycle, intents.size())] as Dictionary).duplicate(true)
	for action: Dictionary in intent.get("actions", []):
		match str(action.get("type", "")):
			"cinder_marks": action["declared_tiles"] = kindle_tiles(engine, state, enemy, int(action.get("count", 3)))
			"raise_terrain": action["declared_tiles"] = spire_tiles(engine,state,enemy,int(action.get("count",2)))
			"lightning_strikes": action["declared_tiles"] = storm_tiles(engine,state,enemy,int(action.get("count",3)))
			"umbra_eclipse":
				var braziers: Array = state.get("guardian_braziers",[])
				if not braziers.is_empty():
					var previous: int = int(enemy.get("eclipse_brazier_id", -1))
					var choices: Array = braziers.filter(func(brazier: Dictionary) -> bool: return int(brazier["id"]) != previous)
					# The opening preserves the nearby refuge; later Eclipses
					# alternate by identity, including after a save/resume.
					choices.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return Paths.manhattan(a["pos"], state["player"]["pos"]) > Paths.manhattan(b["pos"], state["player"]["pos"]))
					if not choices.is_empty():
						action["brazier_id"] = int(choices[0]["id"])
						enemy["eclipse_brazier_id"] = action["brazier_id"]
	intent = engine._surface_prepare_enemy_intent(state, enemy, intent)
	return Committed.commit(engine, state, index, intent)

static func kindle_tiles(engine: RefCounted, state: Dictionary, enemy: Dictionary, count: int) -> Array[Vector2i]:
	var target: Vector2i = state["player"]["pos"]
	var edge: Vector2i = engine._closest_enemy_tile_to(enemy, target)
	var direction: Vector2i = engine._cardinal_direction(target - edge)
	if direction == Vector2i.ZERO: direction = Vector2i.LEFT
	var side := Vector2i(-direction.y, direction.x)
	var body: Array[Vector2i] = engine._enemy_footprint_tiles(enemy)
	var front: Array[Vector2i] = []
	var nearest_corner: Vector2i = edge
	var far_corner: Vector2i = edge
	var target_side: int = (target.x * side.x + target.y * side.y)
	var nearest_distance: int = 1000
	var far_distance: int = -1
	for tile: Vector2i in body:
		if body.has(tile + direction): continue
		front.append(tile + direction)
		var distance: int = absi((tile.x * side.x + tile.y * side.y) - target_side)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_corner = tile
		if distance > far_distance:
			far_distance = distance
			far_corner = tile
	var outward: Vector2i = side if (nearest_corner.x * side.x + nearest_corner.y * side.y) > (far_corner.x * side.x + far_corner.y * side.y) else -side
	# Kindle occupies the two melee approach cells and the nearest corner's
	# lateral exit. The opposite flank stays open. Crownfire can catch the
	# dragon, so pushing it away buys space at the cost of its self-damage.
	var candidates: Array[Vector2i] = front.duplicate()
	candidates.append(nearest_corner + outward)
	candidates.append(far_corner - outward)
	var result: Array[Vector2i] = []
	for tile: Vector2i in candidates:
		if result.size() >= count: break
		if not Paths.is_passable(state["grid"], tile): continue
		if engine._terrain_index_at_tile(state, tile) >= 0 or engine._trap_index_at_tile(state, tile) >= 0: continue
		if body.has(tile) or result.has(tile): continue
		result.append(tile)
	return result

static func spire_tiles(engine: RefCounted, state: Dictionary, enemy: Dictionary, count: int) -> Array[Vector2i]:
	var preview: Dictionary = state.duplicate(true)
	var result: Array[Vector2i] = []
	var choices: Array[Vector2i] = Committed.candidates(engine,state,enemy["pos"],state["player"]["pos"],5)
	for tile: Vector2i in choices:
		if result.size() >= count or engine._dragon_spires(preview).size() >= 2: break
		if engine._enemy_distance_to_tile(enemy,tile) < 1: continue
		if not spire_preserves_routes(engine, preview, enemy, tile): continue
		preview["terrain"].append({"kind":engine.DRAGON_SPIRE_KIND, "pos":tile, "hp":4})
		result.append(tile)
	return result

static func spire_preserves_routes(engine: RefCounted, state: Dictionary, enemy: Dictionary, tile: Vector2i) -> bool:
	if not Committed.preserves_routes(engine, state, tile): return false
	var preview: Dictionary = state.duplicate(true)
	preview["terrain"].append({"kind":engine.DRAGON_SPIRE_KIND, "pos":tile, "hp":4})
	var blockers: Dictionary = engine._enemy_path_blockers(preview, enemy, true, false)
	var exits: int = 0
	for direction: Vector2i in Paths.DIRS_4:
		if engine._enemy_can_occupy_anchor(preview, enemy, enemy["pos"] + direction, blockers): exits += 1
	return exits >= 2

static func storm_tiles(engine: RefCounted, state: Dictionary, enemy: Dictionary, count: int) -> Array[Vector2i]:
	var target: Vector2i = state["player"]["pos"]
	var direction: Vector2i = engine._cardinal_direction(target-engine._closest_enemy_tile_to(enemy,target))
	if direction == Vector2i.ZERO: direction = Vector2i.LEFT
	var side := Vector2i(-direction.y,direction.x)
	var choices: Array[Vector2i] = [target,target+side*2,target-side*2,target+direction*2,target-direction*2]
	var result: Array[Vector2i] = []
	for tile: Vector2i in choices:
		if result.size() >= count: break
		if not Paths.is_passable(state["grid"],tile) or engine._enemy_index_at_tile(state,tile)>=0: continue
		result.append(tile)
	return result

static func eclipse_preview(state: Dictionary, action: Dictionary) -> Dictionary:
	var preview: Dictionary = state.duplicate(true)
	for brazier: Dictionary in preview.get("guardian_braziers",[]):
		if int(brazier["id"]) == int(action.get("brazier_id",-1)): brazier["lit"] = false
	return preview
