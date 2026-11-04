extends RefCounted

const TypedArrays = preload("res://scripts/typed_arrays.gd")
const Paths = preload("res://scripts/path_utils.gd")
const Committed = preload("res://scripts/guardian_combat_rules.gd")
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const Fields = preload("res://scripts/dragon_pressure_fields.gd")

static func initialize(engine: RefCounted, state: Dictionary) -> void:
	if not state.get("battlefield_rule", {}).is_empty(): return
	for enemy: Dictionary in state.get("enemies", []):
		var key: String = str(engine.GameData.enemy_def(str(enemy.get("type", ""))).get("battlefield_instance", ""))
		if key.is_empty(): continue
		engine.BattlefieldRules.install(engine, state, engine.BattlefieldRules.instance_for(key, int(enemy["id"])))
		return

# Only dragon-owned Outcrops fuel Faultline. A player Outcrop with the same
# numeric actor id is not the source's stone.
static func owned_stone(state: Dictionary, owner_id: int = -1) -> Array[Dictionary]:
	var sources: Dictionary = {}
	for enemy: Dictionary in state.get("enemies", []):
		if str(enemy.get("type", "")) == "tharokh": sources[int(enemy["id"])] = true
	var result: Array[Dictionary]
	for terrain: Dictionary in state.get("terrain", []):
		var id: int = int(terrain.get("owner_id", -1))
		if str(terrain.get("kind", "")) == "crag_outcrop" and str(terrain.get("owner_kind", "")) == "enemy" and sources.has(id) and (owner_id < 0 or id == owner_id) and int(terrain.get("hp", 0)) > 0: result.append(terrain)
	return result

static func migrate_save(value: Variant) -> void:
	if value is Array:
		for child: Variant in value: migrate_save(child)
	elif value is Dictionary:
		value.erase("dive_wake")
		if str(value.get("record_trail", "")) == "dive_wake": value.erase("record_trail")
		if str(value.get("kind", "")) == "dragon_spire":
			value["kind"] = "crag_outcrop"
			value["owner_kind"] = "enemy"
		if str(value.get("type", "")) in ["vyraketh", "tharokh", "iskaldra", "vaeloryx", "zekarion", "noctyrax"]:
			var intent: Dictionary = value.get("intent", {})
			var kept: Array[Dictionary]
			for action: Dictionary in intent.get("actions", []):
				if str(action.get("committed_shape", "")) in ["surface_snapshot", "trail_snapshot"] or str(action.get("field_anchor", "")) == "player" or str(action.get("type", "")) == "raise_terrain": continue
				if str(value["type"]) == "tharokh" and str(action.get("type", "")) == "terrain_burst":
					if str(intent.get("id", "")) != "faultline": continue
					if int(action.get("radius", 0)) != 1: action["radius"] = 1
				action.erase("record_trail")
				kept.append(action)
			if intent.has("actions"): intent["actions"] = kept
			# Removed riders may have been the only reason this saved intent held
			# a plan. Keep retained geometry, but do not suppress live movement.
			if not Committed.has_authored_actions(intent): intent.erase("committed_plan")
		for key: Variant in value:
			if str(key) in ["analytics", "analytics_context", "analytics_events", "progression_analytics_outbox", "completed_run_results", "last_run_result", "log", "surface_events", "elemental_source", "rubble_source"]: continue
			migrate_save(value[key])

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
	var front: Array[Vector2i]
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
	var candidates: Array[Vector2i] = TypedArrays.vector2i(front.duplicate())
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

static func spire_preserves_routes(engine: RefCounted, state: Dictionary, enemy: Dictionary, tile: Vector2i) -> bool:
	if not Committed.preserves_routes(engine, state, tile): return false
	var preview: Dictionary = state.duplicate(true)
	preview["terrain"].append({"kind":"crag_outcrop", "pos":tile, "hp":4})
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
	var choices: Array[Vector2i] = TypedArrays.vector2i([target,target+side*2,target-side*2,target+direction*2,target-direction*2])
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

# Noctyrax's relight-on-step, also enabled by a room's `brazier_relight_on_step`
# (Last Light, spx-08). The dragon's own fight keeps its exact event.
static func relight_brazier(state: Dictionary) -> void:
	var shadow_dragon_alive: bool = false
	for enemy: Dictionary in state.get("enemies", []):
		if str(enemy.get("type", "")) == "noctyrax" and int(enemy.get("hp", 0)) > 0:
			shadow_dragon_alive = true
			break
	var room_enabled: bool = bool(state.get("brazier_relight_on_step", false))
	if not shadow_dragon_alive and not room_enabled: return
	var position: Vector2i = state["player"]["pos"]
	for brazier: Dictionary in state.get("guardian_braziers", []):
		if brazier.get("pos", Vector2i(-1, -1)) != position or bool(brazier.get("lit", true)): continue
		brazier["lit"] = true
		Surfaces.record_event(state, {"kind": "dragon_light_restored" if shadow_dragon_alive else "brazier_relit", "brazier_id": int(brazier["id"]), "tile": position, "trigger": "player_arrival", "source": {"actor_kind": "player"}})
