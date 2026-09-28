extends RefCounted

const Paths = preload("res://scripts/path_utils.gd")
const Committed = preload("res://scripts/guardian_combat_rules.gd")
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const Fields = preload("res://scripts/dragon_pressure_fields.gd")

static func declare(engine: RefCounted, state: Dictionary, index: int, intents: Array) -> Dictionary:
	var enemy: Dictionary = state["enemies"][index]
	# Honor a previously saved first-revision Night Coil warning once. Current
	# data never sets this flag; all newly declared Coils require player relight.
	if str(enemy.get("type","")) == "noctyrax" and bool((enemy.get("intent",{}) as Dictionary).get("restore_braziers",false)):
		var restored: Array[Vector2i]
		for brazier: Dictionary in state.get("guardian_braziers",[]):
			if not bool(brazier.get("lit",true)): restored.append(brazier["pos"])
			brazier["lit"] = true
		Surfaces.record_event(state,{"kind":"dragon_light_restored","tiles":restored,"trigger":"legacy_saved_night_coil","source":{"actor_kind":"enemy","actor_id":enemy["id"]}})
	var cycle: int = int(enemy.get("dragon_cycle", -1)) + 1
	enemy["dragon_cycle"] = cycle
	var intent: Dictionary = (intents[posmod(cycle, intents.size())] as Dictionary).duplicate(true)
	for action: Dictionary in intent.get("actions", []):
		match str(action.get("type", "")):
			"cinder_marks":
				if str(action.get("placement", "")) == "band": action["declared_tiles"] = Fields.band_tiles(engine, state, enemy, int(action.get("count", 7)))
				else: action["declared_tiles"] = meteor_tiles(engine, state, enemy, int(action.get("count", 5))) if str(action.get("placement", "")) == "scattered" else kindle_tiles(engine, state, enemy, int(action.get("count", 3)))
			"raise_terrain": action["declared_tiles"] = spire_tiles(engine,state,enemy,int(action.get("count",4)),int(action.get("maximum",4)),str(action.get("placement","")) == "paired")
			"lightning_strikes": action["declared_tiles"] = Fields.band_tiles(engine,state,enemy,int(action.get("count",7))) if str(action.get("placement","")) == "band" else storm_tiles(engine,state,enemy,int(action.get("count",3)))
		if bool(action.get("snuff_brazier",false)):
			var braziers: Array = state.get("guardian_braziers",[])
			if not braziers.is_empty():
				var previous: int = int(enemy.get("eclipse_brazier_id", -1))
				var choices: Array = braziers.filter(func(brazier: Dictionary) -> bool: return int(brazier["id"]) != previous)
				# The opening preserves the nearby refuge; later Coils
				# alternate by identity, including after a save/resume.
				choices.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return Paths.manhattan(a["pos"], state["player"]["pos"]) > Paths.manhattan(b["pos"], state["player"]["pos"]))
				if bool(action.get("snuff_nearest",false)):
					choices = braziers.duplicate()
					choices.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return Paths.manhattan(a["pos"], state["player"]["pos"]) < Paths.manhattan(b["pos"], state["player"]["pos"]))
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
	var result: Array[Vector2i]
	for tile: Vector2i in candidates:
		if result.size() >= count: break
		if not Paths.is_passable(state["grid"], tile): continue
		if engine._terrain_index_at_tile(state, tile) >= 0 or engine._trap_index_at_tile(state, tile) >= 0: continue
		if body.has(tile) or result.has(tile): continue
		result.append(tile)
	return result

static func meteor_tiles(engine: RefCounted, state: Dictionary, enemy: Dictionary, count: int) -> Array[Vector2i]:
	var target: Vector2i = state["player"]["pos"]
	var result: Array[Vector2i] = kindle_tiles(engine, state, enemy, mini(2, count))
	if result.size() < count and Surfaces.can_place(state, target) and not result.has(target): result.append(target)
	var candidates: Array[Vector2i] = engine._all_passable_tiles(state)
	while result.size() < count:
		var selected := Vector2i(-1, -1)
		var best_score: int = -99999
		for tile: Vector2i in candidates:
			if result.has(tile) or not Surfaces.can_place(state, tile) or engine._enemy_index_at_tile(state, tile) >= 0: continue
			if engine._enemy_distance_to_tile(enemy, tile) > 4: continue
			var separation: int = 99
			for existing: Vector2i in result: separation = mini(separation, Paths.manhattan(existing, tile))
			var score: int = mini(separation, 4) * 10 - Paths.manhattan(target, tile)
			if score > best_score:
				best_score = score
				selected = tile
		if selected.x < 0: break
		result.append(selected)
	return result

static func spire_tiles(engine: RefCounted, state: Dictionary, enemy: Dictionary, count: int, maximum: int = 4, paired: bool = false) -> Array[Vector2i]:
	var preview: Dictionary = state.duplicate(true)
	var result: Array[Vector2i]
	var choices: Array[Vector2i] = Committed.candidates(engine,state,enemy["pos"],state["player"]["pos"],6)
	var approach: Vector2i = _approach_spire_tile(engine, preview, enemy, choices)
	while result.size() < count and engine._dragon_spires(preview).size() < maximum:
		var selected: Vector2i = approach if result.is_empty() else Vector2i(-1, -1)
		var best_score: int = -99999
		if selected.x < 0:
			for tile: Vector2i in choices:
				if result.has(tile) or engine._enemy_distance_to_tile(enemy,tile) < 1: continue
				if not spire_preserves_routes(engine, preview, enemy, tile): continue
				var separation: int = 4
				for existing: Dictionary in engine._dragon_spires(preview): separation = mini(separation, Paths.manhattan(existing["pos"], tile))
				# Spread the four future radius-2 bursts across routes. A cluster of
				# four rocks is still a single cheap dodge, despite its larger count.
				var score: int = separation * 10 - Paths.manhattan(tile, state["player"]["pos"])
				if paired:
					# Stagger paired pressure across the approach. Radius-one pulses
					# overlap without putting all four rocks in one incidental Sweep.
					var preferred_gap: int = 2 if result.size() % 2 == 1 else 4
					score = -absi(separation - preferred_gap) * 20 - Paths.manhattan(tile, state["player"]["pos"]) * 3
				if score > best_score:
					best_score = score
					selected = tile
		if selected.x < 0: break
		preview["terrain"].append({"kind":engine.DRAGON_SPIRE_KIND, "pos":selected, "hp":4})
		result.append(selected)
	return result

static func _approach_spire_tile(engine: RefCounted, state: Dictionary, enemy: Dictionary, choices: Array[Vector2i]) -> Vector2i:
	var target: Vector2i = state["player"]["pos"]
	if engine._enemy_distance_to_tile(enemy, target) < 3 or not engine._dragon_spires(state).is_empty(): return Vector2i(-1, -1)
	var selected := Vector2i(-1, -1)
	var nearest_body: int = 99999
	# At range, reserve one approach flank before spreading the other spires.
	# The native western approach otherwise cleared its only nearby rock as
	# incidental boss damage. Close combat retains the existing placement score.
	for tile: Vector2i in choices:
		if absi(tile.x - target.x) != 1 or absi(tile.y - target.y) != 1: continue
		var body_distance: int = engine._enemy_distance_to_tile(enemy, tile)
		if body_distance < 1 or body_distance >= nearest_body: continue
		if not spire_preserves_routes(engine, state, enemy, tile): continue
		selected = tile
		nearest_body = body_distance
	return selected

static func spire_preserves_routes(engine: RefCounted, state: Dictionary, enemy: Dictionary, tile: Vector2i) -> bool:
	if not Committed.preserves_routes(engine, state, tile): return false
	var preview: Dictionary = state.duplicate(true)
	preview["terrain"].append({"kind":engine.DRAGON_SPIRE_KIND, "pos":tile, "hp":4})
	# Structural exits ignore temporary actors. Actual placement still rejects
	# occupied marks; a nearby player must not cancel every held spire.
	var blockers: Dictionary = engine._occupied_terrain_tiles(preview)
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
	var result: Array[Vector2i]
	for tile: Vector2i in choices:
		if result.size() >= count: break
		if not Paths.is_passable(state["grid"],tile) or engine._enemy_index_at_tile(state,tile)>=0: continue
		result.append(tile)
	return result

# Persisted first-revision Eclipse intents retain their originally declared
# snuff. New Eclipse data has no snuff flag: Night Coil supplies the reaction gap.
static func eclipse_preview(state: Dictionary, action: Dictionary) -> Dictionary:
	if not bool(action.get("snuff_brazier",false)): return state
	var preview: Dictionary = state.duplicate(true)
	for brazier: Dictionary in preview.get("guardian_braziers",[]):
		if int(brazier["id"]) == int(action.get("brazier_id",-1)): brazier["lit"] = false
	return preview

static func relight_brazier(state: Dictionary) -> void:
	var shadow_dragon_alive: bool = false
	for enemy: Dictionary in state.get("enemies", []):
		if str(enemy.get("type", "")) == "noctyrax" and int(enemy.get("hp", 0)) > 0:
			shadow_dragon_alive = true
			break
	if not shadow_dragon_alive: return
	var position: Vector2i = state["player"]["pos"]
	for brazier: Dictionary in state.get("guardian_braziers", []):
		if brazier.get("pos", Vector2i(-1, -1)) != position or bool(brazier.get("lit", true)): continue
		brazier["lit"] = true
		Surfaces.record_event(state, {"kind": "dragon_light_restored", "brazier_id": int(brazier["id"]), "tile": position, "trigger": "player_arrival", "source": {"actor_kind": "player"}})
